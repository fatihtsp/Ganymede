{===============================================================================
  Ganymede™ - Embeddable Native Scripting Engine

  Copyright © 2026-present tinyBigGAMES™ LLC
  All Rights Reserved.

  See LICENSE for license information
===============================================================================}

unit Ganymede.Types;

{$I Ganymede.Defines.inc}

interface

uses
  System.SysUtils,
  System.Generics.Collections,
  Ganymede.Utils;

const
  //============================================================================
  // Version Constants
  //============================================================================
  VIPER_MAJOR_VERSION = 0;
  VIPER_MINOR_VERSION = 1;
  VIPER_PATCH_VERSION = 0;
  PXLNATIVE_VERSION = (VIPER_MAJOR_VERSION * 10000) + (VIPER_MINOR_VERSION * 100) + VIPER_PATCH_VERSION;
  PXLNATIVE_VERSION_STR = '0.1.0';

  //============================================================================
  // x86-64 Register Encodings
  //============================================================================
  REG_RAX = 0;  REG_RCX = 1;  REG_RDX = 2;  REG_RBX = 3;
  REG_RSP = 4;  REG_RBP = 5;  REG_RSI = 6;  REG_RDI = 7;
  REG_R8  = 8;  REG_R9  = 9;  REG_R10 = 10; REG_R11 = 11;
  REG_R12 = 12; REG_R13 = 13; REG_R14 = 14; REG_R15 = 15;

  //============================================================================
  // XMM Register Encodings (SSE/AVX floating-point)
  //============================================================================
  REG_XMM0 = 0; REG_XMM1 = 1; REG_XMM2 = 2; REG_XMM3 = 3;
  REG_XMM4 = 4; REG_XMM5 = 5; REG_XMM6 = 6; REG_XMM7 = 7;

  //============================================================================
  // x86-64 Unwind Codes (Win64 SEH)
  //============================================================================
  UNW_FLAG_NHANDLER  = 0;
  UNW_FLAG_EHANDLER  = 1;
  UNW_FLAG_UHANDLER  = 2;
  UNW_FLAG_CHAININFO = 4;

  UWOP_PUSH_NONVOL = 0;
  UWOP_ALLOC_LARGE = 1;
  UWOP_ALLOC_SMALL = 2;
  UWOP_SET_FPREG   = 3;

  // Standard unwind info for functions with push rbp; mov rbp, rsp prologue.
  // Version=1, Flags=0, SizeOfProlog=4, CountOfCodes=1
  // UnwindCode: offset=4, op=UWOP_PUSH_NONVOL, info=RBP(5)
  STANDARD_UNWIND_INFO: array[0..7] of Byte = (
    $01,  // Version=1, Flags=0
    $04,  // SizeOfProlog=4
    $01,  // CountOfCodes=1
    $05,  // FrameRegister=RBP(5), FrameOffset=0
    $04,  // UnwindCode[0].CodeOffset = 4
    $50,  // UnwindCode[0].UnwindOp = UWOP_PUSH_NONVOL(0), OpInfo = RBP(5)
    $00, $00  // Padding to align to DWORD
  );

  //============================================================================
  // Win64 Calling Convention (Microsoft x64)
  //============================================================================

  // Integer/pointer argument registers (in order)
  WIN64_ARG_REGS: array[0..3] of Byte = (REG_RCX, REG_RDX, REG_R8, REG_R9);
  WIN64_MAX_REG_ARGS = 4;

  // Shadow space: 32 bytes mandatory for all calls
  WIN64_SHADOW_SPACE = 32;

  // Callee-saved registers (must be preserved across calls)
  WIN64_CALLEE_SAVED: array[0..7] of Byte = (
    REG_RBX, REG_RBP, REG_RDI, REG_RSI,
    REG_R12, REG_R13, REG_R14, REG_R15
  );

  // Stack alignment requirement
  WIN64_STACK_ALIGN = 16;

