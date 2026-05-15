{===============================================================================
  Ganymede™ - Embeddable Native Scripting Engine

  Copyright © 2026-present tinyBigGAMES™ LLC
  All Rights Reserved.

  See LICENSE for license information
===============================================================================}

unit Ganymede.Builders;

{$I Ganymede.Defines.inc}

interface

uses
  System.SysUtils,
  System.Classes,
  System.Generics.Collections,
  Ganymede.Utils,
  Ganymede.Types,
  Ganymede.Resources;

type
  // Forward declarations
  TCodeBuilder = class;

  { TDataBuilder }
  TDataBuilder = class(TGnyBaseObject)
  private
    FEntries: TList<TDataEntry>;
    FData: TMemoryStream;

  public
    constructor Create(); override;
    destructor Destroy(); override;

    function AddString(const AValue: string): TDataHandle;
    function AddStringA(const AValue: AnsiString): TDataHandle;
    function AddStringW(const AValue: string): TDataHandle;
    function AddBytes(const AData: TBytes): TDataHandle;
    function AddInt8(const AValue: Int8): TDataHandle;
    function AddInt16(const AValue: Int16): TDataHandle;
    function AddInt32(const AValue: Int32): TDataHandle;
    function AddInt64(const AValue: Int64): TDataHandle;
    function AddUInt8(const AValue: UInt8): TDataHandle;
    function AddUInt16(const AValue: UInt16): TDataHandle;
    function AddUInt32(const AValue: UInt32): TDataHandle;
    function AddUInt64(const AValue: UInt64): TDataHandle;
    function AddFloat32(const AValue: Single): TDataHandle;
    function AddFloat64(const AValue: Double): TDataHandle;
    function AddPointer(const ATarget: TDataHandle): TDataHandle;
    function Reserve(const ASize: Integer; const AAlign: Integer = 8): TDataHandle;

    procedure Align(const AAlignment: Integer);
    procedure Clear();

    function GetEntry(const AHandle: TDataHandle): TDataEntry;
    function GetData(): TBytes;
    function GetDataPointer(): Pointer;
    function GetSize(): Integer;
  end;

  //============================================================================
  // TImportBuilder
  //============================================================================

  { TImportBuilder }
  TImportBuilder = class(TGnyBaseObject)
  private
    FEntries: TList<TImportEntry>;

  public
    constructor Create(); reintroduce;
    destructor Destroy(); override;

    function Add(const ADllName, AFuncName: string): TImportHandle; overload;
    function Add(const ADllName, AFuncName: string; const AReturnType: TGnyValueType): TImportHandle; overload;
    function Add(const ADllName, AFuncName: string; const AReturnType: TGnyValueType;
      const AIsStatic: Boolean;
      const AHostAddr: Pointer = nil): TImportHandle; overload;
    function Add(const ADllName, AFuncName: string; const AReturnType: TGnyValueType;
      const AIsStatic: Boolean; const ALinkage: TLinkage;
      const AParamTypes: TArray<TGnyValueType>;
      const AHostAddr: Pointer = nil): TImportHandle; overload;

    procedure Clear();
    function GetEntry(const AHandle: TImportHandle): TImportEntry;
    function GetCount(): Integer;
    function GetEntryByIndex(const AIndex: Integer): TImportEntry;
  end;

  //============================================================================
  // TExportBuilder
  //============================================================================

  { TExportBuilder }
  TExportBuilder = class(TGnyBaseObject)
  private
    FCodeBuilder: TCodeBuilder;
    FEntries: TList<TExportEntry>;

  public
    constructor Create(const ACodeBuilder: TCodeBuilder); reintroduce;
    destructor Destroy(); override;

    procedure Add(const AFuncHandle: TFuncHandle); overload;
    procedure Add(const AFuncHandle: TFuncHandle; const AExportName: string); overload;

    procedure Clear();
    function GetCount(): Integer;
    function GetEntryByIndex(const AIndex: Integer): TExportEntry;
  end;

  //============================================================================
  // TCodeBuilder (Fluent Interface)
  //============================================================================

  { TCodeBuilder }
  TCodeBuilder = class(TGnyBaseObject)
  private
    FFunctions: TList<TFuncInfo>;
    FCurrentFunc: Integer;

    // Source location tracking (for debugger)
    FCurrentSourceLine: Integer;
    FCurrentSourceColumn: Integer;
    FCurrentSourceFile: string;

    function GetCurrentFunc(): TFuncInfo;
    procedure SetCurrentFunc(const AFunc: TFuncInfo);
    function AllocTemp(): TTempHandle;
    procedure AddInstr(const AInstr: TInstruction);

  public
    constructor Create(); reintroduce;
    destructor Destroy(); override;

    //--------------------------------------------------------------------------
    // Function Management
    //--------------------------------------------------------------------------
    function BeginProc(
      const AName: string;
      const AIsEntryPoint: Boolean = False;
      const AIsDllEntry: Boolean = False;
      const AIsPublic: Boolean = False;
      const ALinkage: TLinkage = plDefault
    ): TCodeBuilder;
    function SetReturnType(const AType: TGnyValueType): TCodeBuilder; overload;
    function SetReturnType(const AType: TGnyValueType; const ASize: Integer; const AAlignment: Integer): TCodeBuilder; overload;
    function SetIsVariadic(const AValue: Boolean): TCodeBuilder;
    function EndProc(): TCodeBuilder;

    //--------------------------------------------------------------------------
    // Parameters and Locals
    //--------------------------------------------------------------------------
    function AddParam(const AName: string; const AType: TGnyValueType; const AIsByRef: Boolean = False): TLocalHandle; overload;
    function AddParam(const AName: string; const ASize: Integer; const AAlignment: Integer; const AIsByRef: Boolean = False): TLocalHandle; overload;
    function AddLocal(const AName: string; const AType: TGnyValueType): TLocalHandle; overload;
    function AddLocal(const AName: string; const ASize: Integer): TLocalHandle; overload;
    function AddLocal(const AName: string; const ASize: Integer; const AAlignment: Integer): TLocalHandle; overload;

    //--------------------------------------------------------------------------
    // Labels
    //--------------------------------------------------------------------------
    function DefineLabel(const AName: string = ''): TLabelHandle;
    function MarkLabel(const ALabel: TLabelHandle): TCodeBuilder;

    //--------------------------------------------------------------------------
    // Exception Scopes (for SEH)
    //--------------------------------------------------------------------------
    procedure AddExceptionScope(
      const ATryBegin: TLabelHandle;
      const ATryEnd: TLabelHandle;
      const AExcept: TLabelHandle;
      const AFinally: TLabelHandle;
      const AEnd: TLabelHandle
    );

    //--------------------------------------------------------------------------
    // Function Calls
    //--------------------------------------------------------------------------
    function Call(const AImport: TImportHandle): TCodeBuilder; overload;
    function Call(const AImport: TImportHandle; const AArgs: array of TOperand): TCodeBuilder; overload;
    function Call(const AFunc: TFuncHandle): TCodeBuilder; overload;
    function Call(const AFunc: TFuncHandle; const AArgs: array of TOperand): TCodeBuilder; overload;

    function CallFunc(const AImport: TImportHandle): TTempHandle; overload;
    function CallFunc(const AImport: TImportHandle; const AArgs: array of TOperand): TTempHandle; overload;
    function CallFunc(const AFunc: TFuncHandle): TTempHandle; overload;
    function CallFunc(const AFunc: TFuncHandle; const AArgs: array of TOperand): TTempHandle; overload;

    // Indirect calls (through function pointer)
    function CallIndirect(const AFuncPtr: TOperand): TCodeBuilder; overload;
    function CallIndirect(const AFuncPtr: TOperand; const AArgs: array of TOperand): TCodeBuilder; overload;
    function CallIndirectFunc(const AFuncPtr: TOperand): TTempHandle; overload;
    function CallIndirectFunc(const AFuncPtr: TOperand; const AArgs: array of TOperand): TTempHandle; overload;

    // Function address
    function LoadFuncAddr(const AFuncIndex: Integer): TTempHandle;

    //--------------------------------------------------------------------------
    // Return
    //--------------------------------------------------------------------------
    function Return(): TCodeBuilder; overload;
    function Return(const AValue: TOperand): TCodeBuilder; overload;

    //--------------------------------------------------------------------------
    // Arithmetic
    //--------------------------------------------------------------------------
    function OpAdd(const ALeft, ARight: TOperand): TTempHandle;
    function OpSub(const ALeft, ARight: TOperand): TTempHandle;
    function OpMul(const ALeft, ARight: TOperand): TTempHandle;
    function OpDiv(const ALeft, ARight: TOperand): TTempHandle;
    function OpMod(const ALeft, ARight: TOperand): TTempHandle;
    function OpFAdd(const ALeft, ARight: TOperand): TTempHandle;
    function OpFSub(const ALeft, ARight: TOperand): TTempHandle;
    function OpFMul(const ALeft, ARight: TOperand): TTempHandle;
    function OpFDiv(const ALeft, ARight: TOperand): TTempHandle;
    function OpFNeg(const AValue: TOperand): TTempHandle;

    //--------------------------------------------------------------------------
    // Type Conversion
    //--------------------------------------------------------------------------
    function OpIntToFloat(const AValue: TOperand): TTempHandle;
    function OpFloatToInt(const AValue: TOperand): TTempHandle;

    //--------------------------------------------------------------------------
    // Bitwise
    //--------------------------------------------------------------------------
    function OpAnd(const ALeft, ARight: TOperand): TTempHandle;
    function OpOr(const ALeft, ARight: TOperand): TTempHandle;
    function OpXor(const ALeft, ARight: TOperand): TTempHandle;
    function OpNot(const AValue: TOperand): TTempHandle;
    function OpShl(const AValue, ACount: TOperand): TTempHandle;
    function OpShr(const AValue, ACount: TOperand): TTempHandle;

    //--------------------------------------------------------------------------
    // Comparison
    //--------------------------------------------------------------------------
    function CmpEq(const ALeft, ARight: TOperand): TTempHandle;
    function CmpNe(const ALeft, ARight: TOperand): TTempHandle;
    function CmpLt(const ALeft, ARight: TOperand): TTempHandle;
    function CmpLe(const ALeft, ARight: TOperand): TTempHandle;
    function CmpGt(const ALeft, ARight: TOperand): TTempHandle;
    function CmpGe(const ALeft, ARight: TOperand): TTempHandle;

    //--------------------------------------------------------------------------
    // Float Comparison
    //--------------------------------------------------------------------------
    function FCmpEq(const ALeft, ARight: TOperand): TTempHandle;
    function FCmpNe(const ALeft, ARight: TOperand): TTempHandle;
    function FCmpLt(const ALeft, ARight: TOperand): TTempHandle;
    function FCmpLe(const ALeft, ARight: TOperand): TTempHandle;
    function FCmpGt(const ALeft, ARight: TOperand): TTempHandle;
    function FCmpGe(const ALeft, ARight: TOperand): TTempHandle;

    //--------------------------------------------------------------------------
    // Set Operations
    //--------------------------------------------------------------------------
    function OpSetLiteral(const AElements: array of Integer; const ALowBound: Integer; const AStorageSize: Integer): TTempHandle;
    function OpSetUnion(const ALeft, ARight: TOperand): TTempHandle;
    function OpSetDiff(const ALeft, ARight: TOperand): TTempHandle;
    function OpSetInter(const ALeft, ARight: TOperand): TTempHandle;
    function OpSetIn(const AElement, ASet: TOperand; const ALowBound: Integer): TTempHandle;
    function OpSetEq(const ALeft, ARight: TOperand): TTempHandle;
    function OpSetNe(const ALeft, ARight: TOperand): TTempHandle;
    function OpSetSubset(const ALeft, ARight: TOperand): TTempHandle;
    function OpSetSuperset(const ALeft, ARight: TOperand): TTempHandle;

    //--------------------------------------------------------------------------
    // Variadic Intrinsics
    //--------------------------------------------------------------------------
    function VaCount(): TTempHandle;
    function VaArgAt(const AIndex: TOperand; const AType: TGnyValueType): TTempHandle;

    //--------------------------------------------------------------------------
    // Memory Operations
    //--------------------------------------------------------------------------
    function Store(const ADest: TLocalHandle; const AValue: TOperand): TCodeBuilder;
    function Load(const ASrc: TLocalHandle): TTempHandle;
    function StorePtr(const APtr, AValue: TOperand; const AMemSize: Integer = 0; const AMemIsFloat: Boolean = False): TCodeBuilder;
    function LoadPtr(const APtr: TOperand; const AMemSize: Integer = 0; const AMemIsFloat: Boolean = False): TTempHandle;
    function AddressOf(const ALocal: TLocalHandle): TTempHandle;

    //--------------------------------------------------------------------------
    // Control Flow
    //--------------------------------------------------------------------------
    function Jump(const ALabel: TLabelHandle): TCodeBuilder;
    function JumpIf(const ACond: TOperand; const ALabel: TLabelHandle): TCodeBuilder;
    function JumpIfNot(const ACond: TOperand; const ALabel: TLabelHandle): TCodeBuilder;

    //--------------------------------------------------------------------------
    // Source Location (for debugger)
    //--------------------------------------------------------------------------
    procedure SetSourceLocation(const ALine: Integer; const AColumn: Integer; const AFile: string = '');

    //--------------------------------------------------------------------------
    // Query
    //--------------------------------------------------------------------------
    function GetFuncCount(): Integer;
    function GetFunc(const AIndex: Integer): TFuncInfo;
    function GetFuncHandle(const AName: string): TFuncHandle;
    function GetCurrentFuncHandle(): TFuncHandle;

    procedure Clear();
  end;

  //============================================================================
  // TGnyNativeBackend (Main Facade)
  //============================================================================


