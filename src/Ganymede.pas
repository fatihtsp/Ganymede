{===============================================================================
  Ganymede™ - Embeddable Native Scripting Engine

  Copyright © 2026-present tinyBigGAMES™ LLC
  All Rights Reserved.

  See LICENSE for license information
===============================================================================}

unit Ganymede;

{$I Ganymede.Defines.inc}

interface

uses
  System.SysUtils,
  System.IOUtils,
  System.Generics.Collections,
  System.Classes,
  Ganymede.Utils,
  Ganymede.Resources,
  Ganymede.Lexer,
  Ganymede.Parser,
  Ganymede.Semantics,
  Ganymede.Emitter,
  Ganymede.Native;

const
  GNY_SCRIPT_EXT = 'pxs';

  //--- Value type aliases (re-exported from Ganymede.Types) -------------------
  gvtVoid    = TGnyValueType.gvtVoid;
  gvtInt8    = TGnyValueType.gvtInt8;
  gvtInt16   = TGnyValueType.gvtInt16;
  gvtInt32   = TGnyValueType.gvtInt32;
  gvtInt64   = TGnyValueType.gvtInt64;
  gvtUInt8   = TGnyValueType.gvtUInt8;
  gvtUInt16  = TGnyValueType.gvtUInt16;
  gvtUInt32  = TGnyValueType.gvtUInt32;
  gvtUInt64  = TGnyValueType.gvtUInt64;
  gvtFloat32 = TGnyValueType.gvtFloat32;
  gvtFloat64 = TGnyValueType.gvtFloat64;
  gvtPointer = TGnyValueType.gvtPointer;

