{===============================================================================
  Ganymede™ - Embeddable Native Scripting Engine

  Copyright © 2026-present tinyBigGAMES™ LLC
  All Rights Reserved.

  See LICENSE for license information
===============================================================================}

unit Ganymede.Core;

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
  GNY_SCRIPT_EXT = 'gny';

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

  plDefault = Ganymede.Types.TLinkage.plDefault;
  plC       = Ganymede.Types.TLinkage.plC;

type

  TGnyValueType = Ganymede.Types.TGnyValueType;

  TGnyStatusCallback = Ganymede.Utils.TGnyStatusCallback;

  TGnyLinkage = Ganymede.Types.TLinkage;

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

  { TGanymede }
  TGanymede = class(TGnyBaseObject)
  private type
    { TGnyHostImport — stored host function registration for replay on recompile }
    TGnyHostImport = record
      FuncName: string;
      HostAddr: Pointer;
      ParamTypes: TArray<TGnyValueType>;
      ReturnType: TGnyValueType;
      Linkage: TGnyLinkage;
    end;
  private
    FLexer: TGnyScriptLexer;
    FParser: TGnyScriptParser;
    FSemantics: TGnyScriptSemantics;
    FEmitter: TGnyScriptEmitter;
    FBackend: TGnyNativeBackend;
    FJIT: TGnyJIT;
    FHostImports: TList<TGnyHostImport>;
    FLibPaths: TStringList;
    FDefines: TDictionary<string, string>;
    FSource: string;
    FFilename: string;
    FOptimizationLevel: TGnyOptLevel;
    FOutputPath: string;
    FDumpIR: Boolean;
    function GetCompiled(): Boolean;
    function ValueTypeToStr(const AType: TGnyValueType): string;
    {$HINTS OFF}
    function StrToValueType(const AName: string): TGnyValueType;
    {$HINTS ON}
    procedure ResetBackend();
    procedure ProcessImports();
    procedure SetupPredefinedDefines();
    function PreprocessDirectives(): Boolean;

  public
    constructor Create(); override;
    destructor Destroy(); override;

    // Override to propagate to all child components
    procedure SetStatusCallback(const ACallback: TGnyStatusCallback; const AUserData: Pointer = nil); override;

    // Register a host function pointer for script calls
    function ImportHost(const AFuncName: string;
      const AHostAddr: Pointer;
      const AParams: array of TGnyValueType;
      const AReturn: TGnyValueType = gvtVoid;
      const ALinkage: TGnyLinkage = plC): TGanymede;

    // Set output path for lib/exe targets (derived from filename if not set)
    function SetOutputPath(const APath: string): TGanymede;

    // Add a library search path
    function AddLibPath(const APath: string): TGanymede;

    // Load source
    function LoadFromString(const ASource: string;
      const AFilename: string = ''): TGanymede;
    function LoadFromFile(const AFilename: string): TGanymede;

    // Compile — lex + parse + semantic + emit + build (routes by module kind)
    function Compile(): Boolean;

    // Conditional compilation defines
    procedure SetDefine(const AName: string; const AValue: string);
    procedure Undefine(const AName: string);
    function IsDefined(const AName: string): Boolean;

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

    // Optimization level
    function  GetOptimizationLevel(): TGnyOptLevel;
    procedure SetOptimizationLevel(const ALevel: TGnyOptLevel);

    // State
    property Compiled: Boolean read GetCompiled;
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
    FLibPaths := TStringList.Create();
    FLibPaths.CaseSensitive := False;
    FLibPaths.Duplicates := dupIgnore;
    FDefines := TDictionary<string, string>.Create();
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
  FreeAndNil(FDefines);
  FreeAndNil(FLibPaths);
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
  const AReturn: TGnyValueType; const ALinkage: TGnyLinkage): TGanymede;
var
  LImport: TGnyHostImport;
  LI: Integer;
begin
  // Store for replay on recompile
  LImport := Default(TGnyHostImport);
  LImport.FuncName := AFuncName;
  LImport.HostAddr := AHostAddr;
  LImport.ReturnType := AReturn;
  LImport.Linkage := ALinkage;
  SetLength(LImport.ParamTypes, Length(AParams));
  for LI := 0 to High(AParams) do
    LImport.ParamTypes[LI] := AParams[LI];
  FHostImports.Add(LImport);

  // Register on current backend
  FBackend.ImportHost(AFuncName, AHostAddr, AParams, AReturn);
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

