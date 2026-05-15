{===============================================================================
  Ganymede™ - Embeddable Native Scripting Engine

  Copyright © 2026-present tinyBigGAMES™ LLC
  All Rights Reserved.

  See LICENSE for license information
===============================================================================}

unit Ganymede.IR;

{$I Ganymede.Defines.inc}

interface

uses
  System.SysUtils,
  System.Generics.Collections,
  Ganymede.Utils,
  Ganymede.Resources,
  Ganymede.Types;

type
  //============================================================================
  // Forward Declarations
  //============================================================================
  TIR = class;

  //============================================================================
  // TIRExpr - Expression handle (opaque to user)
  //============================================================================
  TIRExpr = record
    Index: Integer;

    class function None(): TIRExpr; static;
    function IsValid(): Boolean;

    class operator Implicit(const AValue: Integer): TIRExpr;
    class operator Implicit(const AValue: Int64): TIRExpr;
    class operator Implicit(const AValue: Double): TIRExpr;
  end;

  //============================================================================
  // TTypeRef - Reference to a type (primitive or composite)
  //============================================================================
  TTypeRef = record
    IsPrimitive: Boolean;
    Primitive: TValueType;    // Valid when IsPrimitive = True
    TypeIndex: Integer;          // Valid when IsPrimitive = False (index into type registry)

    class function FromPrimitive(const AType: TValueType): TTypeRef; static;
    class function FromComposite(const AIndex: Integer): TTypeRef; static;
    class function None(): TTypeRef; static;
    function IsValid(): Boolean;
    function ToString(): string;

    class operator Equal(const A: TTypeRef; const B: TTypeRef): Boolean;
    class operator NotEqual(const A: TTypeRef; const B: TTypeRef): Boolean;
  end;

  //============================================================================
  // TIR - High-level fluent IR builder
  //============================================================================
  TIR = class(TGnyBaseObject)
  public type
    //--------------------------------------------------------------------------
    // Internal: Import info
    //--------------------------------------------------------------------------
    TIRImport = record
      DllName: string;
      FuncName: string;
      ParamTypes: TArray<TValueType>;
      ReturnType: TValueType;
      IsVarArgs: Boolean;
      IsStatic: Boolean;       // True for ImportLib (static linking)
      Linkage: TLinkage;  // plC = raw name, plDefault = Itanium mangled
      HostAddr: Pointer;       // non-nil = host function pointer (JIT only)
    end;

    //--------------------------------------------------------------------------
    // Internal: String literal
    //--------------------------------------------------------------------------
    TIRString = record
      Value: string;
      IsWide: Boolean;
    end;

    //--------------------------------------------------------------------------
    // Internal: Global variable
    //--------------------------------------------------------------------------
    TIRGlobal = record
      GlobalName: string;
      GlobalType: TValueType;
      GlobalTypeRef: TTypeRef;  // For composite/managed types (string)
      InitExpr: Integer;  // -1 if uninitialized
      IsPublic: Boolean;  // If True, exported in DLL .edata section
    end;

    //--------------------------------------------------------------------------
    // Internal: Variable (param or local)
    //--------------------------------------------------------------------------
    TIRVar = record
      VarName: string;
      VarTypeRef: TTypeRef;  // Supports both primitive and composite types
      IsParam: Boolean;
      IsByRef: Boolean;
    end;

    //--------------------------------------------------------------------------
    // Internal: Expression node kinds
    //--------------------------------------------------------------------------
    TIRExprKind = (
      ekNone,
      ekConstInt,
      ekConstFloat,
      ekConstString,
      ekVariable,
      ekBinary,
      ekUnary,
      ekCall,
      ekFieldAccess,       // record.field
      ekArrayIndex,        // array[index]
      ekFuncAddr,          // @funcName
      ekCallIndirect,      // funcPtr(args)
      ekGetExceptionCode,  // getexceptioncode()
      ekGetExceptionMsg,   // getexceptionmessage()
      ekSetLiteral,        // {1, 3, 5..10}
      ekVaCount,           // VaCount()
      ekVaArgAt            // VaArg(index, type)
    );

    //--------------------------------------------------------------------------
    // Internal: Binary/Unary operation kinds
    //--------------------------------------------------------------------------
    TIROpKind = (
      opNone,
      // Arithmetic
      opAdd,
      opSub,
      opMul,
      opDiv,
      opMod,
      opNeg,
      // Float arithmetic
      opFAdd,
      opFSub,
      opFMul,
      opFDiv,
      opFNeg,
      // Type conversion
      opIntToFloat,
      opFloatToInt,
      // Bitwise
      opBitAnd,
      opBitOr,
      opBitXor,
      opBitNot,
      opShl,
      opShr,
      // Comparison
      opCmpEq,
      opCmpNe,
      opCmpLt,
      opCmpLe,
      opCmpGt,
      opCmpGe,
      // Float Comparison
      opFCmpEq,
      opFCmpNe,
      opFCmpLt,
      opFCmpLe,
      opFCmpGt,
      opFCmpGe,
      // Logical
      opAnd,
      opOr,
      opNot,
      // Pointer
      opAddrOf,
      opDeref,
      // Set operations
      opSetUnion,     // set1 + set2
      opSetDiff,      // set1 - set2
      opSetInter,     // set1 * set2
      opSetIn,        // element in set
      opSetEq,        // set1 = set2
      opSetNe,        // set1 <> set2
      opSetSubset,    // set1 <= set2
      opSetSuperset   // set1 >= set2
    );

    //--------------------------------------------------------------------------
    // Internal: Expression node
    //--------------------------------------------------------------------------
    TIRExprNode = record
      Kind: TIRExprKind;
      ResultType: TTypeRef;   // Type this expression evaluates to
      ConstInt: Int64;
      ConstFloat: Double;
      StringIndex: Integer;
      VarName: string;
      Op: TIROpKind;
      Left: Integer;
      Right: Integer;
      CallTarget: string;
      CallArgs: TArray<Integer>;
      // For ekFieldAccess
      ObjectExpr: Integer;       // Expression yielding record/object
      FieldName: string;         // Field name to access
      FieldOffset: Integer;      // Pre-computed byte offset
      FieldSize: Integer;        // Pre-computed field size
      BitWidth: Integer;         // 0 = full field, >0 = bit field width
      BitOffset: Integer;        // Bit position within storage unit
      // For ekArrayIndex
      ArrayExpr: Integer;        // Expression yielding array
      IndexExpr: Integer;        // Expression yielding index
      ElementSize: Integer;      // Pre-computed element size
      // For ekFuncAddr
      FuncAddrName: string;      // Name of function to take address of
      // For ekCallIndirect
      IndirectTarget: Integer;   // Expression index of function pointer
      // For set operations
      SetLowBound: Integer;      // LowBound for SetIn (element adjustment)
      // For ekSetLiteral
      SetTypeIndex: Integer;     // Index into type registry for set type
      SetElements: TArray<Integer>;  // Individual element values (adjusted by LowBound)
      // For ekVaArgAt
      VaArgIndex: Integer;       // Expression index for the arg index
      VaArgType: TValueType;  // Type to read as
    end;

    //--------------------------------------------------------------------------
    // Internal: Statement kinds
    //--------------------------------------------------------------------------
    TIRStmtKind = (
      skAssign,
      skCall,
      skReturn,
      skReturnValue,
      skWhenBegin,
      skOtherwiseBegin,
      skWhenEnd,
      skLoopBegin,
      skLoopEnd,
      skLoopBreak,
      skLoopContinue,
      skCountBegin,
      skCountEnd,
      skDoRepeatBegin,
      skDoRepeatEnd,
      skMatchBegin,
      skOn,
      skOnElse,
      skMatchEnd,
      skCallIndirect,
      skGuardBegin,
      skCatchBegin,
      skEnsureBegin,
      skGuardEnd,
      skThrow,
      skThrowCode
    );

    //--------------------------------------------------------------------------
    // Internal: Statement node
    //--------------------------------------------------------------------------
    TIRStmt = record
      Kind: TIRStmtKind;
      DestVar: string;
      DestExpr: Integer;       // For assigning to field/index expressions (-1 = use DestVar)
      Expr: Integer;
      CallTarget: string;
      CallArgs: TArray<Integer>;
      ForVar: string;
      ForFrom: Integer;
      ForTo: Integer;
      ForDownTo: Boolean;
      CaseValues: TArray<Integer>;  // Raw integer values for CaseOf matching
      IndirectTarget: Integer;        // Expression index for indirect calls
      RaiseMsg: Integer;              // Expression index for raise message
      RaiseCode: Integer;             // Expression index for raise code (skThrowCode only)
      SourceLine: Integer;            // Source line number (0 = not set)
      SourceColumn: Integer;          // Source column number (0 = not set)
      SourceFile: string;             // Source file path ('' = not set)
    end;

    //--------------------------------------------------------------------------
    // Internal: Function definition
    //--------------------------------------------------------------------------
    TIRFunc = record
      FuncName: string;
      ReturnType: TValueType;
      ReturnSize: Integer;          // Size in bytes (for composite return types)
      ReturnAlignment: Integer;     // Alignment in bytes (for ABI classification)
      IsEntryPoint: Boolean;
      IsDllEntry: Boolean;        // If True, this is the DllMain entry point
      IsPublic: Boolean;          // If True, export this function
      Linkage: TLinkage;
      ParamTypes: TArray<TValueType>;  // For mangling
      Vars: TList<TIRVar>;
      Stmts: TList<TIRStmt>;
      IsVariadic: Boolean;        // If True, function accepts variadic args
    end;

    //--------------------------------------------------------------------------
    // Internal: Control flow block tracking
    //--------------------------------------------------------------------------
    TBlockKind = (
      bkWhen,
      bkOtherwise,
      bkLoop,
      bkCount,
      bkRepeat,
      bkMatch,
      bkGuard,
      bkCatch,
      bkEnsure
    );

    TBlockInfo = record
      Kind: TBlockKind;
      LabelStart: TLabelHandle;
      LabelEnd: TLabelHandle;
      LabelElse: TLabelHandle;
      ForVar: string;
      ForTo: Integer;
      ForDownTo: Boolean;
      CaseSelectorExpr: Integer;       // Expression index of case selector
      LabelNextCase: TLabelHandle;  // Label for next CaseOf/CaseElse/CaseEnd
    end;

    //--------------------------------------------------------------------------
    // Internal: Type system - Type kinds
    //--------------------------------------------------------------------------
    TIRTypeKind = (
      tkRecord,
      tkUnion,
      tkFixedArray,
      tkDynArray,
      tkEnum,
      tkAlias,
      tkPointer,
      tkRoutine,
      tkSet
    );

    //--------------------------------------------------------------------------
    // Internal: Record field definition
    //--------------------------------------------------------------------------
    TIRRecordField = record
      FieldName: string;
      FieldType: TTypeRef;
      FieldOffset: Integer;     // Computed during finalization (byte offset)
      BitWidth: Integer;        // 0 = full width, >0 = bit field width
      BitOffset: Integer;       // Bit position within storage unit (0-63)
      OverlayGroup: Integer;    // Records: 0 = normal, >0 = overlay group (anon union)
      AnonRecordGroup: Integer; // Unions: 0 = normal, >0 = sequential group (anon record)
    end;

    //--------------------------------------------------------------------------
    // Internal: Record type definition
    //--------------------------------------------------------------------------
    TIRRecordType = record
      TypeName: string;
      Fields: TArray<TIRRecordField>;
      TotalSize: Integer;    // Computed during finalization
      Alignment: Integer;    // Computed during finalization
      ExplicitAlign: Integer; // 0 = natural, else 1/2/4/8/16
      BaseTypeIndex: Integer; // -1 = no base, else index into FTypes
      IsPacked: Boolean;
      IsFinalized: Boolean;
    end;

    //--------------------------------------------------------------------------
    // Internal: Union type definition
    //--------------------------------------------------------------------------
    TIRUnionType = record
      TypeName: string;
      Fields: TArray<TIRRecordField>;  // Reuse field type, all at offset 0
      TotalSize: Integer;              // Max field size
      Alignment: Integer;              // Max field alignment
      IsFinalized: Boolean;
    end;

    //--------------------------------------------------------------------------
    // Internal: Fixed array type definition
    //--------------------------------------------------------------------------
    TIRFixedArrayType = record
      TypeName: string;
      ElementType: TTypeRef;
      LowBound: Integer;
      HighBound: Integer;
      TotalSize: Integer;    // Computed: (High - Low + 1) * ElementSize
    end;

    //--------------------------------------------------------------------------
    // Internal: Dynamic array type definition
    //--------------------------------------------------------------------------
    TIRDynArrayType = record
      TypeName: string;
      ElementType: TTypeRef;
      // Runtime layout: pointer to record with Length + Data
    end;

    //--------------------------------------------------------------------------
    // Internal: Enum value definition
    //--------------------------------------------------------------------------
    TIREnumValue = record
      ValueName: string;
      OrdinalValue: Int64;
    end;

    //--------------------------------------------------------------------------
    // Internal: Enum type definition
    //--------------------------------------------------------------------------
    TIREnumType = record
      TypeName: string;
      Values: TArray<TIREnumValue>;
      BaseType: TValueType;  // Usually vtInt32
    end;

    //--------------------------------------------------------------------------
    // Internal: Type alias definition
    //--------------------------------------------------------------------------
    TIRAliasType = record
      TypeName: string;
      AliasedType: TTypeRef;
    end;

    //--------------------------------------------------------------------------
    // Internal: Pointer type definition
    //--------------------------------------------------------------------------
    TIRPointerType = record
      TypeName: string;
      PointeeType: TTypeRef;  // Type being pointed to (None = untyped)
      IsConst: Boolean;          // pointer to const T
    end;

    //--------------------------------------------------------------------------
    // Internal: Routine (procedural) type definition
    //--------------------------------------------------------------------------
    TIRRoutineType = record
      TypeName: string;
      ParamTypes: TArray<TTypeRef>;
      ReturnType: TTypeRef;
      Linkage: TLinkage;
      IsVarArgs: Boolean;
    end;

    //--------------------------------------------------------------------------
    // Internal: Set type definition
    //--------------------------------------------------------------------------
    TIRSetType = record
      TypeName: string;
      LowBound: Integer;     // Minimum element value (offset)
      HighBound: Integer;    // Maximum element value
      BaseType: TTypeRef; // For enum-based sets, None for integer ranges
      StorageSize: Integer;  // 1, 2, 4, or 8 bytes based on range span
    end;

    //--------------------------------------------------------------------------
    // Internal: Unified type entry (tagged union)
    //--------------------------------------------------------------------------
    TIRTypeEntry = record
      Kind: TIRTypeKind;
      RecordType: TIRRecordType;
      UnionType: TIRUnionType;
      FixedArrayType: TIRFixedArrayType;
      DynArrayType: TIRDynArrayType;
      EnumType: TIREnumType;
      AliasType: TIRAliasType;
      PointerType: TIRPointerType;
      RoutineType: TIRRoutineType;
      SetType: TIRSetType;
    end;

  private
    FImports: TList<TIRImport>;
    FStrings: TList<TIRString>;
    FGlobals: TList<TIRGlobal>;
    FFunctions: TList<TIRFunc>;
    FExpressions: TList<TIRExprNode>;
    FCurrentFunc: Integer;

    // Runtime snapshot (marks boundary between user code and injected runtime)
    FSnapshotFuncs: Integer;
    FSnapshotImports: Integer;
    FSnapshotStrings: Integer;
    FSnapshotGlobals: Integer;
    FSnapshotExprs: Integer;

    // Type registry
    FTypes: TList<TIRTypeEntry>;
    FBuildingRecordIndex: Integer;  // Index of record being built, -1 if none
    FSkipBuildingRecord: Boolean;    // True when DefineRecord skipped (type exists)
    FBuildingUnionIndex: Integer;   // Index of union being built, -1 if none
    FBuildingEnumIndex: Integer;    // Index of enum being built, -1 if none
    FNextEnumOrdinal: Int64;        // Next ordinal value for enum
    FNextOverlayGroup: Integer;     // Counter for overlay groups in records
    FAnonUnionFieldStart: Integer;  // First field index of current anon union, -1 if not in anon union
    FNextAnonRecordGroup: Integer;  // Counter for anon record groups in unions
    FAnonRecordInUnion: Boolean;    // True when building anon record inside union
    FBuildingRoutineIndex: Integer;  // Index of routine type being built, -1 if none

    // Source location tracking (for debugger)
    FCurrentSourceLine: Integer;
    FCurrentSourceColumn: Integer;
    FCurrentSourceFile: string;

    function GetCurrentFunc(): TIRFunc;
    function AddExpr(const ANode: TIRExprNode): TIRExpr;
    function MakeBinaryExpr(const ALeft, ARight: TIRExpr; const AOp: TIROpKind): TIRExpr;
    function MakeUnaryExpr(const AValue: TIRExpr; const AOp: TIROpKind): TIRExpr;

    {$HINTS OFF}
    function FindLocalFunc(const AName: string): Integer;
    {$HINTS ON}

    // Type system helpers
    function GetPrimitiveSize(const AType: TValueType): Integer;
    function GetPrimitiveAlignment(const AType: TValueType): Integer;
    procedure FinalizeRecordLayout(const ATypeIndex: Integer);
    procedure FinalizeUnionLayout(const ATypeIndex: Integer);
    function FindVarType(const AVarName: string): TTypeRef;

  public
    constructor Create(); reintroduce;
    destructor Destroy(); override;

    //--------------------------------------------------------------------------
    // Imports
    //--------------------------------------------------------------------------
    function Import(
      const ADllName: string;
      const AFuncName: string;
      const AParams: array of TValueType;
      const AReturn: TValueType = vtVoid;
      const AVarArgs: Boolean = False;
      const ALinkage: TLinkage = plC
    ): TIR;

    function ImportLib(
      const ALibName: string;
      const AFuncName: string;
      const AParams: array of TValueType;
      const AReturn: TValueType = vtVoid;
      const AVarArgs: Boolean = False;
      const ALinkage: TLinkage = plC
    ): TIR;

    function ImportHost(
      const AFuncName: string;
      const AHostAddr: Pointer;
      const AParams: array of TValueType;
      const AReturn: TValueType = vtVoid
    ): TIR;

    //--------------------------------------------------------------------------
    // Global Variables
    //--------------------------------------------------------------------------
    function Global(const AName: string; const AType: TValueType; const AIsPublic: Boolean = False): TIR; overload;
    function Global(const AName: string; const AType: TValueType; const AInit: TIRExpr; const AIsPublic: Boolean = False): TIR; overload;
    function Global(const AName: string; const ATypeRef: TTypeRef; const AIsPublic: Boolean = False): TIR; overload;
    function Global(const AName: string; const ATypeName: string; const AIsPublic: Boolean = False): TIR; overload;

    //--------------------------------------------------------------------------
    // Type Definitions (fluent)
    //--------------------------------------------------------------------------
    // Record types
    function DefineRecord(const AName: string; const AIsPacked: Boolean = False;
      const AExplicitAlign: Integer = 0; const ABaseTypeName: string = ''): TIR;
    function BeginRecord(): TIR;  // Anonymous record in union
    function Field(const AName: string; const AType: TValueType): TIR; overload;
    function Field(const AName: string; const ATypeName: string): TIR; overload;
    function BitField(const AName: string; const AType: TValueType; const ABitWidth: Integer): TIR;
    function EndRecord(): TIR;

    // Union types
    function DefineUnion(const AName: string): TIR;
    function BeginUnion(): TIR;  // Anonymous union in record
    function EndUnion(): TIR;

    // Array types
    function DefineArray(const AName: string; const AElementType: TValueType;
      const ALowBound: Integer; const AHighBound: Integer): TIR; overload;
    function DefineArray(const AName: string; const AElementTypeName: string;
      const ALowBound: Integer; const AHighBound: Integer): TIR; overload;
    function DefineDynArray(const AName: string; const AElementType: TValueType): TIR; overload;
    function DefineDynArray(const AName: string; const AElementTypeName: string): TIR; overload;

    // Enum types
    function DefineEnum(const AName: string): TIR;
    function EnumValue(const AName: string): TIR; overload;
    function EnumValue(const AName: string; const AOrdinal: Int64): TIR; overload;
    function EndEnum(): TIR;

    // Type aliases
    function DefineAlias(const AName: string; const AType: TValueType): TIR; overload;
    function DefineAlias(const AName: string; const ATypeName: string): TIR; overload;

    // Pointer types
    function DefinePointer(const AName: string): TIR; overload;
    function DefinePointer(const AName: string; const APointeeType: TValueType;
      const AIsConst: Boolean = False): TIR; overload;
    function DefinePointer(const AName: string; const APointeeTypeName: string;
      const AIsConst: Boolean = False): TIR; overload;

    // Routine (procedural) types
    function DefineRoutine(const AName: string; const ALinkage: TLinkage = plDefault): TIR;
    function RoutineParam(const AType: TValueType): TIR; overload;
    function RoutineParam(const ATypeName: string): TIR; overload;
    function RoutineReturns(const AType: TValueType): TIR; overload;
    function RoutineReturns(const ATypeName: string): TIR; overload;
    function RoutineVarArgs(): TIR;
    function EndRoutine(): TIR;

    // Set types
    function DefineSet(const AName: string): TIR; overload;
    function DefineSet(const AName: string; const ALow: Integer; const AHigh: Integer): TIR; overload;
    function DefineSet(const AName: string; const AEnumTypeName: string): TIR; overload;

    // Type queries
    function FindType(const AName: string): Integer;
    function GetTypeSize(const ATypeRef: TTypeRef): Integer;
    function GetTypeAlignment(const ATypeRef: TTypeRef): Integer;
    function TypeRef(const AName: string): TTypeRef;
    function GetTypeCount(): Integer;
    function GetTypeEntry(const AIndex: Integer): TIRTypeEntry;
    function IsStringType(const ATypeRef: TTypeRef): Boolean;
    function IsWStringType(const ATypeRef: TTypeRef): Boolean;
    function IsManagedType(const ATypeRef: TTypeRef): Boolean;

    //--------------------------------------------------------------------------
    // Function Definition (fluent)
    //--------------------------------------------------------------------------
    function Func(
      const AName: string;
      const AReturnType: TValueType = vtVoid;
      const AIsEntryPoint: Boolean = False;
      const ALinkage: TLinkage = plDefault;
      const AIsPublic: Boolean = False
    ): TIR;
    function OverloadFunc(
      const AName: string;
      const AReturnType: TValueType = vtVoid;
      const AIsEntryPoint: Boolean = False;
      const AIsPublic: Boolean = False
    ): TIR;
    function VariadicFunc(
      const AName: string;
      const AReturnType: TValueType = vtVoid;
      const AIsEntryPoint: Boolean = False;
      const AIsPublic: Boolean = False
    ): TIR;
    function DllMain(): TIR;
    function Param(const AName: string; const AType: TValueType; const AByRef: Boolean = False): TIR; overload;
    function Param(const AName: string; const ATypeName: string; const AByRef: Boolean = False): TIR; overload;
    function Returns(const ATypeName: string): TIR;
    function Local(const AName: string; const AType: TValueType): TIR; overload;
    function Local(const AName: string; const ATypeName: string): TIR; overload;
    function EndFunc(): TIR;

    //--------------------------------------------------------------------------
    // Source Location (for debugger)
    //--------------------------------------------------------------------------
    function SetLine(const ALine: Integer; const AColumn: Integer = 0): TIR;
    function SetSourceFile(const AFile: string): TIR;

    //--------------------------------------------------------------------------
    // Statements (fluent)
    //--------------------------------------------------------------------------
    function Assign(const ADest: string; const AValue: TIRExpr): TIR;
    function SetVal(const ADest: TIRExpr; const AValue: TIRExpr): TIR;
    function Call(const AFuncName: string): TIR; overload;
    function Call(const AFuncName: string; const AArgs: array of TIRExpr): TIR; overload;
    function CallAssign(const ADest: string; const AFuncName: string; const AArgs: array of TIRExpr): TIR;
    function Return(): TIR; overload;
    function Return(const AValue: TIRExpr): TIR; overload;

    // Short aliases
    function Let(const ADest: string; const AValue: TIRExpr): TIR;
    function VarDecl(const AName: string; const AType: TValueType): TIR; overload;
    function VarDecl(const AName: string; const ATypeName: string): TIR; overload;
    function Ret(): TIR; overload;
    function Ret(const AValue: TIRExpr): TIR; overload;

    // Indirect calls (via function pointer)
    function CallIndirect(const AFuncPtr: TIRExpr): TIR; overload;
    function CallIndirect(const AFuncPtr: TIRExpr; const AArgs: array of TIRExpr): TIR; overload;
    function CallIndirectAssign(const ADest: string; const AFuncPtr: TIRExpr;
      const AArgs: array of TIRExpr): TIR;

    //--------------------------------------------------------------------------
    // Control Flow (fluent)
    //--------------------------------------------------------------------------
    function When(const ACond: TIRExpr): TIR;
    function Otherwise(): TIR;
    function EndWhen(): TIR;

    function Loop(const ACond: TIRExpr): TIR;
    function EndLoop(): TIR;
    function LoopBreak(): TIR;
    function LoopContinue(): TIR;

    function Count(const AVar: string; const AFrom: TIRExpr; const ATo: TIRExpr): TIR;
    function CountDown(const AVar: string; const AFrom: TIRExpr; const ATo: TIRExpr): TIR;
    function EndCount(): TIR;

    function DoRepeat(): TIR;
    function StopWhen(const ACond: TIRExpr): TIR;

    function Match(const ASelector: TIRExpr): TIR;
    function On(const AValues: array of TIRExpr): TIR; overload;
    function On(const AValues: array of Integer): TIR; overload;
    function OnElse(): TIR;
    function EndMatch(): TIR;

    function Guard(): TIR;
    function Catch(): TIR;
    function Ensure(): TIR;
    function EndGuard(): TIR;

    function Throw(const AMsg: TIRExpr): TIR;
    function ThrowCode(const ACode: TIRExpr; const AMsg: TIRExpr): TIR;

    function Incr(const AVarName: string): TIR; overload;
    function Incr(const AVarName: string; const AAmount: TIRExpr): TIR; overload;
    function Decr(const AVarName: string): TIR; overload;
    function Decr(const AVarName: string; const AAmount: TIRExpr): TIR; overload;

    //--------------------------------------------------------------------------
    // Expressions - Literals
    //--------------------------------------------------------------------------
    function Str(const AValue: string): TIRExpr;
    function WStr(const AValue: string): TIRExpr;
    function MakeInt64(const AValue: Int64): TIRExpr;
    function Int32(const AValue: Int32): TIRExpr;
    function Float64(const AValue: Double): TIRExpr;
    function Bool(const AValue: Boolean): TIRExpr;
    function Int8(const AValue: Int8): TIRExpr;
    function Int16(const AValue: Int16): TIRExpr;
    function UInt8(const AValue: UInt8): TIRExpr;
    function UInt16(const AValue: UInt16): TIRExpr;
    function UInt32(const AValue: UInt32): TIRExpr;
    function UInt64(const AValue: UInt64): TIRExpr;
    function Float32(const AValue: Single): TIRExpr;
    function Null(): TIRExpr;

    //--------------------------------------------------------------------------
    // Expressions - Variable Reference
    //--------------------------------------------------------------------------
    function Get(const AName: string): TIRExpr;

    //--------------------------------------------------------------------------
    // Expressions - Arithmetic
    //--------------------------------------------------------------------------
    function Add(const ALeft: TIRExpr; const ARight: TIRExpr): TIRExpr;
    function Sub(const ALeft: TIRExpr; const ARight: TIRExpr): TIRExpr;
    function Mul(const ALeft: TIRExpr; const ARight: TIRExpr): TIRExpr;
    function IDiv(const ALeft: TIRExpr; const ARight: TIRExpr): TIRExpr;
    function IMod(const ALeft: TIRExpr; const ARight: TIRExpr): TIRExpr;
    function Neg(const AValue: TIRExpr): TIRExpr;
    function FAdd(const ALeft: TIRExpr; const ARight: TIRExpr): TIRExpr;
    function FSub(const ALeft: TIRExpr; const ARight: TIRExpr): TIRExpr;
    function FMul(const ALeft: TIRExpr; const ARight: TIRExpr): TIRExpr;
    function FDiv(const ALeft: TIRExpr; const ARight: TIRExpr): TIRExpr;
    function FNeg(const AValue: TIRExpr): TIRExpr;

    // Type conversion
    function IntToFloat64(const AValue: TIRExpr): TIRExpr;
    function Float64ToInt(const AValue: TIRExpr): TIRExpr;

    //--------------------------------------------------------------------------
    // Expressions - Bitwise
    //--------------------------------------------------------------------------
    function BitAnd(const ALeft: TIRExpr; const ARight: TIRExpr): TIRExpr;
    function BitOr(const ALeft: TIRExpr; const ARight: TIRExpr): TIRExpr;
    function BitXor(const ALeft: TIRExpr; const ARight: TIRExpr): TIRExpr;
    function BitNot(const AValue: TIRExpr): TIRExpr;
    function ShiftL(const AValue: TIRExpr; const ACount: TIRExpr): TIRExpr;
    function ShiftR(const AValue: TIRExpr; const ACount: TIRExpr): TIRExpr;

    //--------------------------------------------------------------------------
    // Expressions - Comparison
    //--------------------------------------------------------------------------
    function Eq(const ALeft: TIRExpr; const ARight: TIRExpr): TIRExpr;
    function Ne(const ALeft: TIRExpr; const ARight: TIRExpr): TIRExpr;
    function Lt(const ALeft: TIRExpr; const ARight: TIRExpr): TIRExpr;
    function Le(const ALeft: TIRExpr; const ARight: TIRExpr): TIRExpr;
    function Gt(const ALeft: TIRExpr; const ARight: TIRExpr): TIRExpr;
    function Ge(const ALeft: TIRExpr; const ARight: TIRExpr): TIRExpr;

    //--------------------------------------------------------------------------
    // Expressions - Float Comparison
    //--------------------------------------------------------------------------
    function FEq(const ALeft: TIRExpr; const ARight: TIRExpr): TIRExpr;
    function FNe(const ALeft: TIRExpr; const ARight: TIRExpr): TIRExpr;
    function FLt(const ALeft: TIRExpr; const ARight: TIRExpr): TIRExpr;
    function FLe(const ALeft: TIRExpr; const ARight: TIRExpr): TIRExpr;
    function FGt(const ALeft: TIRExpr; const ARight: TIRExpr): TIRExpr;
    function FGe(const ALeft: TIRExpr; const ARight: TIRExpr): TIRExpr;

    //--------------------------------------------------------------------------
    // Expressions - Logical
    //--------------------------------------------------------------------------
    function LogAnd(const ALeft: TIRExpr; const ARight: TIRExpr): TIRExpr;
    function LogOr(const ALeft: TIRExpr; const ARight: TIRExpr): TIRExpr;
    function LogNot(const AValue: TIRExpr): TIRExpr;

    //--------------------------------------------------------------------------
    // Expressions - Pointers
    //--------------------------------------------------------------------------
    function AddrOf(const AName: string): TIRExpr;
    function AddrOfVal(const AExpr: TIRExpr): TIRExpr;
    function Deref(const APtr: TIRExpr): TIRExpr; overload;
    function Deref(const APtr: TIRExpr; const ATypeName: string): TIRExpr; overload;
    function Deref(const APtr: TIRExpr; const AType: TValueType): TIRExpr; overload;

    //--------------------------------------------------------------------------
    // Expressions - Function Pointers
    //--------------------------------------------------------------------------
    function FuncAddr(const AFuncName: string): TIRExpr;
    function InvokeIndirect(const AFuncPtr: TIRExpr; const AArgs: array of TIRExpr): TIRExpr;

    //--------------------------------------------------------------------------
    // Expressions - Composite Type Access
    //--------------------------------------------------------------------------
    function GetField(const AObject: TIRExpr; const AFieldName: string): TIRExpr;
    function GetIndex(const AArray: TIRExpr; const AIndex: TIRExpr): TIRExpr;

    //--------------------------------------------------------------------------
    // Expressions - Function Call
    //--------------------------------------------------------------------------
    function Invoke(const AFuncName: string; const AArgs: array of TIRExpr): TIRExpr;

    //--------------------------------------------------------------------------
    // Expressions - Exception Intrinsics
    //--------------------------------------------------------------------------
    function ExcCode(): TIRExpr;
    function ExcMsg(): TIRExpr;

    //--------------------------------------------------------------------------
    // Expressions - Set Literals
    //--------------------------------------------------------------------------
    function SetLit(const ATypeName: string; const AElements: array of Integer): TIRExpr;
    function SetLitRange(const ATypeName: string; const ALow: Integer; const AHigh: Integer): TIRExpr;
    function EmptySet(const ATypeName: string): TIRExpr;

    //--------------------------------------------------------------------------
    // Expressions - Set Operations
    //--------------------------------------------------------------------------
    function SetUnion(const ALeft: TIRExpr; const ARight: TIRExpr): TIRExpr;
    function SetDiff(const ALeft: TIRExpr; const ARight: TIRExpr): TIRExpr;
    function SetInter(const ALeft: TIRExpr; const ARight: TIRExpr): TIRExpr;
    function SetIn(const AElement: TIRExpr; const ASet: TIRExpr): TIRExpr; overload;
    function SetIn(const AElement: TIRExpr; const ASet: TIRExpr; const ALowBound: Integer): TIRExpr; overload;
    function SetEq(const ALeft: TIRExpr; const ARight: TIRExpr): TIRExpr;
    function SetNe(const ALeft: TIRExpr; const ARight: TIRExpr): TIRExpr;
    function SetSubset(const ALeft: TIRExpr; const ARight: TIRExpr): TIRExpr;
    function SetSuperset(const ALeft: TIRExpr; const ARight: TIRExpr): TIRExpr;

    //--------------------------------------------------------------------------
    // Expressions - Compile-Time Intrinsics
    //--------------------------------------------------------------------------
    function TypeSize(const ATypeName: string): TIRExpr;
    function AlignOf(const ATypeName: string): TIRExpr;
    function High(const ATypeName: string): TIRExpr;
    function Low(const ATypeName: string): TIRExpr;
    function Len(const ATypeName: string): TIRExpr;

    //--------------------------------------------------------------------------
    // Expressions - Runtime Intrinsics
    //--------------------------------------------------------------------------
    function Ord(const AValue: TIRExpr): TIRExpr;
    function Chr(const AValue: TIRExpr): TIRExpr;
    function Succ(const AValue: TIRExpr): TIRExpr;
    function Pred(const AValue: TIRExpr): TIRExpr;

    //--------------------------------------------------------------------------
    // Expressions - Variadic Intrinsics
    //--------------------------------------------------------------------------
    function VaCount(): TIRExpr;
    function VaArg(const AIndex: TIRExpr; const AType: TValueType): TIRExpr;


    //--------------------------------------------------------------------------
    // Reset
    //--------------------------------------------------------------------------
    procedure Clear();

    //--------------------------------------------------------------------------
    // Runtime snapshot (for ResetBuild support)
    //--------------------------------------------------------------------------

    /// <summary>
    ///   Saves the current IR list counts as a snapshot. Everything added after
    ///   this point (typically runtime injection) can be removed by calling
    ///   RestoreSnapshot.
    /// </summary>
    procedure SaveSnapshot();

    /// <summary>
    ///   Truncates all IR lists back to the snapshot point, removing any
    ///   runtime-injected functions, imports, strings, and globals. No-op if
    ///   no snapshot has been saved.
    /// </summary>
    procedure RestoreSnapshot();

    //--------------------------------------------------------------------------
    // Getters for SSA conversion
    //--------------------------------------------------------------------------
    function GetImportCount(): Integer;
    function GetImport(const AIndex: Integer): TIRImport;
    function GetStringCount(): Integer;
    function GetString(const AIndex: Integer): TIRString;
    function GetGlobalCount(): Integer;
    function GetGlobal(const AIndex: Integer): TIRGlobal;
    function FindGlobal(const AName: string): Integer;
    function FindImport(const AName: string): Integer;
    function GetFunctionCount(): Integer;
    function GetFunction(const AIndex: Integer): TIRFunc;
    function GetExpressionCount(): Integer;
    function GetExpression(const AIndex: Integer): TIRExprNode;

    // Field lookup for SSA conversion (handles inheritance)
    function FindRecordField(const ATypeIndex: Integer; const AFieldName: string;
      out AFieldInfo: TIRRecordField): Boolean;
  end;