implementation

//==============================================================================
// TDataBuilder Implementation
//==============================================================================

constructor TDataBuilder.Create();
begin
  inherited Create();

  FEntries := TList<TDataEntry>.Create();
  FData := TMemoryStream.Create();
end;

destructor TDataBuilder.Destroy();
begin
  FData.Free();
  FEntries.Free();

  inherited;
end;

function TDataBuilder.AddString(const AValue: string): TDataHandle;
begin
  Result := AddStringA(UTF8Encode(AValue));
end;

function TDataBuilder.AddStringA(const AValue: AnsiString): TDataHandle;
var
  LEntry: TDataEntry;
begin
  LEntry.Offset := FData.Size;
  LEntry.Size := Length(AValue) + 1;
  LEntry.DataType := gvtPointer;

  if Length(AValue) > 0 then
    FData.WriteBuffer(AValue[1], Length(AValue));
  FData.WriteData(Byte(0));

  Result.Index := FEntries.Count;
  FEntries.Add(LEntry);
end;

function TDataBuilder.AddStringW(const AValue: string): TDataHandle;
var
  LEntry: TDataEntry;
  LI: Integer;
  LChar: Word;
begin
  LEntry.Offset := FData.Size;
  LEntry.Size := (Length(AValue) + 1) * 2;
  LEntry.DataType := gvtPointer;

  for LI := 1 to Length(AValue) do
  begin
    LChar := Word(AValue[LI]);
    FData.WriteData(LChar);
  end;
  LChar := 0;
  FData.WriteData(LChar);

  Result.Index := FEntries.Count;
  FEntries.Add(LEntry);
end;

function TDataBuilder.AddBytes(const AData: TBytes): TDataHandle;
var
  LEntry: TDataEntry;
begin
  LEntry.Offset := FData.Size;
  LEntry.Size := Length(AData);
  LEntry.DataType := gvtPointer;

  if Length(AData) > 0 then
    FData.WriteBuffer(AData[0], Length(AData));

  Result.Index := FEntries.Count;
  FEntries.Add(LEntry);
end;

function TDataBuilder.AddInt8(const AValue: Int8): TDataHandle;
var
  LEntry: TDataEntry;
begin
  LEntry.Offset := FData.Size;
  LEntry.Size := 1;
  LEntry.DataType := gvtInt8;
  FData.WriteData(AValue);

  Result.Index := FEntries.Count;
  FEntries.Add(LEntry);
end;

function TDataBuilder.AddInt16(const AValue: Int16): TDataHandle;
var
  LEntry: TDataEntry;
begin
  Align(2);
  LEntry.Offset := FData.Size;
  LEntry.Size := 2;
  LEntry.DataType := gvtInt16;
  FData.WriteData(AValue);

  Result.Index := FEntries.Count;
  FEntries.Add(LEntry);