function TGanymede.StrToValueType(const AName: string): TGnyValueType;
begin
  if AName = 'int8' then
    Result := gvtInt8
  else if AName = 'int16' then
    Result := gvtInt16
  else if AName = 'int32' then
    Result := gvtInt32
  else if AName = 'int64' then
    Result := gvtInt64
  else if AName = 'uint8' then
    Result := gvtUInt8
  else if AName = 'uint16' then
    Result := gvtUInt16
  else if AName = 'uint32' then
    Result := gvtUInt32
  else if AName = 'uint64' then
    Result := gvtUInt64
  else if AName = 'float32' then
    Result := gvtFloat32
  else if AName = 'float64' then
    Result := gvtFloat64
  else if AName = 'boolean' then
    Result := gvtInt8
  else if AName = 'string' then
    Result := gvtPointer
  else if AName = 'wstring' then
    Result := gvtPointer
  else if AName = 'pointer' then
    Result := gvtPointer
  else
    Result := gvtVoid;
end;

procedure TGanymede.ProcessImports();
var
  LRootNode: TGnyScriptNode;
  LMainRoot: Integer;
  LChildIdx: Integer;
  LImportNode: TGnyScriptNode;
  LModuleNames: TArray<string>;
  LCount: Integer;
  LI: Integer;
  LJ: Integer;
  LK: Integer;
  LModuleName: string;
  LSourceDir: string;
  LResolvedPath: string;
  LFound: Boolean;
  LCandidatePath: string;
  LImportSource: string;
  LImportLexer: TGnyScriptLexer;
  LImportParser: TGnyScriptParser;
  LImpRoot: Integer;
  LImpRootNode: TGnyScriptNode;
  LImpModuleName: string;
  LImpChildIdx: Integer;
  LImpChildNode: TGnyScriptNode;
  LIndexOffset: Integer;
  LGraftedIdx: Integer;
  LModuleExports: TArray<TGnyScriptSymbol>;
  LExportCount: Integer;
  LExportSym: TGnyScriptSymbol;
  LParamNode: TGnyScriptNode;
  LParamIdx: Integer;
  LParamCount: Integer;

  // Recursively copy a node tree from the import parser into the main parser,
  // adjusting all child indices by the offset. Returns the new index.
  function GraftNode(const AParser: TGnyScriptParser; const ASrcIdx: Integer;
    const AOffset: Integer): Integer;
  var
    LSrcNode: TGnyScriptNode;
    LNewNode: TGnyScriptNode;
    LNewIdx: Integer;
    LCI: Integer;
  begin
    LSrcNode := AParser.Nodes[ASrcIdx];
    LNewNode := LSrcNode; // copy record
    // Remap children to new indices
    SetLength(LNewNode.Children, Length(LSrcNode.Children));
    for LCI := 0 to Length(LSrcNode.Children) - 1 do
      LNewNode.Children[LCI] := LSrcNode.Children[LCI] + AOffset;
    LNewIdx := FParser.Nodes.Count;
    FParser.Nodes.Add(LNewNode);
    Result := LNewIdx;
  end;