//==============================================================================
// Module-Level Helper Functions
//
// These call into the current active TIR context via the GActiveExprOwner
// threadvar. Set automatically by TIR.Create. Multi-threaded users call
// TIR.Activate() per thread.
//==============================================================================

// Variable & literal construction
function V(const AName: string): TExpr;
function S(const AValue: string): TExpr;
function W(const AValue: string): TExpr;
function I(const AValue: Int64): TExpr;
function F(const AValue: Double): TExpr;
function B(const AValue: Boolean): TExpr;
function P: TExpr;
function Addr(const AName: string): TExpr;
function Fn(const AName: string): TExpr;
function Inv(const AFuncName: string; const AArgs: array of TExpr): TExpr;

implementation

uses
  Ganymede.ABI;

// Forward declarations for TExpr factory callbacks
function ExprFactory_Binary(const AOwner: Pointer; const AOp: TOpKind; const ALeft, ARight: Integer): TExpr; forward;
function ExprFactory_Unary(const AOwner: Pointer; const AOp: TOpKind; const AOperand: Integer): TExpr; forward;
function ExprFactory_FromInt(const AOwner: Pointer; const AValue: Int64): TExpr; forward;
function ExprFactory_FromFlt(const AOwner: Pointer; const AValue: Double): TExpr; forward;
function ExprFactory_FromBool(const AOwner: Pointer; const AValue: Boolean): TExpr; forward;
function ExprFactory_Field(const AOwner: Pointer; const AExprIdx: Integer; const AFieldName: string): TExpr; forward;
function ExprFactory_Index(const AOwner: Pointer; const AArrIdx: Integer; const AIdxIdx: Integer): TExpr; forward;

//==============================================================================
// TIRExpr
//==============================================================================

class function TIRExpr.None(): TIRExpr;
begin
  Result.Index := -1;
end;

function TIRExpr.IsValid(): Boolean;
begin
  Result := Index >= 0;
end;

class operator TIRExpr.Implicit(const AValue: Integer): TIRExpr;
begin
  // This creates a placeholder - actual conversion happens in context
  Result.Index := -AValue - 1000000;  // Encode as negative with offset
end;

class operator TIRExpr.Implicit(const AValue: Int64): TIRExpr;
begin
  Result.Index := -Integer(AValue) - 1000000;
end;

class operator TIRExpr.Implicit(const AValue: Double): TIRExpr;
begin
  // For doubles, we can't encode directly - user should use Float64()
  Result.Index := -1;
end;

//==============================================================================
// TTypeRef
//==============================================================================

class function TTypeRef.FromPrimitive(const AType: TValueType): TTypeRef;
begin
  Result := Default(TTypeRef);
  Result.IsPrimitive := True;
  Result.Primitive := AType;
  Result.TypeIndex := -1;
end;

class function TTypeRef.FromComposite(const AIndex: Integer): TTypeRef;
begin
  Result := Default(TTypeRef);
  Result.IsPrimitive := False;
  Result.Primitive := vtVoid;
  Result.TypeIndex := AIndex;
end;

class function TTypeRef.None(): TTypeRef;
begin
  Result := Default(TTypeRef);
  Result.IsPrimitive := True;
  Result.Primitive := vtVoid;
  Result.TypeIndex := -1;
end;

function TTypeRef.IsValid(): Boolean;
begin
  if IsPrimitive then
    Result := Primitive <> vtVoid
  else
    Result := TypeIndex >= 0;
end;

function TTypeRef.ToString(): string;
const
  CPrimitiveNames: array[TValueType] of string = (
    'void', 'int8', 'int16', 'int32', 'int64',
    'uint8', 'uint16', 'uint32', 'uint64',
    'float32', 'float64', 'pointer'
  );
begin
  if IsPrimitive then
    Result := CPrimitiveNames[Primitive]
  else
    Result := Format('type#%d', [TypeIndex]);
end;

class operator TTypeRef.Equal(const A: TTypeRef; const B: TTypeRef): Boolean;
begin
  if A.IsPrimitive <> B.IsPrimitive then
    Exit(False);
  if A.IsPrimitive then
    Result := A.Primitive = B.Primitive
  else
    Result := A.TypeIndex = B.TypeIndex;
end;

class operator TTypeRef.NotEqual(const A: TTypeRef; const B: TTypeRef): Boolean;
begin
  Result := not (A = B);
end;

//==============================================================================
// TIR - Construction/Destruction
//==============================================================================

constructor TIR.Create();
begin
  inherited Create();

  FImports := TList<TIRImport>.Create();
  FStrings := TList<TIRString>.Create();
  FGlobals := TList<TIRGlobal>.Create();
  FFunctions := TList<TIRFunc>.Create();
  FExpressions := TList<TIRExprNode>.Create();
  FTypes := TList<TIRTypeEntry>.Create();
  FCurrentFunc := -1;
  FSnapshotFuncs := -1;
  FSnapshotImports := -1;
  FSnapshotStrings := -1;
  FSnapshotGlobals := -1;
  FSnapshotExprs := -1;
  FBuildingRecordIndex := -1;
  FSkipBuildingRecord := False;
  FBuildingUnionIndex := -1;
  FBuildingEnumIndex := -1;
  FNextEnumOrdinal := 0;
  FNextOverlayGroup := 0;
  FAnonUnionFieldStart := -1;
  FNextAnonRecordGroup := 0;
  FAnonRecordInUnion := False;
  FBuildingRoutineIndex := -1;

  // Wire TExpr operator overloads into this IR's expression graph
  TExprFactory.OnBinary   := ExprFactory_Binary;
  TExprFactory.OnUnary    := ExprFactory_Unary;
  TExprFactory.OnFromInt  := ExprFactory_FromInt;
  TExprFactory.OnFromFlt  := ExprFactory_FromFlt;
  TExprFactory.OnFromBool := ExprFactory_FromBool;
  TExprFactory.OnField    := ExprFactory_Field;
  TExprFactory.OnIndex    := ExprFactory_Index;

  // Set thread-local context for implicit TExpr conversions
  GActiveExprOwner := Self;
end;

destructor TIR.Destroy();
var
  LI: Integer;
begin
  for LI := 0 to FFunctions.Count - 1 do
  begin
    FFunctions[LI].Vars.Free();
    FFunctions[LI].Stmts.Free();
  end;

  FTypes.Free();
  FExpressions.Free();
  FFunctions.Free();
  FGlobals.Free();
  FStrings.Free();
  FImports.Free();

  inherited Destroy();
end;

//==============================================================================
// TIR - Private Helpers
//==============================================================================

function TIR.GetCurrentFunc(): TIRFunc;
begin
  if (FCurrentFunc < 0) or (FCurrentFunc >= FFunctions.Count) then
  begin
    if Assigned(FErrors) then
      FErrors.Add(esError, ERR_IR_NO_ACTIVE_FUNCTION, RSIRNoActiveFunction);
    Result := Default(TIRFunc);
    Exit;
  end;
  Result := FFunctions[FCurrentFunc];
end;

function TIR.AddExpr(const ANode: TIRExprNode): TIRExpr;
begin
  Result.Index := FExpressions.Count;
  FExpressions.Add(ANode);
end;

function TIR.MakeBinaryExpr(const ALeft, ARight: TIRExpr; const AOp: TIROpKind): TIRExpr;
var
  LNode: TIRExprNode;
begin
  LNode := Default(TIRExprNode);
  LNode.Kind := ekBinary;
  LNode.Op := AOp;
  LNode.Left := ALeft.Index;
  LNode.Right := ARight.Index;
  Result := AddExpr(LNode);
end;

function TIR.MakeUnaryExpr(const AValue: TIRExpr; const AOp: TIROpKind): TIRExpr;
var
  LNode: TIRExprNode;
begin
  LNode := Default(TIRExprNode);
  LNode.Kind := ekUnary;
  LNode.Op := AOp;
  LNode.Left := AValue.Index;
  LNode.Right := -1;
  Result := AddExpr(LNode);
end;

function TIR.FindGlobal(const AName: string): Integer;
var
  LI: Integer;
begin
  for LI := 0 to FGlobals.Count - 1 do
  begin
    if SameText(FGlobals[LI].GlobalName, AName) then
      Exit(LI);
  end;
  Result := -1;
end;

function TIR.FindImport(const AName: string): Integer;
var
  LI: Integer;
begin
  for LI := 0 to FImports.Count - 1 do
  begin
    if SameText(FImports[LI].FuncName, AName) then
      Exit(LI);
  end;
  Result := -1;
end;

function TIR.FindLocalFunc(const AName: string): Integer;
var
  LI: Integer;
begin
  for LI := 0 to FFunctions.Count - 1 do
  begin
    if SameText(FFunctions[LI].FuncName, AName) then
      Exit(LI);
  end;
  Result := -1;
end;

//==============================================================================
// TIR - Type System Helpers
//==============================================================================

function TIR.GetPrimitiveSize(const AType: TValueType): Integer;
begin
  case AType of
    vtVoid:    Result := 0;
    vtInt8:    Result := 1;
    vtInt16:   Result := 2;
    vtInt32:   Result := 4;
    vtInt64:   Result := 8;
    vtUInt8:   Result := 1;
    vtUInt16:  Result := 2;
    vtUInt32:  Result := 4;
    vtUInt64:  Result := 8;
    vtFloat32: Result := 4;
    vtFloat64: Result := 8;
    vtPointer: Result := 8;
  else
    Result := 8;
  end;
end;

function TIR.BitField(const AName: string; const AType: TValueType; const ABitWidth: Integer): TIR;
var
  LEntry: TIRTypeEntry;
  LField: TIRRecordField;
  LLen: Integer;
  LTypeSize: Integer;