type
  { TGnyOptLevel }
  TGnyOptLevel = (
    olNone,    // No optimization
    olBasic,   // Basic optimizations
    olFull     // Full optimizations
  );

  { TGnyValue — tagged return value from script invocation }
  TGnyValue = record
    ValueType: TGnyValueType;
    case Byte of
      0: (AsInt8: Int8);
      1: (AsInt16: Int16);
      2: (AsInt32: Int32);
      3: (AsInt64: Int64);
      4: (AsUInt8: UInt8);
      5: (AsUInt16: UInt16);
      6: (AsUInt32: UInt32);
      7: (AsUInt64: UInt64);
      8: (AsFloat32: Single);
      9: (AsFloat64: Double);
      10: (AsPointer: Pointer);
  end;

  { TGnyHostImport — stored host function registration for replay on recompile }
  TGnyHostImport = record
    FuncName: string;
    HostAddr: Pointer;
    ParamTypes: TArray<TGnyValueType>;
    ReturnType: TGnyValueType;
  end;

  { TGnyLibImport — stored static lib import for replay on recompile }
  TGnyLibImport = record
    LibName: string;
    FuncName: string;
    ParamTypes: TArray<TGnyValueType>;
    ReturnType: TGnyValueType;
    VarArgs: Boolean;
    Linkage: TGnyLinkage;
  end;

  { TGnyDllImport — stored DLL import for replay on recompile }
  TGnyDllImport = record
    DllName: string;
    FuncName: string;
    ParamTypes: TArray<TGnyValueType>;
    ReturnType: TGnyValueType;
    VarArgs: Boolean;
    Linkage: TGnyLinkage;
  end;

  { TGanymede }
  TGanymede = class(TGnyBaseObject)
  private
    FLexer: TGnyScriptLexer;
    FParser: TGnyScriptParser;
    FSemantics: TGnyScriptSemantics;
    FEmitter: TGnyScriptEmitter;
    FBackend: TGnyNativeBackend;
    FJIT: TGnyJIT;
    FHostImports: TList<TGnyHostImport>;
    FLibImports: TList<TGnyLibImport>;
    FDllImports: TList<TGnyDllImport>;
    FLibPaths: TStringList;
    FSource: string;
    FFilename: string;
    FOptimizationLevel: TGnyOptLevel;
    FOutputPath: string;
    FDumpIR: Boolean;
    function GetCompiled(): Boolean;
    function ValueTypeToStr(const AType: TGnyValueType): string;
    procedure ResetBackend();

  public
    constructor Create(); override;
    destructor Destroy(); override;

    // Override to propagate to all child components
    procedure SetStatusCallback(const ACallback: TGnyStatusCallback; const AUserData: Pointer = nil); override;

    // Load source
    function LoadFromString(const ASource: string;
      const AFilename: string = ''): TGanymede;
    function LoadFromFile(const AFilename: string): TGanymede;

    // Compile — lex + parse + semantic + emit + build (routes by module kind)
    function Compile(): Boolean;

    // Convenience — set output path then compile (for lib/exe modules)
    function CompileToLib(const AOutputPath: string): Boolean;

    // Set output path for lib/exe targets (derived from filename if not set)
    function SetOutputPath(const APath: string): TGanymede;

    // Register a host function pointer for JIT calls
    function ImportHost(const AFuncName: string;
      const AHostAddr: Pointer;
      const AParams: array of TGnyValueType;
      const AReturn: TGnyValueType = gvtVoid): TGanymede;

    // Register a static library import for JIT calls
    function ImportLib(const ALibName: string;
      const AFuncName: string;
      const AParams: array of TGnyValueType;
      const AReturn: TGnyValueType = gvtVoid;
      const AVarArgs: Boolean = False;
      const ALinkage: TGnyLinkage = plC): TGanymede;

    // Register a DLL import for JIT calls
    function ImportDll(const ADllName: string;
      const AFuncName: string;
      const AParams: array of TGnyValueType;
      const AReturn: TGnyValueType = gvtVoid;
      const AVarArgs: Boolean = False;
      const ALinkage: TGnyLinkage = plC): TGanymede;

    // Add a library search path
    function AddLibPath(const APath: string): TGanymede;

    // Symbol access (forwarded from JIT)
    function GetSymbol(const AName: string): Pointer;
    function HasSymbol(const AName: string): Boolean;
    function GetSymbolNames(): TArray<string>;

    // Invocation — single unified method
    function Invoke(const AName: string;
      const AArgs: array of const;
      const AReturn: TGnyValueType = gvtVoid): TGnyValue;

    // Debug - report heap allocations/frees/leaks (opt level 0 only)
    procedure ReportLeaks();

    // Debug — SSA IR dump (call after Compile, before running)
    procedure SetDumpIR(const AValue: Boolean);
    function GetSSADump(): string;

    // Print all errors/warnings/hints with color-coded severity
    procedure PrintErrors();

    // State
    property Compiled: Boolean read GetCompiled;

    // Internal access (for API registration, advanced use)
    property Backend: TGnyNativeBackend read FBackend;

    // Optimization level
    procedure SetOptimizationLevel(const ALevel: TGnyOptLevel);
  end;

implementation

uses
  Ganymede.IR,
  Ganymede.Types;

{ TGanymede }

constructor TGanymede.Create();
begin
  inherited Create();
  try
    FLexer := TGnyScriptLexer.Create();
    FLexer.SetErrors(FErrors);

    FParser := TGnyScriptParser.Create();
    FParser.SetErrors(FErrors);

    FSemantics := TGnyScriptSemantics.Create();
    FSemantics.SetErrors(FErrors);

    FEmitter := TGnyScriptEmitter.Create();
    FEmitter.SetErrors(FErrors);

    FBackend := TGnyNativeBackend.Create();
    FBackend.SetErrors(FErrors);

    FHostImports := TList<TGnyHostImport>.Create();
    FLibImports := TList<TGnyLibImport>.Create();
    FDllImports := TList<TGnyDllImport>.Create();
    FLibPaths := TStringList.Create();
    FLibPaths.CaseSensitive := False;
    FLibPaths.Duplicates := dupIgnore;
  except
    on E: Exception do
    begin
      FErrors.Add(esFatal, '', RSFatalInternalError, [E.Message]);
      Exit;
    end;
  end;

  FJIT := nil;
  FOutputPath := 'output';
  FDumpIR := False;