begin
  LMainRoot := FParser.Root;
  LRootNode := FParser.Nodes[LMainRoot];

  // Derive source directory from the importing file
  if not FFilename.IsEmpty then
    LSourceDir := TPath.GetDirectoryName(TPath.GetFullPath(FFilename))
  else
    LSourceDir := '';

  // Walk root children looking for nkImport nodes
  for LI := 0 to Length(LRootNode.Children) - 1 do
  begin
    LChildIdx := LRootNode.Children[LI];
    LImportNode := FParser.Nodes[LChildIdx];
    if LImportNode.Kind <> nkImport then
      Continue;

    // Collect module names: first in Text, rest in children
    LCount := 1 + Length(LImportNode.Children);
    SetLength(LModuleNames, LCount);
    LModuleNames[0] := LImportNode.Text;
    for LJ := 0 to Length(LImportNode.Children) - 1 do
      LModuleNames[LJ + 1] := FParser.Nodes[LImportNode.Children[LJ]].Text;

    // Process each imported module
    for LJ := 0 to LCount - 1 do
    begin
      LModuleName := LModuleNames[LJ];

      // Resolve source file: source dir first, then lib paths
      LFound := False;
      LResolvedPath := '';

      if not LSourceDir.IsEmpty then
      begin
        LCandidatePath := TPath.Combine(LSourceDir, LModuleName + '.' + GNY_SCRIPT_EXT);
        if TFile.Exists(LCandidatePath) then
        begin
          LResolvedPath := LCandidatePath;
          LFound := True;
        end;
      end;

      if not LFound then
      begin
        for LK := 0 to FLibPaths.Count - 1 do
        begin
          LCandidatePath := TPath.Combine(FLibPaths[LK], LModuleName + '.' + GNY_SCRIPT_EXT);
          if TFile.Exists(LCandidatePath) then
          begin
            LResolvedPath := LCandidatePath;
            LFound := True;
            Break;
          end;
        end;
      end;

      if not LFound then
      begin
        FErrors.Add(LImportNode.Range, esError, '',
          'Cannot resolve import ''%s'': source file not found', [LModuleName]);
        Continue;
      end;

      // Read imported module source
      try
        LImportSource := TFile.ReadAllText(LResolvedPath);
      except
        on E: Exception do
        begin
          FErrors.Add(LImportNode.Range, esError, '',
            'Failed to read import ''%s'': %s', [LModuleName, E.Message]);
          Continue;
        end;
      end;

      // Lex + parse imported module
      LImportLexer := TGnyScriptLexer.Create();
      LImportParser := TGnyScriptParser.Create();
      try
        LImportLexer.SetErrors(FErrors);
        LImportParser.SetErrors(FErrors);

        if not LImportLexer.Tokenize(LImportSource, LResolvedPath) then
          Continue;
        if not LImportParser.Parse(LImportLexer.Tokens) then
          Continue;

        LImpRoot := LImportParser.Root;
        LImpRootNode := LImportParser.Nodes[LImpRoot];
        LImpModuleName := LImpRootNode.Text;

        // Graft: copy ALL nodes from imported parser into main parser
        LIndexOffset := FParser.Nodes.Count;
        for LK := 0 to LImportParser.Nodes.Count - 1 do
          GraftNode(LImportParser, LK, LIndexOffset);

        // Collect exports and add routine declarations as children of main module
        LExportCount := 0;
        SetLength(LModuleExports, Length(LImpRootNode.Children));

        for LK := 0 to Length(LImpRootNode.Children) - 1 do
        begin
          LImpChildIdx := LImpRootNode.Children[LK];
          LImpChildNode := LImportParser.Nodes[LImpChildIdx];

          if LImpChildNode.Kind <> nkRoutineDecl then
            Continue;

          // Add ALL routine declarations as children of main module
          // (both public and private — private helpers must be compiled too)
          LGraftedIdx := LImpChildIdx + LIndexOffset;
          LRootNode := FParser.Nodes[LMainRoot];
          SetLength(LRootNode.Children, Length(LRootNode.Children) + 1);
          LRootNode.Children[Length(LRootNode.Children) - 1] := LGraftedIdx;
          FParser.Nodes[LMainRoot] := LRootNode;

          // Track only public routines as module exports for scoped access
          if not LImpChildNode.IsPublic then
            Continue;

          // Build signature key: "routineName(type1,type2,...)"
          LExportSym := Default(TGnyScriptSymbol);
          LExportSym.Kind := skRoutine;
          LExportSym.ReturnType := LImpChildNode.Extra;
          LParamCount := 0;
          LExportSym.SymbolName := LImpChildNode.Text + '(';
          for LParamIdx := 0 to Length(LImpChildNode.Children) - 1 do
          begin
            LParamNode := LImportParser.Nodes[LImpChildNode.Children[LParamIdx]];
            if LParamNode.Kind = nkParamDecl then
            begin
              if LParamCount > 0 then
                LExportSym.SymbolName := LExportSym.SymbolName + ',';
              LExportSym.SymbolName := LExportSym.SymbolName + LParamNode.Extra;
              Inc(LParamCount);
            end;
          end;
          LExportSym.SymbolName := LExportSym.SymbolName + ')';
          LExportSym.ParamCount := LParamCount;
          LExportSym.NodeIndex := LGraftedIdx;
          LModuleExports[LExportCount] := LExportSym;
          Inc(LExportCount);
        end;

        // Register module with its exported symbols in semantics
        SetLength(LModuleExports, LExportCount);
        FSemantics.RegisterModule(LImpModuleName, LModuleExports);
      finally
        LImportParser.Free();
        LImportLexer.Free();
      end;
    end;
  end;
