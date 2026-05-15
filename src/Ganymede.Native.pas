{===============================================================================
  Ganymede™ - Embeddable Native Scripting Engine

  Copyright © 2026-present tinyBigGAMES™ LLC
  All Rights Reserved.

  See LICENSE for license information
===============================================================================}

unit Ganymede.Native;

{$I Ganymede.Defines.inc}

interface

uses
  System.SysUtils,
  System.Generics.Collections,
  System.IOUtils,
  Ganymede.Utils,
  Ganymede.Resources,
  Ganymede.Types,
  Ganymede.Builders,
  Ganymede.Codegen,
  Ganymede.IR,
  Ganymede.Runtime,
  Ganymede.JIT,
  Ganymede.Debug.SourceMap;

type
  TGnyValueType = Ganymede.Types.TGnyValueType;

  TGnySubsystem = Ganymede.Types.TSubsystem;

  TGnyOutputType = Ganymede.Types.TOutputType;

  TGnyLinkage = Ganymede.Types.TLinkage;

  TGnyExpr = Ganymede.IR.TIRExpr;

  TGnyTypeRef = Ganymede.IR.TTypeRef;

  TGnyErrorSeverity = Ganymede.Utils.TGnyErrorSeverity;

  TGnyError = Ganymede.Utils.TGnyError;

  TGnySourceRange = Ganymede.Utils.TGnySourceRange;

  TGnyStatusCallback = Ganymede.Utils.TGnyStatusCallback;

  TGnyDataHandle = Ganymede.Types.TDataHandle;

  TGnyImportHandle = Ganymede.Types.TImportHandle;

  TGnyOperand = Ganymede.Types.TOperand;

  { TJIT }
  TGnyJIT = Ganymede.JIT.TJIT;

//==============================================================================
// ENUM VALUE CONSTANTS
//==============================================================================
// Re-export enum values so the user can write vtInt32 instead of
// Viper.Types.TValueType.vtInt32.
//==============================================================================

const

  //--- Value Types ------------------------------------------------------------

  gvtVoid    = Ganymede.Types.TGnyValueType.gvtVoid;
  gvtInt8    = Ganymede.Types.TGnyValueType.gvtInt8;
  gvtInt16   = Ganymede.Types.TGnyValueType.gvtInt16;
  gvtInt32   = Ganymede.Types.TGnyValueType.gvtInt32;
  gvtInt64   = Ganymede.Types.TGnyValueType.gvtInt64;
  gvtUInt8   = Ganymede.Types.TGnyValueType.gvtUInt8;
  gvtUInt16  = Ganymede.Types.TGnyValueType.gvtUInt16;
  gvtUInt32  = Ganymede.Types.TGnyValueType.gvtUInt32;
  gvtUInt64  = Ganymede.Types.TGnyValueType.gvtUInt64;
  gvtFloat32 = Ganymede.Types.TGnyValueType.gvtFloat32;
  gvtFloat64 = Ganymede.Types.TGnyValueType.gvtFloat64;
  gvtPointer = Ganymede.Types.TGnyValueType.gvtPointer;

  //--- Type Shorthand Constants -----------------------------------------------

  tVoid = gvtVoid;
  tI8   = gvtInt8;
  tI16  = gvtInt16;
  tI32  = gvtInt32;
  tI64  = gvtInt64;
  tU8   = gvtUInt8;
  tU16  = gvtUInt16;
  tU32  = gvtUInt32;
  tU64  = gvtUInt64;
  tF32  = gvtFloat32;
  tF64  = gvtFloat64;
  tPtr  = gvtPointer;

  //--- Subsystem --------------------------------------------------------------

  ssConsole = Ganymede.Types.TSubsystem.ssConsole;
  ssGui     = Ganymede.Types.TSubsystem.ssGui;

  //--- Linkage ----------------------------------------------------------------

  plDefault = Ganymede.Types.TLinkage.plDefault;
  plC       = Ganymede.Types.TLinkage.plC;

  //--- Error Severity ---------------------------------------------------------

  esHint    = Ganymede.Utils.TGnyErrorSeverity.esHint;
  esWarning = Ganymede.Utils.TGnyErrorSeverity.esWarning;
  esError   = Ganymede.Utils.TGnyErrorSeverity.esError;
  esFatal   = Ganymede.Utils.TGnyErrorSeverity.esFatal;

  //--- Version ----------------------------------------------------------------

  PXLNATIVE_VERSION     = Ganymede.Types.PXLNATIVE_VERSION;

  PXLNATIVE_VERSION_STR = Ganymede.Types.PXLNATIVE_VERSION_STR;