end;

function TDataBuilder.AddInt32(const AValue: Int32): TDataHandle;
var
  LEntry: TDataEntry;
begin
  Align(4);
  LEntry.Offset := FData.Size;
  LEntry.Size := 4;
  LEntry.DataType := gvtInt32;
  FData.WriteData(AValue);

  Result.Index := FEntries.Count;
  FEntries.Add(LEntry);
end;

function TDataBuilder.AddInt64(const AValue: Int64): TDataHandle;
var
  LEntry: TDataEntry;
begin
  Align(8);
  LEntry.Offset := FData.Size;
  LEntry.Size := 8;
  LEntry.DataType := gvtInt64;
  FData.WriteData(AValue);

  Result.Index := FEntries.Count;
  FEntries.Add(LEntry);
end;

function TDataBuilder.AddUInt8(const AValue: UInt8): TDataHandle;
var
  LEntry: TDataEntry;
begin
  LEntry.Offset := FData.Size;
  LEntry.Size := 1;
  LEntry.DataType := gvtUInt8;
  FData.WriteData(AValue);

  Result.Index := FEntries.Count;
  FEntries.Add(LEntry);
end;

function TDataBuilder.AddUInt16(const AValue: UInt16): TDataHandle;
var
  LEntry: TDataEntry;
begin
  Align(2);
  LEntry.Offset := FData.Size;
  LEntry.Size := 2;
  LEntry.DataType := gvtUInt16;
  FData.WriteData(AValue);

  Result.Index := FEntries.Count;
  FEntries.Add(LEntry);
end;

function TDataBuilder.AddUInt32(const AValue: UInt32): TDataHandle;
var
  LEntry: TDataEntry;
begin
  Align(4);
  LEntry.Offset := FData.Size;
  LEntry.Size := 4;
  LEntry.DataType := gvtUInt32;
  FData.WriteData(AValue);

  Result.Index := FEntries.Count;
  FEntries.Add(LEntry);
end;

function TDataBuilder.AddUInt64(const AValue: UInt64): TDataHandle;
var
  LEntry: TDataEntry;
begin
  Align(8);
  LEntry.Offset := FData.Size;
  LEntry.Size := 8;
  LEntry.DataType := gvtUInt64;
  FData.WriteData(AValue);

  Result.Index := FEntries.Count;
  FEntries.Add(LEntry);
end;

function TDataBuilder.AddFloat32(const AValue: Single): TDataHandle;
var
  LEntry: TDataEntry;
begin
  Align(4);
  LEntry.Offset := FData.Size;
  LEntry.Size := 4;
  LEntry.DataType := gvtFloat32;
  FData.WriteData(AValue);

  Result.Index := FEntries.Count;
  FEntries.Add(LEntry);
end;

function TDataBuilder.AddFloat64(const AValue: Double): TDataHandle;
var
  LEntry: TDataEntry;
begin
  Align(8);
  LEntry.Offset := FData.Size;
  LEntry.Size := 8;
  LEntry.DataType := gvtFloat64;
  FData.WriteData(AValue);

  Result.Index := FEntries.Count;
  FEntries.Add(LEntry);
end;

function TDataBuilder.AddPointer(const ATarget: TDataHandle): TDataHandle;
var
  LEntry: TDataEntry;
  LTargetEntry: TDataEntry;
  LValue: UInt64;
begin
  Align(8);
  LEntry.Offset := FData.Size;
  LEntry.Size := 8;
  LEntry.DataType := gvtPointer;

  // Store the offset for now - will be fixed up during build
  LTargetEntry := GetEntry(ATarget);
  LValue := LTargetEntry.Offset;
  FData.WriteData(LValue);

  Result.Index := FEntries.Count;
  FEntries.Add(LEntry);
end;

function TDataBuilder.Reserve(const ASize: Integer; const AAlign: Integer): TDataHandle;
var
  LEntry: TDataEntry;
  LI: Integer;
begin
  if AAlign > 1 then
    Align(AAlign);

  LEntry.Offset := FData.Size;
  LEntry.Size := ASize;
  LEntry.DataType := gvtPointer;

  for LI := 1 to ASize do
    FData.WriteData(Byte(0));

  Result.Index := FEntries.Count;
  FEntries.Add(LEntry);
end;

procedure TDataBuilder.Align(const AAlignment: Integer);
var
  LPadding: Integer;
  LI: Integer;
begin
  if AAlignment <= 1 then
    Exit;

  LPadding := FData.Size mod AAlignment;
  if LPadding > 0 then
  begin
    LPadding := AAlignment - LPadding;
    for LI := 1 to LPadding do
      FData.WriteData(Byte(0));
  end;
end;

procedure TDataBuilder.Clear();
begin
  FEntries.Clear();
  FData.Clear();
end;

function TDataBuilder.GetEntry(const AHandle: TDataHandle): TDataEntry;
begin
  if (AHandle.Index >= 0) and (AHandle.Index < FEntries.Count) then
    Result := FEntries[AHandle.Index]
  else
  begin
    Result.Offset := 0;
    Result.Size := 0;
    Result.DataType := gvtVoid;
  end;
end;

function TDataBuilder.GetData(): TBytes;
begin
  SetLength(Result, FData.Size);
  if FData.Size > 0 then
  begin
    FData.Position := 0;
    FData.ReadBuffer(Result[0], FData.Size);
  end;
end;

function TDataBuilder.GetDataPointer(): Pointer;
begin
  Result := FData.Memory;
end;

function TDataBuilder.GetSize(): Integer;
begin
  Result := FData.Size;
end;

//==============================================================================
// TImportBuilder Implementation
//==============================================================================

constructor TImportBuilder.Create();
begin
  inherited Create();

  FEntries := TList<TImportEntry>.Create();
end;

destructor TImportBuilder.Destroy();
begin
  FEntries.Free();

  inherited;
end;

function TImportBuilder.Add(const ADllName, AFuncName: string): TImportHandle;
begin
  Result := Add(ADllName, AFuncName, gvtVoid);
end;

function TImportBuilder.Add(const ADllName, AFuncName: string; const AReturnType: TGnyValueType): TImportHandle;
begin
  Result := Add(ADllName, AFuncName, AReturnType, False);
end;

function TImportBuilder.Add(const ADllName, AFuncName: string;
  const AReturnType: TGnyValueType; const AIsStatic: Boolean;
  const AHostAddr: Pointer): TImportHandle;
var
  LEntry: TImportEntry;
begin
  LEntry := Default(TImportEntry);
  LEntry.DllName := ADllName;
  LEntry.FuncName := AFuncName;
  LEntry.ReturnType := AReturnType;
  LEntry.IsStatic := AIsStatic;
  LEntry.HostAddr := AHostAddr;

  Result.Index := FEntries.Count;
  FEntries.Add(LEntry);
end;

function TImportBuilder.Add(const ADllName, AFuncName: string;
  const AReturnType: TGnyValueType; const AIsStatic: Boolean;
  const ALinkage: TLinkage; const AParamTypes: TArray<TGnyValueType>;
  const AHostAddr: Pointer): TImportHandle;
var
  LEntry: TImportEntry;
begin
  LEntry := Default(TImportEntry);
  LEntry.DllName := ADllName;
  LEntry.FuncName := AFuncName;
  LEntry.ReturnType := AReturnType;
  LEntry.IsStatic := AIsStatic;
  LEntry.Linkage := ALinkage;
  LEntry.ParamTypes := Copy(AParamTypes);
  LEntry.HostAddr := AHostAddr;

  Result.Index := FEntries.Count;
  FEntries.Add(LEntry);
end;

procedure TImportBuilder.Clear();
begin
  FEntries.Clear();
end;

function TImportBuilder.GetEntry(const AHandle: TImportHandle): TImportEntry;
begin
  if (AHandle.Index >= 0) and (AHandle.Index < FEntries.Count) then
    Result := FEntries[AHandle.Index]
  else
  begin
    Result.DllName := '';
    Result.FuncName := '';
    Result.IATOffset := 0;
    Result.ReturnType := gvtVoid;
  end;
end;

function TImportBuilder.GetCount(): Integer;
begin
  Result := FEntries.Count;
end;