begin
  Result := Self;

  // BitField only valid in records
  if FBuildingRecordIndex < 0 then
  begin
    if Assigned(FErrors) then
      FErrors.Add(esError, ERR_IR_TYPE_BUILD, RSIRBitFieldNoRecord);
    Exit;
  end;

  // Validate bit width
  LTypeSize := GetPrimitiveSize(AType) * 8;  // Size in bits
  if (ABitWidth < 1) or (ABitWidth > LTypeSize) then
  begin
    if Assigned(FErrors) then
      FErrors.Add(esError, ERR_IR_TYPE_BUILD, RSIRBitFieldWidth, [LTypeSize]);
    Exit;
  end;

  LField := Default(TIRRecordField);
  LField.FieldName := AName;
  LField.FieldType := TTypeRef.FromPrimitive(AType);
  LField.FieldOffset := -1;  // Computed during finalization
  LField.BitWidth := ABitWidth;
  LField.BitOffset := -1;  // Computed during finalization
  LField.OverlayGroup := 0;
  LField.AnonRecordGroup := 0;

  // If inside anonymous union, mark as overlay
  if FAnonUnionFieldStart >= 0 then
    LField.OverlayGroup := FNextOverlayGroup;

  LEntry := FTypes[FBuildingRecordIndex];
  LLen := Length(LEntry.RecordType.Fields);
  SetLength(LEntry.RecordType.Fields, LLen + 1);
  LEntry.RecordType.Fields[LLen] := LField;
  FTypes[FBuildingRecordIndex] := LEntry;
end;

function TIR.GetPrimitiveAlignment(const AType: TValueType): Integer;
begin
  // On x64, alignment equals size for primitives (up to 8)
  Result := GetPrimitiveSize(AType);
  if Result > 8 then
    Result := 8;
end;

procedure TIR.FinalizeRecordLayout(const ATypeIndex: Integer);
var
  LEntry: TIRTypeEntry;
  LBaseEntry: TIRTypeEntry;
  LI: Integer;
  LOffset: Integer;
  LFieldSize: Integer;
  LFieldAlign: Integer;
  LMaxAlign: Integer;
  LCurrentOverlay: Integer;
  LOverlayStart: Integer;
  LOverlayMaxSize: Integer;
  // Bit field tracking
  LBitPos: Integer;           // Current bit position within storage unit
  LBitStorageSize: Integer;   // Size of current bit storage unit in bits
  LBitStorageOffset: Integer; // Byte offset of current bit storage unit
begin
  if (ATypeIndex < 0) or (ATypeIndex >= FTypes.Count) then
    Exit;

  LEntry := FTypes[ATypeIndex];
  if LEntry.Kind <> tkRecord then
    Exit;
  if LEntry.RecordType.IsFinalized then
    Exit;

  LOffset := 0;
  LMaxAlign := 1;
  LCurrentOverlay := 0;
  LOverlayStart := 0;
  LOverlayMaxSize := 0;
  LBitPos := 0;
  LBitStorageSize := 0;
  LBitStorageOffset := -1;

  // Handle base type inheritance
  if LEntry.RecordType.BaseTypeIndex >= 0 then
  begin
    // Ensure base is finalized first
    if not FTypes[LEntry.RecordType.BaseTypeIndex].RecordType.IsFinalized then
      FinalizeRecordLayout(LEntry.RecordType.BaseTypeIndex);

    // Get base info (re-read in case it was just finalized)
    LBaseEntry := FTypes[LEntry.RecordType.BaseTypeIndex];

    // Derived starts at base size (properly aligned)
    LOffset := LBaseEntry.RecordType.TotalSize;
    LMaxAlign := LBaseEntry.RecordType.Alignment;
  end;

  // Apply explicit alignment if specified
  if LEntry.RecordType.ExplicitAlign > 0 then
  begin
    if LEntry.RecordType.ExplicitAlign > LMaxAlign then
      LMaxAlign := LEntry.RecordType.ExplicitAlign;
  end;

  for LI := 0 to Length(LEntry.RecordType.Fields) - 1 do
  begin
    // Get field size and alignment
    LFieldSize := GetTypeSize(LEntry.RecordType.Fields[LI].FieldType);
    LFieldAlign := GetTypeAlignment(LEntry.RecordType.Fields[LI].FieldType);

    // Track max alignment
    if LFieldAlign > LMaxAlign then
      LMaxAlign := LFieldAlign;

    // Handle overlay groups (anonymous unions)
    if LEntry.RecordType.Fields[LI].OverlayGroup <> LCurrentOverlay then
    begin
      // Close current bit storage unit if any
      if LBitStorageSize > 0 then
      begin
        LOffset := LBitStorageOffset + (LBitStorageSize div 8);
        LBitStorageSize := 0;
        LBitPos := 0;
        LBitStorageOffset := -1;
      end;

      // Leaving previous overlay group - advance offset by max size
      if LCurrentOverlay > 0 then
        LOffset := LOverlayStart + LOverlayMaxSize;

      // Entering new overlay group
      LCurrentOverlay := LEntry.RecordType.Fields[LI].OverlayGroup;
      if LCurrentOverlay > 0 then
      begin
        // Align for new overlay group
        if not LEntry.RecordType.IsPacked then
        begin
          if (LOffset mod LFieldAlign) <> 0 then
            LOffset := LOffset + (LFieldAlign - (LOffset mod LFieldAlign));
        end;
        LOverlayStart := LOffset;
        LOverlayMaxSize := 0;
      end;
    end;

    // Check if this is a bit field
    if LEntry.RecordType.Fields[LI].BitWidth > 0 then
    begin
      // Bit field processing
      if (LBitStorageSize = 0) or
         (LBitPos + LEntry.RecordType.Fields[LI].BitWidth > LBitStorageSize) or
         (LBitStorageSize <> LFieldSize * 8) then
      begin
        // Need new storage unit: either no current unit, won't fit, or different size
        // Close previous bit storage unit
        if LBitStorageSize > 0 then
          LOffset := LBitStorageOffset + (LBitStorageSize div 8);

        // Align for new storage unit
        if not LEntry.RecordType.IsPacked then
        begin
          if (LOffset mod LFieldAlign) <> 0 then
            LOffset := LOffset + (LFieldAlign - (LOffset mod LFieldAlign));
        end;

        // Start new bit storage unit
        LBitStorageOffset := LOffset;
        LBitStorageSize := LFieldSize * 8;
        LBitPos := 0;
      end;

      // Place bit field
      LEntry.RecordType.Fields[LI].FieldOffset := LBitStorageOffset;
      LEntry.RecordType.Fields[LI].BitOffset := LBitPos;
      LBitPos := LBitPos + LEntry.RecordType.Fields[LI].BitWidth;

      // Track overlay size if in overlay
      if LCurrentOverlay > 0 then
      begin
        if LFieldSize > LOverlayMaxSize then
          LOverlayMaxSize := LFieldSize;
      end;
    end
    else if LCurrentOverlay > 0 then
    begin
      // Close current bit storage unit if any
      if LBitStorageSize > 0 then
      begin
        LOffset := LBitStorageOffset + (LBitStorageSize div 8);
        LBitStorageSize := 0;
        LBitPos := 0;
        LBitStorageOffset := -1;
      end;

      // Inside overlay group - all fields share the same start offset
      LEntry.RecordType.Fields[LI].FieldOffset := LOverlayStart;
      LEntry.RecordType.Fields[LI].BitOffset := 0;
      if LFieldSize > LOverlayMaxSize then
        LOverlayMaxSize := LFieldSize;
    end
    else
    begin
      // Close current bit storage unit if any
      if LBitStorageSize > 0 then
      begin
        LOffset := LBitStorageOffset + (LBitStorageSize div 8);
        LBitStorageSize := 0;
        LBitPos := 0;
        LBitStorageOffset := -1;
      end;

      // Normal field - align and advance
      if not LEntry.RecordType.IsPacked then
      begin
        if (LOffset mod LFieldAlign) <> 0 then
          LOffset := LOffset + (LFieldAlign - (LOffset mod LFieldAlign));
      end;

      LEntry.RecordType.Fields[LI].FieldOffset := LOffset;
      LEntry.RecordType.Fields[LI].BitOffset := 0;
      LOffset := LOffset + LFieldSize;
    end;
  end;

  // Close final bit storage unit if any
  if LBitStorageSize > 0 then
    LOffset := LBitStorageOffset + (LBitStorageSize div 8);

  // Close final overlay group if any
  if LCurrentOverlay > 0 then
    LOffset := LOverlayStart + LOverlayMaxSize;

  // Apply explicit alignment if specified
  if LEntry.RecordType.ExplicitAlign > 0 then
  begin
    if LEntry.RecordType.ExplicitAlign > LMaxAlign then
      LMaxAlign := LEntry.RecordType.ExplicitAlign;
  end;

  // Pad total size to alignment
  if not LEntry.RecordType.IsPacked then
  begin
    if (LOffset mod LMaxAlign) <> 0 then
      LOffset := LOffset + (LMaxAlign - (LOffset mod LMaxAlign));
  end;

  // Ensure alignment is at least explicit alignment
  if LEntry.RecordType.ExplicitAlign > LMaxAlign then
    LMaxAlign := LEntry.RecordType.ExplicitAlign;

  LEntry.RecordType.TotalSize := LOffset;
  LEntry.RecordType.Alignment := LMaxAlign;
  LEntry.RecordType.IsFinalized := True;

  FTypes[ATypeIndex] := LEntry;
end;

procedure TIR.FinalizeUnionLayout(const ATypeIndex: Integer);
var
  LEntry: TIRTypeEntry;
  LI: Integer;
  LFieldSize: Integer;
  LFieldAlign: Integer;
  LMaxSize: Integer;
  LMaxAlign: Integer;
  LCurrentGroup: Integer;
  LGroupOffset: Integer;
  LGroupSize: Integer;
begin
  if (ATypeIndex < 0) or (ATypeIndex >= FTypes.Count) then
    Exit;

  LEntry := FTypes[ATypeIndex];
  if LEntry.Kind <> tkUnion then
    Exit;
  if LEntry.UnionType.IsFinalized then
    Exit;

  LMaxSize := 0;
  LMaxAlign := 1;
  LCurrentGroup := 0;
  LGroupOffset := 0;
  LGroupSize := 0;

  for LI := 0 to Length(LEntry.UnionType.Fields) - 1 do
  begin
    // Get field size and alignment
    LFieldSize := GetTypeSize(LEntry.UnionType.Fields[LI].FieldType);
    LFieldAlign := GetTypeAlignment(LEntry.UnionType.Fields[LI].FieldType);

    // Track max alignment for union overall
    if LFieldAlign > LMaxAlign then
      LMaxAlign := LFieldAlign;

    // Handle anonymous record groups
    if LEntry.UnionType.Fields[LI].AnonRecordGroup <> LCurrentGroup then
    begin
      // Closing previous group - add its size to max
      if LCurrentGroup > 0 then
      begin
        if LGroupSize > LMaxSize then
          LMaxSize := LGroupSize;
      end;

      // Starting new group
      LCurrentGroup := LEntry.UnionType.Fields[LI].AnonRecordGroup;
      LGroupOffset := 0;
      LGroupSize := 0;
    end;

    if LCurrentGroup > 0 then
    begin
      // Inside anonymous record - sequential layout within group
      // Align within group
      if (LGroupOffset mod LFieldAlign) <> 0 then
        LGroupOffset := LGroupOffset + (LFieldAlign - (LGroupOffset mod LFieldAlign));

      LEntry.UnionType.Fields[LI].FieldOffset := LGroupOffset;
      LGroupOffset := LGroupOffset + LFieldSize;
      LGroupSize := LGroupOffset;  // Group size grows
    end
    else
    begin
      // Normal union field - offset 0
      LEntry.UnionType.Fields[LI].FieldOffset := 0;
      if LFieldSize > LMaxSize then
        LMaxSize := LFieldSize;
    end;
  end;

  // Close final group if any
  if LCurrentGroup > 0 then
  begin
    if LGroupSize > LMaxSize then
      LMaxSize := LGroupSize;
  end;

  // Pad total size to alignment
  if (LMaxSize mod LMaxAlign) <> 0 then
    LMaxSize := LMaxSize + (LMaxAlign - (LMaxSize mod LMaxAlign));

  LEntry.UnionType.TotalSize := LMaxSize;
  LEntry.UnionType.Alignment := LMaxAlign;
  LEntry.UnionType.IsFinalized := True;

  FTypes[ATypeIndex] := LEntry;
end;

function TIR.FindVarType(const AVarName: string): TTypeRef;
var
  LFunc: TIRFunc;
  LI: Integer;
begin
  Result := TTypeRef.None();

  // Search function locals first
  if FCurrentFunc >= 0 then
  begin
    LFunc := FFunctions[FCurrentFunc];
    for LI := 0 to LFunc.Vars.Count - 1 do
    begin
      if SameText(LFunc.Vars[LI].VarName, AVarName) then
      begin
        Result := LFunc.Vars[LI].VarTypeRef;
        Exit;
      end;
    end;
  end;

  // Search globals if not found in locals
  for LI := 0 to FGlobals.Count - 1 do
  begin
    if SameText(FGlobals[LI].GlobalName, AVarName) then
    begin
      Result := FGlobals[LI].GlobalTypeRef;
      Exit;
    end;
  end;

  // Search imports if not found in globals (for external variables)
  for LI := 0 to FImports.Count - 1 do
  begin
    if SameText(FImports[LI].FuncName, AVarName) then
    begin
      Result := TTypeRef.FromPrimitive(FImports[LI].ReturnType);
      Exit;
    end;
  end;
end;

//==============================================================================
// TIR - Type Definitions
//==============================================================================

function TIR.DefineRecord(const AName: string; const AIsPacked: Boolean;
  const AExplicitAlign: Integer; const ABaseTypeName: string): TIR;
var
  LEntry: TIRTypeEntry;
  LBaseIndex: Integer;
begin
  Result := Self;

  // Skip if type already exists (idempotent)
  if FindType(AName) >= 0 then
  begin
    FSkipBuildingRecord := True;
    Exit;
  end;

  FSkipBuildingRecord := False;

  if FBuildingRecordIndex >= 0 then
  begin
    if Assigned(FErrors) then
      FErrors.Add(esError, ERR_IR_TYPE_BUILD, RSIRAlreadyBuildingRecord);
    Exit;
  end;

  // Resolve base type if specified
  LBaseIndex := -1;
  if ABaseTypeName <> '' then
  begin
    LBaseIndex := FindType(ABaseTypeName);
    if LBaseIndex < 0 then
    begin
      if Assigned(FErrors) then
        FErrors.Add(esError, ERR_IR_UNKNOWN_TYPE, RSIRUnknownBaseType, [ABaseTypeName]);
      Exit;
    end;
    // Verify base is a record
    if FTypes[LBaseIndex].Kind <> tkRecord then
    begin
      if Assigned(FErrors) then
        FErrors.Add(esError, ERR_IR_TYPE_BUILD, RSIRBaseNotRecord, [ABaseTypeName]);
      Exit;
    end;
  end;

  LEntry := Default(TIRTypeEntry);
  LEntry.Kind := tkRecord;
  LEntry.RecordType.TypeName := AName;
  LEntry.RecordType.IsPacked := AIsPacked;
  LEntry.RecordType.ExplicitAlign := AExplicitAlign;
  LEntry.RecordType.BaseTypeIndex := LBaseIndex;
  LEntry.RecordType.IsFinalized := False;
  SetLength(LEntry.RecordType.Fields, 0);

  FBuildingRecordIndex := FTypes.Count;
  FTypes.Add(LEntry);
end;

function TIR.Field(const AName: string; const AType: TValueType): TIR;
var
  LEntry: TIRTypeEntry;
  LField: TIRRecordField;
  LLen: Integer;
begin
  Result := Self;

  // Skip if DefineRecord was skipped (type already exists)
  if FSkipBuildingRecord then
    Exit;

  LField := Default(TIRRecordField);
  LField.FieldName := AName;
  LField.FieldType := TTypeRef.FromPrimitive(AType);
  LField.FieldOffset := -1;  // Computed during finalization
  LField.OverlayGroup := 0;  // Normal field by default
  LField.AnonRecordGroup := 0;  // Normal field by default

  if FBuildingRecordIndex >= 0 then
  begin
    // If inside anonymous union, mark as overlay
    if FAnonUnionFieldStart >= 0 then
      LField.OverlayGroup := FNextOverlayGroup;

    LEntry := FTypes[FBuildingRecordIndex];
    LLen := Length(LEntry.RecordType.Fields);
    SetLength(LEntry.RecordType.Fields, LLen + 1);
    LEntry.RecordType.Fields[LLen] := LField;
    FTypes[FBuildingRecordIndex] := LEntry;
  end
  else if FBuildingUnionIndex >= 0 then
  begin
    // If inside anonymous record, mark with group
    if FAnonRecordInUnion then
      LField.AnonRecordGroup := FNextAnonRecordGroup;

    LEntry := FTypes[FBuildingUnionIndex];
    LLen := Length(LEntry.UnionType.Fields);
    SetLength(LEntry.UnionType.Fields, LLen + 1);
    LEntry.UnionType.Fields[LLen] := LField;
    FTypes[FBuildingUnionIndex] := LEntry;
  end
  else
  begin
    if Assigned(FErrors) then
      FErrors.Add(esError, ERR_IR_TYPE_BUILD, RSIRNotBuildingRecordUnion);
  end;
end;

function TIR.Field(const AName: string; const ATypeName: string): TIR;
var
  LEntry: TIRTypeEntry;
  LField: TIRRecordField;
  LLen: Integer;
  LTypeIndex: Integer;
begin
  Result := Self;

  // Skip if DefineRecord was skipped (type already exists)
  if FSkipBuildingRecord then
    Exit;

  if (FBuildingRecordIndex < 0) and (FBuildingUnionIndex < 0) then
  begin
    if Assigned(FErrors) then
      FErrors.Add(esError, ERR_IR_TYPE_BUILD, RSIRNotBuildingRecordUnion);
    Exit;
  end;

  LTypeIndex := FindType(ATypeName);
  if LTypeIndex < 0 then
  begin
    if Assigned(FErrors) then
      FErrors.Add(esError, ERR_IR_UNKNOWN_TYPE, RSIRUnknownType, [ATypeName]);
    Exit;
  end;

  LField := Default(TIRRecordField);
  LField.FieldName := AName;
  LField.FieldType := TTypeRef.FromComposite(LTypeIndex);
  LField.FieldOffset := -1;
  LField.OverlayGroup := 0;  // Normal field by default
  LField.AnonRecordGroup := 0;  // Normal field by default

  if FBuildingRecordIndex >= 0 then
  begin
    // If inside anonymous union, mark as overlay
    if FAnonUnionFieldStart >= 0 then
      LField.OverlayGroup := FNextOverlayGroup;

    LEntry := FTypes[FBuildingRecordIndex];
    LLen := Length(LEntry.RecordType.Fields);
    SetLength(LEntry.RecordType.Fields, LLen + 1);
    LEntry.RecordType.Fields[LLen] := LField;
    FTypes[FBuildingRecordIndex] := LEntry;
  end
  else
  begin
    // If inside anonymous record, mark with group
    if FAnonRecordInUnion then
      LField.AnonRecordGroup := FNextAnonRecordGroup;

    LEntry := FTypes[FBuildingUnionIndex];
    LLen := Length(LEntry.UnionType.Fields);
    SetLength(LEntry.UnionType.Fields, LLen + 1);
    LEntry.UnionType.Fields[LLen] := LField;
    FTypes[FBuildingUnionIndex] := LEntry;
  end;
end;

function TIR.BeginRecord(): TIR;
begin
  Result := Self;

  // BeginRecord inside a union = anonymous record (sequential fields)
  if FBuildingUnionIndex >= 0 then
  begin
    if FAnonRecordInUnion then
    begin
      if Assigned(FErrors) then
        FErrors.Add(esError, ERR_IR_TYPE_BUILD, RSIRAlreadyAnonRecord);
      Exit;
    end;

    // Start new anonymous record group
    System.Inc(FNextAnonRecordGroup);
    FAnonRecordInUnion := True;
  end
  else
  begin
    // Not inside a union - error (use DefineRecord for named records)
    if Assigned(FErrors) then
      FErrors.Add(esError, ERR_IR_TYPE_BUILD, RSIRBeginRecordNeedsUnion);
  end;
end;

function TIR.EndRecord(): TIR;
begin
  Result := Self;

  // Skip if DefineRecord was skipped (type already exists)
  if FSkipBuildingRecord then
  begin
    FSkipBuildingRecord := False;
    Exit;
  end;

  // Check if we're closing an anonymous record inside a union
  if (FBuildingUnionIndex >= 0) and FAnonRecordInUnion then
  begin
    // Close anonymous record - reset tracking
    FAnonRecordInUnion := False;
    Exit;
  end;

  // Otherwise closing a named record
  if FBuildingRecordIndex < 0 then
  begin
    if Assigned(FErrors) then
      FErrors.Add(esError, ERR_IR_TYPE_BUILD, RSIRNotBuildingRecord);
    Exit;
  end;

  FinalizeRecordLayout(FBuildingRecordIndex);
  FBuildingRecordIndex := -1;
end;

function TIR.DefineUnion(const AName: string): TIR;
var
  LEntry: TIRTypeEntry;
begin
  Result := Self;

  if FBuildingUnionIndex >= 0 then
  begin
    if Assigned(FErrors) then
      FErrors.Add(esError, ERR_IR_TYPE_BUILD, RSIRAlreadyBuildingUnion);
    Exit;
  end;

  LEntry := Default(TIRTypeEntry);
  LEntry.Kind := tkUnion;
  LEntry.UnionType.TypeName := AName;
  LEntry.UnionType.IsFinalized := False;
  SetLength(LEntry.UnionType.Fields, 0);

  FBuildingUnionIndex := FTypes.Count;
  FTypes.Add(LEntry);
end;

function TIR.BeginUnion(): TIR;
var
  LEntry: TIRTypeEntry;
begin
  Result := Self;

  // BeginUnion inside a record = anonymous union (overlay fields)
  if FBuildingRecordIndex >= 0 then
  begin
    if FAnonUnionFieldStart >= 0 then
    begin
      if Assigned(FErrors) then
        FErrors.Add(esError, ERR_IR_TYPE_BUILD, RSIRAlreadyAnonUnion);
      Exit;
    end;

    // Start new overlay group
    System.Inc(FNextOverlayGroup);
    LEntry := FTypes[FBuildingRecordIndex];
    FAnonUnionFieldStart := Length(LEntry.RecordType.Fields);
  end
  else
  begin
    // Not inside a record - error (use DefineUnion for named unions)
    if Assigned(FErrors) then
      FErrors.Add(esError, ERR_IR_TYPE_BUILD, RSIRBeginUnionNeedsRecord);
  end;
end;