type
  PInt32 = ^Int32;

  //============================================================================
  // PUBLIC ENUMERATIONS
  //============================================================================

  { TOutputType }
  TOutputType = (
    otExe,
    otDll,
    otLib,
    otObj
  );

  { TSubsystem }
  TSubsystem = (
    ssConsole,
    ssGui
  );

  { TValueType }
  TValueType = (
    vtVoid,
    vtInt8,
    vtInt16,
    vtInt32,
    vtInt64,
    vtUInt8,
    vtUInt16,
    vtUInt32,
    vtUInt64,
    vtFloat32,
    vtFloat64,
    vtPointer
  );

  { TOptimizeLevel }
  TOptimizeLevel = (
    olNone,         // O0 — no optimization, fastest compile
    olBasic,        // O1 — constant folding, copy propagation, dead code elimination
    olFull          // O2 — includes CSE and additional backend passes
  );

  { TLinkage }
  TLinkage = (
    plDefault,      // Itanium C++ ABI mangling
    plC             // C linkage — no mangling
  );

  { TOpKind - Expression-level operation kinds (used by TExpr) }
  TOpKind = (
    // Arithmetic
    opAdd,
    opSub,
    opMul,
    opIntDiv,
    opMod,
    opNeg,
    // Bitwise
    opBitAnd,
    opBitOr,
    opBitXor,
    opBitNot,
    // Shift
    opShiftL,
    opShiftR,
    // Comparison
    opEq,
    opNe,
    opLt,
    opLe,
    opGt,
    opGe,
    // Logical
    opLogAnd,
    opLogOr,
    opLogNot
  );

  { TOperandKind }
  TOperandKind = (
    okNone,
    okImmediate,
    okData,
    okGlobal,
    okImport,
    okLocal,
    okTemp,
    okFunc
  );

  { TInstrKind }
  TInstrKind = (
    ikNop,
    ikCall,
    ikCallImport,
    ikCallIndirect,
    ikReturn,
    ikReturnValue,
    ikStore,
    ikLoad,
    ikStorePtr,
    ikLoadPtr,
    ikAddressOf,
    ikAdd,
    ikSub,
    ikMul,
    ikDiv,
    ikMod,
    ikFAdd,          // Float: Dest = Op1 + Op2  (ADDSD)
    ikFSub,          // Float: Dest = Op1 - Op2  (SUBSD)
    ikFMul,          // Float: Dest = Op1 * Op2  (MULSD)
    ikFDiv,          // Float: Dest = Op1 / Op2  (DIVSD)
    ikFNeg,          // Float: Dest = -Op1       (0.0 - Op1)
    ikIntToFloat,    // Dest = float64(Op1)     (CVTSI2SD)
    ikFloatToInt,    // Dest = int64(Op1)       (CVTTSD2SI)
    ikBitAnd,
    ikBitOr,
    ikBitXor,
    ikBitNot,
    ikShl,
    ikShr,
    ikCmpEq,
    ikCmpNe,
    ikCmpLt,
    ikCmpLe,
    ikCmpGt,
    ikCmpGe,
    ikFCmpEq,        // Float: Dest = Op1 = Op2   (UCOMISD)
    ikFCmpNe,        // Float: Dest = Op1 <> Op2  (UCOMISD)
    ikFCmpLt,        // Float: Dest = Op1 < Op2   (UCOMISD)
    ikFCmpLe,        // Float: Dest = Op1 <= Op2  (UCOMISD)
    ikFCmpGt,        // Float: Dest = Op1 > Op2   (UCOMISD)
    ikFCmpGe,        // Float: Dest = Op1 >= Op2  (UCOMISD)
    ikJump,
    ikJumpIf,
    ikJumpIfNot,
    ikVaCount,       // dest := VaCount()
    ikVaArgAt,       // dest := VaArgAt(index, type)
    ikLabel
  );

  //============================================================================
  // HANDLE TYPES (Type-safe wrappers)
  //============================================================================

  { TDataHandle }
  TDataHandle = record
    Index: Integer;
    class function Invalid(): TDataHandle; static;
    function IsValid(): Boolean;
    class operator Equal(const A, B: TDataHandle): Boolean;
    class operator NotEqual(const A, B: TDataHandle): Boolean;
  end;

  { TImportHandle }
  TImportHandle = record
    Index: Integer;
    class function Invalid(): TImportHandle; static;
    function IsValid(): Boolean;
    class operator Equal(const A, B: TImportHandle): Boolean;
    class operator NotEqual(const A, B: TImportHandle): Boolean;
  end;

  { TFuncHandle }
  TFuncHandle = record
    Index: Integer;
    class function Invalid(): TFuncHandle; static;
    function IsValid(): Boolean;
    class operator Equal(const A, B: TFuncHandle): Boolean;
    class operator NotEqual(const A, B: TFuncHandle): Boolean;
  end;

  { TLocalHandle }
  TLocalHandle = record
    Index: Integer;
    IsParam: Boolean;
    class function Invalid(): TLocalHandle; static;
    function IsValid(): Boolean;
    class operator Equal(const A, B: TLocalHandle): Boolean;
    class operator NotEqual(const A, B: TLocalHandle): Boolean;
  end;

  { TLabelHandle }
  TLabelHandle = record
    Index: Integer;
    class function Invalid(): TLabelHandle; static;
    function IsValid(): Boolean;
    class operator Equal(const A, B: TLabelHandle): Boolean;
    class operator NotEqual(const A, B: TLabelHandle): Boolean;
  end;

  { TTempHandle }
  TTempHandle = record
    Index: Integer;
    class function Invalid(): TTempHandle; static;
    function IsValid(): Boolean;
    class operator Equal(const A, B: TTempHandle): Boolean;
    class operator NotEqual(const A, B: TTempHandle): Boolean;
  end;

  //============================================================================
  // EXPRESSION RECORD WITH OPERATOR OVERLOADS
  //============================================================================

  { TExpr }
  TExpr = record
    Index: Integer;
    Owner: Pointer;

    // Arithmetic — returns TExpr
    class operator Add(const A, B: TExpr): TExpr;
    class operator Subtract(const A, B: TExpr): TExpr;
    class operator Multiply(const A, B: TExpr): TExpr;
    class operator IntDivide(const A, B: TExpr): TExpr;
    class operator Modulus(const A, B: TExpr): TExpr;
    class operator Negative(const A: TExpr): TExpr;

    // Bitwise — returns TExpr
    class operator BitwiseAnd(const A, B: TExpr): TExpr;
    class operator BitwiseOr(const A, B: TExpr): TExpr;
    class operator BitwiseXor(const A, B: TExpr): TExpr;
    class operator LogicalNot(const A: TExpr): TExpr;

    // Implicit conversions from Delphi literals
    class operator Implicit(const AValue: Int64): TExpr;
    class operator Implicit(const AValue: Double): TExpr;
    class operator Implicit(const AValue: Boolean): TExpr;

    // Comparisons — method syntax (Delphi forces Boolean return on operators)
    function Eq(const AOther: TExpr): TExpr;
    function Ne(const AOther: TExpr): TExpr;
    function Lt(const AOther: TExpr): TExpr;
    function Le(const AOther: TExpr): TExpr;
    function Gt(const AOther: TExpr): TExpr;
    function Ge(const AOther: TExpr): TExpr;

    // Composite access — chained
    function Field(const AFieldName: string): TExpr;
    function At(const AIndex: TExpr): TExpr;
  end;

  //============================================================================
  // EXPRESSION FACTORY CALLBACKS
  //
  // These function pointers are set by the IR layer (Viper.IR.pas) to wire
  // TExpr's operator overloads into the expression graph. Without these,
  // TExpr operators will raise an assertion.
  //============================================================================

  TExprBinaryFunc  = function(const AOwner: Pointer; const AOp: TOpKind; const ALeft, ARight: Integer): TExpr;
  TExprUnaryFunc   = function(const AOwner: Pointer; const AOp: TOpKind; const AOperand: Integer): TExpr;
  TExprFromIntFunc = function(const AOwner: Pointer; const AValue: Int64): TExpr;
  TExprFromFltFunc = function(const AOwner: Pointer; const AValue: Double): TExpr;
  TExprFromBoolFunc = function(const AOwner: Pointer; const AValue: Boolean): TExpr;
  TExprFieldFunc   = function(const AOwner: Pointer; const AExprIdx: Integer; const AFieldName: string): TExpr;
  TExprIndexFunc   = function(const AOwner: Pointer; const AArrIdx: Integer; const AIdxIdx: Integer): TExpr;

  { TExprFactory }
  TExprFactory = record
    class var OnBinary:   TExprBinaryFunc;
    class var OnUnary:    TExprUnaryFunc;
    class var OnFromInt:  TExprFromIntFunc;
    class var OnFromFlt:  TExprFromFltFunc;
    class var OnFromBool: TExprFromBoolFunc;
    class var OnField:    TExprFieldFunc;
    class var OnIndex:    TExprIndexFunc;
  end;

  //============================================================================
  // OPERAND TYPE
  //============================================================================

  { TOperand }
  TOperand = record
    Kind: TOperandKind;
    ValueType: TValueType;
    ImmInt: Int64;
    ImmFloat: Double;
    DataHandle: TDataHandle;
    ImportHandle: TImportHandle;
    LocalHandle: TLocalHandle;
    TempHandle: TTempHandle;
    FuncHandle: TFuncHandle;

    class function None(): TOperand; static;
    class function FromImm(const AValue: Int64): TOperand; overload; static;
    class function FromImm(const AValue: Double): TOperand; overload; static;
    class function FromData(const AHandle: TDataHandle): TOperand; static;
    class function FromGlobal(const AHandle: TDataHandle): TOperand; static;
    class function FromImport(const AHandle: TImportHandle): TOperand; static;
    class function FromLocal(const AHandle: TLocalHandle): TOperand; static;
    class function FromTemp(const AHandle: TTempHandle): TOperand; static;
    class function FromFunc(const AHandle: TFuncHandle): TOperand; static;

    class operator Implicit(const AValue: Integer): TOperand;
    class operator Implicit(const AValue: Int64): TOperand;
    class operator Implicit(const AValue: Cardinal): TOperand;
    class operator Implicit(const AValue: UInt64): TOperand;
    class operator Implicit(const AValue: Single): TOperand;
    class operator Implicit(const AValue: Double): TOperand;
    class operator Implicit(const AValue: TDataHandle): TOperand;
    class operator Implicit(const AValue: TImportHandle): TOperand;
    class operator Implicit(const AValue: TLocalHandle): TOperand;
    class operator Implicit(const AValue: TTempHandle): TOperand;
    class operator Implicit(const AValue: TFuncHandle): TOperand;
  end;

  //============================================================================
  // INTERNAL DATA STRUCTURES
  //============================================================================

  { TDataEntry }
  TDataEntry = record
    Offset: Cardinal;
    Size: Cardinal;
    DataType: TValueType;
  end;

  { TImportEntry }
  TImportEntry = record
    DllName: string;
    FuncName: string;
    IATOffset: Cardinal;
    ReturnType: TValueType;
    IsStatic: Boolean;
    Linkage: TLinkage;
    ParamTypes: TArray<TValueType>;
    HostAddr: Pointer;           // non-nil = host function, skip DLL resolution
  end;

  { TExportEntry }
  TExportEntry = record
    FuncName: string;
    ExportName: string;
    FuncIndex: Integer;
  end;

  { TParamInfo }
  TParamInfo = record
    ParamName: string;
    ParamType: TValueType;
    ParamSize: Integer;
    ParamAlignment: Integer;
    IsByRef: Boolean;
  end;

  { TLocalInfo }
  TLocalInfo = record
    LocalName: string;
    LocalType: TValueType;
    LocalSize: Integer;
    LocalAlignment: Integer;
    StackOffset: Integer;
  end;

  { TLabelInfo }
  TLabelInfo = record
    LabelName: string;
    CodeOffset: Integer;
    IsDefined: Boolean;
  end;

  { TInstruction }
  TInstruction = record
    Kind: TInstrKind;
    Dest: TTempHandle;
    Op1: TOperand;
    Op2: TOperand;
    LabelTarget: TLabelHandle;
    FuncTarget: TFuncHandle;
    ImportTarget: TImportHandle;
    Args: TArray<TOperand>;
    MemSize: Integer;            // Memory access size (0=default 8, 1/2/4/8)
    MemIsFloat: Boolean;         // True for float32/float64 field access
    SourceLine: Integer;         // Source line number (0 = not set)
    SourceColumn: Integer;       // Source column number (0 = not set)
    SourceFile: string;          // Source file path ('' = not set)
  end;

  { TExceptionScope }
  TExceptionScope = record
    TryBeginLabel: TLabelHandle;
    TryEndLabel: TLabelHandle;
    ExceptLabel: TLabelHandle;
    FinallyLabel: TLabelHandle;
    EndLabel: TLabelHandle;
  end;

  { TFuncInfo }
  TFuncInfo = record
    FuncName: string;
    IsEntryPoint: Boolean;
    IsDllEntry: Boolean;
    IsPublic: Boolean;
    Linkage: TLinkage;
    ExportName: string;
    ReturnType: TValueType;
    ReturnSize: Integer;
    ReturnAlignment: Integer;
    Params: TArray<TParamInfo>;
    Locals: TArray<TLocalInfo>;
    Labels: TArray<TLabelInfo>;
    Instructions: TArray<TInstruction>;
    TempCount: Integer;
    ExceptionScopes: TArray<TExceptionScope>;
    IsVariadic: Boolean;
  end;