function TImportBuilder.GetEntryByIndex(const AIndex: Integer): TImportEntry;
begin
  Result := FEntries[AIndex];
end;

//==============================================================================
// TExportBuilder Implementation
//==============================================================================

constructor TExportBuilder.Create(const ACodeBuilder: TCodeBuilder);
begin
  inherited Create();
  FCodeBuilder := ACodeBuilder;

  FEntries := TList<TExportEntry>.Create();
end;

destructor TExportBuilder.Destroy();
begin
  FEntries.Free();

  inherited;
end;

procedure TExportBuilder.Add(const AFuncHandle: TFuncHandle);
var
  LEntry: TExportEntry;
  LFunc: TFuncInfo;
begin
  LFunc := FCodeBuilder.GetFunc(AFuncHandle.Index);
  LEntry.FuncName := LFunc.FuncName;
  LEntry.ExportName := LFunc.FuncName;
  LEntry.FuncIndex := AFuncHandle.Index;
  FEntries.Add(LEntry);
end;

procedure TExportBuilder.Add(const AFuncHandle: TFuncHandle; const AExportName: string);
var
  LEntry: TExportEntry;
  LFunc: TFuncInfo;
begin
  LFunc := FCodeBuilder.GetFunc(AFuncHandle.Index);
  LEntry.FuncName := LFunc.FuncName;
  LEntry.ExportName := AExportName;
  LEntry.FuncIndex := AFuncHandle.Index;
  FEntries.Add(LEntry);
end;

procedure TExportBuilder.Clear();
begin
  FEntries.Clear();
end;

function TExportBuilder.GetCount(): Integer;
begin
  Result := FEntries.Count;
end;

function TExportBuilder.GetEntryByIndex(const AIndex: Integer): TExportEntry;
begin
  Result := FEntries[AIndex];
end;

//==============================================================================
// TCodeBuilder Implementation
//==============================================================================

constructor TCodeBuilder.Create();
begin
  inherited Create();

  FFunctions := TList<TFuncInfo>.Create();
  FCurrentFunc := -1;
end;

destructor TCodeBuilder.Destroy();
begin
  FFunctions.Free();

  inherited;
end;

function TCodeBuilder.GetCurrentFunc(): TFuncInfo;
begin
  if (FCurrentFunc >= 0) and (FCurrentFunc < FFunctions.Count) then
    Result := FFunctions[FCurrentFunc]
  else
  begin
    if Assigned(FErrors) then
      FErrors.Add(esError, ERR_BACKEND_NO_ACTIVE_FUNC, RSBackendNoActiveFunc);
    Result := Default(TFuncInfo);
    Exit;
  end;
end;

procedure TCodeBuilder.SetCurrentFunc(const AFunc: TFuncInfo);
begin
  if (FCurrentFunc >= 0) and (FCurrentFunc < FFunctions.Count) then
    FFunctions[FCurrentFunc] := AFunc
  else
  begin
    if Assigned(FErrors) then
      FErrors.Add(esError, ERR_BACKEND_NO_ACTIVE_FUNC, RSBackendNoActiveFunc);
    Exit;
  end;
end;

function TCodeBuilder.AllocTemp(): TTempHandle;
var
  LFunc: TFuncInfo;
begin
  LFunc := GetCurrentFunc();
  Result.Index := LFunc.TempCount;
  Inc(LFunc.TempCount);
  SetCurrentFunc(LFunc);
end;

procedure TCodeBuilder.AddInstr(const AInstr: TInstruction);
var
  LFunc: TFuncInfo;
  LLen: Integer;
  LStamped: TInstruction;
begin
  LStamped := AInstr;
  // Auto-stamp source location from builder's current tracking state
  if (LStamped.SourceLine = 0) and (FCurrentSourceLine > 0) then
  begin
    LStamped.SourceLine := FCurrentSourceLine;
    LStamped.SourceColumn := FCurrentSourceColumn;
    LStamped.SourceFile := FCurrentSourceFile;
  end;
  LFunc := GetCurrentFunc();
  LLen := Length(LFunc.Instructions);
  SetLength(LFunc.Instructions, LLen + 1);
  LFunc.Instructions[LLen] := LStamped;
  SetCurrentFunc(LFunc);
end;

procedure TCodeBuilder.SetSourceLocation(const ALine: Integer; const AColumn: Integer; const AFile: string);
begin
  FCurrentSourceLine := ALine;
  FCurrentSourceColumn := AColumn;
  FCurrentSourceFile := AFile;
end;

function TCodeBuilder.BeginProc(
  const AName: string;
  const AIsEntryPoint: Boolean;
  const AIsDllEntry: Boolean;
  const AIsPublic: Boolean;
  const ALinkage: TLinkage
): TCodeBuilder;
var
  LFunc: TFuncInfo;
begin
  LFunc := Default(TFuncInfo);
  LFunc.FuncName := AName;
  LFunc.IsEntryPoint := AIsEntryPoint;
  LFunc.IsDllEntry := AIsDllEntry;
  LFunc.IsPublic := AIsPublic;
  LFunc.Linkage := ALinkage;
  LFunc.ReturnType := gvtVoid;
  LFunc.TempCount := 0;

  FCurrentFunc := FFunctions.Count;
  FFunctions.Add(LFunc);

  Result := Self;
end;

function TCodeBuilder.SetReturnType(const AType: TGnyValueType): TCodeBuilder;
var
  LFunc: TFuncInfo;
begin
  LFunc := GetCurrentFunc();
  LFunc.ReturnType := AType;
  LFunc.ReturnSize := 0;
  LFunc.ReturnAlignment := 0;
  SetCurrentFunc(LFunc);
  Result := Self;
end;

function TCodeBuilder.SetReturnType(const AType: TGnyValueType;
  const ASize: Integer; const AAlignment: Integer): TCodeBuilder;
var
  LFunc: TFuncInfo;
begin
  LFunc := GetCurrentFunc();
  LFunc.ReturnType := AType;
  LFunc.ReturnSize := ASize;
  LFunc.ReturnAlignment := AAlignment;
  SetCurrentFunc(LFunc);
  Result := Self;
end;

function TCodeBuilder.SetIsVariadic(const AValue: Boolean): TCodeBuilder;
var
  LFunc: TFuncInfo;
begin
  LFunc := GetCurrentFunc();
  LFunc.IsVariadic := AValue;
  SetCurrentFunc(LFunc);
  Result := Self;
end;

function TCodeBuilder.EndProc(): TCodeBuilder;
var
  LFunc: TFuncInfo;
begin
  // Compute ExportName based on linkage if function is public
  LFunc := GetCurrentFunc();
  if LFunc.IsPublic then
  begin
    case LFunc.Linkage of
      plC:
        // C linkage - use raw function name
        LFunc.ExportName := LFunc.FuncName;
      plDefault:
        // Default linkage - for now use raw name, mangling can be added later
        // TODO: Use TGnyNativeABIMangler when circular dependency is resolved
        LFunc.ExportName := LFunc.FuncName;
    end;
    SetCurrentFunc(LFunc);
  end;
  
  FCurrentFunc := -1;
  Result := Self;
end;

function TCodeBuilder.AddParam(const AName: string; const AType: TGnyValueType; const AIsByRef: Boolean): TLocalHandle;
var
  LFunc: TFuncInfo;
  LParam: TParamInfo;
  LLen: Integer;
begin
  LFunc := GetCurrentFunc();

  LParam.ParamName := AName;
  LParam.ParamType := AType;
  LParam.IsByRef := AIsByRef;

  LLen := Length(LFunc.Params);
  SetLength(LFunc.Params, LLen + 1);
  LFunc.Params[LLen] := LParam;

  SetCurrentFunc(LFunc);

  Result.Index := LLen;
  Result.IsParam := True;
end;

function TCodeBuilder.AddParam(const AName: string; const ASize: Integer; const AAlignment: Integer; const AIsByRef: Boolean): TLocalHandle;
var
  LFunc: TFuncInfo;
  LParam: TParamInfo;
  LLen: Integer;
begin
  LFunc := GetCurrentFunc();

  LParam.ParamName := AName;
  LParam.ParamType := gvtVoid;  // Composite type - no primitive type
  LParam.ParamSize := ASize;
  LParam.ParamAlignment := AAlignment;
  LParam.IsByRef := AIsByRef;

  LLen := Length(LFunc.Params);
  SetLength(LFunc.Params, LLen + 1);
  LFunc.Params[LLen] := LParam;

  SetCurrentFunc(LFunc);

  Result.Index := LLen;
  Result.IsParam := True;