function TIR.EndUnion(): TIR;
begin
  Result := Self;

  // Check if we're closing an anonymous union inside a record
  if (FBuildingRecordIndex >= 0) and (FAnonUnionFieldStart >= 0) then
  begin
    // Close anonymous union - reset tracking
    FAnonUnionFieldStart := -1;
    Exit;
  end;

  // Otherwise closing a named union
  if FBuildingUnionIndex < 0 then
  begin
    if Assigned(FErrors) then
      FErrors.Add(esError, ERR_IR_TYPE_BUILD, RSIRNotBuildingUnion);
    Exit;
  end;

  FinalizeUnionLayout(FBuildingUnionIndex);
  FBuildingUnionIndex := -1;
end;

function TIR.DefineArray(const AName: string; const AElementType: TValueType;
  const ALowBound: Integer; const AHighBound: Integer): TIR;
var
  LEntry: TIRTypeEntry;
  LElementSize: Integer;
begin
  Result := Self;

  LEntry := Default(TIRTypeEntry);
  LEntry.Kind := tkFixedArray;
  LEntry.FixedArrayType.TypeName := AName;
  LEntry.FixedArrayType.ElementType := TTypeRef.FromPrimitive(AElementType);
  LEntry.FixedArrayType.LowBound := ALowBound;
  LEntry.FixedArrayType.HighBound := AHighBound;

  LElementSize := GetPrimitiveSize(AElementType);
  LEntry.FixedArrayType.TotalSize := (AHighBound - ALowBound + 1) * LElementSize;

  FTypes.Add(LEntry);
end;

function TIR.DefineArray(const AName: string; const AElementTypeName: string;
  const ALowBound: Integer; const AHighBound: Integer): TIR;
var
  LEntry: TIRTypeEntry;
  LTypeIndex: Integer;
  LElementSize: Integer;
begin
  Result := Self;

  LTypeIndex := FindType(AElementTypeName);
  if LTypeIndex < 0 then
  begin
    if Assigned(FErrors) then
      FErrors.Add(esError, ERR_IR_UNKNOWN_TYPE, RSIRUnknownType, [AElementTypeName]);
    Exit;
  end;

  LEntry := Default(TIRTypeEntry);
  LEntry.Kind := tkFixedArray;
  LEntry.FixedArrayType.TypeName := AName;
  LEntry.FixedArrayType.ElementType := TTypeRef.FromComposite(LTypeIndex);
  LEntry.FixedArrayType.LowBound := ALowBound;
  LEntry.FixedArrayType.HighBound := AHighBound;

  LElementSize := GetTypeSize(TTypeRef.FromComposite(LTypeIndex));
  LEntry.FixedArrayType.TotalSize := (AHighBound - ALowBound + 1) * LElementSize;

  FTypes.Add(LEntry);
end;

function TIR.DefineDynArray(const AName: string; const AElementType: TValueType): TIR;
var
  LEntry: TIRTypeEntry;
begin
  Result := Self;

  LEntry := Default(TIRTypeEntry);
  LEntry.Kind := tkDynArray;
  LEntry.DynArrayType.TypeName := AName;
  LEntry.DynArrayType.ElementType := TTypeRef.FromPrimitive(AElementType);

  FTypes.Add(LEntry);
end;

function TIR.DefineDynArray(const AName: string; const AElementTypeName: string): TIR;
var
  LEntry: TIRTypeEntry;
  LTypeIndex: Integer;
begin
  Result := Self;

  LTypeIndex := FindType(AElementTypeName);
  if LTypeIndex < 0 then
  begin
    if Assigned(FErrors) then
      FErrors.Add(esError, ERR_IR_UNKNOWN_TYPE, RSIRUnknownType, [AElementTypeName]);
    Exit;
  end;

  LEntry := Default(TIRTypeEntry);
  LEntry.Kind := tkDynArray;
  LEntry.DynArrayType.TypeName := AName;
  LEntry.DynArrayType.ElementType := TTypeRef.FromComposite(LTypeIndex);

  FTypes.Add(LEntry);
end;

function TIR.DefineEnum(const AName: string): TIR;
var
  LEntry: TIRTypeEntry;
begin
  Result := Self;

  if FBuildingEnumIndex >= 0 then
  begin
    if Assigned(FErrors) then
      FErrors.Add(esError, ERR_IR_TYPE_BUILD, RSIRAlreadyBuildingEnum);
    Exit;
  end;

  LEntry := Default(TIRTypeEntry);
  LEntry.Kind := tkEnum;
  LEntry.EnumType.TypeName := AName;
  LEntry.EnumType.BaseType := vtInt32;
  SetLength(LEntry.EnumType.Values, 0);

  FBuildingEnumIndex := FTypes.Count;
  FNextEnumOrdinal := 0;
  FTypes.Add(LEntry);
end;

function TIR.EnumValue(const AName: string): TIR;
var
  LEntry: TIRTypeEntry;
  LValue: TIREnumValue;
  LLen: Integer;
begin
  Result := Self;

  if FBuildingEnumIndex < 0 then
  begin
    if Assigned(FErrors) then
      FErrors.Add(esError, ERR_IR_TYPE_BUILD, RSIRNotBuildingEnum);
    Exit;
  end;

  LEntry := FTypes[FBuildingEnumIndex];

  LValue := Default(TIREnumValue);
  LValue.ValueName := AName;
  LValue.OrdinalValue := FNextEnumOrdinal;
  System.Inc(FNextEnumOrdinal);

  LLen := Length(LEntry.EnumType.Values);
  SetLength(LEntry.EnumType.Values, LLen + 1);
  LEntry.EnumType.Values[LLen] := LValue;

  FTypes[FBuildingEnumIndex] := LEntry;
end;

function TIR.EnumValue(const AName: string; const AOrdinal: Int64): TIR;
var
  LEntry: TIRTypeEntry;
  LValue: TIREnumValue;
  LLen: Integer;
begin
  Result := Self;

  if FBuildingEnumIndex < 0 then
  begin
    if Assigned(FErrors) then
      FErrors.Add(esError, ERR_IR_TYPE_BUILD, RSIRNotBuildingEnum);
    Exit;
  end;

  LEntry := FTypes[FBuildingEnumIndex];

  LValue := Default(TIREnumValue);
  LValue.ValueName := AName;
  LValue.OrdinalValue := AOrdinal;
  FNextEnumOrdinal := AOrdinal + 1;

  LLen := Length(LEntry.EnumType.Values);
  SetLength(LEntry.EnumType.Values, LLen + 1);
  LEntry.EnumType.Values[LLen] := LValue;

  FTypes[FBuildingEnumIndex] := LEntry;
end;

function TIR.EndEnum(): TIR;
begin
  Result := Self;

  if FBuildingEnumIndex < 0 then
  begin
    if Assigned(FErrors) then
      FErrors.Add(esError, ERR_IR_TYPE_BUILD, RSIRNotBuildingEnum);
    Exit;
  end;

  FBuildingEnumIndex := -1;
  FNextEnumOrdinal := 0;
end;

function TIR.DefineAlias(const AName: string; const AType: TValueType): TIR;
var
  LEntry: TIRTypeEntry;
begin
  Result := Self;

  LEntry := Default(TIRTypeEntry);
  LEntry.Kind := tkAlias;
  LEntry.AliasType.TypeName := AName;
  LEntry.AliasType.AliasedType := TTypeRef.FromPrimitive(AType);

  FTypes.Add(LEntry);
end;

function TIR.DefineAlias(const AName: string; const ATypeName: string): TIR;
var
  LEntry: TIRTypeEntry;
  LTypeIndex: Integer;
begin
  Result := Self;

  LTypeIndex := FindType(ATypeName);
  if LTypeIndex < 0 then
  begin
    if Assigned(FErrors) then
      FErrors.Add(esError, ERR_IR_UNKNOWN_TYPE, RSIRUnknownType, [ATypeName]);
    Exit;
  end;

  LEntry := Default(TIRTypeEntry);
  LEntry.Kind := tkAlias;
  LEntry.AliasType.TypeName := AName;
  LEntry.AliasType.AliasedType := TTypeRef.FromComposite(LTypeIndex);

  FTypes.Add(LEntry);
end;

function TIR.DefinePointer(const AName: string): TIR;
var
  LEntry: TIRTypeEntry;
begin
  Result := Self;

  // Skip if type already exists (idempotent)
  if FindType(AName) >= 0 then
    Exit;

  LEntry := Default(TIRTypeEntry);
  LEntry.Kind := tkPointer;
  LEntry.PointerType.TypeName := AName;
  LEntry.PointerType.PointeeType := TTypeRef.None();
  LEntry.PointerType.IsConst := False;

  FTypes.Add(LEntry);
end;

function TIR.DefinePointer(const AName: string; const APointeeType: TValueType;
  const AIsConst: Boolean): TIR;
var
  LEntry: TIRTypeEntry;
begin
  Result := Self;

  // Skip if type already exists (idempotent)
  if FindType(AName) >= 0 then
    Exit;

  LEntry := Default(TIRTypeEntry);
  LEntry.Kind := tkPointer;
  LEntry.PointerType.TypeName := AName;
  LEntry.PointerType.PointeeType := TTypeRef.FromPrimitive(APointeeType);
  LEntry.PointerType.IsConst := AIsConst;

  FTypes.Add(LEntry);
end;

function TIR.DefinePointer(const AName: string; const APointeeTypeName: string;
  const AIsConst: Boolean): TIR;
var
  LEntry: TIRTypeEntry;
  LTypeIndex: Integer;
begin
  Result := Self;

  // Skip if type already exists (idempotent)
  if FindType(AName) >= 0 then
    Exit;

  LTypeIndex := FindType(APointeeTypeName);
  if LTypeIndex < 0 then
  begin
    if Assigned(FErrors) then
      FErrors.Add(esError, ERR_IR_UNKNOWN_TYPE, RSIRUnknownType, [APointeeTypeName]);
    Exit;
  end;

  LEntry := Default(TIRTypeEntry);
  LEntry.Kind := tkPointer;
  LEntry.PointerType.TypeName := AName;
  LEntry.PointerType.PointeeType := TTypeRef.FromComposite(LTypeIndex);
  LEntry.PointerType.IsConst := AIsConst;

  FTypes.Add(LEntry);
end;

//==============================================================================
// TIR - Routine (Procedural) Type Definition
//==============================================================================

function TIR.DefineRoutine(const AName: string; const ALinkage: TLinkage): TIR;
var
  LEntry: TIRTypeEntry;
begin
  Result := Self;

  LEntry := Default(TIRTypeEntry);
  LEntry.Kind := tkRoutine;
  LEntry.RoutineType.TypeName := AName;
  LEntry.RoutineType.ReturnType := TTypeRef.FromPrimitive(vtVoid);  // Default return type
  LEntry.RoutineType.Linkage := ALinkage;
  LEntry.RoutineType.IsVarArgs := False;

  FBuildingRoutineIndex := FTypes.Count;
  FTypes.Add(LEntry);
end;

function TIR.RoutineParam(const AType: TValueType): TIR;
var
  LEntry: TIRTypeEntry;
  LLen: Integer;
begin
  Result := Self;

  if FBuildingRoutineIndex < 0 then
  begin
    if Assigned(FErrors) then
      FErrors.Add(esError, ERR_IR_TYPE_BUILD, RSIRNotBuildingRoutine);
    Exit;
  end;

  LEntry := FTypes[FBuildingRoutineIndex];
  LLen := Length(LEntry.RoutineType.ParamTypes);
  SetLength(LEntry.RoutineType.ParamTypes, LLen + 1);
  LEntry.RoutineType.ParamTypes[LLen] := TTypeRef.FromPrimitive(AType);
  FTypes[FBuildingRoutineIndex] := LEntry;
end;

function TIR.RoutineParam(const ATypeName: string): TIR;
var
  LEntry: TIRTypeEntry;
  LTypeIndex: Integer;
  LLen: Integer;
begin
  Result := Self;

  if FBuildingRoutineIndex < 0 then
  begin
    if Assigned(FErrors) then
      FErrors.Add(esError, ERR_IR_TYPE_BUILD, RSIRNotBuildingRoutine);
    Exit;
  end;

  LTypeIndex := FindType(ATypeName);
  if LTypeIndex < 0 then
  begin
    if Assigned(FErrors) then
      FErrors.Add(esError, ERR_IR_UNKNOWN_TYPE, RSIRUnknownType, [ATypeName]);
    Exit;
  end;

  LEntry := FTypes[FBuildingRoutineIndex];
  LLen := Length(LEntry.RoutineType.ParamTypes);
  SetLength(LEntry.RoutineType.ParamTypes, LLen + 1);
  LEntry.RoutineType.ParamTypes[LLen] := TTypeRef.FromComposite(LTypeIndex);
  FTypes[FBuildingRoutineIndex] := LEntry;
end;

function TIR.RoutineReturns(const AType: TValueType): TIR;
var
  LEntry: TIRTypeEntry;
begin
  Result := Self;

  if FBuildingRoutineIndex < 0 then
  begin
    if Assigned(FErrors) then
      FErrors.Add(esError, ERR_IR_TYPE_BUILD, RSIRNotBuildingRoutine);
    Exit;
  end;

  LEntry := FTypes[FBuildingRoutineIndex];
  LEntry.RoutineType.ReturnType := TTypeRef.FromPrimitive(AType);
  FTypes[FBuildingRoutineIndex] := LEntry;
end;

function TIR.RoutineReturns(const ATypeName: string): TIR;
var
  LEntry: TIRTypeEntry;
  LTypeIndex: Integer;
begin
  Result := Self;

  if FBuildingRoutineIndex < 0 then
  begin
    if Assigned(FErrors) then
      FErrors.Add(esError, ERR_IR_TYPE_BUILD, RSIRNotBuildingRoutine);
    Exit;
  end;

  LTypeIndex := FindType(ATypeName);
  if LTypeIndex < 0 then
  begin
    if Assigned(FErrors) then
      FErrors.Add(esError, ERR_IR_UNKNOWN_TYPE, RSIRUnknownType, [ATypeName]);
    Exit;
  end;

  LEntry := FTypes[FBuildingRoutineIndex];
  LEntry.RoutineType.ReturnType := TTypeRef.FromComposite(LTypeIndex);
  FTypes[FBuildingRoutineIndex] := LEntry;
end;

function TIR.RoutineVarArgs(): TIR;
var
  LEntry: TIRTypeEntry;
begin
  Result := Self;

  if FBuildingRoutineIndex < 0 then
  begin
    if Assigned(FErrors) then
      FErrors.Add(esError, ERR_IR_TYPE_BUILD, RSIRNotBuildingRoutine);
    Exit;
  end;

  LEntry := FTypes[FBuildingRoutineIndex];
  LEntry.RoutineType.IsVarArgs := True;
  FTypes[FBuildingRoutineIndex] := LEntry;
end;

function TIR.EndRoutine(): TIR;
begin
  Result := Self;

  if FBuildingRoutineIndex < 0 then
  begin
    if Assigned(FErrors) then
      FErrors.Add(esError, ERR_IR_TYPE_BUILD, RSIRNotBuildingRoutine);
    Exit;
  end;

  FBuildingRoutineIndex := -1;
end;

function TIR.DefineSet(const AName: string): TIR;
begin
  // Bare "set" is alias for set of 0..63
  Result := DefineSet(AName, 0, 63);
end;

function TIR.DefineSet(const AName: string; const ALow: Integer; const AHigh: Integer): TIR;
var
  LEntry: TIRTypeEntry;
  LSpan: Integer;
begin
  Result := Self;

  // Validate range
  if AHigh < ALow then
  begin
    if Assigned(FErrors) then
      FErrors.Add(esError, ERR_IR_TYPE_BUILD, RSIRInvalidSetRange, [ALow, AHigh]);
    Exit;
  end;

  LSpan := AHigh - ALow + 1;
  if LSpan > 64 then
  begin
    if Assigned(FErrors) then
      FErrors.Add(esError, ERR_IR_TYPE_BUILD, RSIRSetRangeTooLarge, [LSpan]);
    Exit;
  end;

  LEntry := Default(TIRTypeEntry);
  LEntry.Kind := tkSet;
  LEntry.SetType.TypeName := AName;
  LEntry.SetType.LowBound := ALow;
  LEntry.SetType.HighBound := AHigh;
  LEntry.SetType.BaseType := TTypeRef.None();

  // On x86-64, all register-sized values need 8-byte stack slots.
  // The bit masking in OpSetLiteral handles the actual bit pattern correctly.
  LEntry.SetType.StorageSize := 8;

  FTypes.Add(LEntry);
end;

function TIR.DefineSet(const AName: string; const AEnumTypeName: string): TIR;
var
  LEnumIndex: Integer;
  LEnumEntry: TIRTypeEntry;
  LMinOrd: System.Int64;
  LMaxOrd: System.Int64;
  LI: Integer;
  LEntry: TIRTypeEntry;
  LSpan: Integer;
begin
  Result := Self;

  // Find the enum type
  LEnumIndex := FindType(AEnumTypeName);
  if LEnumIndex < 0 then
  begin
    if Assigned(FErrors) then
      FErrors.Add(esError, ERR_IR_TYPE_BUILD, RSIRUnknownEnumType, [AEnumTypeName]);
    Exit;
  end;

  LEnumEntry := FTypes[LEnumIndex];
  if LEnumEntry.Kind <> tkEnum then
  begin
    if Assigned(FErrors) then
      FErrors.Add(esError, ERR_IR_TYPE_BUILD, RSIRTypeNotEnum, [AEnumTypeName]);
    Exit;
  end;

  // Find min/max ordinal values in the enum
  if Length(LEnumEntry.EnumType.Values) = 0 then
  begin
    if Assigned(FErrors) then
      FErrors.Add(esError, ERR_IR_TYPE_BUILD, RSIREnumNoValues, [AEnumTypeName]);
    Exit;
  end;

  LMinOrd := LEnumEntry.EnumType.Values[0].OrdinalValue;
  LMaxOrd := LMinOrd;
  for LI := 1 to System.High(LEnumEntry.EnumType.Values) do
  begin
    if LEnumEntry.EnumType.Values[LI].OrdinalValue < LMinOrd then
      LMinOrd := LEnumEntry.EnumType.Values[LI].OrdinalValue;
    if LEnumEntry.EnumType.Values[LI].OrdinalValue > LMaxOrd then
      LMaxOrd := LEnumEntry.EnumType.Values[LI].OrdinalValue;
  end;

  LSpan := LMaxOrd - LMinOrd + 1;
  if LSpan > 64 then
  begin
    if Assigned(FErrors) then
      FErrors.Add(esError, ERR_IR_TYPE_BUILD, RSIREnumRangeTooLarge, [LSpan]);
    Exit;
  end;

  LEntry := Default(TIRTypeEntry);
  LEntry.Kind := tkSet;
  LEntry.SetType.TypeName := AName;
  LEntry.SetType.LowBound := LMinOrd;
  LEntry.SetType.HighBound := LMaxOrd;
  LEntry.SetType.BaseType := TTypeRef.FromComposite(LEnumIndex);

  // On x86-64, all register-sized values need 8-byte stack slots.
  LEntry.SetType.StorageSize := 8;

  FTypes.Add(LEntry);
end;

function TIR.FindType(const AName: string): Integer;
var
  LI: Integer;
  LEntry: TIRTypeEntry;
begin
  for LI := 0 to FTypes.Count - 1 do
  begin
    LEntry := FTypes[LI];
    case LEntry.Kind of
      tkRecord:     if SameText(LEntry.RecordType.TypeName, AName) then Exit(LI);
      tkUnion:      if SameText(LEntry.UnionType.TypeName, AName) then Exit(LI);
      tkFixedArray: if SameText(LEntry.FixedArrayType.TypeName, AName) then Exit(LI);
      tkDynArray:   if SameText(LEntry.DynArrayType.TypeName, AName) then Exit(LI);
      tkEnum:       if SameText(LEntry.EnumType.TypeName, AName) then Exit(LI);
      tkAlias:      if SameText(LEntry.AliasType.TypeName, AName) then Exit(LI);
      tkPointer:    if SameText(LEntry.PointerType.TypeName, AName) then Exit(LI);
      tkRoutine:    if SameText(LEntry.RoutineType.TypeName, AName) then Exit(LI);
      tkSet:        if SameText(LEntry.SetType.TypeName, AName) then Exit(LI);
    end;
  end;
  Result := -1;
end;

function TIR.GetTypeSize(const ATypeRef: TTypeRef): Integer;
var
  LEntry: TIRTypeEntry;
begin
  if ATypeRef.IsPrimitive then
    Exit(GetPrimitiveSize(ATypeRef.Primitive));

  if (ATypeRef.TypeIndex < 0) or (ATypeRef.TypeIndex >= FTypes.Count) then
    Exit(0);

  LEntry := FTypes[ATypeRef.TypeIndex];
  case LEntry.Kind of
    tkRecord:
      begin
        if not LEntry.RecordType.IsFinalized then
          FinalizeRecordLayout(ATypeRef.TypeIndex);
        Result := FTypes[ATypeRef.TypeIndex].RecordType.TotalSize;
      end;
    tkUnion:
      begin
        if not LEntry.UnionType.IsFinalized then
          FinalizeUnionLayout(ATypeRef.TypeIndex);
        Result := FTypes[ATypeRef.TypeIndex].UnionType.TotalSize;
      end;
    tkFixedArray:
      Result := LEntry.FixedArrayType.TotalSize;
    tkDynArray:
      Result := 8;  // Pointer size
    tkEnum:
      Result := GetPrimitiveSize(LEntry.EnumType.BaseType);
    tkAlias:
      Result := GetTypeSize(LEntry.AliasType.AliasedType);
    tkPointer:
      Result := 8;  // Pointer size on Win64
    tkRoutine:
      Result := 8;  // Function pointer size on Win64
    tkSet:
      Result := LEntry.SetType.StorageSize;
  else
    Result := 0;
  end;
end;

function TIR.GetTypeAlignment(const ATypeRef: TTypeRef): Integer;
var
  LEntry: TIRTypeEntry;
begin
  if ATypeRef.IsPrimitive then
    Exit(GetPrimitiveAlignment(ATypeRef.Primitive));

  if (ATypeRef.TypeIndex < 0) or (ATypeRef.TypeIndex >= FTypes.Count) then
    Exit(1);

  LEntry := FTypes[ATypeRef.TypeIndex];
  case LEntry.Kind of
    tkRecord:
      begin
        if not LEntry.RecordType.IsFinalized then
          FinalizeRecordLayout(ATypeRef.TypeIndex);
        Result := FTypes[ATypeRef.TypeIndex].RecordType.Alignment;
      end;
    tkUnion:
      begin
        if not LEntry.UnionType.IsFinalized then
          FinalizeUnionLayout(ATypeRef.TypeIndex);
        Result := FTypes[ATypeRef.TypeIndex].UnionType.Alignment;
      end;
    tkFixedArray:
      Result := GetTypeAlignment(LEntry.FixedArrayType.ElementType);
    tkDynArray:
      Result := 8;  // Pointer alignment
    tkEnum:
      Result := GetPrimitiveAlignment(LEntry.EnumType.BaseType);
    tkAlias:
      Result := GetTypeAlignment(LEntry.AliasType.AliasedType);
    tkPointer:
      Result := 8;  // Pointer alignment on Win64
    tkRoutine:
      Result := 8;  // Function pointer alignment on Win64
    tkSet:
      Result := LEntry.SetType.StorageSize;  // Alignment matches storage size
  else
    Result := 1;
  end;