end;

//------------------------------------------------------------------------------
// Conditional compilation — public API
//------------------------------------------------------------------------------

procedure TGanymede.SetDefine(const AName: string; const AValue: string);
begin
  FDefines.AddOrSetValue(AName, AValue);
end;

procedure TGanymede.Undefine(const AName: string);
begin
  FDefines.Remove(AName);
end;

function TGanymede.IsDefined(const AName: string): Boolean;
begin
  Result := FDefines.ContainsKey(AName);
end;

//------------------------------------------------------------------------------
// Populates FDefines with platform, engine, module-kind, optimization, and
// app-type symbols. Called at the start of Compile() after lexing so the
// module kind can be read from the token stream. Mutually exclusive pairs
// (DEBUG/RELEASE, BUILD_*, APPTYPE_*) are cleared before setting.
//------------------------------------------------------------------------------

procedure TGanymede.SetupPredefinedDefines();
var
  LModuleKind: string;
  LAppType: TGnyAppType;
begin
  // Engine identity
  SetDefine('GANYMEDE', '1');

  // Platform symbols (Win64-only target)
  SetDefine('WINDOWS', '1');
  SetDefine('MSWINDOWS', '1');
  SetDefine('WIN64', '1');
  SetDefine('TARGET_WIN64', '1');
  SetDefine('CPUX64', '1');

  // Optimization level — clear both, then set the correct one
  Undefine('DEBUG');
  Undefine('RELEASE');
  if FOptimizationLevel = olNone then
    SetDefine('DEBUG', '1')
  else
    SetDefine('RELEASE', '1');

  // Module-kind symbols — clear all, then set the correct one
  Undefine('BUILD_EXE');
  Undefine('BUILD_DLL');
  Undefine('BUILD_LIB');
  Undefine('BUILD_MEM');
  LModuleKind := '';
  if (FLexer.Tokens.Count >= 2) and (FLexer.Tokens[0].Kind = tkModule) then
    LModuleKind := FLexer.Tokens[1].Text;
  if LModuleKind = 'exe' then
    SetDefine('BUILD_EXE', '1')
  else if LModuleKind = 'dll' then
    SetDefine('BUILD_DLL', '1')
  else if LModuleKind = 'lib' then
    SetDefine('BUILD_LIB', '1')
  else if LModuleKind = 'mem' then
    SetDefine('BUILD_MEM', '1');

  // App type — query host executable PE header
  Undefine('APPTYPE_CONSOLE');
  Undefine('APPTYPE_GUI');
  LAppType := TGnyUtils.GetAppType();
  if LAppType = atConsole then
    SetDefine('APPTYPE_CONSOLE', '1')
  else if LAppType = atGUI then
    SetDefine('APPTYPE_GUI', '1');
end;

//------------------------------------------------------------------------------
// Conditional compilation preprocessor
//
// Walks the token stream after lexing, evaluates @ifdef/@ifndef/@elseif/@else/
// @endif/@define/@undef directives, and removes tokens inside false branches
// plus the directive tokens themselves. Platform and module-kind symbols are
// predefined. Returns True if no errors.
//------------------------------------------------------------------------------

function TGanymede.PreprocessDirectives(): Boolean;
const
  // Error codes for conditional compilation
  GNY_ERROR_COND_MISSING_ARG  = 'SC0001';
  GNY_ERROR_COND_UNMATCHED    = 'SC0002';
  GNY_ERROR_COND_DUPLICATE    = 'SC0003';
  GNY_ERROR_COND_UNTERMINATED = 'SC0004';
type
  TCondState = record
    Active: Boolean;    // is this branch currently emitting tokens?
    HadTrue: Boolean;   // has any branch in this if/elseif/else chain been true?
    HadElse: Boolean;   // have we seen @else already?
    ParentActive: Boolean; // was the enclosing level active?
  end;