end;

function TCodeBuilder.AddLocal(const AName: string; const AType: TGnyValueType): TLocalHandle;
var
  LFunc: TFuncInfo;
  LLocal: TLocalInfo;
  LLen: Integer;
  LSize: Integer;
begin
  LFunc := GetCurrentFunc();

  // Calculate size based on type
  case AType of
    gvtInt8, gvtUInt8: LSize := 1;
    gvtInt16, gvtUInt16: LSize := 2;
    gvtInt32, gvtUInt32, gvtFloat32: LSize := 4;
    gvtInt64, gvtUInt64, gvtFloat64, gvtPointer: LSize := 8;
  else
    LSize := 8;  // Default to 8 bytes
  end;

  // Align size to 8 bytes for stack alignment
  LSize := ((LSize + 7) div 8) * 8;

  LLocal.LocalName := AName;
  LLocal.LocalType := AType;
  LLocal.LocalSize := LSize;
  LLocal.LocalAlignment := 8;  // All primitives align to 8 bytes
  LLocal.StackOffset := 0;  // Will be calculated during code generation

  LLen := Length(LFunc.Locals);
  SetLength(LFunc.Locals, LLen + 1);
  LFunc.Locals[LLen] := LLocal;

  SetCurrentFunc(LFunc);

  Result.Index := LLen;
  Result.IsParam := False;
end;

function TCodeBuilder.AddLocal(const AName: string; const ASize: Integer): TLocalHandle;
var
  LFunc: TFuncInfo;
  LLocal: TLocalInfo;
  LLen: Integer;
  LAlignedSize: Integer;
begin
  LFunc := GetCurrentFunc();

  // Align size to 8 bytes for stack alignment
  LAlignedSize := ((ASize + 7) div 8) * 8;

  LLocal.LocalName := AName;
  LLocal.LocalType := gvtVoid;  // Composite type
  LLocal.LocalSize := LAlignedSize;
  LLocal.LocalAlignment := 8;  // Default alignment for composite types
  LLocal.StackOffset := 0;  // Will be calculated during code generation

  LLen := Length(LFunc.Locals);
  SetLength(LFunc.Locals, LLen + 1);
  LFunc.Locals[LLen] := LLocal;

  SetCurrentFunc(LFunc);

  Result.Index := LLen;
  Result.IsParam := False;
end;

function TCodeBuilder.AddLocal(const AName: string; const ASize: Integer; const AAlignment: Integer): TLocalHandle;
var
  LFunc: TFuncInfo;
  LLocal: TLocalInfo;
  LLen: Integer;
  LAlignedSize: Integer;
begin
  LFunc := GetCurrentFunc();

  // Align size to 8 bytes for stack alignment
  LAlignedSize := ((ASize + 7) div 8) * 8;

  LLocal.LocalName := AName;
  LLocal.LocalType := gvtVoid;  // Composite type
  LLocal.LocalSize := LAlignedSize;
  LLocal.LocalAlignment := AAlignment;
  LLocal.StackOffset := 0;  // Will be calculated during code generation

  LLen := Length(LFunc.Locals);
  SetLength(LFunc.Locals, LLen + 1);
  LFunc.Locals[LLen] := LLocal;

  SetCurrentFunc(LFunc);

  Result.Index := LLen;
  Result.IsParam := False;
end;

function TCodeBuilder.DefineLabel(const AName: string): TLabelHandle;
var
  LFunc: TFuncInfo;
  LLabel: TLabelInfo;
  LLen: Integer;
begin
  LFunc := GetCurrentFunc();

  LLabel.LabelName := AName;
  LLabel.CodeOffset := -1;
  LLabel.IsDefined := False;

  LLen := Length(LFunc.Labels);
  SetLength(LFunc.Labels, LLen + 1);
  LFunc.Labels[LLen] := LLabel;

  SetCurrentFunc(LFunc);

  Result.Index := LLen;
end;

function TCodeBuilder.MarkLabel(const ALabel: TLabelHandle): TCodeBuilder;
var
  LInstr: TInstruction;
begin
  LInstr := Default(TInstruction);
  LInstr.Kind := ikLabel;
  LInstr.LabelTarget := ALabel;
  AddInstr(LInstr);

  Result := Self;
end;

procedure TCodeBuilder.AddExceptionScope(
  const ATryBegin: TLabelHandle;
  const ATryEnd: TLabelHandle;
  const AExcept: TLabelHandle;
  const AFinally: TLabelHandle;
  const AEnd: TLabelHandle
);
var
  LFunc: TFuncInfo;
  LScope: TExceptionScope;
  LLen: Integer;
begin
  if FCurrentFunc < 0 then
    Exit;
  
  LScope.TryBeginLabel := ATryBegin;
  LScope.TryEndLabel := ATryEnd;
  LScope.ExceptLabel := AExcept;
  LScope.FinallyLabel := AFinally;
  LScope.EndLabel := AEnd;
  
  LFunc := FFunctions[FCurrentFunc];
  LLen := Length(LFunc.ExceptionScopes);
  SetLength(LFunc.ExceptionScopes, LLen + 1);
  LFunc.ExceptionScopes[LLen] := LScope;
  FFunctions[FCurrentFunc] := LFunc;
end;

function TCodeBuilder.Call(const AImport: TImportHandle): TCodeBuilder;
begin
  Result := Call(AImport, []);
end;

function TCodeBuilder.Call(const AImport: TImportHandle; const AArgs: array of TOperand): TCodeBuilder;
var
  LInstr: TInstruction;
  LI: Integer;
begin
  LInstr := Default(TInstruction);
  LInstr.Kind := ikCallImport;
  LInstr.ImportTarget := AImport;
  LInstr.Dest := TTempHandle.Invalid();

  SetLength(LInstr.Args, Length(AArgs));
  for LI := 0 to High(AArgs) do
    LInstr.Args[LI] := AArgs[LI];

  AddInstr(LInstr);
  Result := Self;
end;

function TCodeBuilder.Call(const AFunc: TFuncHandle): TCodeBuilder;
begin
  Result := Call(AFunc, []);
end;

function TCodeBuilder.Call(const AFunc: TFuncHandle; const AArgs: array of TOperand): TCodeBuilder;
var
  LInstr: TInstruction;
  LI: Integer;
begin
  LInstr := Default(TInstruction);
  LInstr.Kind := ikCall;
  LInstr.FuncTarget := AFunc;
  LInstr.Dest := TTempHandle.Invalid();

  SetLength(LInstr.Args, Length(AArgs));
  for LI := 0 to High(AArgs) do
    LInstr.Args[LI] := AArgs[LI];

  AddInstr(LInstr);
  Result := Self;
end;

function TCodeBuilder.CallFunc(const AImport: TImportHandle): TTempHandle;
begin
  Result := CallFunc(AImport, []);
end;

function TCodeBuilder.CallFunc(const AImport: TImportHandle; const AArgs: array of TOperand): TTempHandle;
var
  LInstr: TInstruction;
  LI: Integer;
begin
  Result := AllocTemp();

  LInstr := Default(TInstruction);
  LInstr.Kind := ikCallImport;
  LInstr.ImportTarget := AImport;
  LInstr.Dest := Result;

  SetLength(LInstr.Args, Length(AArgs));
  for LI := 0 to High(AArgs) do
    LInstr.Args[LI] := AArgs[LI];

  AddInstr(LInstr);
end;

function TCodeBuilder.CallFunc(const AFunc: TFuncHandle): TTempHandle;
begin
  Result := CallFunc(AFunc, []);
end;

function TCodeBuilder.CallFunc(const AFunc: TFuncHandle; const AArgs: array of TOperand): TTempHandle;
var
  LInstr: TInstruction;
  LI: Integer;
begin
  Result := AllocTemp();

  LInstr := Default(TInstruction);
  LInstr.Kind := ikCall;
  LInstr.FuncTarget := AFunc;
  LInstr.Dest := Result;

  SetLength(LInstr.Args, Length(AArgs));
  for LI := 0 to High(AArgs) do
    LInstr.Args[LI] := AArgs[LI];

  AddInstr(LInstr);