end;

function TIR.TypeRef(const AName: string): TTypeRef;
var
  LIndex: Integer;
begin
  LIndex := FindType(AName);
  if LIndex >= 0 then
    Result := TTypeRef.FromComposite(LIndex)
  else
    Result := TTypeRef.None();
end;

function TIR.GetTypeCount(): Integer;
begin
  Result := FTypes.Count;
end;

function TIR.GetTypeEntry(const AIndex: Integer): TIRTypeEntry;
begin
  Result := FTypes[AIndex];
end;

function TIR.IsStringType(const ATypeRef: TTypeRef): Boolean;
var
  LEntry: TIRTypeEntry;
  LTypeName: string;
begin
  Result := False;

  // Primitives are never string types
  if ATypeRef.IsPrimitive then
    Exit;

  // Check composite type
  if (ATypeRef.TypeIndex < 0) or (ATypeRef.TypeIndex >= FTypes.Count) then
    Exit;

  LEntry := FTypes[ATypeRef.TypeIndex];

  // Get the type name based on kind
  case LEntry.Kind of
    TIRTypeKind.tkRecord:
      LTypeName := LEntry.RecordType.TypeName;
    TIRTypeKind.tkPointer:
      LTypeName := LEntry.PointerType.TypeName;
    TIRTypeKind.tkAlias:
      begin
        LTypeName := LEntry.AliasType.TypeName;
        // Also check if aliased type is string
        if not SameText(LTypeName, 'string') then
          Result := IsStringType(LEntry.AliasType.AliasedType);
        Exit;
      end;
  else
    Exit;
  end;

  Result := SameText(LTypeName, 'string');
end;

function TIR.IsWStringType(const ATypeRef: TTypeRef): Boolean;
var
  LEntry: TIRTypeEntry;
  LTypeName: string;
begin
  Result := False;

  // Primitives are never wstring types
  if ATypeRef.IsPrimitive then
    Exit;

  // Check composite type
  if (ATypeRef.TypeIndex < 0) or (ATypeRef.TypeIndex >= FTypes.Count) then
    Exit;

  LEntry := FTypes[ATypeRef.TypeIndex];

  // Get the type name based on kind
  case LEntry.Kind of
    TIRTypeKind.tkRecord:
      LTypeName := LEntry.RecordType.TypeName;
    TIRTypeKind.tkPointer:
      LTypeName := LEntry.PointerType.TypeName;
    TIRTypeKind.tkAlias:
      begin
        LTypeName := LEntry.AliasType.TypeName;
        if not SameText(LTypeName, 'wstring') then
          Result := IsWStringType(LEntry.AliasType.AliasedType);
        Exit;
      end;
  else
    Exit;
  end;

  Result := SameText(LTypeName, 'wstring');
end;

function TIR.IsManagedType(const ATypeRef: TTypeRef): Boolean;
var
  LEntry: TIRTypeEntry;
  LI: Integer;
begin
  // A managed type is any type that contains string references and thus
  // requires cleanup (release) when going out of scope.

  // Check if it's directly a string type
  if IsStringType(ATypeRef) then
    Exit(True);

  // Check if it's directly a wstring type (raw PWideChar, needs FreeMem)
  if IsWStringType(ATypeRef) then
    Exit(True);

  Result := False;

  // Primitives are never managed (strings are handled above via IsStringType)
  if ATypeRef.IsPrimitive then
    Exit;

  if (ATypeRef.TypeIndex < 0) or (ATypeRef.TypeIndex >= FTypes.Count) then
    Exit;

  LEntry := FTypes[ATypeRef.TypeIndex];

  case LEntry.Kind of
    tkFixedArray:
      // Array is managed if its element type is managed
      Result := IsManagedType(LEntry.FixedArrayType.ElementType);

    tkDynArray:
      // Dynamic arrays are always managed (the pointer itself needs freeing,
      // and elements may contain strings)
      Result := True;

    tkRecord:
      begin
        // Record is managed if any field is managed
        for LI := 0 to System.High(LEntry.RecordType.Fields) do
        begin
          if IsManagedType(LEntry.RecordType.Fields[LI].FieldType) then
            Exit(True);
        end;
      end;

    tkUnion:
      begin
        // Union is managed if any variant is managed
        for LI := 0 to System.High(LEntry.UnionType.Fields) do
        begin
          if IsManagedType(LEntry.UnionType.Fields[LI].FieldType) then
            Exit(True);
        end;
      end;

    tkAlias:
      Result := IsManagedType(LEntry.AliasType.AliasedType);
  end;
end;

//==============================================================================
// TIR - Import
//==============================================================================

function TIR.Import(
  const ADllName: string;
  const AFuncName: string;
  const AParams: array of TValueType;
  const AReturn: TValueType;
  const AVarArgs: Boolean;
  const ALinkage: TLinkage
): TIR;
var
  LImport: TIRImport;
  LI: Integer;
  LJ: Integer;
  LMatch: Boolean;
begin
  Result := Self;

  // Check for duplicate - skip if already imported
  // Must compare param types too (overloaded imports have same name)
  for LI := 0 to FImports.Count - 1 do
  begin
    if SameText(FImports[LI].DllName, ADllName) and
       SameText(FImports[LI].FuncName, AFuncName) then
    begin
      // Same name — check if param signature also matches
      if Length(FImports[LI].ParamTypes) = Length(AParams) then
      begin
        LMatch := True;
        for LJ := 0 to Length(AParams) - 1 do
        begin
          if FImports[LI].ParamTypes[LJ] <> AParams[LJ] then
          begin
            LMatch := False;
            Break;
          end;
        end;
        if LMatch then
          Exit;  // Exact duplicate — skip
      end;
      // Same name but different params — not a duplicate, continue
    end;
  end;

  LImport := Default(TIRImport);
  LImport.DllName := ADllName;
  LImport.FuncName := AFuncName;
  LImport.ReturnType := AReturn;
  LImport.IsVarArgs := AVarArgs;
  LImport.Linkage := ALinkage;

  SetLength(LImport.ParamTypes, Length(AParams));
  for LI := 0 to System.High(AParams) do
    LImport.ParamTypes[LI] := AParams[LI];

  FImports.Add(LImport);
end;

function TIR.ImportLib(
  const ALibName: string;
  const AFuncName: string;
  const AParams: array of TValueType;
  const AReturn: TValueType;
  const AVarArgs: Boolean;
  const ALinkage: TLinkage
): TIR;
var
  LImport: TIRImport;
  LI: Integer;
  LJ: Integer;
  LMatch: Boolean;
begin
  Result := Self;

  // Check for duplicate - skip if already imported
  // Must compare param types too, not just name (overloaded imports have same name)
  for LI := 0 to FImports.Count - 1 do
  begin
    if FImports[LI].IsStatic and
       SameText(FImports[LI].DllName, ALibName) and
       SameText(FImports[LI].FuncName, AFuncName) then
    begin
      // Same name — check if param signature also matches
      if Length(FImports[LI].ParamTypes) = Length(AParams) then
      begin
        LMatch := True;
        for LJ := 0 to Length(AParams) - 1 do
        begin
          if FImports[LI].ParamTypes[LJ] <> AParams[LJ] then
          begin
            LMatch := False;
            Break;
          end;
        end;
        if LMatch then
          Exit;  // Exact duplicate — skip
      end;
      // Same name but different params — not a duplicate, continue
    end;
  end;

  LImport := Default(TIRImport);
  LImport.DllName := ALibName;
  LImport.FuncName := AFuncName;
  LImport.ReturnType := AReturn;
  LImport.IsVarArgs := AVarArgs;
  LImport.IsStatic := True;
  LImport.Linkage := ALinkage;

  SetLength(LImport.ParamTypes, Length(AParams));
  for LI := 0 to System.High(AParams) do
    LImport.ParamTypes[LI] := AParams[LI];

  FImports.Add(LImport);
end;

function TIR.ImportHost(
  const AFuncName: string;
  const AHostAddr: Pointer;
  const AParams: array of TValueType;
  const AReturn: TValueType
): TIR;
var
  LImport: TIRImport;
  LI: Integer;
begin
  Result := Self;

  LImport := Default(TIRImport);
  LImport.DllName := '';
  LImport.FuncName := AFuncName;
  LImport.ReturnType := AReturn;
  LImport.IsVarArgs := False;
  LImport.IsStatic := False;
  LImport.Linkage := plC;
  LImport.HostAddr := AHostAddr;

  SetLength(LImport.ParamTypes, Length(AParams));
  for LI := 0 to System.High(AParams) do
    LImport.ParamTypes[LI] := AParams[LI];

  FImports.Add(LImport);
end;

//==============================================================================
// TIR - Global Variables
//==============================================================================

function TIR.Global(const AName: string; const AType: TValueType; const AIsPublic: Boolean): TIR;
var
  LGlobal: TIRGlobal;
begin
  LGlobal := Default(TIRGlobal);
  LGlobal.GlobalName := AName;
  LGlobal.GlobalType := AType;
  LGlobal.GlobalTypeRef := TTypeRef.FromPrimitive(AType);
  LGlobal.InitExpr := -1;  // Uninitialized
  LGlobal.IsPublic := AIsPublic;

  FGlobals.Add(LGlobal);
  Result := Self;
end;

function TIR.Global(const AName: string; const AType: TValueType; const AInit: TIRExpr; const AIsPublic: Boolean): TIR;
var
  LGlobal: TIRGlobal;
begin
  LGlobal := Default(TIRGlobal);
  LGlobal.GlobalName := AName;
  LGlobal.GlobalType := AType;
  LGlobal.GlobalTypeRef := TTypeRef.FromPrimitive(AType);
  LGlobal.InitExpr := AInit.Index;
  LGlobal.IsPublic := AIsPublic;

  FGlobals.Add(LGlobal);
  Result := Self;
end;

function TIR.Global(const AName: string; const ATypeRef: TTypeRef; const AIsPublic: Boolean): TIR;
var
  LGlobal: TIRGlobal;
begin
  LGlobal := Default(TIRGlobal);
  LGlobal.GlobalName := AName;
  LGlobal.GlobalType := vtPointer;  // Managed types are pointers
  LGlobal.GlobalTypeRef := ATypeRef;
  LGlobal.InitExpr := -1;  // Uninitialized
  LGlobal.IsPublic := AIsPublic;

  FGlobals.Add(LGlobal);
  Result := Self;
end;

function TIR.Global(const AName: string; const ATypeName: string; const AIsPublic: Boolean): TIR;
var
  LGlobal: TIRGlobal;
  LTypeIndex: Integer;
begin
  Result := Self;

  LTypeIndex := FindType(ATypeName);
  if LTypeIndex < 0 then
  begin
    if Assigned(FErrors) then
      FErrors.Add(esError, ERR_IR_UNKNOWN_TYPE, RSIRUnknownType, [ATypeName]);
    Exit;
  end;

  LGlobal := Default(TIRGlobal);
  LGlobal.GlobalName := AName;
  LGlobal.GlobalType := vtPointer;  // Managed/composite types are pointers
  LGlobal.GlobalTypeRef := TTypeRef.FromComposite(LTypeIndex);
  LGlobal.InitExpr := -1;  // Uninitialized
  LGlobal.IsPublic := AIsPublic;

  FGlobals.Add(LGlobal);
end;

//==============================================================================
// TIR - Function Definition
//==============================================================================

function TIR.Func(
  const AName: string;
  const AReturnType: TValueType;
  const AIsEntryPoint: Boolean;
  const ALinkage: TLinkage;
  const AIsPublic: Boolean
): TIR;
var
  LFunc: TIRFunc;
begin
  LFunc := Default(TIRFunc);
  LFunc.FuncName := AName;
  LFunc.ReturnType := AReturnType;
  LFunc.IsEntryPoint := AIsEntryPoint;
  LFunc.IsDllEntry := False;
  LFunc.IsPublic := AIsPublic;
  LFunc.Linkage := ALinkage;
  LFunc.IsVariadic := False;
  LFunc.Vars := TList<TIRVar>.Create();
  LFunc.Stmts := TList<TIRStmt>.Create();

  FCurrentFunc := FFunctions.Count;
  FFunctions.Add(LFunc);
  Result := Self;
end;

function TIR.OverloadFunc(
  const AName: string;
  const AReturnType: TValueType;
  const AIsEntryPoint: Boolean;
  const AIsPublic: Boolean
): TIR;
var
  LFunc: TIRFunc;
  LI: Integer;
begin
  Result := Self;

  // Validate: existing function(s) with same name must not have C linkage
  for LI := 0 to FFunctions.Count - 1 do
  begin
    if SameText(FFunctions[LI].FuncName, AName) then
    begin
      if FFunctions[LI].Linkage = plC then
      begin
        if Assigned(FErrors) then
          FErrors.Add(esError, ERR_IR_OVERLOAD_C_LINKAGE,
            RSIROverloadCLinkage, [AName]);
        Exit;
      end;
    end;
  end;

  // Create function with forced C++ linkage
  LFunc := Default(TIRFunc);
  LFunc.FuncName := AName;
  LFunc.ReturnType := AReturnType;
  LFunc.IsEntryPoint := AIsEntryPoint;
  LFunc.IsDllEntry := False;
  LFunc.IsPublic := AIsPublic;
  LFunc.Linkage := plDefault;  // C++ linkage - forced, no parameter
  LFunc.IsVariadic := False;
  LFunc.Vars := TList<TIRVar>.Create();
  LFunc.Stmts := TList<TIRStmt>.Create();

  FCurrentFunc := FFunctions.Count;
  FFunctions.Add(LFunc);
end;

function TIR.VariadicFunc(
  const AName: string;
  const AReturnType: TValueType;
  const AIsEntryPoint: Boolean;
  const AIsPublic: Boolean
): TIR;
var
  LFunc: TIRFunc;
  LI: Integer;
begin
  Result := Self;

  // Validate: no existing function with same name (variadics cannot be overloaded)
  for LI := 0 to FFunctions.Count - 1 do
  begin
    if SameText(FFunctions[LI].FuncName, AName) then
    begin
      if Assigned(FErrors) then
        FErrors.Add(esError, ERR_IR_VARIADIC_OVERLOAD,
            RSIRVariadicOverload, [AName]);
      Exit;
    end;
  end;

  // Create variadic function
  LFunc := Default(TIRFunc);
  LFunc.FuncName := AName;
  LFunc.ReturnType := AReturnType;
  LFunc.IsEntryPoint := AIsEntryPoint;
  LFunc.IsDllEntry := False;
  LFunc.IsPublic := AIsPublic;
  LFunc.Linkage := plC;  // Variadic uses C-style linkage (no mangling)
  LFunc.IsVariadic := True;
  LFunc.Vars := TList<TIRVar>.Create();
  LFunc.Stmts := TList<TIRStmt>.Create();

  FCurrentFunc := FFunctions.Count;
  FFunctions.Add(LFunc);
end;

function TIR.DllMain(): TIR;
var
  LFunc: TIRFunc;
begin
  // DllMain signature: (HINSTANCE, DWORD, LPVOID) -> BOOL
  // In our types: (vtPointer, vtUInt32, vtPointer) -> vtInt32
  LFunc := Default(TIRFunc);
  LFunc.FuncName := 'DllMain';
  LFunc.ReturnType := vtInt32;  // BOOL
  LFunc.IsEntryPoint := False;  // Not the EXE entry point
  LFunc.IsDllEntry := True;     // This IS the DLL entry point
  LFunc.IsPublic := False;      // Not exported (OS calls it directly)
  LFunc.Linkage := plC;         // C linkage
  LFunc.IsVariadic := False;
  LFunc.Vars := TList<TIRVar>.Create();
  LFunc.Stmts := TList<TIRStmt>.Create();

  FCurrentFunc := FFunctions.Count;
  FFunctions.Add(LFunc);

  // Add standard DllMain parameters
  Param('hinstDLL', vtPointer);   // HINSTANCE
  Param('fdwReason', vtUInt32);   // DWORD
  Param('lpvReserved', vtPointer); // LPVOID

  Result := Self;
end;

function TIR.Param(const AName: string; const AType: TValueType; const AByRef: Boolean): TIR;
var
  LVar: TIRVar;
  LFunc: TIRFunc;
  LLen: Integer;
begin
  LFunc := GetCurrentFunc();

  LVar := Default(TIRVar);
  LVar.VarName := AName;
  LVar.VarTypeRef := TTypeRef.FromPrimitive(AType);
  LVar.IsParam := True;
  LVar.IsByRef := AByRef;

  LFunc.Vars.Add(LVar);

  // Track param types for mangling
  LLen := Length(LFunc.ParamTypes);
  SetLength(LFunc.ParamTypes, LLen + 1);
  LFunc.ParamTypes[LLen] := AType;

  FFunctions[FCurrentFunc] := LFunc;
  Result := Self;
end;

function TIR.Param(const AName: string; const ATypeName: string; const AByRef: Boolean): TIR;
var
  LVar: TIRVar;
  LFunc: TIRFunc;
  LTypeIndex: Integer;
begin
  Result := Self;
  LFunc := GetCurrentFunc();

  LTypeIndex := FindType(ATypeName);
  if LTypeIndex < 0 then
  begin
    if Assigned(FErrors) then
      FErrors.Add(esError, ERR_IR_UNKNOWN_TYPE, RSIRUnknownType, [ATypeName]);
    Exit;
  end;

  LVar := Default(TIRVar);
  LVar.VarName := AName;
  LVar.VarTypeRef := TTypeRef.FromComposite(LTypeIndex);
  LVar.IsParam := True;
  LVar.IsByRef := AByRef;

  LFunc.Vars.Add(LVar);
  FFunctions[FCurrentFunc] := LFunc;
end;

function TIR.Returns(const ATypeName: string): TIR;
var
  LFunc: TIRFunc;
  LTypeIndex: Integer;
begin
  Result := Self;
  LFunc := GetCurrentFunc();

  LTypeIndex := FindType(ATypeName);
  if LTypeIndex < 0 then
  begin
    if Assigned(FErrors) then
      FErrors.Add(esError, ERR_IR_UNKNOWN_TYPE, RSIRUnknownType, [ATypeName]);
    Exit;
  end;

  // Set return type to pointer (large structs are returned via hidden pointer)
  LFunc.ReturnType := vtPointer;
  LFunc.ReturnSize := GetTypeSize(TTypeRef.FromComposite(LTypeIndex));
  LFunc.ReturnAlignment := GetTypeAlignment(TTypeRef.FromComposite(LTypeIndex));
  FFunctions[FCurrentFunc] := LFunc;
end;

function TIR.Local(const AName: string; const AType: TValueType): TIR;
var
  LVar: TIRVar;
  LFunc: TIRFunc;
begin
  LFunc := GetCurrentFunc();

  LVar := Default(TIRVar);
  LVar.VarName := AName;
  LVar.VarTypeRef := TTypeRef.FromPrimitive(AType);
  LVar.IsParam := False;

  LFunc.Vars.Add(LVar);
  FFunctions[FCurrentFunc] := LFunc;
  Result := Self;
end;

function TIR.Local(const AName: string; const ATypeName: string): TIR;
var
  LVar: TIRVar;
  LFunc: TIRFunc;
  LTypeIndex: Integer;
begin
  Result := Self;
  LFunc := GetCurrentFunc();

  LTypeIndex := FindType(ATypeName);
  if LTypeIndex < 0 then
  begin
    if Assigned(FErrors) then
      FErrors.Add(esError, ERR_IR_UNKNOWN_TYPE, RSIRUnknownType, [ATypeName]);
    Exit;
  end;

  LVar := Default(TIRVar);
  LVar.VarName := AName;
  LVar.VarTypeRef := TTypeRef.FromComposite(LTypeIndex);
  LVar.IsParam := False;

  LFunc.Vars.Add(LVar);
  FFunctions[FCurrentFunc] := LFunc;
end;

function TIR.EndFunc(): TIR;
var
  LFunc: TIRFunc;
  LNeedsReturn: Boolean;
begin
  // Ensure function has a return statement at the end
  LFunc := GetCurrentFunc();
  LNeedsReturn := True;
  if LFunc.Stmts.Count > 0 then
  begin
    if LFunc.Stmts[LFunc.Stmts.Count - 1].Kind in [skReturn, skReturnValue] then
      LNeedsReturn := False;
  end;
  if LNeedsReturn then
    Return();

  FCurrentFunc := -1;
  Result := Self;
end;

//==============================================================================
// TIR - Source Location
//==============================================================================

function TIR.SetLine(const ALine: Integer; const AColumn: Integer): TIR;
begin
  FCurrentSourceLine := ALine;
  FCurrentSourceColumn := AColumn;
  Result := Self;
end;

function TIR.SetSourceFile(const AFile: string): TIR;
begin
  FCurrentSourceFile := AFile;
  Result := Self;
end;

//==============================================================================
// TIR - Statements
//==============================================================================

function TIR.Assign(const ADest: string; const AValue: TIRExpr): TIR;
var
  LStmt: TIRStmt;
  LFunc: TIRFunc;
begin
  LFunc := GetCurrentFunc();

  LStmt := Default(TIRStmt);
  LStmt.Kind := skAssign;
  LStmt.DestVar := ADest;
  LStmt.DestExpr := -1;  // Not using expression destination
  LStmt.Expr := AValue.Index;

  LStmt.SourceLine := FCurrentSourceLine;
  LStmt.SourceColumn := FCurrentSourceColumn;
    LStmt.SourceFile := FCurrentSourceFile;
  LFunc.Stmts.Add(LStmt);
  FFunctions[FCurrentFunc] := LFunc;
  Result := Self;
end;

function TIR.SetVal(const ADest: TIRExpr; const AValue: TIRExpr): TIR;
var
  LStmt: TIRStmt;
  LFunc: TIRFunc;
begin
  LFunc := GetCurrentFunc();

  LStmt := Default(TIRStmt);
  LStmt.Kind := skAssign;
  LStmt.DestVar := '';
  LStmt.DestExpr := ADest.Index;  // Use expression destination (field/index)
  LStmt.Expr := AValue.Index;

  LStmt.SourceLine := FCurrentSourceLine;
  LStmt.SourceColumn := FCurrentSourceColumn;
    LStmt.SourceFile := FCurrentSourceFile;
  LFunc.Stmts.Add(LStmt);
  FFunctions[FCurrentFunc] := LFunc;
  Result := Self;
end;

function TIR.Call(const AFuncName: string): TIR;
begin
  Result := Call(AFuncName, []);
end;

function TIR.Call(const AFuncName: string; const AArgs: array of TIRExpr): TIR;
var
  LStmt: TIRStmt;
  LFunc: TIRFunc;
  LI: Integer;
begin
  LFunc := GetCurrentFunc();

  LStmt := Default(TIRStmt);
  LStmt.Kind := skCall;
  LStmt.CallTarget := AFuncName;

  SetLength(LStmt.CallArgs, Length(AArgs));
  for LI := 0 to System.High(AArgs) do
    LStmt.CallArgs[LI] := AArgs[LI].Index;

  LStmt.SourceLine := FCurrentSourceLine;
  LStmt.SourceColumn := FCurrentSourceColumn;
    LStmt.SourceFile := FCurrentSourceFile;
  LFunc.Stmts.Add(LStmt);
  FFunctions[FCurrentFunc] := LFunc;
  Result := Self;