var
  LTokens: TList<TGnyScriptToken>;
  LCondStack: TList<TCondState>;
  LFiltered: TList<TGnyScriptToken>;
  LI: Integer;
  LTok: TGnyScriptToken;
  LDirName: string;
  LSymbol: string;
  LState: TCondState;
  LTopActive: Boolean;

  // Returns True if all conditional levels are active (i.e. we should emit tokens)
  function IsEmitting(): Boolean;
  var
    LIdx: Integer;
  begin
    Result := True;
    for LIdx := 0 to LCondStack.Count - 1 do
    begin
      if not LCondStack[LIdx].Active then
      begin
        Result := False;
        Exit;
      end;
    end;
  end;

  // Reads the identifier token following a directive; returns '' on error
  function ReadSymbolArg(const ADirName: string): string;
  begin
    Result := '';
    Inc(LI); // move past the directive token
    if (LI < LTokens.Count) and (LTokens[LI].Kind = tkIdent) then
      Result := LTokens[LI].Text
    else
    begin
      FErrors.Add(LTok.Range, esError, GNY_ERROR_COND_MISSING_ARG,
        RSScriptCondMissingArg, [ADirName]);
    end;
  end;

begin
  LTokens := FLexer.Tokens;

  // Quick scan: if no directives at all, skip preprocessing entirely
  LI := 0;
  while LI < LTokens.Count do
  begin
    if LTokens[LI].Kind = tkDirective then
      Break;
    Inc(LI);
  end;
  if LI >= LTokens.Count then
  begin
    Result := True;
    Exit;
  end;

  LCondStack := TList<TCondState>.Create();
  LFiltered := TList<TGnyScriptToken>.Create();
  try
    // Walk the token stream
    LI := 0;
    while LI < LTokens.Count do
    begin
      LTok := LTokens[LI];

      if LTok.Kind = tkDirective then
      begin
        // Extract directive name without '@' prefix
        LDirName := LTok.Text;
        if (LDirName.Length > 1) and (LDirName[1] = '@') then
          LDirName := LDirName.Substring(1);

        // --- @define SYMBOL ---
        if LDirName = 'define' then
        begin
          LSymbol := ReadSymbolArg('define');
          if LSymbol <> '' then
          begin
            // Only apply if currently emitting
            if IsEmitting() then
              SetDefine(LSymbol, '1');
          end;
          Inc(LI);
          Continue;
        end

        // --- @undef SYMBOL ---
        else if LDirName = 'undef' then
        begin
          LSymbol := ReadSymbolArg('undef');
          if LSymbol <> '' then
          begin
            if IsEmitting() then
              Undefine(LSymbol);
          end;
          Inc(LI);
          Continue;
        end

        // --- @ifdef SYMBOL ---
        else if LDirName = 'ifdef' then
        begin
          LSymbol := ReadSymbolArg('ifdef');
          LTopActive := IsEmitting() and IsDefined(LSymbol);
          LState := Default(TCondState);
          LState.Active := LTopActive;
          LState.HadTrue := LTopActive;
          LState.HadElse := False;
          LState.ParentActive := IsEmitting();
          LCondStack.Add(LState);
          Inc(LI);
          Continue;
        end

        // --- @ifndef SYMBOL ---
        else if LDirName = 'ifndef' then
        begin
          LSymbol := ReadSymbolArg('ifndef');
          LTopActive := IsEmitting() and (not IsDefined(LSymbol));
          LState := Default(TCondState);
          LState.Active := LTopActive;
          LState.HadTrue := LTopActive;
          LState.HadElse := False;
          LState.ParentActive := IsEmitting();
          LCondStack.Add(LState);
          Inc(LI);
          Continue;
        end

        // --- @elseif SYMBOL ---
        else if LDirName = 'elseif' then
        begin
          LSymbol := ReadSymbolArg('elseif');
          if LCondStack.Count = 0 then
          begin
            FErrors.Add(LTok.Range, esError, GNY_ERROR_COND_UNMATCHED,
              RSScriptCondUnmatched, ['elseif']);
            Inc(LI);
            Continue;
          end;
          LState := LCondStack[LCondStack.Count - 1];
          if LState.HadElse then
          begin
            FErrors.Add(LTok.Range, esError, GNY_ERROR_COND_DUPLICATE,
              RSScriptCondDuplicate, []);
            Inc(LI);
            Continue;
          end;
          // Activate this branch only if parent is active, no prior branch was true,
          // and the symbol is defined
          LState.Active := LState.ParentActive and (not LState.HadTrue) and
            IsDefined(LSymbol);
          if LState.Active then
            LState.HadTrue := True;
          LCondStack[LCondStack.Count - 1] := LState;
          Inc(LI);
          Continue;
        end

        // --- @else ---
        else if LDirName = 'else' then
        begin
          if LCondStack.Count = 0 then
          begin
            FErrors.Add(LTok.Range, esError, GNY_ERROR_COND_UNMATCHED,
              RSScriptCondUnmatched, ['else']);
            Inc(LI);
            Continue;
          end;
          LState := LCondStack[LCondStack.Count - 1];
          if LState.HadElse then
          begin
            FErrors.Add(LTok.Range, esError, GNY_ERROR_COND_DUPLICATE,
              RSScriptCondDuplicate, []);
            Inc(LI);
            Continue;
          end;
          LState.HadElse := True;
          // Activate @else only if parent is active and no prior branch was true
          LState.Active := LState.ParentActive and (not LState.HadTrue);
          if LState.Active then
            LState.HadTrue := True;
          LCondStack[LCondStack.Count - 1] := LState;
          Inc(LI);
          Continue;
        end

        // --- @endif ---
        else if LDirName = 'endif' then
        begin
          if LCondStack.Count = 0 then
          begin
            FErrors.Add(LTok.Range, esError, GNY_ERROR_COND_UNMATCHED,
              RSScriptCondUnmatched, ['endif']);
            Inc(LI);
            Continue;
          end;
          LCondStack.Delete(LCondStack.Count - 1);
          Inc(LI);
          Continue;
        end
        else
        begin
          // Unknown directive — leave in stream for future handling
          if IsEmitting() then
            LFiltered.Add(LTok);
          Inc(LI);
          Continue;
        end;
      end;

      // Non-directive token: keep only if all conditional levels are active
      if IsEmitting() then
        LFiltered.Add(LTok);
      Inc(LI);
    end;

    // Check for unterminated conditional blocks
    if LCondStack.Count > 0 then
    begin
      FErrors.Add(LTokens[LTokens.Count - 1].Range, esError,
        GNY_ERROR_COND_UNTERMINATED, RSScriptCondUnterminated, []);
    end;

    // Replace the token list with the filtered result
    LTokens.Clear();
    for LI := 0 to LFiltered.Count - 1 do
      LTokens.Add(LFiltered[LI]);

    Result := FErrors.ErrorCount() = 0;
  finally
    LFiltered.Free();
    LCondStack.Free();
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
  LJ: Integer;
  LModuleKind: string;
  LOutputFile: string;
  LModuleName: string;
  LExt: string;
  LParamTypeStrs: TArray<string>;