end;

function TCodeBuilder.CallIndirect(const AFuncPtr: TOperand): TCodeBuilder;
begin
  Result := CallIndirect(AFuncPtr, []);
end;

function TCodeBuilder.CallIndirect(const AFuncPtr: TOperand; const AArgs: array of TOperand): TCodeBuilder;
var
  LInstr: TInstruction;
  LI: Integer;
begin
  LInstr := Default(TInstruction);
  LInstr.Kind := ikCallIndirect;
  LInstr.Op1 := AFuncPtr;  // Function pointer operand
  LInstr.Dest := TTempHandle.Invalid();

  SetLength(LInstr.Args, Length(AArgs));
  for LI := 0 to High(AArgs) do
    LInstr.Args[LI] := AArgs[LI];

  AddInstr(LInstr);
  Result := Self;
end;

function TCodeBuilder.CallIndirectFunc(const AFuncPtr: TOperand): TTempHandle;
begin
  Result := CallIndirectFunc(AFuncPtr, []);
end;

function TCodeBuilder.CallIndirectFunc(const AFuncPtr: TOperand; const AArgs: array of TOperand): TTempHandle;
var
  LInstr: TInstruction;
  LI: Integer;
begin
  Result := AllocTemp();

  LInstr := Default(TInstruction);
  LInstr.Kind := ikCallIndirect;
  LInstr.Op1 := AFuncPtr;  // Function pointer operand
  LInstr.Dest := Result;

  SetLength(LInstr.Args, Length(AArgs));
  for LI := 0 to High(AArgs) do
    LInstr.Args[LI] := AArgs[LI];

  AddInstr(LInstr);
end;

function TCodeBuilder.LoadFuncAddr(const AFuncIndex: Integer): TTempHandle;
var
  LInstr: TInstruction;
  LFuncHandle: TFuncHandle;
begin
  Result := AllocTemp();

  LFuncHandle.Index := AFuncIndex;

  LInstr := Default(TInstruction);
  LInstr.Kind := ikLoad;  // Will be resolved as LEA to function address
  LInstr.Dest := Result;
  LInstr.Op1 := TOperand.FromFunc(LFuncHandle);

  AddInstr(LInstr);
end;

function TCodeBuilder.Return(): TCodeBuilder;
var
  LInstr: TInstruction;
begin
  LInstr := Default(TInstruction);
  LInstr.Kind := ikReturn;
  AddInstr(LInstr);
  Result := Self;
end;

function TCodeBuilder.Return(const AValue: TOperand): TCodeBuilder;
var
  LInstr: TInstruction;
begin
  LInstr := Default(TInstruction);
  LInstr.Kind := ikReturnValue;
  LInstr.Op1 := AValue;
  AddInstr(LInstr);
  Result := Self;
end;

function TCodeBuilder.OpAdd(const ALeft, ARight: TOperand): TTempHandle;
var
  LInstr: TInstruction;
begin
  Result := AllocTemp();

  LInstr := Default(TInstruction);
  LInstr.Kind := ikAdd;
  LInstr.Dest := Result;
  LInstr.Op1 := ALeft;
  LInstr.Op2 := ARight;
  AddInstr(LInstr);
end;

function TCodeBuilder.OpSub(const ALeft, ARight: TOperand): TTempHandle;
var
  LInstr: TInstruction;
begin
  Result := AllocTemp();

  LInstr := Default(TInstruction);
  LInstr.Kind := ikSub;
  LInstr.Dest := Result;
  LInstr.Op1 := ALeft;
  LInstr.Op2 := ARight;
  AddInstr(LInstr);
end;

function TCodeBuilder.OpMul(const ALeft, ARight: TOperand): TTempHandle;
var
  LInstr: TInstruction;
begin
  Result := AllocTemp();

  LInstr := Default(TInstruction);
  LInstr.Kind := ikMul;
  LInstr.Dest := Result;
  LInstr.Op1 := ALeft;
  LInstr.Op2 := ARight;
  AddInstr(LInstr);
end;

function TCodeBuilder.OpDiv(const ALeft, ARight: TOperand): TTempHandle;
var
  LInstr: TInstruction;
begin
  Result := AllocTemp();

  LInstr := Default(TInstruction);
  LInstr.Kind := ikDiv;
  LInstr.Dest := Result;
  LInstr.Op1 := ALeft;
  LInstr.Op2 := ARight;
  AddInstr(LInstr);
end;

function TCodeBuilder.OpMod(const ALeft, ARight: TOperand): TTempHandle;
var
  LInstr: TInstruction;
begin
  Result := AllocTemp();

  LInstr := Default(TInstruction);
  LInstr.Kind := ikMod;
  LInstr.Dest := Result;
  LInstr.Op1 := ALeft;
  LInstr.Op2 := ARight;
  AddInstr(LInstr);
end;

function TCodeBuilder.OpFAdd(const ALeft, ARight: TOperand): TTempHandle;
var
  LInstr: TInstruction;
begin
  Result := AllocTemp();

  LInstr := Default(TInstruction);
  LInstr.Kind := ikFAdd;
  LInstr.Dest := Result;
  LInstr.Op1 := ALeft;
  LInstr.Op2 := ARight;
  AddInstr(LInstr);
end;

function TCodeBuilder.OpFSub(const ALeft, ARight: TOperand): TTempHandle;
var
  LInstr: TInstruction;
begin
  Result := AllocTemp();

  LInstr := Default(TInstruction);
  LInstr.Kind := ikFSub;
  LInstr.Dest := Result;
  LInstr.Op1 := ALeft;
  LInstr.Op2 := ARight;
  AddInstr(LInstr);
end;

function TCodeBuilder.OpFMul(const ALeft, ARight: TOperand): TTempHandle;
var
  LInstr: TInstruction;
begin
  Result := AllocTemp();

  LInstr := Default(TInstruction);
  LInstr.Kind := ikFMul;
  LInstr.Dest := Result;
  LInstr.Op1 := ALeft;
  LInstr.Op2 := ARight;
  AddInstr(LInstr);
end;

function TCodeBuilder.OpFDiv(const ALeft, ARight: TOperand): TTempHandle;
var
  LInstr: TInstruction;
begin
  Result := AllocTemp();

  LInstr := Default(TInstruction);
  LInstr.Kind := ikFDiv;
  LInstr.Dest := Result;
  LInstr.Op1 := ALeft;
  LInstr.Op2 := ARight;
  AddInstr(LInstr);
end;

function TCodeBuilder.OpFNeg(const AValue: TOperand): TTempHandle;
var
  LInstr: TInstruction;
begin
  Result := AllocTemp();

  LInstr := Default(TInstruction);
  LInstr.Kind := ikFNeg;
  LInstr.Dest := Result;
  LInstr.Op1 := TOperand.FromImm(Double(0.0));
  LInstr.Op2 := AValue;
  AddInstr(LInstr);
end;

function TCodeBuilder.OpIntToFloat(const AValue: TOperand): TTempHandle;
var
  LInstr: TInstruction;
begin
  Result := AllocTemp();
  LInstr := Default(TInstruction);
  LInstr.Kind := ikIntToFloat;
  LInstr.Dest := Result;
  LInstr.Op1 := AValue;
  AddInstr(LInstr);
end;

function TCodeBuilder.OpFloatToInt(const AValue: TOperand): TTempHandle;
var
  LInstr: TInstruction;
begin
  Result := AllocTemp();
  LInstr := Default(TInstruction);
  LInstr.Kind := ikFloatToInt;
  LInstr.Dest := Result;
  LInstr.Op1 := AValue;
  AddInstr(LInstr);
end;

function TCodeBuilder.OpAnd(const ALeft, ARight: TOperand): TTempHandle;
var
  LInstr: TInstruction;
begin
  Result := AllocTemp();

  LInstr := Default(TInstruction);
  LInstr.Kind := ikBitAnd;
  LInstr.Dest := Result;
  LInstr.Op1 := ALeft;
  LInstr.Op2 := ARight;
  AddInstr(LInstr);
end;

function TCodeBuilder.OpOr(const ALeft, ARight: TOperand): TTempHandle;
var
  LInstr: TInstruction;