type
  //============================================================================
  // TGnyNative — Unified Compiler Facade
  //============================================================================

  TGnyNativeBackend = class(TGnyBaseObject)
  private
    FIR: TIR;
    FBackend: TCodegen;
    FRuntime: TRuntime;
    FStatus: TGnyCallback<TGnyStatusCallback>;
    FSourceMap: TSourceMap;  // Created when opt level = 0 (debug mode)

    // Version info
    FAddVersionInfo: Boolean;
    FVIMajor: Word;
    FVIMinor: Word;
    FVIPatch: Word;
    FVIProductName: string;
    FVIDescription: string;
    FVIFilename: string;
    FVICompanyName: string;
    FVICopyright: string;
    FExeIcon: string;

    procedure ApplyPostBuildResources(const AExePath: string);
  public

    constructor Create(); reintroduce;

    destructor Destroy(); override;

    //==========================================================================
    // Target Configuration
    //==========================================================================

    function TargetExe(
      const APath: string;
      const ASubsystem: TGnySubsystem = ssConsole
    ): TGnyNativeBackend;

    function TargetDll(const APath: string): TGnyNativeBackend;
    function TargetLib(const APath: string): TGnyNativeBackend;
    function TargetObj(const APath: string): TGnyNativeBackend;

    //==========================================================================
    // Static Linking
    //==========================================================================

    function AddLib(const APath: string): TGnyNativeBackend;
    function AddObj(const APath: string): TGnyNativeBackend;
    function AddLibPath(const APath: string): TGnyNativeBackend;

    //==========================================================================
    // Build & Lifecycle
    //==========================================================================
    function Build(const AAutoRun: Boolean = True; AExitCode: PCardinal = nil): Boolean;
    function BuildToMemory(): TBytes;
    function BuildJIT(): TGnyJIT;
    function Run(AExitCode: PCardinal = nil): Boolean;
    procedure Reset();
    procedure ResetBuild();

    //==========================================================================
    // Optimization & Diagnostics
    //==========================================================================
    procedure SetOptimizationLevel(const AValue: Integer);
    function GetOptimizationLevel(): Integer;
    function SetLine(const ALine: Integer; const AColumn: Integer = 0): TGnyNativeBackend;
    function SetSourceFile(const AFile: string): TGnyNativeBackend;
    function GetSourceMap(): TSourceMap;
    procedure SetDumpIR(const AValue: Boolean);
    function GetDumpIR(): Boolean;
    function GetSSADump(): string;

    //==========================================================================
    // Status Callback
    //==========================================================================

    procedure SetStatusCallback(
      const ACallback: TGnyStatusCallback;
      const AUserData: Pointer = nil
    ); override;

    //==========================================================================
    // Error Management
    //==========================================================================
    procedure SetMaxErrors(const AValue: Integer);
    function GetMaxErrors(): Integer;
    function HasErrors(): Boolean;
    function HasWarnings(): Boolean;
    function HasHints(): Boolean;
    function HasFatal(): Boolean;
    function ErrorCount(): Integer;
    function WarningCount(): Integer;
    function GetErrorItems(): TList<TGnyError>;
    function GetErrorText(): string;

    //==========================================================================
    // Imports — Dynamic (DLL) and Static (Lib)
    //==========================================================================

    function ImportDll(
      const ADllName: string;
      const AFuncName: string;
      const AParams: array of TGnyValueType;
      const AReturn: TGnyValueType = gvtVoid;
      const AVarArgs: Boolean = False;
      const ALinkage: TGnyLinkage = plC
    ): TGnyNativeBackend;

    function ImportLib(
      const ALibName: string;
      const AFuncName: string;
      const AParams: array of TGnyValueType;
      const AReturn: TGnyValueType = gvtVoid;
      const AVarArgs: Boolean = False;
      const ALinkage: TGnyLinkage = plC
    ): TGnyNativeBackend;

    function ImportHost(
      const AFuncName: string;
      const AHostAddr: Pointer;
      const AParams: array of TGnyValueType;
      const AReturn: TGnyValueType = gvtVoid
    ): TGnyNativeBackend;

    function GetImportParamTypes(const AFuncName: string): TArray<TGnyValueType>;

    //==========================================================================
    // Global Variables
    //==========================================================================
    function Global(const AName: string; const AType: TGnyValueType; const AIsPublic: Boolean = False): TGnyNativeBackend; overload;
    function Global(const AName: string; const AType: TGnyValueType; const AInit: TGnyExpr; const AIsPublic: Boolean = False): TGnyNativeBackend; overload;
    function Global(const AName: string; const ATypeRef: TGnyTypeRef; const AIsPublic: Boolean = False): TGnyNativeBackend; overload;
    function Global(const AName: string; const ATypeName: string; const AIsPublic: Boolean = False): TGnyNativeBackend; overload;

    //==========================================================================
    // Type Definitions — Records
    //==========================================================================

    function DefineRecord(
      const AName: string;
      const AIsPacked: Boolean = False;
      const AExplicitAlign: Integer = 0;
      const ABaseTypeName: string = ''
    ): TGnyNativeBackend;
    function BeginRecord(): TGnyNativeBackend;
    function Field(const AName: string; const AType: TGnyValueType): TGnyNativeBackend; overload;
    function Field(const AName: string; const ATypeName: string): TGnyNativeBackend; overload;
    function BitField(const AName: string; const AType: TGnyValueType; const ABitWidth: Integer): TGnyNativeBackend;
    function EndRecord(): TGnyNativeBackend;

    //==========================================================================
    // Type Definitions — Unions
    //==========================================================================
    function DefineUnion(const AName: string): TGnyNativeBackend;
    function BeginUnion(): TGnyNativeBackend;
    function EndUnion(): TGnyNativeBackend;

    //==========================================================================
    // Type Definitions — Arrays
    //==========================================================================
    function DefineArray(const AName: string; const AElementType: TGnyValueType;
      const ALowBound: Integer; const AHighBound: Integer): TGnyNativeBackend; overload;
    function DefineArray(const AName: string; const AElementTypeName: string;
      const ALowBound: Integer; const AHighBound: Integer): TGnyNativeBackend; overload;
    function DefineDynArray(const AName: string; const AElementType: TGnyValueType): TGnyNativeBackend; overload;
    function DefineDynArray(const AName: string; const AElementTypeName: string): TGnyNativeBackend; overload;

    //==========================================================================
    // Type Definitions — Enumerations
    //==========================================================================
    function DefineEnum(const AName: string): TGnyNativeBackend;
    function EnumValue(const AName: string): TGnyNativeBackend; overload;
    function EnumValue(const AName: string; const AOrdinal: Int64): TGnyNativeBackend; overload;
    function EndEnum(): TGnyNativeBackend;

    //==========================================================================
    // Type Definitions — Aliases, Pointers, Routines, Sets
    //==========================================================================
    function DefineAlias(const AName: string; const AType: TGnyValueType): TGnyNativeBackend; overload;
    function DefineAlias(const AName: string; const ATypeName: string): TGnyNativeBackend; overload;
    function DefinePointer(const AName: string): TGnyNativeBackend; overload;
    function DefinePointer(const AName: string; const APointeeType: TGnyValueType;
      const AIsConst: Boolean = False): TGnyNativeBackend; overload;
    function DefinePointer(const AName: string; const APointeeTypeName: string;
      const AIsConst: Boolean = False): TGnyNativeBackend; overload;
    function DefineRoutine(const AName: string; const ALinkage: TGnyLinkage = plDefault): TGnyNativeBackend;
    function RoutineParam(const AType: TGnyValueType): TGnyNativeBackend; overload;
    function RoutineParam(const ATypeName: string): TGnyNativeBackend; overload;
    function RoutineReturns(const AType: TGnyValueType): TGnyNativeBackend; overload;
    function RoutineReturns(const ATypeName: string): TGnyNativeBackend; overload;
    function RoutineVarArgs(): TGnyNativeBackend;
    function EndRoutine(): TGnyNativeBackend;
    function DefineSet(const AName: string): TGnyNativeBackend; overload;
    function DefineSet(const AName: string; const ALow: Integer; const AHigh: Integer): TGnyNativeBackend; overload;
    function DefineSet(const AName: string; const AEnumTypeName: string): TGnyNativeBackend; overload;

    //==========================================================================
    // Type Queries
    //==========================================================================
    function FindType(const AName: string): Integer;
    function GetTypeSize(const ATypeRef: TGnyTypeRef): Integer;
    function GetTypeAlignment(const ATypeRef: TGnyTypeRef): Integer;
    function TypeRef(const AName: string): TGnyTypeRef;

    //==========================================================================
    // Function Definition
    //==========================================================================
    function Func(const AName: string;
      const AReturnType: TGnyValueType = gvtVoid;
      const AIsEntryPoint: Boolean = False;
      const ALinkage: TGnyLinkage = plDefault;
      const AIsPublic: Boolean = False): TGnyNativeBackend;

    function OverloadFunc(const AName: string;
      const AReturnType: TGnyValueType = gvtVoid;
      const AIsEntryPoint: Boolean = False;
      const AIsPublic: Boolean = False): TGnyNativeBackend;

    function VariadicFunc(const AName: string;
      const AReturnType: TGnyValueType = gvtVoid;
      const AIsEntryPoint: Boolean = False;
      const AIsPublic: Boolean = False): TGnyNativeBackend;

    function DllMain(): TGnyNativeBackend;
    function Arg(const AName: string; const AType: TGnyValueType; const AByRef: Boolean = False): TGnyNativeBackend; overload;
    function Arg(const AName: string; const ATypeName: string; const AByRef: Boolean = False): TGnyNativeBackend; overload;
    function Returns(const ATypeName: string): TGnyNativeBackend;
    function VarDecl(const AName: string; const AType: TGnyValueType): TGnyNativeBackend; overload;
    function VarDecl(const AName: string; const ATypeName: string): TGnyNativeBackend; overload;
    function EndFunc(): TGnyNativeBackend;

    //==========================================================================
    // Statements — Assignment, Calls, and Return
    //==========================================================================
    function Let(const ADest: string; const AValue: TGnyExpr): TGnyNativeBackend;
    function SetVal(const ADest: TGnyExpr; const AValue: TGnyExpr): TGnyNativeBackend;
    function Call(const AFuncName: string): TGnyNativeBackend; overload;
    function Call(const AFuncName: string; const AArgs: array of TGnyExpr): TGnyNativeBackend; overload;
    function CallAssign(const ADest: string; const AFuncName: string; const AArgs: array of TGnyExpr): TGnyNativeBackend;
    function Ret(): TGnyNativeBackend; overload;
    function Ret(const AValue: TGnyExpr): TGnyNativeBackend; overload;
    function CallIndirect(const AFuncPtr: TGnyExpr): TGnyNativeBackend; overload;
    function CallIndirect(const AFuncPtr: TGnyExpr; const AArgs: array of TGnyExpr): TGnyNativeBackend; overload;
    function CallIndirectAssign(const ADest: string; const AFuncPtr: TGnyExpr;
      const AArgs: array of TGnyExpr): TGnyNativeBackend;

    //==========================================================================
    // Control Flow
    //==========================================================================
    function When(const ACond: TGnyExpr): TGnyNativeBackend;
    function Otherwise(): TGnyNativeBackend;
    function EndWhen(): TGnyNativeBackend;
    function Loop(const ACond: TGnyExpr): TGnyNativeBackend;
    function EndLoop(): TGnyNativeBackend;
    function LoopBreak(): TGnyNativeBackend;
    function LoopContinue(): TGnyNativeBackend;
    function Count(const AVar: string; const AFrom: TGnyExpr; const ATo: TGnyExpr): TGnyNativeBackend;
    function CountDown(const AVar: string; const AFrom: TGnyExpr; const ATo: TGnyExpr): TGnyNativeBackend;
    function EndCount(): TGnyNativeBackend;
    function DoRepeat(): TGnyNativeBackend;
    function StopWhen(const ACond: TGnyExpr): TGnyNativeBackend;
    function Match(const ASelector: TGnyExpr): TGnyNativeBackend;
    function On(const AValues: array of TGnyExpr): TGnyNativeBackend; overload;
    function On(const AValues: array of Integer): TGnyNativeBackend; overload;
    function OnElse(): TGnyNativeBackend;
    function EndMatch(): TGnyNativeBackend;

    //==========================================================================
    // Exception Handling
    //==========================================================================
    function Guard(): TGnyNativeBackend;
    function Catch(): TGnyNativeBackend;
    function Ensure(): TGnyNativeBackend;
    function EndGuard(): TGnyNativeBackend;
    function Throw(const AMsg: TGnyExpr): TGnyNativeBackend;
    function ThrowCode(const ACode: TGnyExpr; const AMsg: TGnyExpr): TGnyNativeBackend;

    //==========================================================================
    // Increment / Decrement
    //==========================================================================
    function Incr(const AVarName: string): TGnyNativeBackend; overload;
    function Incr(const AVarName: string; const AAmount: TGnyExpr): TGnyNativeBackend; overload;
    function Decr(const AVarName: string): TGnyNativeBackend; overload;
    function Decr(const AVarName: string; const AAmount: TGnyExpr): TGnyNativeBackend; overload;

    //==========================================================================
    // Expressions — Literals
    //==========================================================================
    function Str(const AValue: string): TGnyExpr;
    function WStr(const AValue: string): TGnyExpr;
    function Int64(const AValue: Int64): TGnyExpr;
    function Int32(const AValue: Int32): TGnyExpr;
    function Float64(const AValue: Double): TGnyExpr;
    function Bool(const AValue: Boolean): TGnyExpr;
    function Int8(const AValue: Int8): TGnyExpr;
    function Int16(const AValue: Int16): TGnyExpr;
    function UInt8(const AValue: UInt8): TGnyExpr;
    function UInt16(const AValue: UInt16): TGnyExpr;
    function UInt32(const AValue: UInt32): TGnyExpr;
    function UInt64(const AValue: UInt64): TGnyExpr;
    function Float32(const AValue: Single): TGnyExpr;
    function Null(): TGnyExpr;

    //==========================================================================
    // Expressions — Variable Reference
    //==========================================================================
    function Get(const AName: string): TGnyExpr;

    //==========================================================================
    // Expressions — Arithmetic
    //==========================================================================
    function Add(const ALeft: TGnyExpr; const ARight: TGnyExpr): TGnyExpr;
    function Sub(const ALeft: TGnyExpr; const ARight: TGnyExpr): TGnyExpr;
    function Mul(const ALeft: TGnyExpr; const ARight: TGnyExpr): TGnyExpr;
    function IDiv(const ALeft: TGnyExpr; const ARight: TGnyExpr): TGnyExpr;
    function IMod(const ALeft: TGnyExpr; const ARight: TGnyExpr): TGnyExpr;
    function Neg(const AValue: TGnyExpr): TGnyExpr;

    //==========================================================================
    // Expressions — Float Arithmetic
    //==========================================================================
    function FAdd(const ALeft: TGnyExpr; const ARight: TGnyExpr): TGnyExpr;
    function FSub(const ALeft: TGnyExpr; const ARight: TGnyExpr): TGnyExpr;
    function FMul(const ALeft: TGnyExpr; const ARight: TGnyExpr): TGnyExpr;
    function FDiv(const ALeft: TGnyExpr; const ARight: TGnyExpr): TGnyExpr;
    function FNeg(const AValue: TGnyExpr): TGnyExpr;

    //==========================================================================
    // Expressions — Type Conversion
    //==========================================================================
    function IntToFloat64(const AValue: TGnyExpr): TGnyExpr;
    function Float64ToInt(const AValue: TGnyExpr): TGnyExpr;

    //==========================================================================
    // Expressions — Bitwise
    //==========================================================================
    function BitAnd(const ALeft: TGnyExpr; const ARight: TGnyExpr): TGnyExpr;
    function BitOr(const ALeft: TGnyExpr; const ARight: TGnyExpr): TGnyExpr;
    function BitXor(const ALeft: TGnyExpr; const ARight: TGnyExpr): TGnyExpr;
    function BitNot(const AValue: TGnyExpr): TGnyExpr;
    function ShiftL(const AValue: TGnyExpr; const ACount: TGnyExpr): TGnyExpr;
    function ShiftR(const AValue: TGnyExpr; const ACount: TGnyExpr): TGnyExpr;

    //==========================================================================
    // Expressions — Comparison
    //==========================================================================
    function Eq(const ALeft: TGnyExpr; const ARight: TGnyExpr): TGnyExpr;
    function Ne(const ALeft: TGnyExpr; const ARight: TGnyExpr): TGnyExpr;
    function Lt(const ALeft: TGnyExpr; const ARight: TGnyExpr): TGnyExpr;
    function Le(const ALeft: TGnyExpr; const ARight: TGnyExpr): TGnyExpr;
    function Gt(const ALeft: TGnyExpr; const ARight: TGnyExpr): TGnyExpr;
    function Ge(const ALeft: TGnyExpr; const ARight: TGnyExpr): TGnyExpr;

    //==========================================================================
    // Expressions — Float Comparison
    //==========================================================================
    function FEq(const ALeft: TGnyExpr; const ARight: TGnyExpr): TGnyExpr;
    function FNe(const ALeft: TGnyExpr; const ARight: TGnyExpr): TGnyExpr;
    function FLt(const ALeft: TGnyExpr; const ARight: TGnyExpr): TGnyExpr;
    function FLe(const ALeft: TGnyExpr; const ARight: TGnyExpr): TGnyExpr;
    function FGt(const ALeft: TGnyExpr; const ARight: TGnyExpr): TGnyExpr;
    function FGe(const ALeft: TGnyExpr; const ARight: TGnyExpr): TGnyExpr;

    //==========================================================================
    // Expressions — Logical
    //==========================================================================
    function LogAnd(const ALeft: TGnyExpr; const ARight: TGnyExpr): TGnyExpr;
    function LogOr(const ALeft: TGnyExpr; const ARight: TGnyExpr): TGnyExpr;
    function LogNot(const AValue: TGnyExpr): TGnyExpr;

    //==========================================================================
    // Expressions — Pointers
    //==========================================================================
    function AddrOf(const AName: string): TGnyExpr;
    function AddrOfVal(const AExpr: TGnyExpr): TGnyExpr;
    function Deref(const APtr: TGnyExpr): TGnyExpr; overload;
    function Deref(const APtr: TGnyExpr; const ATypeName: string): TGnyExpr; overload;
    function Deref(const APtr: TGnyExpr; const AType: TGnyValueType): TGnyExpr; overload;

    //==========================================================================
    // Expressions — Function Pointers
    //==========================================================================
    function FuncAddr(const AFuncName: string): TGnyExpr;
    function InvokeIndirect(const AFuncPtr: TGnyExpr; const AArgs: array of TGnyExpr): TGnyExpr;

    //==========================================================================
    // Expressions — Composite Access
    //==========================================================================
    function GetField(const AObject: TGnyExpr; const AFieldName: string): TGnyExpr;
    function GetIndex(const AArray: TGnyExpr; const AIndex: TGnyExpr): TGnyExpr;

    //==========================================================================
    // Expressions — Function Call
    //==========================================================================
    function Invoke(const AFuncName: string; const AArgs: array of TGnyExpr): TGnyExpr;

    //==========================================================================
    // Expressions — Exception Intrinsics
    //==========================================================================
    function ExcCode(): TGnyExpr;
    function ExcMsg(): TGnyExpr;

    //==========================================================================
    // Expressions — Set Literals & Operations
    //==========================================================================
    function SetLit(const ATypeName: string; const AElements: array of Integer): TGnyExpr;
    function SetLitRange(const ATypeName: string; const ALow: Integer; const AHigh: Integer): TGnyExpr;
    function EmptySet(const ATypeName: string): TGnyExpr;
    function SetUnion(const ALeft: TGnyExpr; const ARight: TGnyExpr): TGnyExpr;
    function SetDiff(const ALeft: TGnyExpr; const ARight: TGnyExpr): TGnyExpr;
    function SetInter(const ALeft: TGnyExpr; const ARight: TGnyExpr): TGnyExpr;
    function SetIn(const AElement: TGnyExpr; const ASet: TGnyExpr): TGnyExpr; overload;
    function SetIn(const AElement: TGnyExpr; const ASet: TGnyExpr; const ALowBound: Integer): TGnyExpr; overload;
    function SetEq(const ALeft: TGnyExpr; const ARight: TGnyExpr): TGnyExpr;
    function SetNe(const ALeft: TGnyExpr; const ARight: TGnyExpr): TGnyExpr;
    function SetSubset(const ALeft: TGnyExpr; const ARight: TGnyExpr): TGnyExpr;
    function SetSuperset(const ALeft: TGnyExpr; const ARight: TGnyExpr): TGnyExpr;

    //==========================================================================
    // Expressions — Compile-Time Intrinsics
    //==========================================================================
    function TypeSize(const ATypeName: string): TGnyExpr;
    function AlignOf(const ATypeName: string): TGnyExpr;
    function High(const ATypeName: string): TGnyExpr;
    function Low(const ATypeName: string): TGnyExpr;
    function Len(const ATypeName: string): TGnyExpr;

    //==========================================================================
    // Expressions — Runtime Intrinsics
    //==========================================================================
    function Ord(const AValue: TGnyExpr): TGnyExpr;
    function Chr(const AValue: TGnyExpr): TGnyExpr;
    function Succ(const AValue: TGnyExpr): TGnyExpr;
    function Pred(const AValue: TGnyExpr): TGnyExpr;

    //==========================================================================
    // Expressions — Variadic Intrinsics
    //==========================================================================
    function VaCount(): TGnyExpr;
    function VaArg(const AIndex: TGnyExpr; const AType: TGnyValueType): TGnyExpr;

    //==========================================================================
    // Advanced — Direct Access to Internal Objects
    //==========================================================================
    function GetIR(): TIR;
    function GetBackend(): TCodegen;
    function GetErrors(): TGnyErrors;
    function GetTypeCount(): Integer;
    function GetFieldOffset(const ATypeName: string; const AFieldName: string): Integer;

    //==========================================================================
    // VersionInfo
    //==========================================================================
    procedure AddVersionInfo(const AEnable: Boolean);
    procedure SetVersionInfo(const AMajor, AMinor, APatch: Word;
      const AProductName, ADescription, AFilename, ACompanyName,
      ACopyright: string);
    procedure AddExeIcon(const AFilename: string);

    //==========================================================================
    // Shorthand Aliases — Expression Builders
    //==========================================================================
    function V(const AName: string): TGnyExpr; inline;
    function S(const AValue: string): TGnyExpr; inline;
    function W(const AValue: string): TGnyExpr; inline;
    function I(const AValue: Int64): TGnyExpr; inline;
    function F(const AValue: Double): TGnyExpr; inline;
    function B(const AValue: Boolean): TGnyExpr; inline;
    function P(): TGnyExpr; inline;
    function Inv(const AFuncName: string; const AArgs: array of TGnyExpr): TGnyExpr;
    function Fn(const AName: string): TGnyExpr; inline;
    function Addr(const AName: string): TGnyExpr; inline;
  end;