begin
  Result := False;

  // Reset backend for clean compilation (supports recompile)
  ResetBackend();
  FErrors.Clear();

  // Guard: no source loaded
  if FSource.Trim().IsEmpty() then
  begin
    FErrors.Add(FFilename, 1, 1, esError, 'GC0001',
      'No source code loaded (call LoadFromFile or LoadFromString first)');
    Exit;
  end;

  // Phase 1: Lex
  if not FLexer.Tokenize(FSource, FFilename) then
    Exit;

  // Phase 1b: Setup predefined defines and preprocess conditional directives
  SetupPredefinedDefines();
  if not PreprocessDirectives() then
    Exit;

  // Phase 2: Parse
  if not FParser.Parse(FLexer.Tokens) then
    Exit;

  // Read module kind from AST (mem, lib, exe)
  LModuleKind := FParser.Nodes[FParser.Root].Extra;

  // Phase 2b: Resolve and process import clauses
  ProcessImports();
  if FErrors.ErrorCount() > 0 then
    Exit;

  // Pre-register imported functions (from API/host + imports) as known externals
  LIR := FBackend.GetIR();
  for LI := 0 to LIR.GetImportCount() - 1 do
  begin
    LImport := LIR.GetImport(LI);
    // Convert TGnyValueType array to string array for signature keys
    SetLength(LParamTypeStrs, Length(LImport.ParamTypes));
    for LJ := 0 to Length(LImport.ParamTypes) - 1 do
      LParamTypeStrs[LJ] := ValueTypeToStr(LImport.ParamTypes[LJ]);
    FSemantics.RegisterExtern(LImport.FuncName,
      LParamTypeStrs, ValueTypeToStr(LImport.ReturnType));
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
  else if (LModuleKind = 'lib') or (LModuleKind = 'dll') then
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
        LExt := '.dll';
      LOutputFile := TPath.Combine(FOutputPath, LModuleName + LExt);
    end;

    // Ensure output directory exists
    TGnyUtils.CreateDirInPath(LOutputFile);

    if LModuleKind = 'lib' then
      FBackend.TargetLib(LOutputFile)
    else
      FBackend.TargetDll(LOutputFile);

    Result := FBackend.Build(False);
  end
  else
  begin
    FErrors.Add(esError, '', 'Unknown module kind: %s', [LModuleKind]);
    Exit;
  end;