//============================================================================
// TYPE SHORTHAND CONSTANTS
//============================================================================
const
  tVoid = TValueType.vtVoid;
  tI8   = TValueType.vtInt8;
  tI16  = TValueType.vtInt16;
  tI32  = TValueType.vtInt32;
  tI64  = TValueType.vtInt64;
  tU8   = TValueType.vtUInt8;
  tU16  = TValueType.vtUInt16;
  tU32  = TValueType.vtUInt32;
  tU64  = TValueType.vtUInt64;
  tF32  = TValueType.vtFloat32;
  tF64  = TValueType.vtFloat64;
  tPtr  = TValueType.vtPointer;

//============================================================================
// THREAD-LOCAL EXPRESSION CONTEXT
//
// Set by TGnyNative.Create/Activate. Used by TExpr implicit conversions
// (Int64/Double/Boolean → TExpr) which need an Owner context but don't
// have one from a pre-existing TExpr operand.
//============================================================================
threadvar
  GActiveExprOwner: Pointer;

implementation

//==============================================================================
// TDataHandle
//==============================================================================

{ TDataHandle }

class function TDataHandle.Invalid(): TDataHandle;
begin
  Result.Index := -1;
end;

function TDataHandle.IsValid(): Boolean;
begin
  Result := Index >= 0;