end;

destructor TGanymede.Destroy();
begin
  FreeAndNil(FJIT);
  FreeAndNil(FLibPaths);
  FreeAndNil(FDllImports);
  FreeAndNil(FLibImports);
  FreeAndNil(FHostImports);
  FreeAndNil(FBackend);
  FreeAndNil(FEmitter);
  FreeAndNil(FSemantics);
  FreeAndNil(FParser);
  FreeAndNil(FLexer);
  inherited Destroy();
end;

procedure TGanymede.SetStatusCallback(const ACallback: TGnyStatusCallback;
  const AUserData: Pointer);
begin
  inherited SetStatusCallback(ACallback, AUserData);
  if Assigned(FLexer) then
    FLexer.SetStatusCallback(ACallback, AUserData);
  if Assigned(FParser) then
    FParser.SetStatusCallback(ACallback, AUserData);
  if Assigned(FSemantics) then
    FSemantics.SetStatusCallback(ACallback, AUserData);
  if Assigned(FEmitter) then
    FEmitter.SetStatusCallback(ACallback, AUserData);
  if Assigned(FBackend) then
    FBackend.SetStatusCallback(ACallback, AUserData);
end;

function TGanymede.LoadFromString(const ASource: string;
  const AFilename: string): TGanymede;
var
  LFilename: string;
begin
  if not AFilename.IsEmpty then
    LFilename := TPath.ChangeExtension(AFilename, GNY_SCRIPT_EXT)
  else
    LFilename := '';
  FSource := ASource;
  FFilename := LFilename;
  Result := Self;
end;

function TGanymede.LoadFromFile(const AFilename: string): TGanymede;
var
  LFilename: string;
begin
  try
    if not AFilename.IsEmpty then
      LFilename := TPath.ChangeExtension(AFilename, GNY_SCRIPT_EXT)
    else
      LFilename := '';
    FSource := TFile.ReadAllText(AFilename);
    FFilename := LFilename;
  except
    on E: Exception do
    begin
      FErrors.Add(esFatal, '', RSFatalFileReadError, [AFilename, E.Message]);
    end;
  end;
  Result := Self;
end;

function TGanymede.ImportHost(const AFuncName: string;
  const AHostAddr: Pointer; const AParams: array of TGnyValueType;
  const AReturn: TGnyValueType): TGanymede;
var
  LImport: TGnyHostImport;
  LI: Integer;
begin
  // Store for replay on recompile
  LImport := Default(TGnyHostImport);
  LImport.FuncName := AFuncName;
  LImport.HostAddr := AHostAddr;
  LImport.ReturnType := AReturn;
  SetLength(LImport.ParamTypes, Length(AParams));
  for LI := 0 to High(AParams) do
    LImport.ParamTypes[LI] := AParams[LI];
  FHostImports.Add(LImport);

  // Register on current backend
  FBackend.ImportHost(AFuncName, AHostAddr, AParams, AReturn);
  Result := Self;
end;

function TGanymede.ImportLib(const ALibName: string;
  const AFuncName: string; const AParams: array of TGnyValueType;
  const AReturn: TGnyValueType; const AVarArgs: Boolean;
  const ALinkage: TGnyLinkage): TGanymede;
var
  LImport: TGnyLibImport;
  LI: Integer;
begin
  // Store for replay on recompile
  LImport := Default(TGnyLibImport);
  LImport.LibName := ALibName;
  LImport.FuncName := AFuncName;
  LImport.ReturnType := AReturn;
  LImport.VarArgs := AVarArgs;
  LImport.Linkage := ALinkage;
  SetLength(LImport.ParamTypes, Length(AParams));
  for LI := 0 to High(AParams) do
    LImport.ParamTypes[LI] := AParams[LI];
  FLibImports.Add(LImport);

  // Register on current backend
  FBackend.ImportLib(ALibName, AFuncName, AParams, AReturn, AVarArgs, ALinkage);
  Result := Self;