end;

function TIR.CallAssign(const ADest: string; const AFuncName: string; const AArgs: array of TIRExpr): TIR;
var
  LCallExpr: TIRExpr;
begin
  LCallExpr := Invoke(AFuncName, AArgs);
  Result := Assign(ADest, LCallExpr);
end;

function TIR.Return(): TIR;
var
  LStmt: TIRStmt;
  LFunc: TIRFunc;
begin
  LFunc := GetCurrentFunc();

  LStmt := Default(TIRStmt);
  LStmt.Kind := skReturn;

  LStmt.SourceLine := FCurrentSourceLine;
  LStmt.SourceColumn := FCurrentSourceColumn;
    LStmt.SourceFile := FCurrentSourceFile;
  LFunc.Stmts.Add(LStmt);
  FFunctions[FCurrentFunc] := LFunc;
  Result := Self;
end;

function TIR.Return(const AValue: TIRExpr): TIR;
var
  LStmt: TIRStmt;
  LFunc: TIRFunc;
begin
  LFunc := GetCurrentFunc();

  LStmt := Default(TIRStmt);
  LStmt.Kind := skReturnValue;
  LStmt.Expr := AValue.Index;

  LStmt.SourceLine := FCurrentSourceLine;
  LStmt.SourceColumn := FCurrentSourceColumn;
    LStmt.SourceFile := FCurrentSourceFile;
  LFunc.Stmts.Add(LStmt);
  FFunctions[FCurrentFunc] := LFunc;
  Result := Self;
end;

//------------------------------------------------------------------------------
// Short aliases
//------------------------------------------------------------------------------

function TIR.Let(const ADest: string; const AValue: TIRExpr): TIR;
begin
  Result := Assign(ADest, AValue);
end;

function TIR.VarDecl(const AName: string; const AType: TValueType): TIR;
begin
  Result := Local(AName, AType);
end;

function TIR.VarDecl(const AName: string; const ATypeName: string): TIR;
begin
  Result := Local(AName, ATypeName);
end;

function TIR.Ret(): TIR;
begin
  Result := Return();
end;

function TIR.Ret(const AValue: TIRExpr): TIR;
begin
  Result := Return(AValue);
end;

function TIR.CallIndirect(const AFuncPtr: TIRExpr): TIR;
begin
  Result := CallIndirect(AFuncPtr, []);
end;

function TIR.CallIndirect(const AFuncPtr: TIRExpr; const AArgs: array of TIRExpr): TIR;
var
  LStmt: TIRStmt;
  LFunc: TIRFunc;
  LI: Integer;
begin
  LFunc := GetCurrentFunc();

  LStmt := Default(TIRStmt);
  LStmt.Kind := skCallIndirect;
  LStmt.IndirectTarget := AFuncPtr.Index;

  SetLength(LStmt.CallArgs, Length(AArgs));
  for LI := 0 to System.High(AArgs) do
    LStmt.CallArgs[LI] := AArgs[LI].Index;

  LStmt.SourceLine := FCurrentSourceLine;
  LStmt.SourceColumn := FCurrentSourceColumn;
    LStmt.SourceFile := FCurrentSourceFile;
  LFunc.Stmts.Add(LStmt);
  FFunctions[FCurrentFunc] := LFunc;
  Result := Self;
end;

function TIR.CallIndirectAssign(const ADest: string; const AFuncPtr: TIRExpr;
  const AArgs: array of TIRExpr): TIR;
var
  LCallExpr: TIRExpr;
begin
  LCallExpr := InvokeIndirect(AFuncPtr, AArgs);
  Result := Assign(ADest, LCallExpr);
end;

//==============================================================================
// TIR - Control Flow
//==============================================================================

function TIR.When(const ACond: TIRExpr): TIR;
var
  LStmt: TIRStmt;
  LFunc: TIRFunc;
begin
  LFunc := GetCurrentFunc();

  LStmt := Default(TIRStmt);
  LStmt.Kind := skWhenBegin;
  LStmt.Expr := ACond.Index;

  LStmt.SourceLine := FCurrentSourceLine;
  LStmt.SourceColumn := FCurrentSourceColumn;
    LStmt.SourceFile := FCurrentSourceFile;
  LFunc.Stmts.Add(LStmt);
  FFunctions[FCurrentFunc] := LFunc;
  Result := Self;
end;

function TIR.Otherwise(): TIR;
var
  LStmt: TIRStmt;
  LFunc: TIRFunc;
begin
  LFunc := GetCurrentFunc();

  LStmt := Default(TIRStmt);
  LStmt.Kind := skOtherwiseBegin;

  LStmt.SourceLine := FCurrentSourceLine;
  LStmt.SourceColumn := FCurrentSourceColumn;
    LStmt.SourceFile := FCurrentSourceFile;
  LFunc.Stmts.Add(LStmt);
  FFunctions[FCurrentFunc] := LFunc;
  Result := Self;
end;

function TIR.EndWhen(): TIR;
var
  LStmt: TIRStmt;
  LFunc: TIRFunc;
begin
  LFunc := GetCurrentFunc();

  LStmt := Default(TIRStmt);
  LStmt.Kind := skWhenEnd;

  LStmt.SourceLine := FCurrentSourceLine;
  LStmt.SourceColumn := FCurrentSourceColumn;
    LStmt.SourceFile := FCurrentSourceFile;
  LFunc.Stmts.Add(LStmt);
  FFunctions[FCurrentFunc] := LFunc;
  Result := Self;
end;

function TIR.Loop(const ACond: TIRExpr): TIR;
var
  LStmt: TIRStmt;
  LFunc: TIRFunc;
begin
  LFunc := GetCurrentFunc();

  LStmt := Default(TIRStmt);
  LStmt.Kind := skLoopBegin;
  LStmt.Expr := ACond.Index;

  LStmt.SourceLine := FCurrentSourceLine;
  LStmt.SourceColumn := FCurrentSourceColumn;
    LStmt.SourceFile := FCurrentSourceFile;
  LFunc.Stmts.Add(LStmt);
  FFunctions[FCurrentFunc] := LFunc;
  Result := Self;
end;

function TIR.EndLoop(): TIR;
var
  LStmt: TIRStmt;
  LFunc: TIRFunc;
begin
  LFunc := GetCurrentFunc();

  LStmt := Default(TIRStmt);
  LStmt.Kind := skLoopEnd;

  LStmt.SourceLine := FCurrentSourceLine;
  LStmt.SourceColumn := FCurrentSourceColumn;
    LStmt.SourceFile := FCurrentSourceFile;
  LFunc.Stmts.Add(LStmt);
  FFunctions[FCurrentFunc] := LFunc;
  Result := Self;
end;

function TIR.LoopBreak(): TIR;
var
  LStmt: TIRStmt;
  LFunc: TIRFunc;
begin
  LFunc := GetCurrentFunc();

  LStmt := Default(TIRStmt);
  LStmt.Kind := skLoopBreak;

  LStmt.SourceLine := FCurrentSourceLine;
  LStmt.SourceColumn := FCurrentSourceColumn;
    LStmt.SourceFile := FCurrentSourceFile;
  LFunc.Stmts.Add(LStmt);
  FFunctions[FCurrentFunc] := LFunc;
  Result := Self;
end;

function TIR.LoopContinue(): TIR;
var
  LStmt: TIRStmt;
  LFunc: TIRFunc;
begin
  LFunc := GetCurrentFunc();

  LStmt := Default(TIRStmt);
  LStmt.Kind := skLoopContinue;

  LStmt.SourceLine := FCurrentSourceLine;
  LStmt.SourceColumn := FCurrentSourceColumn;
    LStmt.SourceFile := FCurrentSourceFile;
  LFunc.Stmts.Add(LStmt);
  FFunctions[FCurrentFunc] := LFunc;
  Result := Self;
end;

function TIR.Count(const AVar: string; const AFrom: TIRExpr; const ATo: TIRExpr): TIR;
var
  LStmt: TIRStmt;
  LFunc: TIRFunc;
begin
  LFunc := GetCurrentFunc();

  LStmt := Default(TIRStmt);
  LStmt.Kind := skCountBegin;
  LStmt.ForVar := AVar;
  LStmt.ForFrom := AFrom.Index;
  LStmt.ForTo := ATo.Index;
  LStmt.ForDownTo := False;

  LStmt.SourceLine := FCurrentSourceLine;
  LStmt.SourceColumn := FCurrentSourceColumn;
    LStmt.SourceFile := FCurrentSourceFile;
  LFunc.Stmts.Add(LStmt);
  FFunctions[FCurrentFunc] := LFunc;
  Result := Self;
end;

function TIR.CountDown(const AVar: string; const AFrom: TIRExpr; const ATo: TIRExpr): TIR;
var
  LStmt: TIRStmt;
  LFunc: TIRFunc;
begin
  LFunc := GetCurrentFunc();

  LStmt := Default(TIRStmt);
  LStmt.Kind := skCountBegin;
  LStmt.ForVar := AVar;
  LStmt.ForFrom := AFrom.Index;
  LStmt.ForTo := ATo.Index;
  LStmt.ForDownTo := True;

  LStmt.SourceLine := FCurrentSourceLine;
  LStmt.SourceColumn := FCurrentSourceColumn;
    LStmt.SourceFile := FCurrentSourceFile;
  LFunc.Stmts.Add(LStmt);
  FFunctions[FCurrentFunc] := LFunc;
  Result := Self;
end;

function TIR.EndCount(): TIR;
var
  LStmt: TIRStmt;
  LFunc: TIRFunc;
begin
  LFunc := GetCurrentFunc();

  LStmt := Default(TIRStmt);
  LStmt.Kind := skCountEnd;

  LStmt.SourceLine := FCurrentSourceLine;
  LStmt.SourceColumn := FCurrentSourceColumn;
    LStmt.SourceFile := FCurrentSourceFile;
  LFunc.Stmts.Add(LStmt);
  FFunctions[FCurrentFunc] := LFunc;
  Result := Self;
end;

function TIR.DoRepeat(): TIR;
var
  LStmt: TIRStmt;
  LFunc: TIRFunc;
begin
  LFunc := GetCurrentFunc();

  LStmt := Default(TIRStmt);
  LStmt.Kind := skDoRepeatBegin;

  LStmt.SourceLine := FCurrentSourceLine;
  LStmt.SourceColumn := FCurrentSourceColumn;
    LStmt.SourceFile := FCurrentSourceFile;
  LFunc.Stmts.Add(LStmt);
  FFunctions[FCurrentFunc] := LFunc;
  Result := Self;
end;

function TIR.StopWhen(const ACond: TIRExpr): TIR;
var
  LStmt: TIRStmt;
  LFunc: TIRFunc;
begin
  LFunc := GetCurrentFunc();

  LStmt := Default(TIRStmt);
  LStmt.Kind := skDoRepeatEnd;
  LStmt.Expr := ACond.Index;

  LStmt.SourceLine := FCurrentSourceLine;
  LStmt.SourceColumn := FCurrentSourceColumn;
    LStmt.SourceFile := FCurrentSourceFile;
  LFunc.Stmts.Add(LStmt);
  FFunctions[FCurrentFunc] := LFunc;
  Result := Self;
end;

//==============================================================================
// TIR - Case Statement
//==============================================================================

function TIR.Match(const ASelector: TIRExpr): TIR;
var
  LStmt: TIRStmt;
  LFunc: TIRFunc;
begin
  LFunc := GetCurrentFunc();

  LStmt := Default(TIRStmt);
  LStmt.Kind := skMatchBegin;
  LStmt.Expr := ASelector.Index;

  LStmt.SourceLine := FCurrentSourceLine;
  LStmt.SourceColumn := FCurrentSourceColumn;
    LStmt.SourceFile := FCurrentSourceFile;
  LFunc.Stmts.Add(LStmt);
  FFunctions[FCurrentFunc] := LFunc;
  Result := Self;
end;

function TIR.On(const AValues: array of TIRExpr): TIR;
var
  LStmt: TIRStmt;
  LFunc: TIRFunc;
  LI: Integer;
  LExpr: TIRExprNode;
begin
  LFunc := GetCurrentFunc();

  LStmt := Default(TIRStmt);
  LStmt.Kind := skOn;

  // Extract constant values from expressions
  SetLength(LStmt.CaseValues, Length(AValues));
  for LI := 0 to System.High(AValues) do
  begin
    if (AValues[LI].Index >= 0) and (AValues[LI].Index < FExpressions.Count) then
    begin
      LExpr := FExpressions[AValues[LI].Index];
      if LExpr.Kind = ekConstInt then
        LStmt.CaseValues[LI] := LExpr.ConstInt
      else
        LStmt.CaseValues[LI] := 0;  // Non-constant expression - error case
    end
    else
      LStmt.CaseValues[LI] := 0;
  end;

  LStmt.SourceLine := FCurrentSourceLine;
  LStmt.SourceColumn := FCurrentSourceColumn;
    LStmt.SourceFile := FCurrentSourceFile;
  LFunc.Stmts.Add(LStmt);
  FFunctions[FCurrentFunc] := LFunc;
  Result := Self;
end;

function TIR.On(const AValues: array of Integer): TIR;
var
  LStmt: TIRStmt;
  LFunc: TIRFunc;
  LI: Integer;
begin
  LFunc := GetCurrentFunc();

  LStmt := Default(TIRStmt);
  LStmt.Kind := skOn;

  // Store raw integer values directly (these are case match values, not expression indices)
  SetLength(LStmt.CaseValues, Length(AValues));
  for LI := 0 to System.High(AValues) do
    LStmt.CaseValues[LI] := AValues[LI];

  LStmt.SourceLine := FCurrentSourceLine;
  LStmt.SourceColumn := FCurrentSourceColumn;
    LStmt.SourceFile := FCurrentSourceFile;
  LFunc.Stmts.Add(LStmt);
  FFunctions[FCurrentFunc] := LFunc;
  Result := Self;
end;

function TIR.OnElse(): TIR;
var
  LStmt: TIRStmt;
  LFunc: TIRFunc;
begin
  LFunc := GetCurrentFunc();

  LStmt := Default(TIRStmt);
  LStmt.Kind := skOnElse;

  LStmt.SourceLine := FCurrentSourceLine;
  LStmt.SourceColumn := FCurrentSourceColumn;
    LStmt.SourceFile := FCurrentSourceFile;
  LFunc.Stmts.Add(LStmt);
  FFunctions[FCurrentFunc] := LFunc;
  Result := Self;
end;

function TIR.EndMatch(): TIR;
var
  LStmt: TIRStmt;
  LFunc: TIRFunc;
begin
  LFunc := GetCurrentFunc();

  LStmt := Default(TIRStmt);
  LStmt.Kind := skMatchEnd;

  LStmt.SourceLine := FCurrentSourceLine;
  LStmt.SourceColumn := FCurrentSourceColumn;
    LStmt.SourceFile := FCurrentSourceFile;
  LFunc.Stmts.Add(LStmt);
  FFunctions[FCurrentFunc] := LFunc;
  Result := Self;
end;

function TIR.Guard(): TIR;
var
  LStmt: TIRStmt;
  LFunc: TIRFunc;
begin
  LFunc := GetCurrentFunc();

  LStmt := Default(TIRStmt);
  LStmt.Kind := skGuardBegin;

  LStmt.SourceLine := FCurrentSourceLine;
  LStmt.SourceColumn := FCurrentSourceColumn;
    LStmt.SourceFile := FCurrentSourceFile;
  LFunc.Stmts.Add(LStmt);
  FFunctions[FCurrentFunc] := LFunc;
  Result := Self;
end;

function TIR.Catch(): TIR;
var
  LStmt: TIRStmt;
  LFunc: TIRFunc;
begin
  LFunc := GetCurrentFunc();

  LStmt := Default(TIRStmt);
  LStmt.Kind := skCatchBegin;

  LStmt.SourceLine := FCurrentSourceLine;
  LStmt.SourceColumn := FCurrentSourceColumn;
    LStmt.SourceFile := FCurrentSourceFile;
  LFunc.Stmts.Add(LStmt);
  FFunctions[FCurrentFunc] := LFunc;
  Result := Self;
end;

function TIR.Ensure(): TIR;
var
  LStmt: TIRStmt;
  LFunc: TIRFunc;
begin
  LFunc := GetCurrentFunc();

  LStmt := Default(TIRStmt);
  LStmt.Kind := skEnsureBegin;

  LStmt.SourceLine := FCurrentSourceLine;
  LStmt.SourceColumn := FCurrentSourceColumn;
    LStmt.SourceFile := FCurrentSourceFile;
  LFunc.Stmts.Add(LStmt);
  FFunctions[FCurrentFunc] := LFunc;
  Result := Self;
end;

function TIR.EndGuard(): TIR;
var
  LStmt: TIRStmt;
  LFunc: TIRFunc;
begin
  LFunc := GetCurrentFunc();

  LStmt := Default(TIRStmt);
  LStmt.Kind := skGuardEnd;

  LStmt.SourceLine := FCurrentSourceLine;
  LStmt.SourceColumn := FCurrentSourceColumn;
    LStmt.SourceFile := FCurrentSourceFile;
  LFunc.Stmts.Add(LStmt);
  FFunctions[FCurrentFunc] := LFunc;
  Result := Self;
end;

function TIR.Throw(const AMsg: TIRExpr): TIR;
var
  LStmt: TIRStmt;
  LFunc: TIRFunc;
begin
  LFunc := GetCurrentFunc();

  LStmt := Default(TIRStmt);
  LStmt.Kind := skThrow;
  LStmt.RaiseMsg := AMsg.Index;
  LStmt.RaiseCode := -1;  // No code for simple raise

  LStmt.SourceLine := FCurrentSourceLine;
  LStmt.SourceColumn := FCurrentSourceColumn;
    LStmt.SourceFile := FCurrentSourceFile;
  LFunc.Stmts.Add(LStmt);
  FFunctions[FCurrentFunc] := LFunc;
  Result := Self;
end;

function TIR.ThrowCode(const ACode: TIRExpr; const AMsg: TIRExpr): TIR;
var
  LStmt: TIRStmt;
  LFunc: TIRFunc;
begin
  LFunc := GetCurrentFunc();

  LStmt := Default(TIRStmt);
  LStmt.Kind := skThrowCode;
  LStmt.RaiseCode := ACode.Index;
  LStmt.RaiseMsg := AMsg.Index;

  LStmt.SourceLine := FCurrentSourceLine;
  LStmt.SourceColumn := FCurrentSourceColumn;
    LStmt.SourceFile := FCurrentSourceFile;
  LFunc.Stmts.Add(LStmt);
  FFunctions[FCurrentFunc] := LFunc;
  Result := Self;
end;

function TIR.Incr(const AVarName: string): TIR;
begin
  // Inc(x) = x := x + 1
  Result := Assign(AVarName, Add(Get(AVarName), MakeInt64(1)));
end;

function TIR.Incr(const AVarName: string; const AAmount: TIRExpr): TIR;
begin
  // Inc(x, n) = x := x + n
  Result := Assign(AVarName, Add(Get(AVarName), AAmount));
end;

function TIR.Decr(const AVarName: string): TIR;
begin
  // Dec(x) = x := x - 1
  Result := Assign(AVarName, Sub(Get(AVarName), MakeInt64(1)));
end;

function TIR.Decr(const AVarName: string; const AAmount: TIRExpr): TIR;
begin
  // Dec(x, n) = x := x - n
  Result := Assign(AVarName, Sub(Get(AVarName), AAmount));
end;

//==============================================================================
// TIR - Expressions: Literals
//==============================================================================

function TIR.Str(const AValue: string): TIRExpr;
var
  LNode: TIRExprNode;
  LStr: TIRString;
begin
  // Add string to table
  LStr := Default(TIRString);
  LStr.Value := AValue;
  LStr.IsWide := False;
  FStrings.Add(LStr);

  // Create expression
  LNode := Default(TIRExprNode);
  LNode.Kind := ekConstString;
  LNode.StringIndex := FStrings.Count - 1;
  Result := AddExpr(LNode);
end;

function TIR.WStr(const AValue: string): TIRExpr;
var
  LNode: TIRExprNode;
  LStr: TIRString;
begin
  // Add wide string to table
  LStr := Default(TIRString);
  LStr.Value := AValue;
  LStr.IsWide := True;
  FStrings.Add(LStr);

  // Create expression
  LNode := Default(TIRExprNode);
  LNode.Kind := ekConstString;
  LNode.StringIndex := FStrings.Count - 1;
  Result := AddExpr(LNode);
end;

function TIR.MakeInt64(const AValue: Int64): TIRExpr;
var
  LNode: TIRExprNode;
begin
  LNode := Default(TIRExprNode);
  LNode.Kind := ekConstInt;
  LNode.ConstInt := AValue;
  // Int64 literal
  LNode.ResultType := TTypeRef.FromPrimitive(vtInt64);
  Result := AddExpr(LNode);
end;

function TIR.Int32(const AValue: Int32): TIRExpr;
var
  LNode: TIRExprNode;
begin
  LNode := Default(TIRExprNode);
  LNode.Kind := ekConstInt;
  LNode.ConstInt := AValue;
  LNode.ResultType := TTypeRef.FromPrimitive(vtInt32);
  Result := AddExpr(LNode);
end;


function TIR.Float64(const AValue: Double): TIRExpr;
var
  LNode: TIRExprNode;
begin
  LNode := Default(TIRExprNode);
  LNode.Kind := ekConstFloat;
  LNode.ConstFloat := AValue;
  LNode.ResultType := TTypeRef.FromPrimitive(vtFloat64);
  Result := AddExpr(LNode);
end;

function TIR.Bool(const AValue: Boolean): TIRExpr;
begin
  if AValue then
    Result := MakeInt64(1)
  else
    Result := MakeInt64(0);
end;

function TIR.Int8(const AValue: Int8): TIRExpr;
var
  LNode: TIRExprNode;
begin
  LNode := Default(TIRExprNode);
  LNode.Kind := ekConstInt;
  LNode.ConstInt := AValue;
  LNode.ResultType := TTypeRef.FromPrimitive(vtInt8);
  Result := AddExpr(LNode);
end;

function TIR.Int16(const AValue: Int16): TIRExpr;
var
  LNode: TIRExprNode;
begin
  LNode := Default(TIRExprNode);
  LNode.Kind := ekConstInt;
  LNode.ConstInt := AValue;
  LNode.ResultType := TTypeRef.FromPrimitive(vtInt16);
  Result := AddExpr(LNode);
end;

function TIR.UInt8(const AValue: UInt8): TIRExpr;
var
  LNode: TIRExprNode;
begin
  LNode := Default(TIRExprNode);
  LNode.Kind := ekConstInt;
  LNode.ConstInt := AValue;
  LNode.ResultType := TTypeRef.FromPrimitive(vtUInt8);
  Result := AddExpr(LNode);
end;

function TIR.UInt16(const AValue: UInt16): TIRExpr;
var
  LNode: TIRExprNode;