end;

class operator TDataHandle.Equal(const A, B: TDataHandle): Boolean;
begin
  Result := A.Index = B.Index;
end;

class operator TDataHandle.NotEqual(const A, B: TDataHandle): Boolean;
begin
  Result := A.Index <> B.Index;
end;

//==============================================================================
// TImportHandle
//==============================================================================

{ TImportHandle }

class function TImportHandle.Invalid(): TImportHandle;
begin
  Result.Index := -1;
end;

function TImportHandle.IsValid(): Boolean;
begin
  Result := Index >= 0;
end;

class operator TImportHandle.Equal(const A, B: TImportHandle): Boolean;
begin
  Result := A.Index = B.Index;
end;

class operator TImportHandle.NotEqual(const A, B: TImportHandle): Boolean;
begin
  Result := A.Index <> B.Index;
end;

//==============================================================================
// TFuncHandle
//==============================================================================

{ TFuncHandle }

class function TFuncHandle.Invalid(): TFuncHandle;
begin
  Result.Index := -1;
end;

function TFuncHandle.IsValid(): Boolean;
begin
  Result := Index >= 0;
end;

class operator TFuncHandle.Equal(const A, B: TFuncHandle): Boolean;
begin
  Result := A.Index = B.Index;
end;

class operator TFuncHandle.NotEqual(const A, B: TFuncHandle): Boolean;
begin
  Result := A.Index <> B.Index;