end;

function TGanymede.ImportDll(const ADllName: string;
  const AFuncName: string; const AParams: array of TGnyValueType;
  const AReturn: TGnyValueType; const AVarArgs: Boolean;
  const ALinkage: TGnyLinkage): TGanymede;
var
  LImport: TGnyDllImport;
  LI: Integer;
begin
  LImport := Default(TGnyDllImport);
  LImport.DllName := ADllName;
  LImport.FuncName := AFuncName;
  LImport.ReturnType := AReturn;
  LImport.VarArgs := AVarArgs;
  LImport.Linkage := ALinkage;
  SetLength(LImport.ParamTypes, Length(AParams));
  for LI := 0 to High(AParams) do
    LImport.ParamTypes[LI] := AParams[LI];
  FDllImports.Add(LImport);

  FBackend.ImportDll(ADllName, AFuncName, AParams, AReturn, AVarArgs, ALinkage);
  Result := Self;
end;

function TGanymede.AddLibPath(const APath: string): TGanymede;
begin
  // Store for replay on recompile
  if FLibPaths.IndexOf(APath) < 0 then
    FLibPaths.Add(APath);

  // Register on current backend
  FBackend.AddLibPath(APath);
  Result := Self;
end;

procedure TGanymede.ResetBackend();
var
  LI: Integer;
  LHostImport: TGnyHostImport;
  LLibImport: TGnyLibImport;
  LDllImport: TGnyDllImport;
begin
  FreeAndNil(FJIT);
  FreeAndNil(FBackend);

  FBackend := TGnyNativeBackend.Create();
  FBackend.SetErrors(FErrors);
  if FStatusCallback.IsAssigned() then
    FBackend.SetStatusCallback(FStatusCallback.Callback, FStatusCallback.UserData);

  // Replay stored host imports onto fresh backend
  for LI := 0 to FHostImports.Count - 1 do
  begin
    LHostImport := FHostImports[LI];
    FBackend.ImportHost(LHostImport.FuncName, LHostImport.HostAddr,
      LHostImport.ParamTypes, LHostImport.ReturnType);
  end;

  // Replay stored lib imports onto fresh backend
  for LI := 0 to FLibImports.Count - 1 do
  begin
    LLibImport := FLibImports[LI];
    FBackend.ImportLib(LLibImport.LibName, LLibImport.FuncName,
      LLibImport.ParamTypes, LLibImport.ReturnType,
      LLibImport.VarArgs, LLibImport.Linkage);
  end;

  // Replay stored DLL imports onto fresh backend
  for LI := 0 to FDllImports.Count - 1 do
  begin
    LDllImport := FDllImports[LI];
    FBackend.ImportDll(LDllImport.DllName, LDllImport.FuncName,
      LDllImport.ParamTypes, LDllImport.ReturnType,
      LDllImport.VarArgs, LDllImport.Linkage);
  end;

  // Replay stored lib search paths
  for LI := 0 to FLibPaths.Count - 1 do
    FBackend.AddLibPath(FLibPaths[LI]);

  // Replay DumpIR flag
  if FDumpIR then
    FBackend.SetDumpIR(True);
end;

function TGanymede.ValueTypeToStr(const AType: TGnyValueType): string;
begin
  case AType of
    gvtVoid:    Result := 'void';
    gvtInt8:    Result := 'int8';
    gvtInt16:   Result := 'int16';
    gvtInt32:   Result := 'int32';
    gvtInt64:   Result := 'int64';
    gvtUInt8:   Result := 'uint8';
    gvtUInt16:  Result := 'uint16';
    gvtUInt32:  Result := 'uint32';
    gvtUInt64:  Result := 'uint64';
    gvtFloat32: Result := 'float32';
    gvtFloat64: Result := 'float64';
    gvtPointer: Result := 'pointer';
  else
    Result := 'void';
  end;
end;