begin
  LNode := Default(TIRExprNode);
  LNode.Kind := ekConstInt;
  LNode.ConstInt := AValue;
  LNode.ResultType := TTypeRef.FromPrimitive(vtUInt16);
  Result := AddExpr(LNode);
end;

function TIR.UInt32(const AValue: UInt32): TIRExpr;
var
  LNode: TIRExprNode;
begin
  LNode := Default(TIRExprNode);
  LNode.Kind := ekConstInt;
  LNode.ConstInt := AValue;
  LNode.ResultType := TTypeRef.FromPrimitive(vtUInt32);
  Result := AddExpr(LNode);
end;

function TIR.UInt64(const AValue: UInt64): TIRExpr;
var
  LNode: TIRExprNode;
begin
  LNode := Default(TIRExprNode);
  LNode.Kind := ekConstInt;
  LNode.ConstInt := System.Int64(AValue);
  LNode.ResultType := TTypeRef.FromPrimitive(vtUInt64);
  Result := AddExpr(LNode);
end;

function TIR.Float32(const AValue: Single): TIRExpr;
var
  LNode: TIRExprNode;
begin
  LNode := Default(TIRExprNode);
  LNode.Kind := ekConstFloat;
  LNode.ConstFloat := AValue;
  LNode.ResultType := TTypeRef.FromPrimitive(vtFloat32);
  Result := AddExpr(LNode);
end;

function TIR.Null(): TIRExpr;
var
  LNode: TIRExprNode;
begin
  LNode := Default(TIRExprNode);
  LNode.Kind := ekConstInt;
  LNode.ConstInt := 0;
  LNode.ResultType := TTypeRef.FromPrimitive(vtPointer);
  Result := AddExpr(LNode);
end;

//==============================================================================
// TIR - Expressions: Variable Reference
//==============================================================================

function TIR.Get(const AName: string): TIRExpr;
var
  LNode: TIRExprNode;
begin
  LNode := Default(TIRExprNode);
  LNode.Kind := ekVariable;
  LNode.VarName := AName;
  LNode.ResultType := FindVarType(AName);  // Resolve type at creation time
  Result := AddExpr(LNode);
end;

//==============================================================================
// TIR - Expressions: Arithmetic
//==============================================================================

function TIR.Add(const ALeft: TIRExpr; const ARight: TIRExpr): TIRExpr;
begin
  Result := MakeBinaryExpr(ALeft, ARight, opAdd);
end;

function TIR.Sub(const ALeft: TIRExpr; const ARight: TIRExpr): TIRExpr;
begin
  Result := MakeBinaryExpr(ALeft, ARight, opSub);
end;

function TIR.Mul(const ALeft: TIRExpr; const ARight: TIRExpr): TIRExpr;
begin
  Result := MakeBinaryExpr(ALeft, ARight, opMul);
end;

function TIR.IDiv(const ALeft: TIRExpr; const ARight: TIRExpr): TIRExpr;
begin
  Result := MakeBinaryExpr(ALeft, ARight, opDiv);
end;

function TIR.IMod(const ALeft: TIRExpr; const ARight: TIRExpr): TIRExpr;
begin
  Result := MakeBinaryExpr(ALeft, ARight, opMod);
end;

function TIR.Neg(const AValue: TIRExpr): TIRExpr;
begin
  Result := MakeUnaryExpr(AValue, opNeg);
end;

function TIR.FAdd(const ALeft: TIRExpr; const ARight: TIRExpr): TIRExpr;
begin
  Result := MakeBinaryExpr(ALeft, ARight, opFAdd);
end;

function TIR.FSub(const ALeft: TIRExpr; const ARight: TIRExpr): TIRExpr;
begin
  Result := MakeBinaryExpr(ALeft, ARight, opFSub);
end;

function TIR.FMul(const ALeft: TIRExpr; const ARight: TIRExpr): TIRExpr;
begin
  Result := MakeBinaryExpr(ALeft, ARight, opFMul);
end;

function TIR.FDiv(const ALeft: TIRExpr; const ARight: TIRExpr): TIRExpr;
begin
  Result := MakeBinaryExpr(ALeft, ARight, opFDiv);
end;

function TIR.FNeg(const AValue: TIRExpr): TIRExpr;
begin
  Result := MakeUnaryExpr(AValue, opFNeg);
end;

function TIR.IntToFloat64(const AValue: TIRExpr): TIRExpr;
var
  LSrcType: TValueType;
begin
  // Check source expression type to decide conversion
  if (AValue.Index >= 0) and (AValue.Index < FExpressions.Count) then
  begin
    LSrcType := FExpressions[AValue.Index].ResultType.Primitive;
    // Already float — no conversion needed
    if LSrcType in [vtFloat32, vtFloat64] then
      Exit(AValue);
    // Known integer type — emit CVTSI2SD
    if LSrcType in [vtInt8, vtInt16, vtInt32, vtInt64,
                    vtUInt8, vtUInt16, vtUInt32, vtUInt64] then
      Exit(MakeUnaryExpr(AValue, opIntToFloat));
  end;
  // Unknown/untracked type — emit conversion (safe default)
  Result := MakeUnaryExpr(AValue, opIntToFloat);
end;

function TIR.Float64ToInt(const AValue: TIRExpr): TIRExpr;
var
  LSrcType: TValueType;
begin
  // Check source expression type to decide conversion
  if (AValue.Index >= 0) and (AValue.Index < FExpressions.Count) then
  begin
    LSrcType := FExpressions[AValue.Index].ResultType.Primitive;
    // Already integer — no conversion needed
    if LSrcType in [vtInt8, vtInt16, vtInt32, vtInt64,
                    vtUInt8, vtUInt16, vtUInt32, vtUInt64] then
      Exit(AValue);
    // Known float type — emit CVTTSD2SI
    if LSrcType in [vtFloat32, vtFloat64] then
      Exit(MakeUnaryExpr(AValue, opFloatToInt));
  end;
  // Unknown/untracked type — passthrough (assume integer, safer than corrupt)
  Result := AValue;
end;

//==============================================================================
// TIR - Expressions: Bitwise
//==============================================================================

function TIR.BitAnd(const ALeft: TIRExpr; const ARight: TIRExpr): TIRExpr;
begin
  Result := MakeBinaryExpr(ALeft, ARight, opBitAnd);
end;

function TIR.BitOr(const ALeft: TIRExpr; const ARight: TIRExpr): TIRExpr;
begin
  Result := MakeBinaryExpr(ALeft, ARight, opBitOr);
end;

function TIR.BitXor(const ALeft: TIRExpr; const ARight: TIRExpr): TIRExpr;
begin
  Result := MakeBinaryExpr(ALeft, ARight, opBitXor);
end;

function TIR.BitNot(const AValue: TIRExpr): TIRExpr;
begin
  Result := MakeUnaryExpr(AValue, opBitNot);
end;

function TIR.ShiftL(const AValue: TIRExpr; const ACount: TIRExpr): TIRExpr;
begin
  Result := MakeBinaryExpr(AValue, ACount, opShl);
end;

function TIR.ShiftR(const AValue: TIRExpr; const ACount: TIRExpr): TIRExpr;
begin
  Result := MakeBinaryExpr(AValue, ACount, opShr);
end;

//==============================================================================
// TIR - Expressions: Comparison
//==============================================================================

function TIR.Eq(const ALeft: TIRExpr; const ARight: TIRExpr): TIRExpr;
begin
  Result := MakeBinaryExpr(ALeft, ARight, opCmpEq);
end;

function TIR.Ne(const ALeft: TIRExpr; const ARight: TIRExpr): TIRExpr;
begin
  Result := MakeBinaryExpr(ALeft, ARight, opCmpNe);
end;

function TIR.Lt(const ALeft: TIRExpr; const ARight: TIRExpr): TIRExpr;
begin
  Result := MakeBinaryExpr(ALeft, ARight, opCmpLt);
end;

function TIR.Le(const ALeft: TIRExpr; const ARight: TIRExpr): TIRExpr;
begin
  Result := MakeBinaryExpr(ALeft, ARight, opCmpLe);
end;

function TIR.Gt(const ALeft: TIRExpr; const ARight: TIRExpr): TIRExpr;
begin
  Result := MakeBinaryExpr(ALeft, ARight, opCmpGt);
end;

function TIR.Ge(const ALeft: TIRExpr; const ARight: TIRExpr): TIRExpr;
begin
  Result := MakeBinaryExpr(ALeft, ARight, opCmpGe);
end;

//==============================================================================
// TIR - Expressions: Float Comparison
//==============================================================================

function TIR.FEq(const ALeft: TIRExpr; const ARight: TIRExpr): TIRExpr;
begin
  Result := MakeBinaryExpr(ALeft, ARight, opFCmpEq);
end;

function TIR.FNe(const ALeft: TIRExpr; const ARight: TIRExpr): TIRExpr;
begin
  Result := MakeBinaryExpr(ALeft, ARight, opFCmpNe);
end;

function TIR.FLt(const ALeft: TIRExpr; const ARight: TIRExpr): TIRExpr;
begin
  Result := MakeBinaryExpr(ALeft, ARight, opFCmpLt);
end;

function TIR.FLe(const ALeft: TIRExpr; const ARight: TIRExpr): TIRExpr;
begin
  Result := MakeBinaryExpr(ALeft, ARight, opFCmpLe);
end;

function TIR.FGt(const ALeft: TIRExpr; const ARight: TIRExpr): TIRExpr;
begin
  Result := MakeBinaryExpr(ALeft, ARight, opFCmpGt);
end;

function TIR.FGe(const ALeft: TIRExpr; const ARight: TIRExpr): TIRExpr;
begin
  Result := MakeBinaryExpr(ALeft, ARight, opFCmpGe);
end;

//==============================================================================
// TIR - Expressions: Logical
//==============================================================================

function TIR.LogAnd(const ALeft: TIRExpr; const ARight: TIRExpr): TIRExpr;
begin
  Result := MakeBinaryExpr(ALeft, ARight, opAnd);
end;

function TIR.LogOr(const ALeft: TIRExpr; const ARight: TIRExpr): TIRExpr;
begin
  Result := MakeBinaryExpr(ALeft, ARight, opOr);
end;

function TIR.LogNot(const AValue: TIRExpr): TIRExpr;
begin
  Result := MakeUnaryExpr(AValue, opNot);
end;

//==============================================================================
// TIR - Expressions: Pointers
//==============================================================================

function TIR.AddrOf(const AName: string): TIRExpr;
var
  LNode: TIRExprNode;
begin
  LNode := Default(TIRExprNode);
  LNode.Kind := ekUnary;
  LNode.Op := opAddrOf;
  LNode.VarName := AName;
  LNode.Left := -1;
  Result := AddExpr(LNode);
end;

function TIR.AddrOfVal(const AExpr: TIRExpr): TIRExpr;
var
  LNode: TIRExprNode;
begin
  LNode := Default(TIRExprNode);
  LNode.Kind := ekUnary;
  LNode.Op := opAddrOf;
  LNode.Left := AExpr.Index;
  LNode.ResultType := TTypeRef.FromPrimitive(vtPointer);
  Result := AddExpr(LNode);
end;

function TIR.Deref(const APtr: TIRExpr): TIRExpr;
begin
  Result := MakeUnaryExpr(APtr, opDeref);
end;

function TIR.Deref(const APtr: TIRExpr; const ATypeName: string): TIRExpr;
var
  LNode: TIRExprNode;
  LTypeIndex: Integer;
begin
  LNode := Default(TIRExprNode);
  LNode.Kind := ekUnary;
  LNode.Op := opDeref;
  LNode.Left := APtr.Index;
  LNode.Right := -1;

  // Resolve the type name to set ResultType
  LTypeIndex := FindType(ATypeName);
  if LTypeIndex >= 0 then
    LNode.ResultType := TTypeRef.FromComposite(LTypeIndex)
  else
    LNode.ResultType := TTypeRef.None();

  Result := AddExpr(LNode);
end;

function TIR.Deref(const APtr: TIRExpr; const AType: TValueType): TIRExpr;
var
  LNode: TIRExprNode;
begin
  LNode := Default(TIRExprNode);
  LNode.Kind := ekUnary;
  LNode.Op := opDeref;
  LNode.Left := APtr.Index;
  LNode.Right := -1;
  LNode.ResultType := TTypeRef.FromPrimitive(AType);
  Result := AddExpr(LNode);
end;

//==============================================================================
// TIR - Expressions: Function Pointers
//==============================================================================

function TIR.FuncAddr(const AFuncName: string): TIRExpr;
var
  LNode: TIRExprNode;
begin
  LNode := Default(TIRExprNode);
  LNode.Kind := ekFuncAddr;
  LNode.FuncAddrName := AFuncName;
  LNode.ResultType := TTypeRef.FromPrimitive(vtPointer);  // Function pointer is pointer-sized
  Result := AddExpr(LNode);
end;

function TIR.InvokeIndirect(const AFuncPtr: TIRExpr; const AArgs: array of TIRExpr): TIRExpr;
var
  LNode: TIRExprNode;
  LI: Integer;
begin
  LNode := Default(TIRExprNode);
  LNode.Kind := ekCallIndirect;
  LNode.IndirectTarget := AFuncPtr.Index;

  SetLength(LNode.CallArgs, Length(AArgs));
  for LI := 0 to System.High(AArgs) do
    LNode.CallArgs[LI] := AArgs[LI].Index;

  Result := AddExpr(LNode);
end;

//==============================================================================
// TIR - Expressions: Composite Type Access
//==============================================================================

function TIR.GetField(const AObject: TIRExpr; const AFieldName: string): TIRExpr;
var
  LNode: TIRExprNode;
  LObjectNode: TIRExprNode;
  LFieldInfo: TIRRecordField;
begin
  LNode := Default(TIRExprNode);
  LNode.Kind := ekFieldAccess;
  LNode.ObjectExpr := AObject.Index;
  LNode.FieldName := AFieldName;

  // Get object expression's type and resolve field
  if (AObject.Index >= 0) and (AObject.Index < FExpressions.Count) then
  begin
    LObjectNode := FExpressions[AObject.Index];
    if not LObjectNode.ResultType.IsPrimitive and (LObjectNode.ResultType.TypeIndex >= 0) then
    begin
      if FindRecordField(LObjectNode.ResultType.TypeIndex, AFieldName, LFieldInfo) then
      begin
        LNode.FieldOffset := LFieldInfo.FieldOffset;
        LNode.FieldSize := GetTypeSize(LFieldInfo.FieldType);
        LNode.ResultType := LFieldInfo.FieldType;
        LNode.BitWidth := LFieldInfo.BitWidth;
        LNode.BitOffset := LFieldInfo.BitOffset;
      end;
    end;
  end;

  Result := AddExpr(LNode);
end;

function TIR.GetIndex(const AArray: TIRExpr; const AIndex: TIRExpr): TIRExpr;
var
  LNode: TIRExprNode;
  LArrayNode: TIRExprNode;
  LTypeEntry: TIRTypeEntry;
begin
  LNode := Default(TIRExprNode);
  LNode.Kind := ekArrayIndex;
  LNode.ArrayExpr := AArray.Index;
  LNode.IndexExpr := AIndex.Index;

  // Get array expression's element type and size
  if (AArray.Index >= 0) and (AArray.Index < FExpressions.Count) then
  begin
    LArrayNode := FExpressions[AArray.Index];
    if not LArrayNode.ResultType.IsPrimitive and (LArrayNode.ResultType.TypeIndex >= 0) then
    begin
      LTypeEntry := FTypes[LArrayNode.ResultType.TypeIndex];
      if LTypeEntry.Kind = tkFixedArray then
      begin
        LNode.ElementSize := GetTypeSize(LTypeEntry.FixedArrayType.ElementType);
        LNode.ResultType := LTypeEntry.FixedArrayType.ElementType;
      end
      else if LTypeEntry.Kind = tkDynArray then
      begin
        LNode.ElementSize := GetTypeSize(LTypeEntry.DynArrayType.ElementType);
        LNode.ResultType := LTypeEntry.DynArrayType.ElementType;
      end;
    end;
  end;

  Result := AddExpr(LNode);
end;

//==============================================================================
// TIR - Expressions: Function Call
//==============================================================================

function TIR.Invoke(const AFuncName: string; const AArgs: array of TIRExpr): TIRExpr;
var
  LNode: TIRExprNode;
  LI: Integer;
begin
  LNode := Default(TIRExprNode);
  LNode.Kind := ekCall;
  LNode.CallTarget := AFuncName;

  SetLength(LNode.CallArgs, Length(AArgs));
  for LI := 0 to System.High(AArgs) do
    LNode.CallArgs[LI] := AArgs[LI].Index;

  Result := AddExpr(LNode);
end;

function TIR.ExcCode(): TIRExpr;
var
  LNode: TIRExprNode;
begin
  LNode := Default(TIRExprNode);
  LNode.Kind := ekGetExceptionCode;
  LNode.ResultType := TTypeRef.FromPrimitive(vtInt32);
  Result := AddExpr(LNode);
end;

function TIR.ExcMsg(): TIRExpr;
var
  LNode: TIRExprNode;
begin
  LNode := Default(TIRExprNode);
  LNode.Kind := ekGetExceptionMsg;
  LNode.ResultType := TTypeRef.FromPrimitive(vtPointer);  // Pointer to string data
  Result := AddExpr(LNode);
end;

function TIR.SetLit(const ATypeName: string; const AElements: array of Integer): TIRExpr;
var
  LTypeIndex: Integer;
  LEntry: TIRTypeEntry;
  LNode: TIRExprNode;
  LI: Integer;
begin
  Result := TIRExpr.None();

  // Find the set type
  LTypeIndex := FindType(ATypeName);
  if LTypeIndex < 0 then
  begin
    if Assigned(FErrors) then
      FErrors.Add(esError, ERR_IR_UNKNOWN_TYPE, RSIRUnknownSetType, [ATypeName]);
    Exit;
  end;

  LEntry := FTypes[LTypeIndex];
  if LEntry.Kind <> tkSet then
  begin
    if Assigned(FErrors) then
      FErrors.Add(esError, ERR_IR_TYPE_BUILD, RSIRTypeNotSet, [ATypeName]);
    Exit;
  end;

  LNode := Default(TIRExprNode);
  LNode.Kind := ekSetLiteral;
  LNode.ResultType := TTypeRef.FromComposite(LTypeIndex);
  LNode.SetTypeIndex := LTypeIndex;

  // Store elements (they will be adjusted by LowBound during code generation)
  SetLength(LNode.SetElements, Length(AElements));
  for LI := 0 to System.High(AElements) do
    LNode.SetElements[LI] := AElements[LI];

  Result := AddExpr(LNode);
end;

function TIR.SetLitRange(const ATypeName: string; const ALow: Integer; const AHigh: Integer): TIRExpr;
var
  LTypeIndex: Integer;
  LEntry: TIRTypeEntry;
  LNode: TIRExprNode;
  LI: Integer;
  LCount: Integer;
begin
  Result := TIRExpr.None();

  // Find the set type
  LTypeIndex := FindType(ATypeName);
  if LTypeIndex < 0 then
  begin
    if Assigned(FErrors) then
      FErrors.Add(esError, ERR_IR_UNKNOWN_TYPE, RSIRUnknownSetType, [ATypeName]);
    Exit;
  end;

  LEntry := FTypes[LTypeIndex];
  if LEntry.Kind <> tkSet then
  begin
    if Assigned(FErrors) then
      FErrors.Add(esError, ERR_IR_TYPE_BUILD, RSIRTypeNotSet, [ATypeName]);
    Exit;
  end;

  // Validate range
  if AHigh < ALow then
  begin
    if Assigned(FErrors) then
      FErrors.Add(esError, ERR_IR_TYPE_BUILD, RSIRInvalidSetRange, [ALow, AHigh]);
    Exit;
  end;

  LNode := Default(TIRExprNode);
  LNode.Kind := ekSetLiteral;
  LNode.ResultType := TTypeRef.FromComposite(LTypeIndex);
  LNode.SetTypeIndex := LTypeIndex;

  // Expand range into individual elements
  LCount := AHigh - ALow + 1;
  SetLength(LNode.SetElements, LCount);
  for LI := 0 to LCount - 1 do
    LNode.SetElements[LI] := ALow + LI;

  Result := AddExpr(LNode);
end;

function TIR.EmptySet(const ATypeName: string): TIRExpr;
var
  LTypeIndex: Integer;
  LEntry: TIRTypeEntry;
  LNode: TIRExprNode;
begin
  Result := TIRExpr.None();

  // Find the set type
  LTypeIndex := FindType(ATypeName);
  if LTypeIndex < 0 then
  begin
    if Assigned(FErrors) then
      FErrors.Add(esError, ERR_IR_UNKNOWN_TYPE, RSIRUnknownSetType, [ATypeName]);
    Exit;
  end;

  LEntry := FTypes[LTypeIndex];
  if LEntry.Kind <> tkSet then
  begin
    if Assigned(FErrors) then
      FErrors.Add(esError, ERR_IR_TYPE_BUILD, RSIRTypeNotSet, [ATypeName]);
    Exit;
  end;

  LNode := Default(TIRExprNode);
  LNode.Kind := ekSetLiteral;
  LNode.ResultType := TTypeRef.FromComposite(LTypeIndex);
  LNode.SetTypeIndex := LTypeIndex;
  SetLength(LNode.SetElements, 0);  // Empty set

  Result := AddExpr(LNode);
end;

function TIR.SetUnion(const ALeft: TIRExpr; const ARight: TIRExpr): TIRExpr;
begin
  Result := MakeBinaryExpr(ALeft, ARight, opSetUnion);
end;

function TIR.SetDiff(const ALeft: TIRExpr; const ARight: TIRExpr): TIRExpr;
begin
  Result := MakeBinaryExpr(ALeft, ARight, opSetDiff);
end;

function TIR.SetInter(const ALeft: TIRExpr; const ARight: TIRExpr): TIRExpr;
begin
  Result := MakeBinaryExpr(ALeft, ARight, opSetInter);
end;

function TIR.SetIn(const AElement: TIRExpr; const ASet: TIRExpr): TIRExpr;
begin
  Result := MakeBinaryExpr(AElement, ASet, opSetIn);
end;

function TIR.SetIn(const AElement: TIRExpr; const ASet: TIRExpr; const ALowBound: Integer): TIRExpr;
var
  LNode: TIRExprNode;
begin
  LNode := Default(TIRExprNode);
  LNode.Kind := ekBinary;
  LNode.Op := opSetIn;
  LNode.Left := AElement.Index;
  LNode.Right := ASet.Index;
  LNode.SetLowBound := ALowBound;
  Result := AddExpr(LNode);
end;

function TIR.SetEq(const ALeft: TIRExpr; const ARight: TIRExpr): TIRExpr;
begin
  Result := MakeBinaryExpr(ALeft, ARight, opSetEq);
end;

function TIR.SetNe(const ALeft: TIRExpr; const ARight: TIRExpr): TIRExpr;
begin
  Result := MakeBinaryExpr(ALeft, ARight, opSetNe);
end;

function TIR.SetSubset(const ALeft: TIRExpr; const ARight: TIRExpr): TIRExpr;
begin
  Result := MakeBinaryExpr(ALeft, ARight, opSetSubset);