end;

//==============================================================================
// TLocalHandle
//==============================================================================

{ TLocalHandle }

class function TLocalHandle.Invalid(): TLocalHandle;
begin
  Result.Index := -1;
  Result.IsParam := False;
end;

function TLocalHandle.IsValid(): Boolean;
begin
  Result := Index >= 0;
end;

class operator TLocalHandle.Equal(const A, B: TLocalHandle): Boolean;
begin
  Result := (A.Index = B.Index) and (A.IsParam = B.IsParam);
end;

class operator TLocalHandle.NotEqual(const A, B: TLocalHandle): Boolean;
begin
  Result := (A.Index <> B.Index) or (A.IsParam <> B.IsParam);
end;

//==============================================================================
// TLabelHandle
//==============================================================================

{ TLabelHandle }

class function TLabelHandle.Invalid(): TLabelHandle;
begin
  Result.Index := -1;
end;

function TLabelHandle.IsValid(): Boolean;
begin
  Result := Index >= 0;
end;

class operator TLabelHandle.Equal(const A, B: TLabelHandle): Boolean;
begin
  Result := A.Index = B.Index;
end;

class operator TLabelHandle.NotEqual(const A, B: TLabelHandle): Boolean;
begin
  Result := A.Index <> B.Index;
end;

//==============================================================================
// TTempHandle
//==============================================================================