begin
  Result := AllocTemp();

  LInstr := Default(TInstruction);
  LInstr.Kind := ikBitOr;
  LInstr.Dest := Result;
  LInstr.Op1 := ALeft;
  LInstr.Op2 := ARight;
  AddInstr(LInstr);
end;

function TCodeBuilder.OpXor(const ALeft, ARight: TOperand): TTempHandle;
var
  LInstr: TInstruction;
begin
  Result := AllocTemp();

  LInstr := Default(TInstruction);
  LInstr.Kind := ikBitXor;
  LInstr.Dest := Result;
  LInstr.Op1 := ALeft;
  LInstr.Op2 := ARight;
  AddInstr(LInstr);
end;

function TCodeBuilder.OpNot(const AValue: TOperand): TTempHandle;
var
  LInstr: TInstruction;
begin
  Result := AllocTemp();

  LInstr := Default(TInstruction);
  LInstr.Kind := ikBitNot;
  LInstr.Dest := Result;
  LInstr.Op1 := AValue;
  AddInstr(LInstr);
end;

function TCodeBuilder.OpShl(const AValue, ACount: TOperand): TTempHandle;
var
  LInstr: TInstruction;
begin
  Result := AllocTemp();

  LInstr := Default(TInstruction);
  LInstr.Kind := ikShl;
  LInstr.Dest := Result;
  LInstr.Op1 := AValue;
  LInstr.Op2 := ACount;
  AddInstr(LInstr);
end;

function TCodeBuilder.OpShr(const AValue, ACount: TOperand): TTempHandle;
var
  LInstr: TInstruction;
begin
  Result := AllocTemp();

  LInstr := Default(TInstruction);
  LInstr.Kind := ikShr;
  LInstr.Dest := Result;
  LInstr.Op1 := AValue;
  LInstr.Op2 := ACount;
  AddInstr(LInstr);
end;

function TCodeBuilder.CmpEq(const ALeft, ARight: TOperand): TTempHandle;
var
  LInstr: TInstruction;
begin
  Result := AllocTemp();

  LInstr := Default(TInstruction);
  LInstr.Kind := ikCmpEq;
  LInstr.Dest := Result;
  LInstr.Op1 := ALeft;
  LInstr.Op2 := ARight;
  AddInstr(LInstr);
end;

function TCodeBuilder.CmpNe(const ALeft, ARight: TOperand): TTempHandle;
var
  LInstr: TInstruction;
begin
  Result := AllocTemp();

  LInstr := Default(TInstruction);
  LInstr.Kind := ikCmpNe;
  LInstr.Dest := Result;
  LInstr.Op1 := ALeft;
  LInstr.Op2 := ARight;
  AddInstr(LInstr);
end;

function TCodeBuilder.CmpLt(const ALeft, ARight: TOperand): TTempHandle;
var
  LInstr: TInstruction;
begin
  Result := AllocTemp();

  LInstr := Default(TInstruction);
  LInstr.Kind := ikCmpLt;
  LInstr.Dest := Result;
  LInstr.Op1 := ALeft;
  LInstr.Op2 := ARight;
  AddInstr(LInstr);
end;

function TCodeBuilder.CmpLe(const ALeft, ARight: TOperand): TTempHandle;
var
  LInstr: TInstruction;
begin
  Result := AllocTemp();

  LInstr := Default(TInstruction);
  LInstr.Kind := ikCmpLe;
  LInstr.Dest := Result;
  LInstr.Op1 := ALeft;
  LInstr.Op2 := ARight;
  AddInstr(LInstr);
end;

function TCodeBuilder.CmpGt(const ALeft, ARight: TOperand): TTempHandle;
var
  LInstr: TInstruction;
begin
  Result := AllocTemp();

  LInstr := Default(TInstruction);
  LInstr.Kind := ikCmpGt;
  LInstr.Dest := Result;
  LInstr.Op1 := ALeft;
  LInstr.Op2 := ARight;
  AddInstr(LInstr);
end;

function TCodeBuilder.CmpGe(const ALeft, ARight: TOperand): TTempHandle;
var
  LInstr: TInstruction;
begin
  Result := AllocTemp();

  LInstr := Default(TInstruction);
  LInstr.Kind := ikCmpGe;
  LInstr.Dest := Result;
  LInstr.Op1 := ALeft;
  LInstr.Op2 := ARight;
  AddInstr(LInstr);
end;

function TCodeBuilder.FCmpEq(const ALeft, ARight: TOperand): TTempHandle;
var
  LInstr: TInstruction;
begin
  Result := AllocTemp();

  LInstr := Default(TInstruction);
  LInstr.Kind := ikFCmpEq;
  LInstr.Dest := Result;
  LInstr.Op1 := ALeft;
  LInstr.Op2 := ARight;
  AddInstr(LInstr);
end;

function TCodeBuilder.FCmpNe(const ALeft, ARight: TOperand): TTempHandle;
var
  LInstr: TInstruction;
begin
  Result := AllocTemp();

  LInstr := Default(TInstruction);
  LInstr.Kind := ikFCmpNe;
  LInstr.Dest := Result;
  LInstr.Op1 := ALeft;
  LInstr.Op2 := ARight;
  AddInstr(LInstr);
end;

function TCodeBuilder.FCmpLt(const ALeft, ARight: TOperand): TTempHandle;
var
  LInstr: TInstruction;
begin
  Result := AllocTemp();

  LInstr := Default(TInstruction);
  LInstr.Kind := ikFCmpLt;
  LInstr.Dest := Result;
  LInstr.Op1 := ALeft;
  LInstr.Op2 := ARight;
  AddInstr(LInstr);
end;

function TCodeBuilder.FCmpLe(const ALeft, ARight: TOperand): TTempHandle;
var
  LInstr: TInstruction;
begin
  Result := AllocTemp();

  LInstr := Default(TInstruction);
  LInstr.Kind := ikFCmpLe;
  LInstr.Dest := Result;
  LInstr.Op1 := ALeft;
  LInstr.Op2 := ARight;
  AddInstr(LInstr);
end;

function TCodeBuilder.FCmpGt(const ALeft, ARight: TOperand): TTempHandle;
var
  LInstr: TInstruction;
begin
  Result := AllocTemp();

  LInstr := Default(TInstruction);
  LInstr.Kind := ikFCmpGt;
  LInstr.Dest := Result;
  LInstr.Op1 := ALeft;
  LInstr.Op2 := ARight;
  AddInstr(LInstr);
end;

function TCodeBuilder.FCmpGe(const ALeft, ARight: TOperand): TTempHandle;
var
  LInstr: TInstruction;
begin
  Result := AllocTemp();

  LInstr := Default(TInstruction);
  LInstr.Kind := ikFCmpGe;
  LInstr.Dest := Result;
  LInstr.Op1 := ALeft;
  LInstr.Op2 := ARight;
  AddInstr(LInstr);
end;

function TCodeBuilder.OpSetLiteral(const AElements: array of Integer; const ALowBound: Integer; const AStorageSize: Integer): TTempHandle;
var
  LBitPattern: UInt64;
  LI: Integer;
  LInstr: TInstruction;
begin
  // Compute the bit pattern from elements
  LBitPattern := 0;
  for LI := 0 to High(AElements) do
    LBitPattern := LBitPattern or (UInt64(1) shl (AElements[LI] - ALowBound));
  
  // Create temp with the bit pattern as immediate
  Result := AllocTemp();
  
  LInstr := Default(TInstruction);
  LInstr.Kind := ikBitOr;  // Use OR with 0 to load immediate
  LInstr.Dest := Result;
  LInstr.Op1 := TOperand.FromImm(0);
  LInstr.Op2 := TOperand.FromImm(Int64(LBitPattern));
  AddInstr(LInstr);
end;

function TCodeBuilder.OpSetUnion(const ALeft, ARight: TOperand): TTempHandle;
begin
  // Union is bitwise OR
  Result := OpOr(ALeft, ARight);
end;

function TCodeBuilder.OpSetDiff(const ALeft, ARight: TOperand): TTempHandle;
var
  LNotRight: TTempHandle;
begin
  // Difference is A AND (NOT B)
  LNotRight := OpNot(ARight);
  Result := OpAnd(ALeft, TOperand.FromTemp(LNotRight));
end;

function TCodeBuilder.OpSetInter(const ALeft, ARight: TOperand): TTempHandle;
begin
  // Intersection is bitwise AND
  Result := OpAnd(ALeft, ARight);