implementation

{$R Ganymede.ResData.res}

//==============================================================================
// TGnyNative
//==============================================================================

constructor TGnyNativeBackend.Create();
begin
  inherited Create();

  FErrors.SetMaxErrors(100);

  FIR := TIR.Create();
  FIR.SetErrors(FErrors);

  // Win64 backend and runtime
  FBackend := TCodegen.Create();
  FRuntime := TRuntime.Create();

  FBackend.SetErrors(FErrors);

  // Inject string types early so user code can reference 'string' type
  FRuntime.AddTypes(FIR);

  FStatus := Default(TGnyCallback<TGnyStatusCallback>);
end;

destructor TGnyNativeBackend.Destroy();
begin
  FSourceMap.Free();
  FRuntime.Free();
  FBackend.Free();
  FIR.Free();

  inherited;
end;

procedure TGnyNativeBackend.ApplyPostBuildResources(const AExePath: string);
var
  LIconPath: string;
  LIsExe: Boolean;
  LIsDll: Boolean;
begin
  LIsExe := AExePath.EndsWith('.exe', True);
  LIsDll := AExePath.EndsWith('.dll', True);

  // Only applies to EXE and DLL files
  if not LIsExe and not LIsDll then
    Exit;

  // 1. Add manifest (EXE only)
  if LIsExe then
  begin
    if TGnyUtils.ResourceExist('EXE_MANIFEST') then
    begin
      if not TGnyUtils.AddResManifestFromResource('EXE_MANIFEST', AExePath) then
        FErrors.Add(esWarning, WRN_MANIFEST_FAILED, RSWarnManifestFailed)
      else
        FBackend.Status('Added application manifest');
    end;
  end;

  // 2. Add icon if specified (EXE only)
  if LIsExe and (FExeIcon <> '') then
  begin
    try
      LIconPath := FExeIcon;
      (*
      // Resolve relative paths against source file directory
      if not TPath.IsPathRooted(LIconPath) then
        LIconPath := TPath.GetFullPath(TPath.Combine(TPath.GetDirectoryName(FSourceFile), LIconPath));
      *)
      if TFile.Exists(LIconPath) then
      begin
        TGnyUtils.UpdateIconResource(AExePath, LIconPath);
        FBackend.Status('Added icon: %s', [LIconPath.Replace('\', '/')]);
      end
      else
        FErrors.Add(esWarning, WRN_ICON_NOT_FOUND, Format(RSWarnIconNotFound, [LIconPath]));
    except
      on E: Exception do
        FErrors.Add(esWarning, WRN_ICON_FAILED, Format(RSWarnIconFailed, [E.Message]));
    end;
  end;

  // 3. Add version info if enabled (EXE and DLL)
  if FAddVersionInfo then
  begin
    try
      TGnyUtils.UpdateVersionInfoResource(
        AExePath,
        FVIMajor,
        FVIMinor,
        FVIPatch,
        FVIProductName,
        FVIDescription,
        FVIFilename,
        FVICompanyName,
        FVICopyright
      );
      FBackend.Status('Added version info: %d.%d.%d', [FVIMajor, FVIMinor, FVIPatch]);
    except
      on E: Exception do
        FErrors.Add(esWarning, WRN_VERSIONINFO_FAILED, Format(RSWarnVersionInfoFailed, [E.Message]));
    end;
  end;
end;

//------------------------------------------------------------------------------
// Target Configuration
//------------------------------------------------------------------------------

function TGnyNativeBackend.TargetExe(const APath: string;
  const ASubsystem: TGnySubsystem): TGnyNativeBackend;
begin
  FBackend.TargetExe(APath, ASubsystem);
  Result := Self;
end;

function TGnyNativeBackend.TargetDll(const APath: string): TGnyNativeBackend;
begin
  FBackend.TargetDll(APath);
  Result := Self;
end;

function TGnyNativeBackend.TargetLib(const APath: string): TGnyNativeBackend;
begin
  FBackend.TargetLib(APath);
  Result := Self;
end;

function TGnyNativeBackend.TargetObj(const APath: string): TGnyNativeBackend;
begin
  FBackend.TargetObj(APath);
  Result := Self;
end;

//------------------------------------------------------------------------------
// Static Linking
//------------------------------------------------------------------------------

function TGnyNativeBackend.AddLib(const APath: string): TGnyNativeBackend;
begin
  FBackend.AddLib(APath);
  Result := Self;
end;

function TGnyNativeBackend.AddObj(const APath: string): TGnyNativeBackend;
begin
  FBackend.AddObj(APath);
  Result := Self;
end;

function TGnyNativeBackend.AddLibPath(const APath: string): TGnyNativeBackend;
begin
  FBackend.AddLibPath(APath);
  Result := Self;
end;

//------------------------------------------------------------------------------
// Build & Lifecycle
//------------------------------------------------------------------------------

function TGnyNativeBackend.Build(const AAutoRun: Boolean; AExitCode: PCardinal): Boolean;
var
  LExitCode: Cardinal;
begin
  // Strip any previously-injected runtime, then mark user code boundary
  FIR.RestoreSnapshot();
  FIR.SaveSnapshot();

  // Inject runtime library (optimizer removes unused routines)
  FRuntime.AddAll(FIR, FBackend.GetOptimizationLevel());

  // Debug mode (opt level 0): create source map for debugger support
  if FBackend.GetOptimizationLevel() = 0 then
  begin
    FreeAndNil(FSourceMap);
    FSourceMap := TSourceMap.Create();
    FBackend.SetSourceMap(FSourceMap);
  end
  else
    FBackend.SetSourceMap(nil);

  // Compile IR through the codegen pipeline
  FBackend.Compile(FIR, FStatus.Callback, FStatus.UserData);

  // Produce the target binary
  Result := FBackend.Build();

  if Result then
  begin
    // Apply post build resources
    ApplyPostBuildResources(FBackend.GetOutputPath());

    // Autorun (skip for DLLs/shared libraries - they can't be executed directly)
    if AAutoRun and
       not FBackend.GetOutputPath().EndsWith('.dll', True) and
       not FBackend.GetOutputPath().EndsWith('.lib', True) and
       not FBackend.GetOutputPath().EndsWith('.obj', True) then
    begin
      FBackend.Status('Running: %s', [FBackend.GetOutputPath().Replace('\', '/')]);
      LExitCode := FBackend.Run();
      FBackend.Status('Process exited with code: %d', [LExitCode]);
      if Assigned(AExitCode) then
        AExitCode^ := LExitCode;
    end;
  end;
end;

function TGnyNativeBackend.Run(AExitCode: PCardinal): Boolean;
var
  LExitCode: Cardinal;
begin
  Result := False;

  // Skip non-executable output types
  if FBackend.GetOutputPath().EndsWith('.dll', True) or
     FBackend.GetOutputPath().EndsWith('.lib', True) or
     FBackend.GetOutputPath().EndsWith('.obj', True) then
    Exit;

  FBackend.Status('Running: %s', [FBackend.GetOutputPath().Replace('\', '/')]);
  LExitCode := FBackend.Run();
  FBackend.Status('Process exited with code: %d', [LExitCode]);

  if Assigned(AExitCode) then
    AExitCode^ := LExitCode;

  Result := True;
end;

function TGnyNativeBackend.BuildToMemory(): TBytes;
begin
  // Strip any previously-injected runtime, then mark user code boundary
  FIR.RestoreSnapshot();
  FIR.SaveSnapshot();

  // Inject runtime library
  FRuntime.AddAll(FIR, FBackend.GetOptimizationLevel());

  // Compile IR through the codegen pipeline
  FBackend.Compile(FIR, FStatus.Callback, FStatus.UserData);

  // Produce the binary in memory
  Result := FBackend.BuildToMemory();
end;

function TGnyNativeBackend.BuildJIT(): TGnyJIT;
begin
  // Strip any previously-injected runtime, then mark user code boundary
  FIR.RestoreSnapshot();
  FIR.SaveSnapshot();

  // Inject runtime library (optimizer removes unused routines)
  FRuntime.AddAll(FIR, FBackend.GetOptimizationLevel());

  // Debug mode (opt level 0): create source map for debugger support
  if FBackend.GetOptimizationLevel() = 0 then
  begin
    FreeAndNil(FSourceMap);
    FSourceMap := TSourceMap.Create();
    FBackend.SetSourceMap(FSourceMap);
  end
  else
    FBackend.SetSourceMap(nil);

  // Compile IR through the codegen pipeline
  FBackend.Compile(FIR, FStatus.Callback, FStatus.UserData);

  // Produce JIT-executable code in memory
  Result := FBackend.BuildJIT();
end;

procedure TGnyNativeBackend.Reset();
begin
  FreeAndNil(FSourceMap);
  FBackend.SetSourceMap(nil);
  FIR.Clear();
  FBackend.Clear();
  FErrors.Clear();
end;

procedure TGnyNativeBackend.ResetBuild();
begin
  FreeAndNil(FSourceMap);
  FBackend.SetSourceMap(nil);
  FBackend.Clear();
  FErrors.Clear();
end;

//------------------------------------------------------------------------------
// Optimization & Diagnostics
//------------------------------------------------------------------------------

procedure TGnyNativeBackend.SetOptimizationLevel(const AValue: Integer);
begin
  FBackend.SetOptimizationLevel(AValue);
end;

function TGnyNativeBackend.GetOptimizationLevel(): Integer;
begin
  Result := FBackend.GetOptimizationLevel();
end;

function TGnyNativeBackend.SetLine(const ALine: Integer; const AColumn: Integer): TGnyNativeBackend;
begin
  FIR.SetLine(ALine, AColumn);
  Result := Self;
end;

function TGnyNativeBackend.SetSourceFile(const AFile: string): TGnyNativeBackend;
begin
  FIR.SetSourceFile(AFile);
  Result := Self;
end;

function TGnyNativeBackend.GetSourceMap(): TSourceMap;
begin
  Result := FSourceMap;
end;

procedure TGnyNativeBackend.SetDumpIR(const AValue: Boolean);
begin
  FBackend.SetDumpIR(AValue);
end;

function TGnyNativeBackend.GetDumpIR(): Boolean;
begin
  Result := FBackend.GetDumpIR();
end;

function TGnyNativeBackend.GetSSADump(): string;
begin
  Result := FBackend.GetSSADump();
end;

//------------------------------------------------------------------------------
// Status Callback
//------------------------------------------------------------------------------

procedure TGnyNativeBackend.SetStatusCallback(const ACallback: TGnyStatusCallback;
  const AUserData: Pointer);
begin
  FStatus.Callback := ACallback;
  FStatus.UserData := AUserData;
  FBackend.SetStatusCallback(ACallback, AUserData);
end;

//------------------------------------------------------------------------------
// Error Management
//------------------------------------------------------------------------------

procedure TGnyNativeBackend.SetMaxErrors(const AValue: Integer);
begin
  FErrors.SetMaxErrors(AValue);
end;

function TGnyNativeBackend.GetMaxErrors(): Integer;
begin
  Result := FErrors.GetMaxErrors();
end;

function TGnyNativeBackend.HasErrors(): Boolean;
begin
  Result := FErrors.HasErrors();
end;

function TGnyNativeBackend.HasWarnings(): Boolean;
begin
  Result := FErrors.HasWarnings();
end;

function TGnyNativeBackend.HasHints(): Boolean;
begin
  Result := FErrors.HasHints();
end;

function TGnyNativeBackend.HasFatal(): Boolean;
begin
  Result := FErrors.HasFatal();
end;

function TGnyNativeBackend.ErrorCount(): Integer;
begin
  Result := FErrors.ErrorCount();
end;

function TGnyNativeBackend.WarningCount(): Integer;
begin
  Result := FErrors.WarningCount();
end;

function TGnyNativeBackend.GetErrorItems(): TList<TGnyError>;
begin
  Result := FErrors.GetItems();
end;

function TGnyNativeBackend.GetErrorText(): string;
var
  LBuilder: TStringBuilder;
  LI: Integer;
begin
  if FErrors.Count() = 0 then
    Exit('');

  LBuilder := TStringBuilder.Create();
  try
    for LI := 0 to FErrors.GetItems().Count - 1 do
    begin
      if LI > 0 then
        LBuilder.AppendLine();
      LBuilder.Append(FErrors.GetItems()[LI].ToFullString());
    end;
    Result := LBuilder.ToString();
  finally
    LBuilder.Free();
  end;
end;

//------------------------------------------------------------------------------
// Imports
//------------------------------------------------------------------------------

function TGnyNativeBackend.ImportDll(const ADllName: string; const AFuncName: string;
  const AParams: array of TGnyValueType; const AReturn: TGnyValueType;
  const AVarArgs: Boolean; const ALinkage: TGnyLinkage): TGnyNativeBackend;
begin
  FIR.Import(ADllName, AFuncName, AParams, AReturn, AVarArgs, ALinkage);
  Result := Self;
end;

function TGnyNativeBackend.ImportLib(const ALibName: string; const AFuncName: string;
  const AParams: array of TGnyValueType; const AReturn: TGnyValueType;
  const AVarArgs: Boolean; const ALinkage: TGnyLinkage): TGnyNativeBackend;
begin
  FIR.ImportLib(ALibName, AFuncName, AParams, AReturn, AVarArgs, ALinkage);
  Result := Self;
end;

function TGnyNativeBackend.ImportHost(const AFuncName: string;
  const AHostAddr: Pointer; const AParams: array of TGnyValueType;
  const AReturn: TGnyValueType): TGnyNativeBackend;
begin
  FIR.ImportHost(AFuncName, AHostAddr, AParams, AReturn);
  Result := Self;
end;

function TGnyNativeBackend.GetImportParamTypes(const AFuncName: string): TArray<TGnyValueType>;
var
  LI: Integer;
begin
  Result := nil;
  for LI := 0 to FIR.GetImportCount() - 1 do
  begin
    if SameText(FIR.GetImport(LI).FuncName, AFuncName) then
    begin
      Result := FIR.GetImport(LI).ParamTypes;
      Exit;
    end;
  end;
end;

//------------------------------------------------------------------------------
// Global Variables
//------------------------------------------------------------------------------

function TGnyNativeBackend.Global(const AName: string; const AType: TGnyValueType; const AIsPublic: Boolean): TGnyNativeBackend;
begin
  FIR.Global(AName, AType, AIsPublic);
  Result := Self;
end;

function TGnyNativeBackend.Global(const AName: string; const AType: TGnyValueType;
  const AInit: TGnyExpr; const AIsPublic: Boolean): TGnyNativeBackend;
begin
  FIR.Global(AName, AType, AInit, AIsPublic);
  Result := Self;
end;

function TGnyNativeBackend.Global(const AName: string; const ATypeRef: TGnyTypeRef; const AIsPublic: Boolean): TGnyNativeBackend;
begin
  FIR.Global(AName, ATypeRef, AIsPublic);
  Result := Self;
end;

function TGnyNativeBackend.Global(const AName: string; const ATypeName: string; const AIsPublic: Boolean): TGnyNativeBackend;
begin
  FIR.Global(AName, ATypeName, AIsPublic);
  Result := Self;
end;

//------------------------------------------------------------------------------
// Type Definitions — Records
//------------------------------------------------------------------------------

function TGnyNativeBackend.DefineRecord(const AName: string; const AIsPacked: Boolean;
  const AExplicitAlign: Integer; const ABaseTypeName: string): TGnyNativeBackend;
begin
  FIR.DefineRecord(AName, AIsPacked, AExplicitAlign, ABaseTypeName);
  Result := Self;
end;

function TGnyNativeBackend.BeginRecord(): TGnyNativeBackend;
begin
  FIR.BeginRecord();
  Result := Self;
end;

function TGnyNativeBackend.Field(const AName: string; const AType: TGnyValueType): TGnyNativeBackend;
begin
  FIR.Field(AName, AType);
  Result := Self;
end;

function TGnyNativeBackend.Field(const AName: string; const ATypeName: string): TGnyNativeBackend;
begin
  FIR.Field(AName, ATypeName);
  Result := Self;
end;

function TGnyNativeBackend.BitField(const AName: string; const AType: TGnyValueType;
  const ABitWidth: Integer): TGnyNativeBackend;
begin
  FIR.BitField(AName, AType, ABitWidth);
  Result := Self;
end;

function TGnyNativeBackend.EndRecord(): TGnyNativeBackend;
begin
  FIR.EndRecord();
  Result := Self;
end;

function TGnyNativeBackend.DefineUnion(const AName: string): TGnyNativeBackend;
begin
  FIR.DefineUnion(AName);
  Result := Self;
end;

function TGnyNativeBackend.BeginUnion(): TGnyNativeBackend;
begin
  FIR.BeginUnion();
  Result := Self;
end;

function TGnyNativeBackend.EndUnion(): TGnyNativeBackend;
begin
  FIR.EndUnion();
  Result := Self;
end;

function TGnyNativeBackend.DefineArray(const AName: string;
  const AElementType: TGnyValueType; const ALowBound: Integer;
  const AHighBound: Integer): TGnyNativeBackend;
begin
  FIR.DefineArray(AName, AElementType, ALowBound, AHighBound);
  Result := Self;
end;

function TGnyNativeBackend.DefineArray(const AName: string;
  const AElementTypeName: string; const ALowBound: Integer;
  const AHighBound: Integer): TGnyNativeBackend;
begin
  FIR.DefineArray(AName, AElementTypeName, ALowBound, AHighBound);
  Result := Self;
end;

function TGnyNativeBackend.DefineDynArray(const AName: string;
  const AElementType: TGnyValueType): TGnyNativeBackend;
begin
  FIR.DefineDynArray(AName, AElementType);
  Result := Self;
end;

function TGnyNativeBackend.DefineDynArray(const AName: string;
  const AElementTypeName: string): TGnyNativeBackend;
begin
  FIR.DefineDynArray(AName, AElementTypeName);
  Result := Self;
end;

function TGnyNativeBackend.DefineEnum(const AName: string): TGnyNativeBackend;
begin
  FIR.DefineEnum(AName);
  Result := Self;
end;

function TGnyNativeBackend.EnumValue(const AName: string): TGnyNativeBackend;
begin
  FIR.EnumValue(AName);
  Result := Self;
end;

function TGnyNativeBackend.EnumValue(const AName: string; const AOrdinal: Int64): TGnyNativeBackend;
begin
  FIR.EnumValue(AName, AOrdinal);
  Result := Self;
end;

function TGnyNativeBackend.EndEnum(): TGnyNativeBackend;
begin
  FIR.EndEnum();
  Result := Self;
end;

function TGnyNativeBackend.DefineAlias(const AName: string; const AType: TGnyValueType): TGnyNativeBackend;
begin
  FIR.DefineAlias(AName, AType);
  Result := Self;
end;

function TGnyNativeBackend.DefineAlias(const AName: string; const ATypeName: string): TGnyNativeBackend;
begin
  FIR.DefineAlias(AName, ATypeName);
  Result := Self;
end;

function TGnyNativeBackend.DefinePointer(const AName: string): TGnyNativeBackend;
begin
  FIR.DefinePointer(AName);
  Result := Self;
end;

function TGnyNativeBackend.DefinePointer(const AName: string;
  const APointeeType: TGnyValueType; const AIsConst: Boolean): TGnyNativeBackend;
begin
  FIR.DefinePointer(AName, APointeeType, AIsConst);
  Result := Self;
end;

function TGnyNativeBackend.DefinePointer(const AName: string;
  const APointeeTypeName: string; const AIsConst: Boolean): TGnyNativeBackend;
begin
  FIR.DefinePointer(AName, APointeeTypeName, AIsConst);
  Result := Self;
end;

function TGnyNativeBackend.DefineRoutine(const AName: string;
  const ALinkage: TGnyLinkage): TGnyNativeBackend;
begin
  FIR.DefineRoutine(AName, ALinkage);
  Result := Self;
end;

function TGnyNativeBackend.RoutineParam(const AType: TGnyValueType): TGnyNativeBackend;
begin
  FIR.RoutineParam(AType);
  Result := Self;
end;

function TGnyNativeBackend.RoutineParam(const ATypeName: string): TGnyNativeBackend;
begin
  FIR.RoutineParam(ATypeName);
  Result := Self;
end;

function TGnyNativeBackend.RoutineReturns(const AType: TGnyValueType): TGnyNativeBackend;
begin
  FIR.RoutineReturns(AType);
  Result := Self;
end;

function TGnyNativeBackend.RoutineReturns(const ATypeName: string): TGnyNativeBackend;
begin
  FIR.RoutineReturns(ATypeName);
  Result := Self;
end;

function TGnyNativeBackend.RoutineVarArgs(): TGnyNativeBackend;
begin
  FIR.RoutineVarArgs();
  Result := Self;
end;

function TGnyNativeBackend.EndRoutine(): TGnyNativeBackend;
begin
  FIR.EndRoutine();
  Result := Self;
end;

function TGnyNativeBackend.DefineSet(const AName: string): TGnyNativeBackend;
begin
  FIR.DefineSet(AName);
  Result := Self;
end;

function TGnyNativeBackend.DefineSet(const AName: string; const ALow: Integer;
  const AHigh: Integer): TGnyNativeBackend;
begin
  FIR.DefineSet(AName, ALow, AHigh);
  Result := Self;
end;

function TGnyNativeBackend.DefineSet(const AName: string; const AEnumTypeName: string): TGnyNativeBackend;
begin
  FIR.DefineSet(AName, AEnumTypeName);
  Result := Self;
end;

function TGnyNativeBackend.FindType(const AName: string): Integer;
begin
  Result := FIR.FindType(AName);
end;

function TGnyNativeBackend.GetTypeSize(const ATypeRef: TGnyTypeRef): Integer;
begin
  Result := FIR.GetTypeSize(ATypeRef);
end;

function TGnyNativeBackend.GetTypeAlignment(const ATypeRef: TGnyTypeRef): Integer;
begin
  Result := FIR.GetTypeAlignment(ATypeRef);
end;

function TGnyNativeBackend.TypeRef(const AName: string): TGnyTypeRef;
begin
  Result := FIR.TypeRef(AName);
end;

//------------------------------------------------------------------------------
// Function Definition
//------------------------------------------------------------------------------

function TGnyNativeBackend.Func(const AName: string;
  const AReturnType: TGnyValueType; const AIsEntryPoint: Boolean;
  const ALinkage: TGnyLinkage; const AIsPublic: Boolean): TGnyNativeBackend;
begin
  FIR.Func(AName, AReturnType, AIsEntryPoint, ALinkage, AIsPublic);
  Result := Self;
end;

function TGnyNativeBackend.OverloadFunc(const AName: string;
  const AReturnType: TGnyValueType; const AIsEntryPoint: Boolean;
  const AIsPublic: Boolean): TGnyNativeBackend;
begin
  FIR.OverloadFunc(AName, AReturnType, AIsEntryPoint, AIsPublic);
  Result := Self;
end;

function TGnyNativeBackend.VariadicFunc(const AName: string;
  const AReturnType: TGnyValueType; const AIsEntryPoint: Boolean;
  const AIsPublic: Boolean): TGnyNativeBackend;
begin
  FIR.VariadicFunc(AName, AReturnType, AIsEntryPoint, AIsPublic);
  Result := Self;
end;

function TGnyNativeBackend.DllMain(): TGnyNativeBackend;
begin
  FIR.DllMain();
  Result := Self;
end;

function TGnyNativeBackend.Arg(const AName: string; const AType: TGnyValueType; const AByRef: Boolean): TGnyNativeBackend;
begin
  FIR.Param(AName, AType, AByRef);
  Result := Self;
end;

function TGnyNativeBackend.Arg(const AName: string; const ATypeName: string; const AByRef: Boolean): TGnyNativeBackend;
begin
  FIR.Param(AName, ATypeName, AByRef);
  Result := Self;
end;

function TGnyNativeBackend.Returns(const ATypeName: string): TGnyNativeBackend;
begin
  FIR.Returns(ATypeName);
  Result := Self;
end;

function TGnyNativeBackend.VarDecl(const AName: string; const AType: TGnyValueType): TGnyNativeBackend;
begin
  FIR.Local(AName, AType);
  Result := Self;
end;

function TGnyNativeBackend.VarDecl(const AName: string; const ATypeName: string): TGnyNativeBackend;
begin
  FIR.Local(AName, ATypeName);
  Result := Self;
end;

function TGnyNativeBackend.EndFunc(): TGnyNativeBackend;
begin
  FIR.EndFunc();
  Result := Self;
end;

//------------------------------------------------------------------------------
// Statements
//------------------------------------------------------------------------------

function TGnyNativeBackend.Let(const ADest: string; const AValue: TGnyExpr): TGnyNativeBackend;
begin
  FIR.Assign(ADest, AValue);
  Result := Self;
end;

function TGnyNativeBackend.SetVal(const ADest: TGnyExpr;
  const AValue: TGnyExpr): TGnyNativeBackend;
begin
  FIR.SetVal(ADest, AValue);
  Result := Self;
end;

function TGnyNativeBackend.Call(const AFuncName: string): TGnyNativeBackend;
begin
  FIR.Call(AFuncName);
  Result := Self;
end;

function TGnyNativeBackend.Call(const AFuncName: string;
  const AArgs: array of TGnyExpr): TGnyNativeBackend;
begin
  FIR.Call(AFuncName, AArgs);
  Result := Self;
end;

function TGnyNativeBackend.CallAssign(const ADest: string; const AFuncName: string;
  const AArgs: array of TGnyExpr): TGnyNativeBackend;
begin
  FIR.CallAssign(ADest, AFuncName, AArgs);
  Result := Self;
end;

function TGnyNativeBackend.Ret(): TGnyNativeBackend;
begin
  FIR.Return();
  Result := Self;
end;

function TGnyNativeBackend.Ret(const AValue: TGnyExpr): TGnyNativeBackend;
begin
  FIR.Return(AValue);
  Result := Self;
end;

function TGnyNativeBackend.CallIndirect(const AFuncPtr: TGnyExpr): TGnyNativeBackend;
begin
  FIR.CallIndirect(AFuncPtr);
  Result := Self;
end;

function TGnyNativeBackend.CallIndirect(const AFuncPtr: TGnyExpr;
  const AArgs: array of TGnyExpr): TGnyNativeBackend;
begin
  FIR.CallIndirect(AFuncPtr, AArgs);
  Result := Self;
end;

function TGnyNativeBackend.CallIndirectAssign(const ADest: string;
  const AFuncPtr: TGnyExpr; const AArgs: array of TGnyExpr): TGnyNativeBackend;
begin
  FIR.CallIndirectAssign(ADest, AFuncPtr, AArgs);
  Result := Self;
end;

//------------------------------------------------------------------------------
// Control Flow
//------------------------------------------------------------------------------

function TGnyNativeBackend.When(const ACond: TGnyExpr): TGnyNativeBackend;
begin
  FIR.When(ACond);
  Result := Self;
end;

function TGnyNativeBackend.Otherwise(): TGnyNativeBackend;
begin
  FIR.Otherwise();
  Result := Self;
end;

function TGnyNativeBackend.EndWhen(): TGnyNativeBackend;
begin
  FIR.EndWhen();
  Result := Self;
end;

function TGnyNativeBackend.Loop(const ACond: TGnyExpr): TGnyNativeBackend;
begin
  FIR.Loop(ACond);
  Result := Self;
end;

function TGnyNativeBackend.EndLoop(): TGnyNativeBackend;
begin
  FIR.EndLoop();
  Result := Self;
end;

function TGnyNativeBackend.LoopBreak(): TGnyNativeBackend;
begin
  FIR.LoopBreak();
  Result := Self;
end;

function TGnyNativeBackend.LoopContinue(): TGnyNativeBackend;
begin
  FIR.LoopContinue();
  Result := Self;
end;

function TGnyNativeBackend.Count(const AVar: string; const AFrom: TGnyExpr;
  const ATo: TGnyExpr): TGnyNativeBackend;
begin
  FIR.Count(AVar, AFrom, ATo);
  Result := Self;
end;

function TGnyNativeBackend.CountDown(const AVar: string; const AFrom: TGnyExpr;
  const ATo: TGnyExpr): TGnyNativeBackend;
begin
  FIR.CountDown(AVar, AFrom, ATo);
  Result := Self;
end;

function TGnyNativeBackend.EndCount(): TGnyNativeBackend;
begin
  FIR.EndCount();
  Result := Self;
end;

function TGnyNativeBackend.DoRepeat(): TGnyNativeBackend;
begin
  FIR.DoRepeat();
  Result := Self;
end;

function TGnyNativeBackend.StopWhen(const ACond: TGnyExpr): TGnyNativeBackend;
begin
  FIR.StopWhen(ACond);
  Result := Self;
end;

function TGnyNativeBackend.Match(const ASelector: TGnyExpr): TGnyNativeBackend;
begin
  FIR.Match(ASelector);
  Result := Self;
end;

function TGnyNativeBackend.On(const AValues: array of TGnyExpr): TGnyNativeBackend;
begin
  FIR.On(AValues);
  Result := Self;
end;

function TGnyNativeBackend.On(const AValues: array of Integer): TGnyNativeBackend;
begin
  FIR.On(AValues);
  Result := Self;
end;

function TGnyNativeBackend.OnElse(): TGnyNativeBackend;
begin
  FIR.OnElse();
  Result := Self;
end;

function TGnyNativeBackend.EndMatch(): TGnyNativeBackend;
begin
  FIR.EndMatch();
  Result := Self;
end;

//------------------------------------------------------------------------------
// Exception Handling
//------------------------------------------------------------------------------

function TGnyNativeBackend.Guard(): TGnyNativeBackend;
begin
  FIR.Guard();
  Result := Self;
end;

function TGnyNativeBackend.Catch(): TGnyNativeBackend;
begin
  FIR.Catch();
  Result := Self;
end;

function TGnyNativeBackend.Ensure(): TGnyNativeBackend;
begin
  FIR.Ensure();
  Result := Self;
end;

function TGnyNativeBackend.EndGuard(): TGnyNativeBackend;
begin
  FIR.EndGuard();
  Result := Self;
end;

function TGnyNativeBackend.Throw(const AMsg: TGnyExpr): TGnyNativeBackend;
begin
  FIR.Throw(AMsg);
  Result := Self;
end;

function TGnyNativeBackend.ThrowCode(const ACode: TGnyExpr;
  const AMsg: TGnyExpr): TGnyNativeBackend;
begin
  FIR.ThrowCode(ACode, AMsg);
  Result := Self;
end;

//------------------------------------------------------------------------------
// Increment / Decrement
//------------------------------------------------------------------------------

function TGnyNativeBackend.Incr(const AVarName: string): TGnyNativeBackend;
begin
  FIR.Incr(AVarName);
  Result := Self;
end;

function TGnyNativeBackend.Incr(const AVarName: string; const AAmount: TGnyExpr): TGnyNativeBackend;
begin
  FIR.Incr(AVarName, AAmount);
  Result := Self;
end;

function TGnyNativeBackend.Decr(const AVarName: string): TGnyNativeBackend;
begin
  FIR.Decr(AVarName);
  Result := Self;
end;

function TGnyNativeBackend.Decr(const AVarName: string; const AAmount: TGnyExpr): TGnyNativeBackend;
begin
  FIR.Decr(AVarName, AAmount);
  Result := Self;
end;

//------------------------------------------------------------------------------
// Expressions — Literals
//------------------------------------------------------------------------------

function TGnyNativeBackend.Str(const AValue: string): TGnyExpr;
begin
  Result := FIR.Str(AValue);
end;

function TGnyNativeBackend.WStr(const AValue: string): TGnyExpr;
begin
  Result := FIR.WStr(AValue);
end;

function TGnyNativeBackend.Int64(const AValue: Int64): TGnyExpr;
begin
  Result := FIR.MakeInt64(AValue);
end;

function TGnyNativeBackend.Int32(const AValue: Int32): TGnyExpr;
begin
  Result := FIR.Int32(AValue);
end;

function TGnyNativeBackend.Float64(const AValue: Double): TGnyExpr;
begin
  Result := FIR.Float64(AValue);
end;

function TGnyNativeBackend.Bool(const AValue: Boolean): TGnyExpr;
begin
  Result := FIR.Bool(AValue);
end;

function TGnyNativeBackend.Null(): TGnyExpr;
begin
  Result := FIR.Null();
end;

function TGnyNativeBackend.Int8(const AValue: Int8): TGnyExpr;
begin
  Result := FIR.Int8(AValue);
end;

function TGnyNativeBackend.Int16(const AValue: Int16): TGnyExpr;
begin
  Result := FIR.Int16(AValue);
end;

function TGnyNativeBackend.UInt8(const AValue: UInt8): TGnyExpr;
begin
  Result := FIR.UInt8(AValue);
end;

function TGnyNativeBackend.UInt16(const AValue: UInt16): TGnyExpr;
begin
  Result := FIR.UInt16(AValue);
end;

function TGnyNativeBackend.UInt32(const AValue: UInt32): TGnyExpr;
begin
  Result := FIR.UInt32(AValue);
end;

function TGnyNativeBackend.UInt64(const AValue: UInt64): TGnyExpr;
begin
  Result := FIR.UInt64(AValue);
end;

function TGnyNativeBackend.Float32(const AValue: Single): TGnyExpr;
begin
  Result := FIR.Float32(AValue);
end;

//------------------------------------------------------------------------------
// Expressions — Variable Reference
//------------------------------------------------------------------------------

function TGnyNativeBackend.Get(const AName: string): TGnyExpr;
begin
  Result := FIR.Get(AName);
end;

//------------------------------------------------------------------------------
// Expressions — Arithmetic
//------------------------------------------------------------------------------

function TGnyNativeBackend.Add(const ALeft: TGnyExpr; const ARight: TGnyExpr): TGnyExpr;
begin
  Result := FIR.Add(ALeft, ARight);
end;

function TGnyNativeBackend.Sub(const ALeft: TGnyExpr; const ARight: TGnyExpr): TGnyExpr;
begin
  Result := FIR.Sub(ALeft, ARight);
end;

function TGnyNativeBackend.Mul(const ALeft: TGnyExpr; const ARight: TGnyExpr): TGnyExpr;
begin
  Result := FIR.Mul(ALeft, ARight);
end;

function TGnyNativeBackend.IDiv(const ALeft: TGnyExpr; const ARight: TGnyExpr): TGnyExpr;
begin
  Result := FIR.IDiv(ALeft, ARight);
end;

function TGnyNativeBackend.IMod(const ALeft: TGnyExpr; const ARight: TGnyExpr): TGnyExpr;
begin
  Result := FIR.IMod(ALeft, ARight);
end;

function TGnyNativeBackend.Neg(const AValue: TGnyExpr): TGnyExpr;
begin
  Result := FIR.Neg(AValue);
end;

//------------------------------------------------------------------------------
// Expressions — Float Arithmetic
//------------------------------------------------------------------------------

function TGnyNativeBackend.FAdd(const ALeft: TGnyExpr; const ARight: TGnyExpr): TGnyExpr;
begin
  Result := FIR.FAdd(ALeft, ARight);
end;

function TGnyNativeBackend.FSub(const ALeft: TGnyExpr; const ARight: TGnyExpr): TGnyExpr;
begin
  Result := FIR.FSub(ALeft, ARight);
end;

function TGnyNativeBackend.FMul(const ALeft: TGnyExpr; const ARight: TGnyExpr): TGnyExpr;
begin
  Result := FIR.FMul(ALeft, ARight);
end;

function TGnyNativeBackend.FDiv(const ALeft: TGnyExpr; const ARight: TGnyExpr): TGnyExpr;
begin
  Result := FIR.FDiv(ALeft, ARight);
end;

function TGnyNativeBackend.FNeg(const AValue: TGnyExpr): TGnyExpr;
begin
  Result := FIR.FNeg(AValue);
end;

function TGnyNativeBackend.IntToFloat64(const AValue: TGnyExpr): TGnyExpr;
begin
  Result := FIR.IntToFloat64(AValue);
end;

function TGnyNativeBackend.Float64ToInt(const AValue: TGnyExpr): TGnyExpr;
begin
  Result := FIR.Float64ToInt(AValue);
end;

//------------------------------------------------------------------------------
// Expressions — Bitwise
//------------------------------------------------------------------------------

function TGnyNativeBackend.BitAnd(const ALeft: TGnyExpr; const ARight: TGnyExpr): TGnyExpr;
begin
  Result := FIR.BitAnd(ALeft, ARight);
end;

function TGnyNativeBackend.BitOr(const ALeft: TGnyExpr; const ARight: TGnyExpr): TGnyExpr;
begin
  Result := FIR.BitOr(ALeft, ARight);
end;

function TGnyNativeBackend.BitXor(const ALeft: TGnyExpr; const ARight: TGnyExpr): TGnyExpr;
begin
  Result := FIR.BitXor(ALeft, ARight);
end;

function TGnyNativeBackend.BitNot(const AValue: TGnyExpr): TGnyExpr;
begin
  Result := FIR.BitNot(AValue);
end;

function TGnyNativeBackend.ShiftL(const AValue: TGnyExpr; const ACount: TGnyExpr): TGnyExpr;
begin
  Result := FIR.ShiftL(AValue, ACount);
end;

function TGnyNativeBackend.ShiftR(const AValue: TGnyExpr; const ACount: TGnyExpr): TGnyExpr;
begin
  Result := FIR.ShiftR(AValue, ACount);
end;

//------------------------------------------------------------------------------
// Expressions — Comparison
//------------------------------------------------------------------------------

function TGnyNativeBackend.Eq(const ALeft: TGnyExpr; const ARight: TGnyExpr): TGnyExpr;
begin
  Result := FIR.Eq(ALeft, ARight);
end;

function TGnyNativeBackend.Ne(const ALeft: TGnyExpr; const ARight: TGnyExpr): TGnyExpr;
begin
  Result := FIR.Ne(ALeft, ARight);
end;

function TGnyNativeBackend.Lt(const ALeft: TGnyExpr; const ARight: TGnyExpr): TGnyExpr;
begin
  Result := FIR.Lt(ALeft, ARight);
end;

function TGnyNativeBackend.Le(const ALeft: TGnyExpr; const ARight: TGnyExpr): TGnyExpr;
begin
  Result := FIR.Le(ALeft, ARight);
end;

function TGnyNativeBackend.Gt(const ALeft: TGnyExpr; const ARight: TGnyExpr): TGnyExpr;
begin
  Result := FIR.Gt(ALeft, ARight);
end;

function TGnyNativeBackend.Ge(const ALeft: TGnyExpr; const ARight: TGnyExpr): TGnyExpr;
begin
  Result := FIR.Ge(ALeft, ARight);
end;

//------------------------------------------------------------------------------
// Expressions — Float Comparison
//------------------------------------------------------------------------------

function TGnyNativeBackend.FEq(const ALeft: TGnyExpr; const ARight: TGnyExpr): TGnyExpr;
begin
  Result := FIR.FEq(ALeft, ARight);
end;

function TGnyNativeBackend.FNe(const ALeft: TGnyExpr; const ARight: TGnyExpr): TGnyExpr;
begin
  Result := FIR.FNe(ALeft, ARight);
end;

function TGnyNativeBackend.FLt(const ALeft: TGnyExpr; const ARight: TGnyExpr): TGnyExpr;
begin
  Result := FIR.FLt(ALeft, ARight);
end;

function TGnyNativeBackend.FLe(const ALeft: TGnyExpr; const ARight: TGnyExpr): TGnyExpr;
begin
  Result := FIR.FLe(ALeft, ARight);
end;

function TGnyNativeBackend.FGt(const ALeft: TGnyExpr; const ARight: TGnyExpr): TGnyExpr;
begin
  Result := FIR.FGt(ALeft, ARight);
end;

function TGnyNativeBackend.FGe(const ALeft: TGnyExpr; const ARight: TGnyExpr): TGnyExpr;
begin
  Result := FIR.FGe(ALeft, ARight);
end;

//------------------------------------------------------------------------------
// Expressions — Logical
//------------------------------------------------------------------------------

function TGnyNativeBackend.LogAnd(const ALeft: TGnyExpr; const ARight: TGnyExpr): TGnyExpr;
begin
  Result := FIR.LogAnd(ALeft, ARight);
end;

function TGnyNativeBackend.LogOr(const ALeft: TGnyExpr; const ARight: TGnyExpr): TGnyExpr;
begin
  Result := FIR.LogOr(ALeft, ARight);
end;

function TGnyNativeBackend.LogNot(const AValue: TGnyExpr): TGnyExpr;
begin
  Result := FIR.LogNot(AValue);
end;

//------------------------------------------------------------------------------
// Expressions — Pointers
//------------------------------------------------------------------------------

function TGnyNativeBackend.AddrOf(const AName: string): TGnyExpr;
begin
  Result := FIR.AddrOf(AName);
end;

function TGnyNativeBackend.AddrOfVal(const AExpr: TGnyExpr): TGnyExpr;
begin
  Result := FIR.AddrOfVal(AExpr);
end;

function TGnyNativeBackend.Deref(const APtr: TGnyExpr): TGnyExpr;
begin
  Result := FIR.Deref(APtr);
end;

function TGnyNativeBackend.Deref(const APtr: TGnyExpr; const ATypeName: string): TGnyExpr;
begin
  Result := FIR.Deref(APtr, ATypeName);
end;

function TGnyNativeBackend.Deref(const APtr: TGnyExpr; const AType: TGnyValueType): TGnyExpr;
begin
  Result := FIR.Deref(APtr, AType);
end;

//------------------------------------------------------------------------------
// Expressions — Function Pointers
//------------------------------------------------------------------------------

function TGnyNativeBackend.FuncAddr(const AFuncName: string): TGnyExpr;
begin
  Result := FIR.FuncAddr(AFuncName);
end;

function TGnyNativeBackend.InvokeIndirect(const AFuncPtr: TGnyExpr;
  const AArgs: array of TGnyExpr): TGnyExpr;
begin
  Result := FIR.InvokeIndirect(AFuncPtr, AArgs);
end;

//------------------------------------------------------------------------------
// Expressions — Composite Access
//------------------------------------------------------------------------------

function TGnyNativeBackend.GetField(const AObject: TGnyExpr;
  const AFieldName: string): TGnyExpr;
begin
  Result := FIR.GetField(AObject, AFieldName);
end;

function TGnyNativeBackend.GetIndex(const AArray: TGnyExpr;
  const AIndex: TGnyExpr): TGnyExpr;
begin
  Result := FIR.GetIndex(AArray, AIndex);
end;

//------------------------------------------------------------------------------
// Expressions — Function Call
//------------------------------------------------------------------------------

function TGnyNativeBackend.Invoke(const AFuncName: string;
  const AArgs: array of TGnyExpr): TGnyExpr;
begin
  Result := FIR.Invoke(AFuncName, AArgs);
end;

//------------------------------------------------------------------------------
// Expressions — Exception Intrinsics
//------------------------------------------------------------------------------

function TGnyNativeBackend.ExcCode(): TGnyExpr;
begin
  Result := FIR.ExcCode();
end;

function TGnyNativeBackend.ExcMsg(): TGnyExpr;
begin
  Result := FIR.ExcMsg();
end;

//------------------------------------------------------------------------------
// Expressions — Set Literals & Operations
//------------------------------------------------------------------------------

function TGnyNativeBackend.SetLit(const ATypeName: string;
  const AElements: array of Integer): TGnyExpr;
begin
  Result := FIR.SetLit(ATypeName, AElements);
end;

function TGnyNativeBackend.SetLitRange(const ATypeName: string;
  const ALow: Integer; const AHigh: Integer): TGnyExpr;
begin
  Result := FIR.SetLitRange(ATypeName, ALow, AHigh);
end;

function TGnyNativeBackend.EmptySet(const ATypeName: string): TGnyExpr;
begin
  Result := FIR.EmptySet(ATypeName);
end;

function TGnyNativeBackend.SetUnion(const ALeft: TGnyExpr; const ARight: TGnyExpr): TGnyExpr;
begin
  Result := FIR.SetUnion(ALeft, ARight);
end;

function TGnyNativeBackend.SetDiff(const ALeft: TGnyExpr; const ARight: TGnyExpr): TGnyExpr;
begin
  Result := FIR.SetDiff(ALeft, ARight);
end;

function TGnyNativeBackend.SetInter(const ALeft: TGnyExpr; const ARight: TGnyExpr): TGnyExpr;
begin
  Result := FIR.SetInter(ALeft, ARight);
end;

function TGnyNativeBackend.SetIn(const AElement: TGnyExpr; const ASet: TGnyExpr): TGnyExpr;
begin
  Result := FIR.SetIn(AElement, ASet);
end;

function TGnyNativeBackend.SetIn(const AElement: TGnyExpr; const ASet: TGnyExpr; const ALowBound: Integer): TGnyExpr;
begin
  Result := FIR.SetIn(AElement, ASet, ALowBound);
end;

function TGnyNativeBackend.SetEq(const ALeft: TGnyExpr; const ARight: TGnyExpr): TGnyExpr;
begin
  Result := FIR.SetEq(ALeft, ARight);
end;

function TGnyNativeBackend.SetNe(const ALeft: TGnyExpr; const ARight: TGnyExpr): TGnyExpr;
begin
  Result := FIR.SetNe(ALeft, ARight);
end;

function TGnyNativeBackend.SetSubset(const ALeft: TGnyExpr; const ARight: TGnyExpr): TGnyExpr;
begin
  Result := FIR.SetSubset(ALeft, ARight);
end;

function TGnyNativeBackend.SetSuperset(const ALeft: TGnyExpr; const ARight: TGnyExpr): TGnyExpr;
begin
  Result := FIR.SetSuperset(ALeft, ARight);
end;

//------------------------------------------------------------------------------
// Expressions — Compile-Time Intrinsics
//------------------------------------------------------------------------------

function TGnyNativeBackend.TypeSize(const ATypeName: string): TGnyExpr;
begin
  Result := FIR.TypeSize(ATypeName);
end;

function TGnyNativeBackend.AlignOf(const ATypeName: string): TGnyExpr;
begin
  Result := FIR.AlignOf(ATypeName);
end;

function TGnyNativeBackend.High(const ATypeName: string): TGnyExpr;
begin
  Result := FIR.High(ATypeName);
end;

function TGnyNativeBackend.Low(const ATypeName: string): TGnyExpr;
begin
  Result := FIR.Low(ATypeName);
end;

function TGnyNativeBackend.Len(const ATypeName: string): TGnyExpr;
begin
  Result := FIR.Len(ATypeName);
end;

//------------------------------------------------------------------------------
// Expressions — Runtime Intrinsics
//------------------------------------------------------------------------------

function TGnyNativeBackend.Ord(const AValue: TGnyExpr): TGnyExpr;
begin
  Result := FIR.Ord(AValue);
end;

function TGnyNativeBackend.Chr(const AValue: TGnyExpr): TGnyExpr;
begin
  Result := FIR.Chr(AValue);
end;

function TGnyNativeBackend.Succ(const AValue: TGnyExpr): TGnyExpr;
begin
  Result := FIR.Succ(AValue);
end;

function TGnyNativeBackend.Pred(const AValue: TGnyExpr): TGnyExpr;
begin
  Result := FIR.Pred(AValue);
end;

//------------------------------------------------------------------------------
// Expressions — Variadic Intrinsics
//------------------------------------------------------------------------------

function TGnyNativeBackend.VaCount(): TGnyExpr;
begin
  Result := FIR.VaCount();
end;

function TGnyNativeBackend.VaArg(const AIndex: TGnyExpr;
  const AType: TGnyValueType): TGnyExpr;
begin
  Result := FIR.VaArg(AIndex, AType);
end;

//------------------------------------------------------------------------------
// Syscall — Linux Syscall Intrinsics
//------------------------------------------------------------------------------
// Advanced — Direct Access
//------------------------------------------------------------------------------

function TGnyNativeBackend.GetIR(): TIR;
begin
  Result := FIR;
end;

function TGnyNativeBackend.GetBackend(): TCodegen;
begin
  Result := FBackend;
end;

function TGnyNativeBackend.GetErrors(): TGnyErrors;
begin
  Result := FErrors;
end;

function TGnyNativeBackend.GetTypeCount(): Integer;
begin
  Result := FIR.GetTypeCount();
end;

function TGnyNativeBackend.GetFieldOffset(const ATypeName: string; const AFieldName: string): Integer;
var
  LTypeIndex: Integer;
  LFieldInfo: TIR.TIRRecordField;
begin
  LTypeIndex := FindType(ATypeName);
  if LTypeIndex < 0 then
    Exit(-1);

  if FIR.FindRecordField(LTypeIndex, AFieldName, LFieldInfo) then
    Result := LFieldInfo.FieldOffset
  else
    Result := -1;
end;

//------------------------------------------------------------------------------
// VersionInfo
//------------------------------------------------------------------------------
procedure TGnyNativeBackend.AddVersionInfo(const AEnable: Boolean);
begin
  FAddVersionInfo := AEnable;
end;

procedure TGnyNativeBackend.SetVersionInfo(const AMajor, AMinor, APatch: Word;
  const AProductName, ADescription, AFilename, ACompanyName,
  ACopyright: string);
begin
  Self.FVIMajor := AMajor;
  Self.FVIMinor := AMinor;
  Self.FVIPatch := APatch;
  Self.FVIProductName := AProductName;
  Self.FVIDescription := ADescription;
  Self.FVIFilename := AFilename;
  Self.FVICompanyName := ACompanyName;
  Self.FVICopyright := ACopyright;
end;

procedure TGnyNativeBackend.AddExeIcon(const AFilename: string);
begin
  Self.FExeIcon := AFilename;
end;

//==============================================================================
// TGnyNative — Shorthand Aliases (Expression Builders)
//==============================================================================

function TGnyNativeBackend.V(const AName: string): TGnyExpr;
begin
  Result := Get(AName);
end;

function TGnyNativeBackend.S(const AValue: string): TGnyExpr;
begin
  Result := Str(AValue);
end;

function TGnyNativeBackend.W(const AValue: string): TGnyExpr;
begin
  Result := WStr(AValue);
end;

function TGnyNativeBackend.I(const AValue: Int64): TGnyExpr;
begin
  Result := Int64(AValue);
end;

function TGnyNativeBackend.F(const AValue: Double): TGnyExpr;
begin
  Result := Float64(AValue);
end;

function TGnyNativeBackend.B(const AValue: Boolean): TGnyExpr;
begin
  Result := Bool(AValue);
end;

function TGnyNativeBackend.P(): TGnyExpr;
begin
  Result := Null();
end;

function TGnyNativeBackend.Inv(const AFuncName: string; const AArgs: array of TGnyExpr): TGnyExpr;
begin
  Result := Invoke(AFuncName, AArgs);
end;

function TGnyNativeBackend.Fn(const AName: string): TGnyExpr;
begin
  Result := FuncAddr(AName);
end;

function TGnyNativeBackend.Addr(const AName: string): TGnyExpr;
begin
  Result := AddrOf(AName);
end;

end.