{ TTempHandle }

class function TTempHandle.Invalid(): TTempHandle;
begin
  Result.Index := -1;
end;

function TTempHandle.IsValid(): Boolean;
begin
  Result := Index >= 0;
end;

class operator TTempHandle.Equal(const A, B: TTempHandle): Boolean;
begin
  Result := A.Index = B.Index;
end;

class operator TTempHandle.NotEqual(const A, B: TTempHandle): Boolean;
begin
  Result := A.Index <> B.Index;
end;

//==============================================================================
// TExpr
//==============================================================================

{ TExpr }

class operator TExpr.Add(const A, B: TExpr): TExpr;
begin
  Assert(Assigned(TExprFactory.OnBinary), 'TExpr: No expression factory registered');
  Result := TExprFactory.OnBinary(A.Owner, opAdd, A.Index, B.Index);
end;

class operator TExpr.Subtract(const A, B: TExpr): TExpr;
begin
  Assert(Assigned(TExprFactory.OnBinary), 'TExpr: No expression factory registered');
  Result := TExprFactory.OnBinary(A.Owner, opSub, A.Index, B.Index);
end;

class operator TExpr.Multiply(const A, B: TExpr): TExpr;
begin
  Assert(Assigned(TExprFactory.OnBinary), 'TExpr: No expression factory registered');
  Result := TExprFactory.OnBinary(A.Owner, opMul, A.Index, B.Index);
end;

class operator TExpr.IntDivide(const A, B: TExpr): TExpr;
begin
  Assert(Assigned(TExprFactory.OnBinary), 'TExpr: No expression factory registered');
  Result := TExprFactory.OnBinary(A.Owner, opIntDiv, A.Index, B.Index);
end;

class operator TExpr.Modulus(const A, B: TExpr): TExpr;
begin
  Assert(Assigned(TExprFactory.OnBinary), 'TExpr: No expression factory registered');
  Result := TExprFactory.OnBinary(A.Owner, opMod, A.Index, B.Index);
end;

class operator TExpr.Negative(const A: TExpr): TExpr;
begin
  Assert(Assigned(TExprFactory.OnUnary), 'TExpr: No expression factory registered');
  Result := TExprFactory.OnUnary(A.Owner, opNeg, A.Index);
end;