end;

function TIR.SetSuperset(const ALeft: TIRExpr; const ARight: TIRExpr): TIRExpr;
begin
  Result := MakeBinaryExpr(ALeft, ARight, opSetSuperset);
end;

//==============================================================================
// TIR - Expressions: Compile-Time Intrinsics
//==============================================================================

function TIR.TypeSize(const ATypeName: string): TIRExpr;
var
  LTypeIndex: Integer;
  LTypeRef: TTypeRef;
begin
  LTypeIndex := FindType(ATypeName);
  if LTypeIndex < 0 then
  begin
    if Assigned(FErrors) then
      FErrors.Add(esError, ERR_IR_UNKNOWN_TYPE, RSIRSizeOfUnknown, [ATypeName]);
    Result := TIRExpr.None();
    Exit;
  end;

  LTypeRef := TTypeRef.FromComposite(LTypeIndex);
  Result := MakeInt64(GetTypeSize(LTypeRef));
end;

function TIR.AlignOf(const ATypeName: string): TIRExpr;
var
  LTypeIndex: Integer;
  LTypeRef: TTypeRef;
begin
  LTypeIndex := FindType(ATypeName);
  if LTypeIndex < 0 then
  begin
    if Assigned(FErrors) then
      FErrors.Add(esError, ERR_IR_UNKNOWN_TYPE, RSIRAlignOfUnknown, [ATypeName]);
    Result := TIRExpr.None();
    Exit;
  end;

  LTypeRef := TTypeRef.FromComposite(LTypeIndex);
  Result := MakeInt64(GetTypeAlignment(LTypeRef));
end;

function TIR.High(const ATypeName: string): TIRExpr;
var
  LTypeIndex: Integer;
  LEntry: TIRTypeEntry;
begin
  LTypeIndex := FindType(ATypeName);
  if LTypeIndex < 0 then
  begin
    if Assigned(FErrors) then
      FErrors.Add(esError, ERR_IR_UNKNOWN_TYPE, RSIRHighUnknown, [ATypeName]);
    Result := TIRExpr.None();
    Exit;
  end;

  LEntry := FTypes[LTypeIndex];
  case LEntry.Kind of
    tkFixedArray:
      Result := MakeInt64(LEntry.FixedArrayType.HighBound);
    tkEnum:
      begin
        if Length(LEntry.EnumType.Values) > 0 then
          Result := MakeInt64(LEntry.EnumType.Values[System.High(LEntry.EnumType.Values)].OrdinalValue)
        else
          Result := MakeInt64(0);
      end;
    tkSet:
      Result := MakeInt64(LEntry.SetType.HighBound);
  else
    if Assigned(FErrors) then
      FErrors.Add(esError, ERR_IR_TYPE_BUILD, RSIRHighNotApplicable, [ATypeName]);
    Result := TIRExpr.None();
  end;
end;

function TIR.Low(const ATypeName: string): TIRExpr;
var
  LTypeIndex: Integer;
  LEntry: TIRTypeEntry;
begin
  LTypeIndex := FindType(ATypeName);
  if LTypeIndex < 0 then
  begin
    if Assigned(FErrors) then
      FErrors.Add(esError, ERR_IR_UNKNOWN_TYPE, RSIRLowUnknown, [ATypeName]);
    Result := TIRExpr.None();
    Exit;
  end;

  LEntry := FTypes[LTypeIndex];
  case LEntry.Kind of
    tkFixedArray:
      Result := MakeInt64(LEntry.FixedArrayType.LowBound);
    tkEnum:
      begin
        if Length(LEntry.EnumType.Values) > 0 then
          Result := MakeInt64(LEntry.EnumType.Values[0].OrdinalValue)
        else
          Result := MakeInt64(0);
      end;
    tkSet:
      Result := MakeInt64(LEntry.SetType.LowBound);
  else
    if Assigned(FErrors) then
      FErrors.Add(esError, ERR_IR_TYPE_BUILD, RSIRLowNotApplicable, [ATypeName]);
    Result := TIRExpr.None();
  end;
end;

function TIR.Len(const ATypeName: string): TIRExpr;
var
  LTypeIndex: Integer;
  LEntry: TIRTypeEntry;
begin
  LTypeIndex := FindType(ATypeName);
  if LTypeIndex < 0 then
  begin
    if Assigned(FErrors) then
      FErrors.Add(esError, ERR_IR_UNKNOWN_TYPE, RSIRLenUnknown, [ATypeName]);
    Result := TIRExpr.None();
    Exit;
  end;

  LEntry := FTypes[LTypeIndex];
  case LEntry.Kind of
    tkFixedArray:
      Result := MakeInt64(LEntry.FixedArrayType.HighBound - LEntry.FixedArrayType.LowBound + 1);
  else
    if Assigned(FErrors) then
      FErrors.Add(esError, ERR_IR_TYPE_BUILD, RSIRLenNotApplicable, [ATypeName]);
    Result := TIRExpr.None();
  end;
end;

//==============================================================================
// TIR - Expressions: Runtime Intrinsics
//==============================================================================

function TIR.Ord(const AValue: TIRExpr): TIRExpr;
begin
  // Ord is a pass-through - the ordinal value is the integer representation
  // The expression already holds the numeric value
  Result := AValue;
end;

function TIR.Chr(const AValue: TIRExpr): TIRExpr;
begin
  // Chr is a pass-through - we just interpret the integer as a character
  // The expression already holds the numeric value
  Result := AValue;
end;

function TIR.Succ(const AValue: TIRExpr): TIRExpr;
begin
  // Succ(x) = x + 1
  Result := Add(AValue, MakeInt64(1));
end;

function TIR.Pred(const AValue: TIRExpr): TIRExpr;
begin
  // Pred(x) = x - 1
  Result := Sub(AValue, MakeInt64(1));
end;

//==============================================================================
// TIR - Expressions: Variadic Intrinsics
//==============================================================================

function TIR.VaCount(): TIRExpr;
var
  LNode: TIRExprNode;
begin
  LNode := Default(TIRExprNode);
  LNode.Kind := ekVaCount;
  LNode.ResultType := TTypeRef.FromPrimitive(vtInt32);
  Result := AddExpr(LNode);
end;

function TIR.VaArg(const AIndex: TIRExpr; const AType: TValueType): TIRExpr;
var
  LNode: TIRExprNode;
begin
  LNode := Default(TIRExprNode);
  LNode.Kind := ekVaArgAt;
  LNode.ResultType := TTypeRef.FromPrimitive(AType);
  LNode.VaArgIndex := AIndex.Index;
  LNode.VaArgType := AType;
  Result := AddExpr(LNode);
end;


procedure TIR.Clear();
var
  LI: Integer;
begin
  for LI := 0 to FFunctions.Count - 1 do
  begin
    FFunctions[LI].Vars.Free();
    FFunctions[LI].Stmts.Free();
  end;

  FImports.Clear();
  FStrings.Clear();
  FGlobals.Clear();
  FFunctions.Clear();
  FExpressions.Clear();
  FTypes.Clear();
  FCurrentFunc := -1;
  FBuildingRecordIndex := -1;
  FBuildingUnionIndex := -1;
  FBuildingEnumIndex := -1;
  FNextEnumOrdinal := 0;
  FNextOverlayGroup := 0;
  FAnonUnionFieldStart := -1;
  FNextAnonRecordGroup := 0;
  FAnonRecordInUnion := False;
  FSnapshotFuncs := -1;
  FSnapshotImports := -1;
  FSnapshotStrings := -1;
  FSnapshotGlobals := -1;
  FSnapshotExprs := -1;

end;

//==============================================================================
// TIR - Runtime Snapshot
//==============================================================================

procedure TIR.SaveSnapshot();
begin
  FSnapshotFuncs := FFunctions.Count;
  FSnapshotImports := FImports.Count;
  FSnapshotStrings := FStrings.Count;
  FSnapshotGlobals := FGlobals.Count;
  FSnapshotExprs := FExpressions.Count;
end;

procedure TIR.RestoreSnapshot();
var
  LI: Integer;
  LCount: Integer;
begin
  if FSnapshotFuncs < 0 then
    Exit;

  // Free owned sub-objects on functions being removed
  for LI := FFunctions.Count - 1 downto FSnapshotFuncs do
  begin
    FFunctions[LI].Vars.Free();
    FFunctions[LI].Stmts.Free();
  end;

  // Truncate all lists back to snapshot point
  LCount := FFunctions.Count - FSnapshotFuncs;
  if LCount > 0 then
    FFunctions.DeleteRange(FSnapshotFuncs, LCount);

  LCount := FImports.Count - FSnapshotImports;
  if LCount > 0 then
    FImports.DeleteRange(FSnapshotImports, LCount);

  LCount := FStrings.Count - FSnapshotStrings;
  if LCount > 0 then
    FStrings.DeleteRange(FSnapshotStrings, LCount);

  LCount := FGlobals.Count - FSnapshotGlobals;
  if LCount > 0 then
    FGlobals.DeleteRange(FSnapshotGlobals, LCount);

  LCount := FExpressions.Count - FSnapshotExprs;
  if LCount > 0 then
    FExpressions.DeleteRange(FSnapshotExprs, LCount);

  // Reset snapshot
  FSnapshotFuncs := -1;
end;

//==============================================================================
// TIR - Getters for SSA conversion
//==============================================================================

function TIR.GetImportCount(): Integer;
begin
  Result := FImports.Count;
end;

function TIR.GetImport(const AIndex: Integer): TIRImport;
begin
  Result := FImports[AIndex];
end;

function TIR.GetStringCount(): Integer;
begin
  Result := FStrings.Count;
end;

function TIR.GetString(const AIndex: Integer): TIRString;
begin
  Result := FStrings[AIndex];
end;

function TIR.GetGlobalCount(): Integer;
begin
  Result := FGlobals.Count;
end;

function TIR.GetGlobal(const AIndex: Integer): TIRGlobal;
begin
  Result := FGlobals[AIndex];
end;

function TIR.GetFunctionCount(): Integer;
begin
  Result := FFunctions.Count;
end;

function TIR.GetFunction(const AIndex: Integer): TIRFunc;
begin
  Result := FFunctions[AIndex];
end;

function TIR.GetExpressionCount(): Integer;
begin
  Result := FExpressions.Count;
end;

function TIR.GetExpression(const AIndex: Integer): TIRExprNode;
begin
  Result := FExpressions[AIndex];
end;

function TIR.FindRecordField(const ATypeIndex: Integer; const AFieldName: string;
  out AFieldInfo: TIRRecordField): Boolean;
var
  LEntry: TIRTypeEntry;
  LI: Integer;
begin
  Result := False;
  AFieldInfo := Default(TIRRecordField);

  if (ATypeIndex < 0) or (ATypeIndex >= FTypes.Count) then
    Exit;

  LEntry := FTypes[ATypeIndex];

  if LEntry.Kind = tkRecord then
  begin
    // Ensure record is finalized
    if not LEntry.RecordType.IsFinalized then
      FinalizeRecordLayout(ATypeIndex);

    // Re-read after finalization
    LEntry := FTypes[ATypeIndex];

    // Search in this record's own fields first
    for LI := 0 to Length(LEntry.RecordType.Fields) - 1 do
    begin
      if SameText(LEntry.RecordType.Fields[LI].FieldName, AFieldName) then
      begin
        AFieldInfo := LEntry.RecordType.Fields[LI];
        Result := True;
        Exit;
      end;
    end;

    // Not found in own fields - search base type (recursive)
    if LEntry.RecordType.BaseTypeIndex >= 0 then
      Result := FindRecordField(LEntry.RecordType.BaseTypeIndex, AFieldName, AFieldInfo);
  end
  else if LEntry.Kind = tkUnion then
  begin
    // Ensure union is finalized
    if not LEntry.UnionType.IsFinalized then
      FinalizeUnionLayout(ATypeIndex);

    // Re-read after finalization
    LEntry := FTypes[ATypeIndex];

    // Search union fields (all at offset 0)
    for LI := 0 to Length(LEntry.UnionType.Fields) - 1 do
    begin
      if SameText(LEntry.UnionType.Fields[LI].FieldName, AFieldName) then
      begin
        AFieldInfo := LEntry.UnionType.Fields[LI];
        Result := True;
        Exit;
      end;
    end;
  end;
end;

//==============================================================================
// Module-Level Helper Function Implementations
//==============================================================================

function V(const AName: string): TExpr;
var
  LIR: TIR;
  LIRExpr: TIRExpr;
begin
  Assert(GActiveExprOwner <> nil, 'V(): No active Viper context (call TIR.Create or Activate)');
  LIR := TIR(GActiveExprOwner);
  LIRExpr := LIR.Get(AName);
  Result.Index := LIRExpr.Index;
  Result.Owner := GActiveExprOwner;
end;

function S(const AValue: string): TExpr;
var
  LIR: TIR;
  LIRExpr: TIRExpr;
begin
  Assert(GActiveExprOwner <> nil, 'S(): No active Viper context');
  LIR := TIR(GActiveExprOwner);
  LIRExpr := LIR.Str(AValue);
  Result.Index := LIRExpr.Index;
  Result.Owner := GActiveExprOwner;
end;

function W(const AValue: string): TExpr;
var
  LIR: TIR;
  LIRExpr: TIRExpr;
begin
  Assert(GActiveExprOwner <> nil, 'W(): No active Viper context');
  LIR := TIR(GActiveExprOwner);
  LIRExpr := LIR.WStr(AValue);
  Result.Index := LIRExpr.Index;
  Result.Owner := GActiveExprOwner;
end;

function I(const AValue: Int64): TExpr;
var
  LIR: TIR;
  LIRExpr: TIRExpr;
begin
  Assert(GActiveExprOwner <> nil, 'I(): No active Viper context');
  LIR := TIR(GActiveExprOwner);
  LIRExpr := LIR.MakeInt64(AValue);
  Result.Index := LIRExpr.Index;
  Result.Owner := GActiveExprOwner;
end;

function F(const AValue: Double): TExpr;
var
  LIR: TIR;
  LIRExpr: TIRExpr;
begin
  Assert(GActiveExprOwner <> nil, 'F(): No active Viper context');
  LIR := TIR(GActiveExprOwner);
  LIRExpr := LIR.Float64(AValue);
  Result.Index := LIRExpr.Index;
  Result.Owner := GActiveExprOwner;
end;

function B(const AValue: Boolean): TExpr;
var
  LIR: TIR;
  LIRExpr: TIRExpr;
begin
  Assert(GActiveExprOwner <> nil, 'B(): No active Viper context');
  LIR := TIR(GActiveExprOwner);
  LIRExpr := LIR.Bool(AValue);
  Result.Index := LIRExpr.Index;
  Result.Owner := GActiveExprOwner;
end;

function P: TExpr;
var
  LIR: TIR;
  LIRExpr: TIRExpr;
begin
  Assert(GActiveExprOwner <> nil, 'P: No active Viper context');
  LIR := TIR(GActiveExprOwner);
  LIRExpr := LIR.Null();
  Result.Index := LIRExpr.Index;
  Result.Owner := GActiveExprOwner;
end;

function Addr(const AName: string): TExpr;
var
  LIR: TIR;
  LIRExpr: TIRExpr;
begin
  Assert(GActiveExprOwner <> nil, 'Addr(): No active Viper context');
  LIR := TIR(GActiveExprOwner);

  // Delegate to TIR.AddrOf which creates the correct expression nodes
  LIRExpr := LIR.AddrOf(AName);

  Result.Index := LIRExpr.Index;
  Result.Owner := GActiveExprOwner;
end;

function Fn(const AName: string): TExpr;
var
  LIR: TIR;
  LIRExpr: TIRExpr;
begin
  Assert(GActiveExprOwner <> nil, 'Fn(): No active Viper context');
  LIR := TIR(GActiveExprOwner);

  LIRExpr := LIR.FuncAddr(AName);

  Result.Index := LIRExpr.Index;
  Result.Owner := GActiveExprOwner;
end;

function Inv(const AFuncName: string; const AArgs: array of TExpr): TExpr;
var
  LIR: TIR;
  LIRArgs: TArray<TIRExpr>;
  LIRExpr: TIRExpr;
  LI: Integer;
begin
  Assert(GActiveExprOwner <> nil, 'Inv(): No active Viper context');
  LIR := TIR(GActiveExprOwner);

  // Convert TExpr args → TIRExpr args
  SetLength(LIRArgs, Length(AArgs));
  for LI := 0 to System.High(AArgs) do
    LIRArgs[LI].Index := AArgs[LI].Index;

  LIRExpr := LIR.Invoke(AFuncName, LIRArgs);

  Result.Index := LIRExpr.Index;
  Result.Owner := GActiveExprOwner;
end;

//==============================================================================
// TExpr Factory Callback Implementations
//==============================================================================

function ExprFactory_Binary(const AOwner: Pointer; const AOp: TOpKind;
  const ALeft, ARight: Integer): TExpr;
var
  LIR: TIR;
  LNode: TIR.TIRExprNode;
  LIROp: TIR.TIROpKind;
begin
  LIR := TIR(AOwner);
  LNode := Default(TIR.TIRExprNode);
  LNode.Kind := TIR.TIRExprKind.ekBinary;
  LNode.Left := ALeft;
  LNode.Right := ARight;

  // Map TOpKind → TIROpKind
  case AOp of
    TOpKind.opAdd:    LIROp := TIR.TIROpKind.opAdd;
    TOpKind.opSub:    LIROp := TIR.TIROpKind.opSub;
    TOpKind.opMul:    LIROp := TIR.TIROpKind.opMul;
    TOpKind.opIntDiv: LIROp := TIR.TIROpKind.opDiv;
    TOpKind.opMod:    LIROp := TIR.TIROpKind.opMod;
    TOpKind.opBitAnd: LIROp := TIR.TIROpKind.opBitAnd;
    TOpKind.opBitOr:  LIROp := TIR.TIROpKind.opBitOr;
    TOpKind.opBitXor: LIROp := TIR.TIROpKind.opBitXor;
    TOpKind.opShiftL: LIROp := TIR.TIROpKind.opShl;
    TOpKind.opShiftR: LIROp := TIR.TIROpKind.opShr;
    TOpKind.opEq:     LIROp := TIR.TIROpKind.opCmpEq;
    TOpKind.opNe:     LIROp := TIR.TIROpKind.opCmpNe;
    TOpKind.opLt:     LIROp := TIR.TIROpKind.opCmpLt;
    TOpKind.opLe:     LIROp := TIR.TIROpKind.opCmpLe;
    TOpKind.opGt:     LIROp := TIR.TIROpKind.opCmpGt;
    TOpKind.opGe:     LIROp := TIR.TIROpKind.opCmpGe;
    TOpKind.opLogAnd: LIROp := TIR.TIROpKind.opAnd;
    TOpKind.opLogOr:  LIROp := TIR.TIROpKind.opOr;
  else
    LIROp := TIR.TIROpKind.opNone;
  end;
  LNode.Op := LIROp;

  Result.Index := LIR.FExpressions.Count;
  Result.Owner := AOwner;
  LIR.FExpressions.Add(LNode);
end;

function ExprFactory_Unary(const AOwner: Pointer; const AOp: TOpKind;
  const AOperand: Integer): TExpr;
var
  LIR: TIR;
  LNode: TIR.TIRExprNode;
  LIROp: TIR.TIROpKind;
begin
  LIR := TIR(AOwner);
  LNode := Default(TIR.TIRExprNode);
  LNode.Kind := TIR.TIRExprKind.ekUnary;
  LNode.Left := AOperand;
  LNode.Right := -1;

  case AOp of
    TOpKind.opNeg:    LIROp := TIR.TIROpKind.opNeg;
    TOpKind.opBitNot: LIROp := TIR.TIROpKind.opBitNot;
    TOpKind.opLogNot: LIROp := TIR.TIROpKind.opNot;
  else
    LIROp := TIR.TIROpKind.opNone;
  end;
  LNode.Op := LIROp;

  Result.Index := LIR.FExpressions.Count;
  Result.Owner := AOwner;
  LIR.FExpressions.Add(LNode);
end;

function ExprFactory_FromInt(const AOwner: Pointer; const AValue: Int64): TExpr;
var
  LIR: TIR;
  LNode: TIR.TIRExprNode;
begin
  LIR := TIR(AOwner);
  LNode := Default(TIR.TIRExprNode);
  LNode.Kind := TIR.TIRExprKind.ekConstInt;
  LNode.ConstInt := AValue;
  LNode.ResultType := TTypeRef.FromPrimitive(vtInt64);

  Result.Index := LIR.FExpressions.Count;
  Result.Owner := AOwner;
  LIR.FExpressions.Add(LNode);
end;

function ExprFactory_FromFlt(const AOwner: Pointer; const AValue: Double): TExpr;
var
  LIR: TIR;
  LNode: TIR.TIRExprNode;
begin
  LIR := TIR(AOwner);
  LNode := Default(TIR.TIRExprNode);
  LNode.Kind := TIR.TIRExprKind.ekConstFloat;
  LNode.ConstFloat := AValue;
  LNode.ResultType := TTypeRef.FromPrimitive(vtFloat64);

  Result.Index := LIR.FExpressions.Count;
  Result.Owner := AOwner;
  LIR.FExpressions.Add(LNode);
end;

function ExprFactory_FromBool(const AOwner: Pointer; const AValue: Boolean): TExpr;
var
  LIR: TIR;
  LNode: TIR.TIRExprNode;
begin
  LIR := TIR(AOwner);
  LNode := Default(TIR.TIRExprNode);
  LNode.Kind := TIR.TIRExprKind.ekConstInt;
  if AValue then
    LNode.ConstInt := 1
  else
    LNode.ConstInt := 0;
  LNode.ResultType := TTypeRef.FromPrimitive(vtInt32);

  Result.Index := LIR.FExpressions.Count;
  Result.Owner := AOwner;
  LIR.FExpressions.Add(LNode);
end;

function ExprFactory_Field(const AOwner: Pointer; const AExprIdx: Integer;
  const AFieldName: string): TExpr;
var
  LIR: TIR;
  LNode: TIR.TIRExprNode;
begin
  LIR := TIR(AOwner);
  LNode := Default(TIR.TIRExprNode);
  LNode.Kind := TIR.TIRExprKind.ekFieldAccess;
  LNode.ObjectExpr := AExprIdx;
  LNode.FieldName := AFieldName;

  Result.Index := LIR.FExpressions.Count;
  Result.Owner := AOwner;
  LIR.FExpressions.Add(LNode);
end;

function ExprFactory_Index(const AOwner: Pointer; const AArrIdx: Integer;
  const AIdxIdx: Integer): TExpr;
var
  LIR: TIR;
  LNode: TIR.TIRExprNode;
begin
  LIR := TIR(AOwner);
  LNode := Default(TIR.TIRExprNode);
  LNode.Kind := TIR.TIRExprKind.ekArrayIndex;
  LNode.ArrayExpr := AArrIdx;
  LNode.IndexExpr := AIdxIdx;

  Result.Index := LIR.FExpressions.Count;
  Result.Owner := AOwner;
  LIR.FExpressions.Add(LNode);
end;

end.