end;

(*
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
*)

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
  LIR: TIR;
  LFunc: TIR.TIRFunc;
  LI: Integer;
  LJ: Integer;
  LFixedParams: Integer;
  LVaCount: Integer;
  LRawArgs: TArray<Int64>;
  LConvertedArgs: TArray<Int64>;
  LIsVariadic: Boolean;
begin
  Result := Default(TGnyValue);
  Result.ValueType := AReturn;

  if FJIT = nil then
    Exit;

  // Check if target function is variadic — if so, prepend hidden count arg
  LIsVariadic := False;
  LIR := FBackend.GetIR();
  for LI := 0 to LIR.GetFunctionCount() - 1 do
  begin
    LFunc := LIR.GetFunction(LI);
    if SameText(LFunc.FuncName, AName) and LFunc.IsVariadic then
    begin
      LIsVariadic := True;

      // Count declared (fixed) params
      LFixedParams := 0;
      if LFunc.Vars <> nil then
      begin
        for LJ := 0 to LFunc.Vars.Count - 1 do
        begin
          if LFunc.Vars[LJ].IsParam then
            Inc(LFixedParams);
        end;
      end;

      // Calculate variadic arg count
      LVaCount := Length(AArgs) - LFixedParams;
      if LVaCount < 0 then
        LVaCount := 0;

      // Convert original args to Int64
      SetLength(LConvertedArgs, Length(AArgs));
      for LJ := 0 to High(AArgs) do
      begin
        case AArgs[LJ].VType of
          vtInteger:  LConvertedArgs[LJ] := AArgs[LJ].VInteger;
          vtInt64:    LConvertedArgs[LJ] := AArgs[LJ].VInt64^;
          vtBoolean:  LConvertedArgs[LJ] := Ord(AArgs[LJ].VBoolean);
          vtExtended:
          begin
            LFloat := AArgs[LJ].VExtended^;
            LConvertedArgs[LJ] := PInt64(@LFloat)^;
          end;
          vtPointer:  LConvertedArgs[LJ] := Int64(AArgs[LJ].VPointer);
        else
          LConvertedArgs[LJ] := 0;
        end;
      end;

      // Prepend hidden count as first arg
      SetLength(LRawArgs, Length(LConvertedArgs) + 1);
      LRawArgs[0] := LVaCount;
      for LJ := 0 to High(LConvertedArgs) do
        LRawArgs[LJ + 1] := LConvertedArgs[LJ];

      Break;
    end;
  end;

  if LIsVariadic then
  begin
    case AReturn of
      gvtFloat32:
      begin
        LFloat := FJIT.InvokeFloatRaw(AName, LRawArgs);
        Result.AsFloat32 := Single(LFloat);
      end;
      gvtFloat64:
        Result.AsFloat64 := FJIT.InvokeFloatRaw(AName, LRawArgs);
    else
      LInt := FJIT.InvokeRaw(AName, LRawArgs);
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
  end
  else
  begin
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
end;

function  TGanymede.GetOptimizationLevel(): TGnyOptLevel;
begin
  Result := FOptimizationLevel;
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