class operator TExpr.BitwiseAnd(const A, B: TExpr): TExpr;
begin
  Assert(Assigned(TExprFactory.OnBinary), 'TExpr: No expression factory registered');
  Result := TExprFactory.OnBinary(A.Owner, opBitAnd, A.Index, B.Index);
end;

class operator TExpr.BitwiseOr(const A, B: TExpr): TExpr;
begin
  Assert(Assigned(TExprFactory.OnBinary), 'TExpr: No expression factory registered');
  Result := TExprFactory.OnBinary(A.Owner, opBitOr, A.Index, B.Index);
end;

class operator TExpr.BitwiseXor(const A, B: TExpr): TExpr;
begin
  Assert(Assigned(TExprFactory.OnBinary), 'TExpr: No expression factory registered');
  Result := TExprFactory.OnBinary(A.Owner, opBitXor, A.Index, B.Index);
end;

class operator TExpr.LogicalNot(const A: TExpr): TExpr;
begin
  Assert(Assigned(TExprFactory.OnUnary), 'TExpr: No expression factory registered');
  Result := TExprFactory.OnUnary(A.Owner, opBitNot, A.Index);
end;

class operator TExpr.Implicit(const AValue: Int64): TExpr;
begin
  Assert(Assigned(TExprFactory.OnFromInt), 'TExpr: No expression factory registered');
  Assert(GActiveExprOwner <> nil, 'TExpr: No active native context');
  Result := TExprFactory.OnFromInt(GActiveExprOwner, AValue);
end;

class operator TExpr.Implicit(const AValue: Double): TExpr;
begin
  Assert(Assigned(TExprFactory.OnFromFlt), 'TExpr: No expression factory registered');
  Assert(GActiveExprOwner <> nil, 'TExpr: No active native context');
  Result := TExprFactory.OnFromFlt(GActiveExprOwner, AValue);
end;

class operator TExpr.Implicit(const AValue: Boolean): TExpr;
begin
  Assert(Assigned(TExprFactory.OnFromBool), 'TExpr: No expression factory registered');
  Assert(GActiveExprOwner <> nil, 'TExpr: No active native context');
  Result := TExprFactory.OnFromBool(GActiveExprOwner, AValue);
end;

function TExpr.Eq(const AOther: TExpr): TExpr;
begin
  Assert(Assigned(TExprFactory.OnBinary), 'TExpr: No expression factory registered');
  Result := TExprFactory.OnBinary(Owner, opEq, Index, AOther.Index);
end;

function TExpr.Ne(const AOther: TExpr): TExpr;
begin
  Assert(Assigned(TExprFactory.OnBinary), 'TExpr: No expression factory registered');
  Result := TExprFactory.OnBinary(Owner, opNe, Index, AOther.Index);
end;

function TExpr.Lt(const AOther: TExpr): TExpr;
begin
  Assert(Assigned(TExprFactory.OnBinary), 'TExpr: No expression factory registered');
  Result := TExprFactory.OnBinary(Owner, opLt, Index, AOther.Index);
end;

function TExpr.Le(const AOther: TExpr): TExpr;
begin
  Assert(Assigned(TExprFactory.OnBinary), 'TExpr: No expression factory registered');
  Result := TExprFactory.OnBinary(Owner, opLe, Index, AOther.Index);
end;

function TExpr.Gt(const AOther: TExpr): TExpr;
begin
  Assert(Assigned(TExprFactory.OnBinary), 'TExpr: No expression factory registered');
  Result := TExprFactory.OnBinary(Owner, opGt, Index, AOther.Index);
end;

function TExpr.Ge(const AOther: TExpr): TExpr;
begin
  Assert(Assigned(TExprFactory.OnBinary), 'TExpr: No expression factory registered');
  Result := TExprFactory.OnBinary(Owner, opGe, Index, AOther.Index);
end;

function TExpr.Field(const AFieldName: string): TExpr;
begin
  Assert(Assigned(TExprFactory.OnField), 'TExpr: No expression factory registered');
  Result := TExprFactory.OnField(Owner, Index, AFieldName);
end;