end;

function TCodeBuilder.OpSetIn(const AElement, ASet: TOperand; const ALowBound: Integer): TTempHandle;
var
  LAdjustedElement: TTempHandle;
  LMask: TTempHandle;
  LAndResult: TTempHandle;
  LMemberResult: TTempHandle;
  LNotNeg: TTempHandle;
  LInRange: TTempHandle;
  LBoundsOk: TTempHandle;
begin
  // Test if element is in set: ((1 << (element - lowbound)) AND set) <> 0
  // With bounds check: adjusted must be in [0..63] to avoid SHL wrap-around
  
  // Adjust element by lowbound if needed
  if ALowBound <> 0 then
    LAdjustedElement := OpSub(AElement, TOperand.FromImm(ALowBound))
  else
  begin
    // Just use element directly - copy to temp
    LAdjustedElement := OpAdd(AElement, TOperand.FromImm(0));
  end;
  
  // Bounds check: adjusted >= 0 AND adjusted < 64
  LNotNeg := CmpGe(TOperand.FromTemp(LAdjustedElement), TOperand.FromImm(0));
  LInRange := CmpLt(TOperand.FromTemp(LAdjustedElement), TOperand.FromImm(64));
  LBoundsOk := OpAnd(TOperand.FromTemp(LNotNeg), TOperand.FromTemp(LInRange));
  
  // Create mask: 1 << adjustedElement
  LMask := OpShl(TOperand.FromImm(1), TOperand.FromTemp(LAdjustedElement));
  
  // AND with set
  LAndResult := OpAnd(TOperand.FromTemp(LMask), ASet);
  
  // Compare with 0 (result is 1 if in set, 0 if not)
  LMemberResult := CmpNe(TOperand.FromTemp(LAndResult), TOperand.FromImm(0));
  
  // Final result: membership AND bounds check
  Result := OpAnd(TOperand.FromTemp(LMemberResult), TOperand.FromTemp(LBoundsOk));
end;

function TCodeBuilder.OpSetEq(const ALeft, ARight: TOperand): TTempHandle;
begin
  // Set equality is direct comparison
  Result := CmpEq(ALeft, ARight);
end;

function TCodeBuilder.OpSetNe(const ALeft, ARight: TOperand): TTempHandle;
begin
  // Set inequality is direct comparison
  Result := CmpNe(ALeft, ARight);
end;

function TCodeBuilder.OpSetSubset(const ALeft, ARight: TOperand): TTempHandle;
var
  LAndResult: TTempHandle;
begin
  // A <= B (subset): (A AND B) = A
  LAndResult := OpAnd(ALeft, ARight);
  Result := CmpEq(TOperand.FromTemp(LAndResult), ALeft);
end;

function TCodeBuilder.OpSetSuperset(const ALeft, ARight: TOperand): TTempHandle;
var
  LAndResult: TTempHandle;
begin
  // A >= B (superset): (A AND B) = B
  LAndResult := OpAnd(ALeft, ARight);
  Result := CmpEq(TOperand.FromTemp(LAndResult), ARight);
end;

function TCodeBuilder.VaCount(): TTempHandle;
var
  LInstr: TInstruction;
begin
  Result := AllocTemp();

  LInstr := Default(TInstruction);
  LInstr.Kind := ikVaCount;
  LInstr.Dest := Result;
  AddInstr(LInstr);
end;

function TCodeBuilder.VaArgAt(const AIndex: TOperand; const AType: TGnyValueType): TTempHandle;
var
  LInstr: TInstruction;
begin
  Result := AllocTemp();

  LInstr := Default(TInstruction);
  LInstr.Kind := ikVaArgAt;
  LInstr.Dest := Result;
  LInstr.Op1 := AIndex;                          // Index expression
  LInstr.Op2 := TOperand.FromImm(Ord(AType)); // Type to read as
  AddInstr(LInstr);
end;



function TCodeBuilder.Store(const ADest: TLocalHandle; const AValue: TOperand): TCodeBuilder;
var
  LInstr: TInstruction;
begin
  LInstr := Default(TInstruction);
  LInstr.Kind := ikStore;
  LInstr.Op1 := TOperand.FromLocal(ADest);
  LInstr.Op2 := AValue;
  AddInstr(LInstr);
  Result := Self;
end;

function TCodeBuilder.Load(const ASrc: TLocalHandle): TTempHandle;
var
  LInstr: TInstruction;
begin
  Result := AllocTemp();

  LInstr := Default(TInstruction);
  LInstr.Kind := ikLoad;
  LInstr.Dest := Result;
  LInstr.Op1 := TOperand.FromLocal(ASrc);
  AddInstr(LInstr);
end;

function TCodeBuilder.StorePtr(const APtr, AValue: TOperand; const AMemSize: Integer; const AMemIsFloat: Boolean): TCodeBuilder;
var
  LInstr: TInstruction;
begin
  LInstr := Default(TInstruction);
  LInstr.Kind := ikStorePtr;
  LInstr.Op1 := APtr;
  LInstr.Op2 := AValue;
  LInstr.MemSize := AMemSize;
  LInstr.MemIsFloat := AMemIsFloat;
  AddInstr(LInstr);
  Result := Self;
end;

function TCodeBuilder.LoadPtr(const APtr: TOperand; const AMemSize: Integer; const AMemIsFloat: Boolean): TTempHandle;
var
  LInstr: TInstruction;
begin
  Result := AllocTemp();

  LInstr := Default(TInstruction);
  LInstr.Kind := ikLoadPtr;
  LInstr.Dest := Result;
  LInstr.Op1 := APtr;
  LInstr.MemSize := AMemSize;
  LInstr.MemIsFloat := AMemIsFloat;
  AddInstr(LInstr);
end;

function TCodeBuilder.AddressOf(const ALocal: TLocalHandle): TTempHandle;
var
  LInstr: TInstruction;
begin
  Result := AllocTemp();

  LInstr := Default(TInstruction);
  LInstr.Kind := ikAddressOf;
  LInstr.Dest := Result;
  LInstr.Op1 := TOperand.FromLocal(ALocal);
  AddInstr(LInstr);
end;

function TCodeBuilder.Jump(const ALabel: TLabelHandle): TCodeBuilder;
var
  LInstr: TInstruction;
begin
  LInstr := Default(TInstruction);
  LInstr.Kind := ikJump;
  LInstr.LabelTarget := ALabel;
  AddInstr(LInstr);
  Result := Self;
end;

function TCodeBuilder.JumpIf(const ACond: TOperand; const ALabel: TLabelHandle): TCodeBuilder;
var
  LInstr: TInstruction;
begin
  LInstr := Default(TInstruction);
  LInstr.Kind := ikJumpIf;
  LInstr.Op1 := ACond;
  LInstr.LabelTarget := ALabel;
  AddInstr(LInstr);
  Result := Self;
end;

function TCodeBuilder.JumpIfNot(const ACond: TOperand; const ALabel: TLabelHandle): TCodeBuilder;
var
  LInstr: TInstruction;
begin
  LInstr := Default(TInstruction);
  LInstr.Kind := ikJumpIfNot;
  LInstr.Op1 := ACond;
  LInstr.LabelTarget := ALabel;
  AddInstr(LInstr);
  Result := Self;
end;

function TCodeBuilder.GetFuncCount(): Integer;
begin
  Result := FFunctions.Count;
end;

function TCodeBuilder.GetFunc(const AIndex: Integer): TFuncInfo;
begin
  if (AIndex >= 0) and (AIndex < FFunctions.Count) then
    Result := FFunctions[AIndex]
  else
    Result := Default(TFuncInfo);
end;

function TCodeBuilder.GetFuncHandle(const AName: string): TFuncHandle;
var
  LI: Integer;
begin
  Result := TFuncHandle.Invalid();
  for LI := 0 to FFunctions.Count - 1 do
  begin
    if SameText(FFunctions[LI].FuncName, AName) then
    begin
      Result.Index := LI;
      Exit;
    end;
  end;
end;

function TCodeBuilder.GetCurrentFuncHandle(): TFuncHandle;
begin
  Result.Index := FCurrentFunc;
end;

procedure TCodeBuilder.Clear();
begin
  FFunctions.Clear();
  FCurrentFunc := -1;
end;

end.