function TGanymede.SetOutputPath(const APath: string): TGanymede;
begin
  FOutputPath := APath;
  Result := Self;
end;

function TGanymede.Compile(): Boolean;
var
  LIR: TIR;
  LImport: TIR.TIRImport;
  LI: Integer;
  LModuleKind: string;
  LOutputFile: string;
  LModuleName: string;
  LExt: string;
begin
  Result := False;

  // Reset backend for clean compilation (supports recompile)
  ResetBackend();
  FErrors.Clear();

  // Phase 1: Lex
  if not FLexer.Tokenize(FSource, FFilename) then
    Exit;

  // Phase 2: Parse
  if not FParser.Parse(FLexer.Tokens) then
    Exit;

  // Read module kind from AST (mem, lib, exe)
  LModuleKind := FParser.Nodes[FParser.Root].Extra;

  // Pre-register imported functions (from API/host) as known externals
  LIR := FBackend.GetIR();
  for LI := 0 to LIR.GetImportCount() - 1 do
  begin
    LImport := LIR.GetImport(LI);
    FSemantics.RegisterExtern(LImport.FuncName,
      Length(LImport.ParamTypes), ValueTypeToStr(LImport.ReturnType));
  end;

  // Phase 3: Semantic analysis
  if not FSemantics.Analyze(FParser.Nodes, FParser.Root) then
    Exit;

  // Apply optimization level
  FBackend.SetOptimizationLevel(Ord(FOptimizationLevel));

  // Phase 4: Emit to backend
  if not FEmitter.Emit(FParser.Nodes, FParser.Root, FBackend, FSemantics) then
    Exit;

  // Phase 5: Build — route by module kind
  if LModuleKind = 'mem' then
  begin
    // Compile to memory (JIT)
    FJIT := FBackend.BuildJIT();
    Result := FJIT <> nil;

    // Initialize console for UTF-8 output via runtime (idempotent)
    if Result and FJIT.HasSymbol('Gny_InitConsole') then
      Invoke('Gny_InitConsole', []);
  end
  else if (LModuleKind = 'lib') or (LModuleKind = 'exe') then
  begin
    // Resolve output file path
    if TPath.HasExtension(FOutputPath) then
    begin
      // FOutputPath is a full file path (set by CompileToLib convenience)
      LOutputFile := FOutputPath;
    end
    else
    begin
      // FOutputPath is a directory — derive filename from module name
      LModuleName := FParser.Nodes[FParser.Root].Text;
      if LModuleKind = 'lib' then
        LExt := '.lib'
      else
        LExt := '.exe';
      LOutputFile := TPath.Combine(FOutputPath, LModuleName + LExt);
    end;

    // Ensure output directory exists
    TGnyUtils.CreateDirInPath(LOutputFile);

    if LModuleKind = 'lib' then
      FBackend.TargetLib(LOutputFile)
    else
      FBackend.TargetExe(LOutputFile);

    Result := FBackend.Build(False);
  end
  else
  begin
    FErrors.Add(esError, '', 'Unknown module kind: %s', [LModuleKind]);
    Exit;
  end;
end;

function TGanymede.CompileToLib(const AOutputPath: string): Boolean;
var
  LSavedPath: string;
begin
  // Convenience wrapper — temporarily set the full output path, compile, restore
  LSavedPath := FOutputPath;
  FOutputPath := AOutputPath;
  try
    Result := Compile();
  finally
    FOutputPath := LSavedPath;
  end;
end;

function TGanymede.GetCompiled(): Boolean;
begin
  Result := FJIT <> nil;
end;

function TGanymede.GetSymbol(const AName: string): Pointer;
begin
  if FJIT <> nil then
    Result := FJIT.GetSymbol(AName)
  else
    Result := nil;
end;

function TGanymede.HasSymbol(const AName: string): Boolean;
begin
  if FJIT <> nil then
    Result := FJIT.HasSymbol(AName)
  else
    Result := False;
end;