function TExpr.At(const AIndex: TExpr): TExpr;
begin
  Assert(Assigned(TExprFactory.OnIndex), 'TExpr: No expression factory registered');
  Result := TExprFactory.OnIndex(Owner, Index, AIndex.Index);
end;

//==============================================================================
// TOperand
//==============================================================================

{ TOperand }

class function TOperand.None(): TOperand;
begin
  FillChar(Result, SizeOf(Result), 0);
  Result.Kind := okNone;
end;

class function TOperand.FromImm(const AValue: Int64): TOperand;
begin
  FillChar(Result, SizeOf(Result), 0);
  Result.Kind := okImmediate;
  Result.ValueType := vtInt64;
  Result.ImmInt := AValue;
end;

class function TOperand.FromImm(const AValue: Double): TOperand;
begin
  FillChar(Result, SizeOf(Result), 0);
  Result.Kind := okImmediate;
  Result.ValueType := vtFloat64;
  Result.ImmFloat := AValue;
end;

class function TOperand.FromData(const AHandle: TDataHandle): TOperand;
begin
  FillChar(Result, SizeOf(Result), 0);
  Result.Kind := okData;
  Result.ValueType := vtPointer;
  Result.DataHandle := AHandle;
end;

class function TOperand.FromGlobal(const AHandle: TDataHandle): TOperand;
begin
  FillChar(Result, SizeOf(Result), 0);
  Result.Kind := okGlobal;
  Result.ValueType := vtPointer;
  Result.DataHandle := AHandle;
end;

class function TOperand.FromImport(const AHandle: TImportHandle): TOperand;
begin
  FillChar(Result, SizeOf(Result), 0);
  Result.Kind := okImport;
  Result.ValueType := vtPointer;
  Result.ImportHandle := AHandle;
end;

class function TOperand.FromLocal(const AHandle: TLocalHandle): TOperand;
begin
  FillChar(Result, SizeOf(Result), 0);
  Result.Kind := okLocal;
  Result.LocalHandle := AHandle;
end;

class function TOperand.FromTemp(const AHandle: TTempHandle): TOperand;
begin
  FillChar(Result, SizeOf(Result), 0);
  Result.Kind := okTemp;
  Result.TempHandle := AHandle;
end;

class function TOperand.FromFunc(const AHandle: TFuncHandle): TOperand;
begin
  FillChar(Result, SizeOf(Result), 0);
  Result.Kind := okFunc;
  Result.ValueType := vtPointer;
  Result.FuncHandle := AHandle;
end;

class operator TOperand.Implicit(const AValue: Integer): TOperand;
begin
  Result := FromImm(Int64(AValue));
  Result.ValueType := vtInt32;
end;

class operator TOperand.Implicit(const AValue: Int64): TOperand;
begin
  Result := FromImm(AValue);
end;

class operator TOperand.Implicit(const AValue: Cardinal): TOperand;
begin
  Result := FromImm(Int64(AValue));
  Result.ValueType := vtUInt32;
end;

class operator TOperand.Implicit(const AValue: UInt64): TOperand;
begin
  Result := FromImm(Int64(AValue));
  Result.ValueType := vtUInt64;
end;

class operator TOperand.Implicit(const AValue: Single): TOperand;
begin
  Result := FromImm(Double(AValue));
  Result.ValueType := vtFloat32;
end;

class operator TOperand.Implicit(const AValue: Double): TOperand;
begin
  Result := FromImm(AValue);
end;

class operator TOperand.Implicit(const AValue: TDataHandle): TOperand;
begin
  Result := FromData(AValue);
end;

class operator TOperand.Implicit(const AValue: TImportHandle): TOperand;
begin
  Result := FromImport(AValue);
end;

class operator TOperand.Implicit(const AValue: TLocalHandle): TOperand;
begin
  Result := FromLocal(AValue);
end;

class operator TOperand.Implicit(const AValue: TTempHandle): TOperand;
begin
  Result := FromTemp(AValue);
end;

class operator TOperand.Implicit(const AValue: TFuncHandle): TOperand;
begin
  Result := FromFunc(AValue);
end;

end.