function TGanymede.GetSymbolNames(): TArray<string>;
begin
  if FJIT <> nil then
    Result := FJIT.GetSymbolNames()
  else
    Result := nil;
end;

function TGanymede.Invoke(const AName: string;
  const AArgs: array of const;
  const AReturn: TGnyValueType): TGnyValue;
var
  LInt: Int64;
  LFloat: Double;
begin
  Result := Default(TGnyValue);
  Result.ValueType := AReturn;

  if FJIT = nil then
    Exit;

  case AReturn of
    gvtFloat32:
    begin
      LFloat := FJIT.InvokeFloat(AName, AArgs);
      Result.AsFloat32 := Single(LFloat);
    end;

    gvtFloat64:
      Result.AsFloat64 := FJIT.InvokeFloat(AName, AArgs);

  else
    LInt := FJIT.Invoke(AName, AArgs);
    case AReturn of
      gvtInt8:    Result.AsInt8 := Int8(LInt);
      gvtInt16:   Result.AsInt16 := Int16(LInt);
      gvtInt32:   Result.AsInt32 := Int32(LInt);
      gvtInt64:   Result.AsInt64 := LInt;
      gvtUInt8:   Result.AsUInt8 := UInt8(LInt);
      gvtUInt16:  Result.AsUInt16 := UInt16(LInt);
      gvtUInt32:  Result.AsUInt32 := UInt32(LInt);
      gvtUInt64:  Result.AsUInt64 := UInt64(LInt);
      gvtPointer: Result.AsPointer := Pointer(LInt);
    else
      Result.AsInt64 := LInt;
    end;
  end;
end;

procedure TGanymede.SetOptimizationLevel(const ALevel: TGnyOptLevel);
begin
  FOptimizationLevel := ALevel;
end;

procedure TGanymede.ReportLeaks();
begin
  if HasSymbol('Gny_ReportLeaks') then
    Invoke('Gny_ReportLeaks', []);
end;

procedure TGanymede.SetDumpIR(const AValue: Boolean);
begin
  FDumpIR := AValue;
  FBackend.SetDumpIR(AValue);
end;

function TGanymede.GetSSADump(): string;
begin
  Result := FBackend.GetSSADump();
end;

procedure TGanymede.PrintErrors();
var
  LItems: TList<TGnyError>;
  LI: Integer;
  LErr: TGnyError;
  LColor: string;
  LLabel: string;
begin
  LItems := FErrors.GetItems();
  if LItems.Count = 0 then
    Exit;

  TGnyUtils.PrintLn('');
  for LI := 0 to LItems.Count - 1 do
  begin
    LErr := LItems[LI];
    case LErr.Severity of
      esHint:
      begin
        LColor := COLOR_CYAN;
        LLabel := 'HINT';
      end;
      esWarning:
      begin
        LColor := COLOR_YELLOW;
        LLabel := 'WARN';
      end;
      esError:
      begin
        LColor := COLOR_RED;
        LLabel := 'ERROR';
      end;
      esFatal:
      begin
        LColor := COLOR_MAGENTA;
        LLabel := 'FATAL';
      end;
    else
      LColor := COLOR_WHITE;
      LLabel := '?';
    end;

    if LErr.Code <> '' then
    begin
      if not LErr.Range.IsEmpty() then
        TGnyUtils.PrintLn(LColor + '[%s] %s %s: %s',
          [LLabel, LErr.Range.ToPointString(), LErr.Code, LErr.Message])
      else
        TGnyUtils.PrintLn(LColor + '[%s] %s: %s',
          [LLabel, LErr.Code, LErr.Message]);
    end
    else
    begin
      if not LErr.Range.IsEmpty() then
        TGnyUtils.PrintLn(LColor + '[%s] %s %s',
          [LLabel, LErr.Range.ToPointString(), LErr.Message])
      else
        TGnyUtils.PrintLn(LColor + '[%s] %s', [LLabel, LErr.Message]);
    end;
  end;
end;


end.
