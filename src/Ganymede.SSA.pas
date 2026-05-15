{===============================================================================
  Ganymede™ - Embeddable Native Scripting Engine

  Copyright © 2026-present tinyBigGAMES™ LLC
  All Rights Reserved.

  See LICENSE for license information
===============================================================================}

unit Ganymede.SSA;

{$I Ganymede.Defines.inc}

interface

uses
  System.SysUtils,
  System.Generics.Collections,
  System.Generics.Defaults,
  Ganymede.Utils,
  Ganymede.Resources,
  Ganymede.Types,
  Ganymede.IR;

type
  //============================================================================
  // Forward Declarations
  //============================================================================
  TSSABuilder = class;
  TSSAPass = class;
  TSSABlock = class;
  TSSAFunc = class;

  //============================================================================
  // TSSABuildMode - Debug vs Release compilation
  //============================================================================
  TSSABuildMode = (
    bmDebug,      // No optimization, preserve all debug info
    bmRelease     // Full optimization
  );

  //============================================================================
  // TSSAOptions - Configuration for SSA builder
  //============================================================================
  TSSAOptions = record
    BuildMode: TSSABuildMode;
    
    class function Debug(): TSSAOptions; static;
    class function Release(): TSSAOptions; static;
  end;

  //============================================================================
  // TSSAVar - Versioned variable (name_version)
  //============================================================================
  TSSAVar = record
    BaseName: string;
    Version: Integer;
    
    class function Create(const ABaseName: string; const AVersion: Integer): TSSAVar; static;
    class function None(): TSSAVar; static;
    function IsValid(): Boolean;
    function ToString(): string;
    
    class operator Equal(const A: TSSAVar; const B: TSSAVar): Boolean;
    class operator NotEqual(const A: TSSAVar; const B: TSSAVar): Boolean;
  end;

  //============================================================================
  // TSSAOperandKind - Types of operands in SSA instructions
  //============================================================================
  TSSAOperandKind = (
    sokNone,
    sokImmediate,     // Constant value
    sokVar,           // SSA variable reference
    sokData,          // Data section reference (strings, etc.)
    sokGlobal,        // Global variable reference
    sokImport,        // Import function reference
    sokFunc,          // Local function reference
    sokBlock,         // Basic block reference (for jumps)
    sokLocalIndex     // Local variable by index (for direct stack access)
  );

  //============================================================================
  // TSSAOperand - Operand for SSA instructions
  //============================================================================
  TSSAOperand = record
    Kind: TSSAOperandKind;
    ImmInt: Int64;
    ImmFloat: Double;
    Var_: TSSAVar;
    DataIndex: Integer;
    GlobalIndex: Integer;
    ImportIndex: Integer;
    FuncIndex: Integer;
    BlockIndex: Integer;
    LocalIndex: Integer;   // For sokLocalIndex - local variable by index
    FieldName: string;     // For sikFieldAddr - stores field name
    ElementSize: Integer;  // For sikIndexAddr - stores element size
    BitWidth: Integer;     // For bit field operations
    BitOffset: Integer;    // For bit field operations
    
    class function None(): TSSAOperand; static;
    class function FromImm(const AValue: Int64): TSSAOperand; overload; static;
    class function FromImm(const AValue: Double): TSSAOperand; overload; static;
    class function FromVar(const AVar: TSSAVar): TSSAOperand; static;
    class function FromData(const AIndex: Integer): TSSAOperand; static;
    class function FromGlobal(const AIndex: Integer): TSSAOperand; static;
    class function FromImport(const AIndex: Integer): TSSAOperand; static;
    class function FromFunc(const AIndex: Integer): TSSAOperand; static;
    class function FromBlock(const AIndex: Integer): TSSAOperand; static;
    class function FromLocalIndex(const AIndex: Integer): TSSAOperand; static;
    
    function IsValid(): Boolean;
    function ToString(): string;
  end;
  TSSAInstrKind = (
    sikNop,
    
    // Assignment
    sikAssign,        // dest := op1
    
    // Arithmetic
    sikAdd,           // dest := op1 + op2
    sikSub,           // dest := op1 - op2
    sikMul,           // dest := op1 * op2
    sikDiv,           // dest := op1 / op2
    sikMod,           // dest := op1 mod op2
    sikNeg,           // dest := -op1
    // Float arithmetic
    sikFAdd,          // dest := float(op1 + op2)
    sikFSub,          // dest := float(op1 - op2)
    sikFMul,          // dest := float(op1 * op2)
    sikFDiv,          // dest := float(op1 / op2)
    sikFNeg,          // dest := float(-op1)
    
    // Type conversion
    sikIntToFloat,    // dest := float64(int op1)  — CVTSI2SD
    sikFloatToInt,    // dest := int(float64 op1)  — CVTTSD2SI
    
    // Bitwise
    sikBitAnd,        // dest := op1 and op2
    sikBitOr,         // dest := op1 or op2
    sikBitXor,        // dest := op1 xor op2
    sikBitNot,        // dest := not op1
    sikShl,           // dest := op1 shl op2
    sikShr,           // dest := op1 shr op2
    
    // Comparison (result is 0 or 1)
    sikCmpEq,         // dest := op1 = op2
    sikCmpNe,         // dest := op1 <> op2
    sikCmpLt,         // dest := op1 < op2
    sikCmpLe,         // dest := op1 <= op2
    sikCmpGt,         // dest := op1 > op2
    sikCmpGe,         // dest := op1 >= op2
    // Float Comparison (UCOMISD-based, result is 0 or 1)
    sikFCmpEq,        // dest := float(op1) = float(op2)
    sikFCmpNe,        // dest := float(op1) <> float(op2)
    sikFCmpLt,        // dest := float(op1) < float(op2)
    sikFCmpLe,        // dest := float(op1) <= float(op2)
    sikFCmpGt,        // dest := float(op1) > float(op2)
    sikFCmpGe,        // dest := float(op1) >= float(op2)
    
    // Memory
    sikLoad,          // dest := mem[op1]
    sikStore,         // mem[op1] := op2
    sikAddressOf,     // dest := @op1
    sikFieldAddr,     // dest := @(op1.field) - field offset in Op2.ImmInt
    sikIndexAddr,     // dest := @(op1[op2]) - element size in CallTarget.ImmInt
    
    // Control flow
    sikJump,          // goto block
    sikJumpIf,        // if op1 then goto block
    sikJumpIfNot,     // if not op1 then goto block
    
    // Phi node (SSA join point)
    sikPhi,           // dest := phi(op1, op2, ...)
    
    // Call
    sikCall,          // call func(args)
    sikCallAssign,    // dest := call func(args)
    
    // Indirect call (via function pointer)
    sikFuncAddr,          // dest := @func
    sikIndirectCall,      // call [op1](args)
    sikIndirectCallAssign,// dest := call [op1](args)
    
    // Return
    sikReturn,        // return
    sikReturnValue,   // return op1
    
    // Set operations
    sikSetLiteral,    // dest := {elements...}
    sikSetUnion,      // dest := op1 + op2
    sikSetDiff,       // dest := op1 - op2
    sikSetInter,      // dest := op1 * op2
    sikSetIn,         // dest := op1 in op2
    sikSetEq,         // dest := op1 = op2
    sikSetNe,         // dest := op1 <> op2
    sikSetSubset,     // dest := op1 <= op2
    sikSetSuperset,   // dest := op1 >= op2
    
    // Variadic intrinsics
    sikVaCount,       // dest := VaCount_()
    sikVaArgAt       // dest := VaArgAt_(index, type)

    // Syscall intrinsics (Linux)
  );

  //============================================================================
  // TSSAPhiEntry - Single entry in a phi node
  //============================================================================
  TSSAPhiEntry = record
    BlockIndex: Integer;    // Predecessor block
    Var_: TSSAVar;       // Variable from that block
  end;

  //============================================================================
  // TSSAInstr - Single SSA instruction
  //============================================================================
  TSSAInstr = record
    Kind: TSSAInstrKind;
    Dest: TSSAVar;
    Op1: TSSAOperand;
    Op2: TSSAOperand;
    
    // For phi nodes
    PhiEntries: TArray<TSSAPhiEntry>;
    
    // For calls
    CallTarget: TSSAOperand;
    CallArgs: TArray<TSSAOperand>;
    
    // For set literals
    SetElements: TArray<Integer>;  // Element values for sikSetLiteral
    SetTypeIndex: Integer;         // Type index for set operations
    SetLowBound: Integer;          // Low bound of set type
    SetStorageSize: Integer;       // Storage size (1, 2, 4, or 8)
    
    // Source location (for debugging)
    SourceLine: Integer;
    SourceColumn: Integer;
    SourceFile: string;
    
    // For sikVaArgAt
    VaArgType: TValueType;  // Type to read vararg as
    // For sized memory access (field loads/stores)
    MemSize: Integer;            // 0=default 8 bytes, 1/2/4/8=explicit size
    MemIsFloat: Boolean;         // True for float32/float64 field access
  end;

  //============================================================================
  // TSSABlock - Basic block containing SSA instructions
  //============================================================================
  TSSABlock = class(TGnyBaseObject)
  private
    FBlockId: Integer;
    FBlockName: string;
    FInstructions: TList<TSSAInstr>;
    FPredecessors: TList<Integer>;
    FSuccessors: TList<Integer>;
    
    // Dominator tree information
    FImmediateDominator: Integer;  // -1 for entry block
    FDominanceFrontier: TList<Integer>;
    FDominatedBlocks: TList<Integer>;  // Blocks immediately dominated by this block
    
    // Variables defined in this block (for phi insertion)
    FDefinedVars: TList<string>;
    
    // Source location tracking (for debugger)
    FCurrentSourceLine: Integer;
    FCurrentSourceColumn: Integer;
    FCurrentSourceFile: string;
    
  public
    constructor Create(const ABlockId: Integer; const ABlockName: string); reintroduce;
    destructor Destroy(); override;
    
    procedure AddInstruction(const AInstr: TSSAInstr);
    procedure InsertInstructionAt(const AIndex: Integer; const AInstr: TSSAInstr);
    procedure AddPredecessor(const ABlockId: Integer);
    procedure AddSuccessor(const ABlockId: Integer);
    procedure AddDefinedVar(const AVarName: string);
    procedure SetSourceLocation(const ALine: Integer; const AColumn: Integer; const AFile: string = '');
    
    function GetBlockId(): Integer;
    function GetBlockName(): string;
    function GetInstructionCount(): Integer;
    function GetInstruction(const AIndex: Integer): TSSAInstr;
    procedure SetInstruction(const AIndex: Integer; const AInstr: TSSAInstr);
    function GetPredecessorCount(): Integer;
    function GetPredecessor(const AIndex: Integer): Integer;
    function GetSuccessorCount(): Integer;
    function GetSuccessor(const AIndex: Integer): Integer;
    
    // Dominator tree access
    function GetImmediateDominator(): Integer;
    procedure SetImmediateDominator(const ABlockId: Integer);
    function GetDominanceFrontierCount(): Integer;
    function GetDominanceFrontier(const AIndex: Integer): Integer;
    procedure AddDominanceFrontier(const ABlockId: Integer);
    procedure ClearDominanceFrontier();
    function GetDominatedBlockCount(): Integer;
    function GetDominatedBlock(const AIndex: Integer): Integer;
    procedure AddDominatedBlock(const ABlockId: Integer);
    function GetDefinedVarCount(): Integer;
    function GetDefinedVar(const AIndex: Integer): string;
    function HasDefinedVar(const AVarName: string): Boolean;
    
    procedure Clear();
  end;

  //============================================================================
  // TSSALocalInfo - Local variable metadata
  //============================================================================
  TSSALocalInfo = record
    LocalName: string;
    LocalTypeRef: TTypeRef;  // Supports primitive and composite types
    LocalSize: Integer;         // Size in bytes (for composite types)
    LocalAlignment: Integer;    // Alignment in bytes (for ABI classification)
    IsParam: Boolean;
    IsByRef: Boolean;
    IsManaged: Boolean;         // True for string types that need cleanup
  end;

  //============================================================================
  // TSSAExceptionScope - Exception region metadata for Backend SCOPE_TABLE
  //============================================================================
  TSSAExceptionScope = record
    TryBlockIndex: Integer;        // Block where try starts
    TryEndBlockIndex: Integer;     // Block where try body ends (before except/finally)
    ExceptBlockIndex: Integer;     // Block where except handler starts (-1 if none)
    FinallyBlockIndex: Integer;    // Block where finally handler starts (-1 if none)
    EndBlockIndex: Integer;        // Block after entire try construct
  end;

  //============================================================================
  // TSSAFunc - Function containing basic blocks
  //============================================================================
  TSSAFunc = class(TGnyBaseObject)
  private
    FFuncName: string;
    FReturnType: TValueType;
    FReturnSize: Integer;
    FReturnAlignment: Integer;
    FIsEntryPoint: Boolean;
    FIsDllEntry: Boolean;
    FIsPublic: Boolean;
    FLinkage: TLinkage;
    FLocals: TList<TSSALocalInfo>;
    FBlocks: TObjectList<TSSABlock>;
    FCurrentBlockIndex: Integer;
    FNextVarVersion: TDictionary<string, Integer>;
    FExceptionScopes: TList<TSSAExceptionScope>;
    FIsVariadic: Boolean;
    
  public
    constructor Create(const AFuncName: string); reintroduce;
    destructor Destroy(); override;
    
    // Setup
    procedure SetReturnType(const AType: TValueType); overload;
    procedure SetReturnType(const AType: TValueType; const ASize: Integer; const AAlignment: Integer); overload;
    procedure SetIsEntryPoint(const AValue: Boolean);
    procedure SetIsDllEntry(const AValue: Boolean);
    procedure SetIsPublic(const AValue: Boolean);
    procedure SetLinkage(const AValue: TLinkage);
    procedure SetIsVariadic(const AValue: Boolean);
    procedure AddLocal(const AName: string; const ATypeRef: TTypeRef; const ASize: Integer; const AAlignment: Integer; const AIsParam: Boolean; const AIsManaged: Boolean = False; const AIsByRef: Boolean = False);
    
    // Block management
    function CreateBlock(const AName: string): Integer;
    procedure SetCurrentBlock(const ABlockIndex: Integer);
    function GetCurrentBlock(): TSSABlock;
    
    // Variable versioning
    function NewVersion(const ABaseName: string): TSSAVar;
    function CurrentVersion(const ABaseName: string): TSSAVar;
    
    // Exception scopes
    procedure AddExceptionScope(const AScope: TSSAExceptionScope);
    function GetExceptionScopeCount(): Integer;
    function GetExceptionScope(const AIndex: Integer): TSSAExceptionScope;
    
    // Getters
    function GetFuncName(): string;
    function GetReturnType(): TValueType;
    function GetReturnSize(): Integer;
    function GetReturnAlignment(): Integer;
    function GetIsEntryPoint(): Boolean;
    function GetIsDllEntry(): Boolean;
    function GetIsPublic(): Boolean;
    function GetLinkage(): TLinkage;
    function GetIsVariadic(): Boolean;
    function GetLocalCount(): Integer;
    function GetLocal(const AIndex: Integer): TSSALocalInfo;
    function GetBlockCount(): Integer;
    function GetBlock(const AIndex: Integer): TSSABlock;
    
    procedure Clear();
  end;

  //============================================================================
  // TSSAPassKind - Types of optimization passes
  //============================================================================
  TSSAPassKind = (
    spkConstantFolding,
    spkConstantPropagation,
    spkDeadCodeElimination,
    spkCommonSubexprElim,
    spkCopyPropagation,
    spkStringCleanup          // Insert Pax_StrRelease calls before returns
  );

  //============================================================================
  // TSSAPass - Abstract base class for optimization passes
  //============================================================================
  TSSAPass = class abstract(TGnyBaseObject)
  private
    FPassKind: TSSAPassKind;
    FPassName: string;
    FMinLevel: Integer;
    
  public
    constructor Create(const APassKind: TSSAPassKind; const APassName: string; const AMinLevel: Integer = 1); reintroduce;
    
    procedure Run(const AFunc: TSSAFunc); virtual; abstract;
    
    function GetPassKind(): TSSAPassKind;
    function GetPassName(): string;
    function GetMinLevel(): Integer;
  end;

  //============================================================================
  // TSSAConstantFolding - Fold constant expressions
  //============================================================================
  TSSAConstantFolding = class(TSSAPass)
  public
    constructor Create(); reintroduce;
    procedure Run(const AFunc: TSSAFunc); override;
  end;

  //============================================================================
  // TSSAConstantPropagation - Propagate constants through variables
  //============================================================================
  TSSAConstantPropagation = class(TSSAPass)
  public
    constructor Create(); reintroduce;
    procedure Run(const AFunc: TSSAFunc); override;
  end;

  //============================================================================
  // TSSADeadCodeElimination - Remove unused instructions
  //============================================================================
  TSSADeadCodeElimination = class(TSSAPass)
  public
    constructor Create(); reintroduce;
    procedure Run(const AFunc: TSSAFunc); override;
  end;

  //============================================================================
  // TSSACopyPropagation - Replace copies with original values
  //============================================================================
  TSSACopyPropagation = class(TSSAPass)
  public
    constructor Create(); reintroduce;
    procedure Run(const AFunc: TSSAFunc); override;
  end;

  //============================================================================
  // TSSACommonSubexprElim - Eliminate redundant computations
  //============================================================================
  TSSACommonSubexprElim = class(TSSAPass)
  public
    constructor Create(); reintroduce;
    procedure Run(const AFunc: TSSAFunc); override;
  end;

  //============================================================================
  // TSSAStringCleanup - Insert Pax_StrRelease calls before returns
  //============================================================================
  TSSAStringCleanup = class(TSSAPass)
  private
    FSSABuilder: TSSABuilder;
    FIR: TIR;
  public
    constructor Create(const ASSABuilder: TSSABuilder; const AIR: TIR); reintroduce;
    procedure Run(const AFunc: TSSAFunc); override;
  end;

  //============================================================================
  // TSSABuilder - Main SSA builder: converts high-level IR to SSA
  //============================================================================
  TSSABuilder = class(TGnyBaseObject)
  private
    FOptions: TSSAOptions;
    FFunctions: TObjectList<TSSAFunc>;
    FCurrentFuncIndex: Integer;
    FPasses: TObjectList<TSSAPass>;
    
    FStrReleaseFuncIdx: Integer;  // Index of Pax_StrRelease function for string cleanup
    FFreMemFuncIdx: Integer;     // Index of Gny_FreeMem for raw pointer cleanup
    FDynFreeFuncIdx: Integer;    // Index of Gny_DynFree for dynamic array cleanup
    FReportLeaksFuncIdx: Integer;  // Index of Pax_ReportLeaks function (debug only)
    FReleaseOnDetachFuncIdx: Integer;  // Index of Gny_ReleaseOnDetach for DLL cleanup
    FExpressionCache: TDictionary<Integer, TSSAVar>;  // Cache for converted expressions per function
    
    // Internal conversion helpers
    procedure ConvertStatements(
      const AIR: TIR;
      const AFuncIndex: Integer;
      const ASSAFunc: TSSAFunc
    );
    function ConvertExpression(
      const AIR: TIR;
      const AExprIndex: Integer;
      const ASSAFunc: TSSAFunc
    ): TSSAVar;
    function FindImportByName(const AIR: TIR; const AName: string): Integer;
    function FindImportBySignature(
      const AIR: TIR;
      const AName: string;
      const AArgTypes: TArray<TTypeRef>
    ): Integer;
    function FindLocalFuncByName(const AIR: TIR; const AName: string): Integer;
    function FindLocalFuncBySignature(
      const AIR: TIR;
      const AName: string;
      const AArgTypes: TArray<TTypeRef>
    ): Integer;
    
    // SSA construction algorithms
    procedure ComputeDominators(const AFunc: TSSAFunc);
    procedure ComputeDominanceFrontiers(const AFunc: TSSAFunc);
    procedure InsertPhiNodes(const AFunc: TSSAFunc);
    procedure RenameVariables(const AFunc: TSSAFunc);
    
  public
    constructor Create(); override;
    destructor Destroy(); override;
    
    // Configuration
    procedure SetOptions(const AOptions: TSSAOptions);
    function GetOptions(): TSSAOptions;
    
    // Build from high-level IR
    procedure BuildFrom(const AIR: TIR; const ADebug: Boolean);
    
    
    // Optimization
    procedure Optimize(const ALevel: Integer);
    procedure RemoveUnreferencedFunctions();
    procedure AddPass(const APass: TSSAPass);
    
    // Debug
    function DumpSSA(): string;
    procedure EliminatePhiNodes(const AFunc: TSSAFunc);
    procedure ClearPasses();
    
    
    // Query
    function GetFunctionCount(): Integer;
    function GetFunction(const AIndex: Integer): TSSAFunc;
    function GetStrReleaseFuncIdx(): Integer;
    function GetFreeMemFuncIdx(): Integer;
    function GetDynFreeFuncIdx(): Integer;
    function GetReportLeaksFuncIdx(): Integer;
    function GetReleaseOnDetachFuncIdx(): Integer;
    
    // Reset
    procedure Clear();
  end;

implementation

type
  // Loop context for break/continue support in SSA lowering
  TSSALoopKind = (slkWhile, slkFor, slkRepeat);
  TSSALoopCtx = record
    Kind: TSSALoopKind;
    HeaderBlock: Integer;   // while/for: header (condition), repeat: body start
    LatchBlock: Integer;    // while: header, for: -1 (inline increment), repeat: latch
    EndBlock: Integer;      // exit target for break
    ForVar: string;         // for loops: counter variable name
    ForDownTo: Boolean;     // for loops: direction flag
  end;

//==============================================================================
// TSSAOptions
//==============================================================================

class function TSSAOptions.Debug(): TSSAOptions;
begin
  Result.BuildMode := bmDebug;
end;

class function TSSAOptions.Release(): TSSAOptions;
begin
  Result.BuildMode := bmRelease;
end;

//==============================================================================
// TSSAVar
//==============================================================================

class function TSSAVar.Create(const ABaseName: string; const AVersion: Integer): TSSAVar;
begin
  Result.BaseName := ABaseName;
  Result.Version := AVersion;
end;

class function TSSAVar.None(): TSSAVar;
begin
  Result.BaseName := '';
  Result.Version := -1;
end;

function TSSAVar.IsValid(): Boolean;
begin
  Result := (BaseName <> '') and (Version >= 0);
end;

function TSSAVar.ToString(): string;
begin
  if IsValid() then
    Result := Format('%s_%d', [BaseName, Version])
  else
    Result := '<invalid>';
end;

class operator TSSAVar.Equal(const A: TSSAVar; const B: TSSAVar): Boolean;
begin
  Result := (A.BaseName = B.BaseName) and (A.Version = B.Version);
end;

class operator TSSAVar.NotEqual(const A: TSSAVar; const B: TSSAVar): Boolean;
begin
  Result := not (A = B);
end;

//==============================================================================
// TSSAOperand
//==============================================================================

class function TSSAOperand.None(): TSSAOperand;
begin
  Result := Default(TSSAOperand);
  Result.Kind := sokNone;
end;

class function TSSAOperand.FromImm(const AValue: Int64): TSSAOperand;
begin
  Result := Default(TSSAOperand);
  Result.Kind := sokImmediate;
  Result.ImmInt := AValue;
end;

class function TSSAOperand.FromImm(const AValue: Double): TSSAOperand;
begin
  Result := Default(TSSAOperand);
  Result.Kind := sokImmediate;
  Result.ImmFloat := AValue;
end;

class function TSSAOperand.FromVar(const AVar: TSSAVar): TSSAOperand;
begin
  Result := Default(TSSAOperand);
  Result.Kind := sokVar;
  Result.Var_ := AVar;
end;

class function TSSAOperand.FromData(const AIndex: Integer): TSSAOperand;
begin
  Result := Default(TSSAOperand);
  Result.Kind := sokData;
  Result.DataIndex := AIndex;
end;

class function TSSAOperand.FromGlobal(const AIndex: Integer): TSSAOperand;
begin
  Result := Default(TSSAOperand);
  Result.Kind := sokGlobal;
  Result.GlobalIndex := AIndex;
end;

class function TSSAOperand.FromImport(const AIndex: Integer): TSSAOperand;
begin
  Result := Default(TSSAOperand);
  Result.Kind := sokImport;
  Result.ImportIndex := AIndex;
end;

class function TSSAOperand.FromFunc(const AIndex: Integer): TSSAOperand;
begin
  Result := Default(TSSAOperand);
  Result.Kind := sokFunc;
  Result.FuncIndex := AIndex;
end;

class function TSSAOperand.FromBlock(const AIndex: Integer): TSSAOperand;
begin
  Result := Default(TSSAOperand);
  Result.Kind := sokBlock;
  Result.BlockIndex := AIndex;
end;

class function TSSAOperand.FromLocalIndex(const AIndex: Integer): TSSAOperand;
begin
  Result := Default(TSSAOperand);
  Result.Kind := sokLocalIndex;
  Result.LocalIndex := AIndex;
end;

function TSSAOperand.IsValid(): Boolean;
begin
  Result := Kind <> sokNone;
end;

function TSSAOperand.ToString(): string;
begin
  case Kind of
    sokNone: Result := 'none';
    sokImmediate:
    begin
      if ImmFloat <> 0.0 then
        Result := FloatToStr(ImmFloat)
      else
        Result := IntToStr(ImmInt);
    end;
    sokVar: Result := Var_.ToString();
    sokData: Result := Format('data_%d', [DataIndex]);
    sokGlobal: Result := Format('global_%d', [GlobalIndex]);
    sokImport: Result := Format('import_%d', [ImportIndex]);
    sokFunc: Result := Format('func_%d', [FuncIndex]);
    sokBlock: Result := Format('block_%d', [BlockIndex]);
    sokLocalIndex: Result := Format('local_%d', [LocalIndex]);
  else
    Result := '?';
  end;
end;

//==============================================================================
// TSSABlock
//==============================================================================

constructor TSSABlock.Create(const ABlockId: Integer; const ABlockName: string);
begin
  inherited Create();
  
  FBlockId := ABlockId;
  FBlockName := ABlockName;
  FInstructions := TList<TSSAInstr>.Create();
  FPredecessors := TList<Integer>.Create();
  FSuccessors := TList<Integer>.Create();
  FImmediateDominator := -1;
  FDominanceFrontier := TList<Integer>.Create();
  FDominatedBlocks := TList<Integer>.Create();
  FDefinedVars := TList<string>.Create();
end;

destructor TSSABlock.Destroy();
begin
  FDefinedVars.Free();
  FDominatedBlocks.Free();
  FDominanceFrontier.Free();
  FSuccessors.Free();
  FPredecessors.Free();
  FInstructions.Free();
  
  inherited Destroy();
end;

procedure TSSABlock.AddInstruction(const AInstr: TSSAInstr);
var
  LInstr: TSSAInstr;
begin
  LInstr := AInstr;
  // Auto-stamp source location from block's current tracking state
  if (LInstr.SourceLine = 0) and (FCurrentSourceLine > 0) then
  begin
    LInstr.SourceLine := FCurrentSourceLine;
    LInstr.SourceColumn := FCurrentSourceColumn;
    LInstr.SourceFile := FCurrentSourceFile;
  end;
  FInstructions.Add(LInstr);
end;

procedure TSSABlock.InsertInstructionAt(const AIndex: Integer; const AInstr: TSSAInstr);
var
  LInstr: TSSAInstr;
begin
  LInstr := AInstr;
  if (LInstr.SourceLine = 0) and (FCurrentSourceLine > 0) then
  begin
    LInstr.SourceLine := FCurrentSourceLine;
    LInstr.SourceColumn := FCurrentSourceColumn;
    LInstr.SourceFile := FCurrentSourceFile;
  end;
  FInstructions.Insert(AIndex, LInstr);
end;

procedure TSSABlock.SetSourceLocation(const ALine: Integer; const AColumn: Integer; const AFile: string);
begin
  FCurrentSourceLine := ALine;
  FCurrentSourceColumn := AColumn;
  FCurrentSourceFile := AFile;
end;

procedure TSSABlock.AddPredecessor(const ABlockId: Integer);
begin
  if not FPredecessors.Contains(ABlockId) then
    FPredecessors.Add(ABlockId);
end;

procedure TSSABlock.AddSuccessor(const ABlockId: Integer);
begin
  if not FSuccessors.Contains(ABlockId) then
    FSuccessors.Add(ABlockId);
end;

procedure TSSABlock.AddDefinedVar(const AVarName: string);
begin
  if not FDefinedVars.Contains(AVarName) then
    FDefinedVars.Add(AVarName);
end;

function TSSABlock.GetBlockId(): Integer;
begin
  Result := FBlockId;
end;

function TSSABlock.GetBlockName(): string;
begin
  Result := FBlockName;
end;

function TSSABlock.GetInstructionCount(): Integer;
begin
  Result := FInstructions.Count;
end;

function TSSABlock.GetInstruction(const AIndex: Integer): TSSAInstr;
begin
  Result := FInstructions[AIndex];
end;

function TSSABlock.GetPredecessorCount(): Integer;
begin
  Result := FPredecessors.Count;
end;

function TSSABlock.GetPredecessor(const AIndex: Integer): Integer;
begin
  Result := FPredecessors[AIndex];
end;

function TSSABlock.GetSuccessorCount(): Integer;
begin
  Result := FSuccessors.Count;
end;

function TSSABlock.GetSuccessor(const AIndex: Integer): Integer;
begin
  Result := FSuccessors[AIndex];
end;

procedure TSSABlock.SetInstruction(const AIndex: Integer; const AInstr: TSSAInstr);
begin
  FInstructions[AIndex] := AInstr;
end;

function TSSABlock.GetImmediateDominator(): Integer;
begin
  Result := FImmediateDominator;
end;

procedure TSSABlock.SetImmediateDominator(const ABlockId: Integer);
begin
  FImmediateDominator := ABlockId;
end;

function TSSABlock.GetDominanceFrontierCount(): Integer;
begin
  Result := FDominanceFrontier.Count;
end;

function TSSABlock.GetDominanceFrontier(const AIndex: Integer): Integer;
begin
  Result := FDominanceFrontier[AIndex];
end;

procedure TSSABlock.AddDominanceFrontier(const ABlockId: Integer);
begin
  if not FDominanceFrontier.Contains(ABlockId) then
    FDominanceFrontier.Add(ABlockId);
end;

procedure TSSABlock.ClearDominanceFrontier();
begin
  FDominanceFrontier.Clear();
end;

function TSSABlock.GetDominatedBlockCount(): Integer;
begin
  Result := FDominatedBlocks.Count;
end;

function TSSABlock.GetDominatedBlock(const AIndex: Integer): Integer;
begin
  Result := FDominatedBlocks[AIndex];
end;

procedure TSSABlock.AddDominatedBlock(const ABlockId: Integer);
begin
  if not FDominatedBlocks.Contains(ABlockId) then
    FDominatedBlocks.Add(ABlockId);
end;

function TSSABlock.GetDefinedVarCount(): Integer;
begin
  Result := FDefinedVars.Count;
end;

function TSSABlock.GetDefinedVar(const AIndex: Integer): string;
begin
  Result := FDefinedVars[AIndex];
end;

function TSSABlock.HasDefinedVar(const AVarName: string): Boolean;
begin
  Result := FDefinedVars.Contains(AVarName);
end;

procedure TSSABlock.Clear();
begin
  FInstructions.Clear();
  FPredecessors.Clear();
  FSuccessors.Clear();
  FImmediateDominator := -1;
  FDominanceFrontier.Clear();
  FDominatedBlocks.Clear();
  FDefinedVars.Clear();
end;

//==============================================================================
// TSSAFunc
//==============================================================================

constructor TSSAFunc.Create(const AFuncName: string);
begin
  inherited Create();
  
  FFuncName := AFuncName;
  FReturnType := vtVoid;
  FIsEntryPoint := False;
  FIsDllEntry := False;
  FLocals := TList<TSSALocalInfo>.Create();
  FBlocks := TObjectList<TSSABlock>.Create(True);
  FCurrentBlockIndex := -1;
  FNextVarVersion := TDictionary<string, Integer>.Create();
  FExceptionScopes := TList<TSSAExceptionScope>.Create();
end;

destructor TSSAFunc.Destroy();
begin
  FExceptionScopes.Free();
  FNextVarVersion.Free();
  FBlocks.Free();
  FLocals.Free();
  
  inherited Destroy();
end;

procedure TSSAFunc.SetReturnType(const AType: TValueType);
begin
  FReturnType := AType;
  FReturnSize := 0;
  FReturnAlignment := 0;
end;

procedure TSSAFunc.SetReturnType(const AType: TValueType;
  const ASize: Integer; const AAlignment: Integer);
begin
  FReturnType := AType;
  FReturnSize := ASize;
  FReturnAlignment := AAlignment;
end;

procedure TSSAFunc.SetIsEntryPoint(const AValue: Boolean);
begin
  FIsEntryPoint := AValue;
end;

procedure TSSAFunc.SetIsDllEntry(const AValue: Boolean);
begin
  FIsDllEntry := AValue;
end;

procedure TSSAFunc.SetIsPublic(const AValue: Boolean);
begin
  FIsPublic := AValue;
end;

procedure TSSAFunc.SetLinkage(const AValue: TLinkage);
begin
  FLinkage := AValue;
end;

procedure TSSAFunc.SetIsVariadic(const AValue: Boolean);
begin
  FIsVariadic := AValue;
end;

procedure TSSAFunc.AddLocal(const AName: string; const ATypeRef: TTypeRef; const ASize: Integer; const AAlignment: Integer; const AIsParam: Boolean; const AIsManaged: Boolean; const AIsByRef: Boolean);
var
  LInfo: TSSALocalInfo;
begin
  LInfo.LocalName := AName;
  LInfo.LocalTypeRef := ATypeRef;
  LInfo.LocalSize := ASize;
  LInfo.LocalAlignment := AAlignment;
  LInfo.IsParam := AIsParam;
  LInfo.IsByRef := AIsByRef;
  LInfo.IsManaged := AIsManaged;
  FLocals.Add(LInfo);
  
  // Initialize version counter for this variable
  FNextVarVersion.AddOrSetValue(AName, 0);
end;

function TSSAFunc.CreateBlock(const AName: string): Integer;
var
  LBlock: TSSABlock;
begin
  Result := FBlocks.Count;
  LBlock := TSSABlock.Create(Result, AName);
  FBlocks.Add(LBlock);
end;

procedure TSSAFunc.SetCurrentBlock(const ABlockIndex: Integer);
begin
  FCurrentBlockIndex := ABlockIndex;
end;

function TSSAFunc.GetCurrentBlock(): TSSABlock;
begin
  if (FCurrentBlockIndex < 0) or (FCurrentBlockIndex >= FBlocks.Count) then
    Result := nil
  else
    Result := FBlocks[FCurrentBlockIndex];
end;

function TSSAFunc.NewVersion(const ABaseName: string): TSSAVar;
var
  LVersion: Integer;
begin
  if not FNextVarVersion.TryGetValue(ABaseName, LVersion) then
    LVersion := 0;
    
  Result := TSSAVar.Create(ABaseName, LVersion);
  FNextVarVersion.AddOrSetValue(ABaseName, LVersion + 1);
end;

function TSSAFunc.CurrentVersion(const ABaseName: string): TSSAVar;
var
  LVersion: Integer;
begin
  if FNextVarVersion.TryGetValue(ABaseName, LVersion) then
  begin
    if LVersion > 0 then
      Result := TSSAVar.Create(ABaseName, LVersion - 1)
    else
      Result := TSSAVar.None();
  end
  else
    Result := TSSAVar.None();
end;

function TSSAFunc.GetFuncName(): string;
begin
  Result := FFuncName;
end;

function TSSAFunc.GetReturnType(): TValueType;
begin
  Result := FReturnType;
end;

function TSSAFunc.GetReturnSize(): Integer;
begin
  Result := FReturnSize;
end;

function TSSAFunc.GetReturnAlignment(): Integer;
begin
  Result := FReturnAlignment;
end;

function TSSAFunc.GetIsEntryPoint(): Boolean;
begin
  Result := FIsEntryPoint;
end;

function TSSAFunc.GetIsDllEntry(): Boolean;
begin
  Result := FIsDllEntry;
end;

function TSSAFunc.GetIsPublic(): Boolean;
begin
  Result := FIsPublic;
end;

function TSSAFunc.GetLinkage(): TLinkage;
begin
  Result := FLinkage;
end;

function TSSAFunc.GetIsVariadic(): Boolean;
begin
  Result := FIsVariadic;
end;

function TSSAFunc.GetLocalCount(): Integer;
begin
  Result := FLocals.Count;
end;

function TSSAFunc.GetLocal(const AIndex: Integer): TSSALocalInfo;
begin
  Result := FLocals[AIndex];
end;

function TSSAFunc.GetBlockCount(): Integer;
begin
  Result := FBlocks.Count;
end;

function TSSAFunc.GetBlock(const AIndex: Integer): TSSABlock;
begin
  Result := FBlocks[AIndex];
end;

procedure TSSAFunc.AddExceptionScope(const AScope: TSSAExceptionScope);
begin
  FExceptionScopes.Add(AScope);
end;

function TSSAFunc.GetExceptionScopeCount(): Integer;
begin
  Result := FExceptionScopes.Count;
end;

function TSSAFunc.GetExceptionScope(const AIndex: Integer): TSSAExceptionScope;
begin
  Result := FExceptionScopes[AIndex];
end;

procedure TSSAFunc.Clear();
begin
  FLocals.Clear();
  FBlocks.Clear();
  FNextVarVersion.Clear();
  FExceptionScopes.Clear();
  FCurrentBlockIndex := -1;
end;

//==============================================================================
// TSSAPass
//==============================================================================

constructor TSSAPass.Create(const APassKind: TSSAPassKind; const APassName: string; const AMinLevel: Integer = 1);
begin
  inherited Create();
  
  FPassKind := APassKind;
  FPassName := APassName;
  FMinLevel := AMinLevel;
end;

function TSSAPass.GetPassKind(): TSSAPassKind;
begin
  Result := FPassKind;
end;

function TSSAPass.GetPassName(): string;
begin
  Result := FPassName;
end;

function TSSAPass.GetMinLevel(): Integer;
begin
  Result := FMinLevel;
end;

//==============================================================================
// TSSAConstantFolding
//==============================================================================

constructor TSSAConstantFolding.Create();
begin
  inherited Create(spkConstantFolding, 'Constant Folding');
end;

procedure TSSAConstantFolding.Run(const AFunc: TSSAFunc);
var
  LBlockIdx: Integer;
  LInstrIdx: Integer;
  LBlock: TSSABlock;
  LInstr: TSSAInstr;
  LVal1: Int64;
  LVal2: Int64;
  LResult: Int64;
  LChanged: Boolean;
  LF1: Double;
  LF2: Double;
  LFResult: Double;
begin
  // Iterate all blocks and instructions
  for LBlockIdx := 0 to AFunc.GetBlockCount() - 1 do
  begin
    LBlock := AFunc.GetBlock(LBlockIdx);
    
    for LInstrIdx := 0 to LBlock.GetInstructionCount() - 1 do
    begin
      LInstr := LBlock.GetInstruction(LInstrIdx);
      LChanged := False;
      
      // Check if both operands are immediate constants
      if (LInstr.Op1.Kind = sokImmediate) and (LInstr.Op2.Kind = sokImmediate) then
      begin
        LVal1 := LInstr.Op1.ImmInt;
        LVal2 := LInstr.Op2.ImmInt;
        LResult := 0;
        
        case LInstr.Kind of
          sikAdd:
            begin
              LResult := LVal1 + LVal2;
              LChanged := True;
            end;
          sikSub:
            begin
              LResult := LVal1 - LVal2;
              LChanged := True;
            end;
          sikMul:
            begin
              LResult := LVal1 * LVal2;
              LChanged := True;
            end;
          sikDiv:
            begin
              if LVal2 <> 0 then
              begin
                LResult := LVal1 div LVal2;
                LChanged := True;
              end;
            end;
          sikMod:
            begin
              if LVal2 <> 0 then
              begin
                LResult := LVal1 mod LVal2;
                LChanged := True;
              end;
            end;
          sikBitAnd:
            begin
              LResult := LVal1 and LVal2;
              LChanged := True;
            end;
          sikBitOr:
            begin
              LResult := LVal1 or LVal2;
              LChanged := True;
            end;
          sikBitXor:
            begin
              LResult := LVal1 xor LVal2;
              LChanged := True;
            end;
          sikShl:
            begin
              LResult := LVal1 shl LVal2;
              LChanged := True;
            end;
          sikShr:
            begin
              LResult := LVal1 shr LVal2;
              LChanged := True;
            end;
          sikCmpEq:
            begin
              if LVal1 = LVal2 then LResult := 1 else LResult := 0;
              LChanged := True;
            end;
          sikCmpNe:
            begin
              if LVal1 <> LVal2 then LResult := 1 else LResult := 0;
              LChanged := True;
            end;
          sikCmpLt:
            begin
              if LVal1 < LVal2 then LResult := 1 else LResult := 0;
              LChanged := True;
            end;
          sikCmpLe:
            begin
              if LVal1 <= LVal2 then LResult := 1 else LResult := 0;
              LChanged := True;
            end;
          sikCmpGt:
            begin
              if LVal1 > LVal2 then LResult := 1 else LResult := 0;
              LChanged := True;
            end;
          sikCmpGe:
            begin
              if LVal1 >= LVal2 then LResult := 1 else LResult := 0;
              LChanged := True;
            end;
        end;
        
        // Replace with assignment of constant result
        if LChanged then
        begin
          LInstr.Kind := sikAssign;
          LInstr.Op1 := TSSAOperand.FromImm(LResult);
          LInstr.Op2 := TSSAOperand.None();
          LBlock.SetInstruction(LInstrIdx, LInstr);
        end;
      end
      // Handle unary ops with single immediate operand
      else if (LInstr.Op1.Kind = sokImmediate) and (LInstr.Op2.Kind = sokNone) then
      begin
        LVal1 := LInstr.Op1.ImmInt;
        LResult := 0;
        
        case LInstr.Kind of
          sikNeg:
            begin
              LResult := -LVal1;
              LChanged := True;
            end;
          sikBitNot:
            begin
              LResult := not LVal1;
              LChanged := True;
            end;
        end;
        
        if LChanged then
        begin
          LInstr.Kind := sikAssign;
          LInstr.Op1 := TSSAOperand.FromImm(LResult);
          LBlock.SetInstruction(LInstrIdx, LInstr);
        end;
      end;

      // Float constant folding
      if (not LChanged) and
         (LInstr.Op1.Kind = sokImmediate) and
         (LInstr.Op2.Kind = sokImmediate) and
         (LInstr.Kind in [sikFAdd, sikFSub, sikFMul, sikFDiv, sikFNeg]) then
      begin
        LF1 := LInstr.Op1.ImmFloat;
        LF2 := LInstr.Op2.ImmFloat;
        LFResult := 0.0;

        case LInstr.Kind of
          sikFAdd:
            begin
              LFResult := LF1 + LF2;
              LChanged := True;
            end;
          sikFSub:
            begin
              LFResult := LF1 - LF2;
              LChanged := True;
            end;
          sikFMul:
            begin
              LFResult := LF1 * LF2;
              LChanged := True;
            end;
          sikFDiv:
            begin
              if LF2 <> 0.0 then
              begin
                LFResult := LF1 / LF2;
                LChanged := True;
              end;
            end;
          sikFNeg:
            begin
              LFResult := -LF1;
              LChanged := True;
            end;
        end;

        if LChanged then
        begin
          LInstr.Kind := sikAssign;
          LInstr.Op1 := TSSAOperand.FromImm(LFResult);
          LInstr.Op2 := TSSAOperand.None();
          LBlock.SetInstruction(LInstrIdx, LInstr);
        end;
      end;
    end;
  end;
end;

//==============================================================================
// TSSAConstantPropagation
//==============================================================================

constructor TSSAConstantPropagation.Create();
begin
  inherited Create(spkConstantPropagation, 'Constant Propagation');
end;

procedure TSSAConstantPropagation.Run(const AFunc: TSSAFunc);
var
  LBlockIdx: Integer;
  LInstrIdx: Integer;
  LBlock: TSSABlock;
  LInstr: TSSAInstr;
  LConstants: TDictionary<string, TSSAOperand>;  // Maps var name to constant operand
  LVarKey: string;
  LConstOp: TSSAOperand;
  LChanged: Boolean;
  LArgIdx: Integer;
begin
  LConstants := TDictionary<string, TSSAOperand>.Create();
  try
    // Pass 1: Collect all variables that are assigned constant values
    for LBlockIdx := 0 to AFunc.GetBlockCount() - 1 do
    begin
      LBlock := AFunc.GetBlock(LBlockIdx);
      
      for LInstrIdx := 0 to LBlock.GetInstructionCount() - 1 do
      begin
        LInstr := LBlock.GetInstruction(LInstrIdx);
        
        // Check for: var = immediate
        if (LInstr.Kind = sikAssign) and 
           (LInstr.Dest.IsValid()) and 
           (LInstr.Op1.Kind = sokImmediate) then
        begin
          LVarKey := LInstr.Dest.ToString();
          LConstants.AddOrSetValue(LVarKey, LInstr.Op1);
        end;
      end;
    end;
    
    // Pass 2: Replace variable uses with constants where possible
    for LBlockIdx := 0 to AFunc.GetBlockCount() - 1 do
    begin
      LBlock := AFunc.GetBlock(LBlockIdx);
      
      for LInstrIdx := 0 to LBlock.GetInstructionCount() - 1 do
      begin
        LInstr := LBlock.GetInstruction(LInstrIdx);
        LChanged := False;
        
        // Replace Op1 if it's a known constant
        if (LInstr.Op1.Kind = sokVar) then
        begin
          LVarKey := LInstr.Op1.Var_.ToString();
          if LConstants.TryGetValue(LVarKey, LConstOp) then
          begin
            LInstr.Op1 := LConstOp;
            LChanged := True;
          end;
        end;
        
        // Replace Op2 if it's a known constant
        if (LInstr.Op2.Kind = sokVar) then
        begin
          LVarKey := LInstr.Op2.Var_.ToString();
          if LConstants.TryGetValue(LVarKey, LConstOp) then
          begin
            LInstr.Op2 := LConstOp;
            LChanged := True;
          end;
        end;
        
        // Replace call arguments if they're known constants
        for LArgIdx := 0 to High(LInstr.CallArgs) do
        begin
          if LInstr.CallArgs[LArgIdx].Kind = sokVar then
          begin
            LVarKey := LInstr.CallArgs[LArgIdx].Var_.ToString();
            if LConstants.TryGetValue(LVarKey, LConstOp) then
            begin
              LInstr.CallArgs[LArgIdx] := LConstOp;
              LChanged := True;
            end;
          end;
        end;
        
        if LChanged then
          LBlock.SetInstruction(LInstrIdx, LInstr);
      end;
    end;
    
  finally
    LConstants.Free();
  end;
end;

//==============================================================================
// TSSADeadCodeElimination
//==============================================================================

constructor TSSADeadCodeElimination.Create();
begin
  inherited Create(spkDeadCodeElimination, 'Dead Code Elimination');
end;

procedure TSSADeadCodeElimination.Run(const AFunc: TSSAFunc);
var
  LBlockIdx: Integer;
  LInstrIdx: Integer;
  LBlock: TSSABlock;
  LInstr: TSSAInstr;
  LUsedVars: TDictionary<string, Boolean>;
  LArgIdx: Integer;
  LPhiIdx: Integer;
  LVarKey: string;
  LToRemove: TList<Integer>;
  LI: Integer;
  LIsManagedLocal: Boolean;
begin
  LUsedVars := TDictionary<string, Boolean>.Create();
  try
    // Pass 1: Collect all used variables
    for LBlockIdx := 0 to AFunc.GetBlockCount() - 1 do
    begin
      LBlock := AFunc.GetBlock(LBlockIdx);
      
      for LInstrIdx := 0 to LBlock.GetInstructionCount() - 1 do
      begin
        LInstr := LBlock.GetInstruction(LInstrIdx);
        
        // Mark Op1 as used if it's a variable
        if LInstr.Op1.Kind = sokVar then
          LUsedVars.AddOrSetValue(LInstr.Op1.Var_.ToString(), True);
        
        // Mark Op2 as used if it's a variable
        if LInstr.Op2.Kind = sokVar then
          LUsedVars.AddOrSetValue(LInstr.Op2.Var_.ToString(), True);
        
        // Mark call arguments as used
        for LArgIdx := 0 to High(LInstr.CallArgs) do
        begin
          if LInstr.CallArgs[LArgIdx].Kind = sokVar then
            LUsedVars.AddOrSetValue(LInstr.CallArgs[LArgIdx].Var_.ToString(), True);
        end;
        
        // Mark phi operands as used
        for LPhiIdx := 0 to High(LInstr.PhiEntries) do
          LUsedVars.AddOrSetValue(LInstr.PhiEntries[LPhiIdx].Var_.ToString(), True);
      end;
    end;
    
    // Pass 2: Remove instructions that define unused variables
    for LBlockIdx := 0 to AFunc.GetBlockCount() - 1 do
    begin
      LBlock := AFunc.GetBlock(LBlockIdx);
      LToRemove := TList<Integer>.Create();
      try
        for LInstrIdx := 0 to LBlock.GetInstructionCount() - 1 do
        begin
          LInstr := LBlock.GetInstruction(LInstrIdx);
          
          // Skip instructions that don't define a variable
          if not LInstr.Dest.IsValid() then
            Continue;
          
          // Skip calls and syscalls (have side effects)
          if LInstr.Kind in [sikCall, sikCallAssign] then
            Continue;
          
          // Skip control flow
          if LInstr.Kind in [sikJump, sikJumpIf, sikJumpIfNot, sikReturn, sikReturnValue] then
            Continue;
          
          // Check if the destination is used
          LVarKey := LInstr.Dest.ToString();
          if not LUsedVars.ContainsKey(LVarKey) then
          begin
            // Don't eliminate assignments to managed locals -- the exit
            // cleanup reads their stack slots via sikLoad(localIndex).
            // That load isn't visible to SSA, so DCE would orphan the slot.
            LIsManagedLocal := False;
            for LI := 0 to AFunc.GetLocalCount() - 1 do
            begin
              if (AFunc.GetLocal(LI).LocalName = LInstr.Dest.BaseName) and
                 AFunc.GetLocal(LI).IsManaged then
              begin
                LIsManagedLocal := True;
                Break;
              end;
            end;

            if not LIsManagedLocal then
              LToRemove.Add(LInstrIdx);
          end;
        end;
        
        // Remove dead instructions (in reverse order to preserve indices)
        for LI := LToRemove.Count - 1 downto 0 do
        begin
          // Convert to NOP instead of removing to avoid index issues
          LInstr := LBlock.GetInstruction(LToRemove[LI]);
          LInstr.Kind := sikNop;
          LInstr.Dest := TSSAVar.None();
          LInstr.Op1 := TSSAOperand.None();
          LInstr.Op2 := TSSAOperand.None();
          LBlock.SetInstruction(LToRemove[LI], LInstr);
        end;
        
      finally
        LToRemove.Free();
      end;
    end;
    
  finally
    LUsedVars.Free();
  end;
end;

//==============================================================================
// TSSACopyPropagation
//==============================================================================

constructor TSSACopyPropagation.Create();
begin
  inherited Create(spkCopyPropagation, 'Copy Propagation', 2);  // Level 2
end;

procedure TSSACopyPropagation.Run(const AFunc: TSSAFunc);
var
  LBlockIdx: Integer;
  LInstrIdx: Integer;
  LBlock: TSSABlock;
  LInstr: TSSAInstr;
  LCopies: TDictionary<string, TSSAOperand>;  // Maps dest to source
  LVarKey: string;
  LSourceOp: TSSAOperand;
  LChanged: Boolean;
  LArgIdx: Integer;
begin
  LCopies := TDictionary<string, TSSAOperand>.Create();
  try
    // Pass 1: Collect all copy instructions (x = y where y is a var or immediate)
    for LBlockIdx := 0 to AFunc.GetBlockCount() - 1 do
    begin
      LBlock := AFunc.GetBlock(LBlockIdx);
      
      for LInstrIdx := 0 to LBlock.GetInstructionCount() - 1 do
      begin
        LInstr := LBlock.GetInstruction(LInstrIdx);
        
        // Check for: dest = var (simple copy)
        if (LInstr.Kind = sikAssign) and 
           (LInstr.Dest.IsValid()) and 
           (LInstr.Op1.Kind = sokVar) then
        begin
          LVarKey := LInstr.Dest.ToString();
          LCopies.AddOrSetValue(LVarKey, LInstr.Op1);
        end;
      end;
    end;
    
    // Pass 2: Replace uses of copied variables with their sources
    for LBlockIdx := 0 to AFunc.GetBlockCount() - 1 do
    begin
      LBlock := AFunc.GetBlock(LBlockIdx);
      
      for LInstrIdx := 0 to LBlock.GetInstructionCount() - 1 do
      begin
        LInstr := LBlock.GetInstruction(LInstrIdx);
        LChanged := False;
        
        // Replace Op1 if it's a copied variable
        if (LInstr.Op1.Kind = sokVar) then
        begin
          LVarKey := LInstr.Op1.Var_.ToString();
          if LCopies.TryGetValue(LVarKey, LSourceOp) then
          begin
            LInstr.Op1 := LSourceOp;
            LChanged := True;
          end;
        end;
        
        // Replace Op2 if it's a copied variable
        if (LInstr.Op2.Kind = sokVar) then
        begin
          LVarKey := LInstr.Op2.Var_.ToString();
          if LCopies.TryGetValue(LVarKey, LSourceOp) then
          begin
            LInstr.Op2 := LSourceOp;
            LChanged := True;
          end;
        end;
        
        // Replace call arguments
        for LArgIdx := 0 to High(LInstr.CallArgs) do
        begin
          if LInstr.CallArgs[LArgIdx].Kind = sokVar then
          begin
            LVarKey := LInstr.CallArgs[LArgIdx].Var_.ToString();
            if LCopies.TryGetValue(LVarKey, LSourceOp) then
            begin
              LInstr.CallArgs[LArgIdx] := LSourceOp;
              LChanged := True;
            end;
          end;
        end;
        
        if LChanged then
          LBlock.SetInstruction(LInstrIdx, LInstr);
      end;
    end;
    
  finally
    LCopies.Free();
  end;
end;

//==============================================================================
// TSSACommonSubexprElim
//==============================================================================

constructor TSSACommonSubexprElim.Create();
begin
  inherited Create(spkCommonSubexprElim, 'Common Subexpression Elimination', 2);  // Level 2
end;

procedure TSSACommonSubexprElim.Run(const AFunc: TSSAFunc);
var
  LBlockIdx: Integer;
  LInstrIdx: Integer;
  LBlock: TSSABlock;
  LInstr: TSSAInstr;
  LExprMap: TDictionary<string, TSSAVar>;  // Maps expression key to result var
  LExprBlockMap: TDictionary<string, Integer>;  // Maps expression key to defining block
  LExprKey: string;
  LExistingVar: TSSAVar;
  LDefBlockIdx: Integer;

  // Check whether block ADomIdx dominates block ATargetIdx by walking the
  // immediate-dominator chain from the target up to the root.
  function BlockDominates(const ADomIdx: Integer; const ATargetIdx: Integer): Boolean;
  var
    LCur: Integer;
  begin
    LCur := ATargetIdx;
    while LCur >= 0 do
    begin
      if LCur = ADomIdx then
        Exit(True);
      LCur := AFunc.GetBlock(LCur).GetImmediateDominator();
    end;
    Result := False;
  end;

begin
  LExprMap := TDictionary<string, TSSAVar>.Create();
  LExprBlockMap := TDictionary<string, Integer>.Create();
  try
    for LBlockIdx := 0 to AFunc.GetBlockCount() - 1 do
    begin
      LBlock := AFunc.GetBlock(LBlockIdx);
      
      for LInstrIdx := 0 to LBlock.GetInstructionCount() - 1 do
      begin
        LInstr := LBlock.GetInstruction(LInstrIdx);
        
        // Only handle binary arithmetic/comparison ops
        if not (LInstr.Kind in [sikAdd, sikSub, sikMul, sikDiv, sikMod,
                                sikFAdd, sikFSub, sikFMul, sikFDiv,
                                sikBitAnd, sikBitOr, sikBitXor, sikShl, sikShr,
                                sikCmpEq, sikCmpNe, sikCmpLt, sikCmpLe, sikCmpGt, sikCmpGe]) then
          Continue;
        
        // Build expression key: "op:operand1:operand2"
        LExprKey := Format('%d:%s:%s', [
          Ord(LInstr.Kind),
          LInstr.Op1.ToString(),
          LInstr.Op2.ToString()
        ]);
        
        // Reuse a cached result only when its defining block dominates us
        if LExprMap.TryGetValue(LExprKey, LExistingVar) and
           LExprBlockMap.TryGetValue(LExprKey, LDefBlockIdx) and
           BlockDominates(LDefBlockIdx, LBlockIdx) then
        begin
          // Replace with copy from existing result
          LInstr.Kind := sikAssign;
          LInstr.Op1 := TSSAOperand.FromVar(LExistingVar);
          LInstr.Op2 := TSSAOperand.None();
          LBlock.SetInstruction(LInstrIdx, LInstr);
        end
        else if not LExprMap.ContainsKey(LExprKey) then
        begin
          // Record this expression (first occurrence wins)
          LExprMap.Add(LExprKey, LInstr.Dest);
          LExprBlockMap.Add(LExprKey, LBlockIdx);
        end;
      end;
    end;
    
  finally
    LExprBlockMap.Free();
    LExprMap.Free();
  end;
end;

//==============================================================================
// TSSAStringCleanup
//==============================================================================

constructor TSSAStringCleanup.Create(const ASSABuilder: TSSABuilder; const AIR: TIR);
begin
  inherited Create(spkStringCleanup, 'String Cleanup', 0);  // Level 0 = always run
  FSSABuilder := ASSABuilder;
  FIR := AIR;
end;

procedure TSSAStringCleanup.Run(const AFunc: TSSAFunc);
var
  LBlockIdx: Integer;
  LInstrIdx: Integer;
  LLocalIdx: Integer;
  LGlobalIdx: Integer;
  LBlock: TSSABlock;
  LInstr: TSSAInstr;
  LLocal: TSSALocalInfo;
  LGlobal: TIR.TIRGlobal;
  LManagedLocals: TList<Integer>;  // Indices of managed non-param locals
  LManagedGlobals: TList<Integer>; // Indices of managed globals
  LManagedTemps: TDictionary<string, TSSAVar>;  // Temps from string-returning calls
  LRawTemps: TDictionary<string, Boolean>;      // Temps needing FreeMem instead of StrRelease
  LTempLastUse: TDictionary<string, Integer>;  // Temp name -> instruction index of last use
  LReleaseInstr: TSSAInstr;
  LLoadInstr: TSSAInstr;
  LFuncIdx: Integer;
  LFreeMemIdx: Integer;
  LDynFreeFuncIdx: Integer;
  LTargetFuncIdx: Integer;
  LTargetFunc: TIR.TIRFunc;
  LI: Integer;
  LJ: Integer;
  LIsEntryPoint: Boolean;
  LIsDllEntry: Boolean;
  LIsNoReturnCall: Boolean;
  LReleaseOnDetachFuncIdx: Integer;
  LReasonVar: TSSAVar;
  LParamCount: Integer;
  LTempName: string;
  LTempVar: TSSAVar;
  LUsedVar: string;
  LInsertions: TList<TPair<Integer, TSSAVar>>;
  LPair: TPair<Integer, TSSAVar>;
begin
  // Get function index for Gny_StrRelease
  LFuncIdx := -1;
  LFreeMemIdx := -1;
  LDynFreeFuncIdx := -1;
  if Assigned(FSSABuilder) then
  begin
    LFuncIdx := FSSABuilder.GetStrReleaseFuncIdx();
    LFreeMemIdx := FSSABuilder.GetFreeMemFuncIdx();
    LDynFreeFuncIdx := FSSABuilder.GetDynFreeFuncIdx();
  end;
    
  //----------------------------------------------------------------------------
  // Phase 1: Release managed temps after their last use
  //----------------------------------------------------------------------------
  if ((LFuncIdx >= 0) or (LFreeMemIdx >= 0)) and Assigned(FIR) then
  begin
    for LBlockIdx := 0 to AFunc.GetBlockCount() - 1 do
    begin
      LBlock := AFunc.GetBlock(LBlockIdx);
      LManagedTemps := TDictionary<string, TSSAVar>.Create();
      LRawTemps := TDictionary<string, Boolean>.Create();
      LTempLastUse := TDictionary<string, Integer>.Create();
      try
        // First pass: find managed temps and their last use in this block
        for LInstrIdx := 0 to LBlock.GetInstructionCount() - 1 do
        begin
          LInstr := LBlock.GetInstruction(LInstrIdx);
          
          // Check if this is a call that returns a managed string or raw pointer
          if (LInstr.Kind = sikCallAssign) and (LInstr.CallTarget.Kind = sokFunc) then
          begin
            LTargetFuncIdx := LInstr.CallTarget.FuncIndex;
            if (LTargetFuncIdx >= 0) and (LTargetFuncIdx < FIR.GetFunctionCount()) then
            begin
              LTargetFunc := FIR.GetFunction(LTargetFuncIdx);
              // Runtime string functions return vtPtr but are actually managed strings
              if (LTargetFunc.FuncName = 'Gny_StrFromLiteral') or
                 (LTargetFunc.FuncName = 'Gny_StrConcat') or
                 (LTargetFunc.FuncName = 'Gny_StrFromChar') then
              begin
                // This call returns a string - track the dest temp
                LTempName := LInstr.Dest.BaseName + '_' + IntToStr(LInstr.Dest.Version);
                LManagedTemps.AddOrSetValue(LTempName, LInstr.Dest);
              end
              // Raw pointer temps (need FreeMem, not StrRelease)
              else if (LTargetFunc.FuncName = 'Gny_Utf8') or
                      (LTargetFunc.FuncName = 'Gny_WStrConcat') or
                      (LTargetFunc.FuncName = 'Gny_WStrFromLiteral') then
              begin
                LTempName := LInstr.Dest.BaseName + '_' + IntToStr(LInstr.Dest.Version);
                LManagedTemps.AddOrSetValue(LTempName, LInstr.Dest);
                LRawTemps.AddOrSetValue(LTempName, True);
              end;
            end;
          end;
          
          // Track uses of managed temps in operands.
          // Special case: if a managed temp is the source of an assignment to
          // a local variable (not a _t temp), ownership transfers to the local.
          // Remove the temp from tracking — Phase 2 handles local cleanup at
          // return. Without this, the temp gets released immediately after the
          // assignment, freeing the string the local still points to.
          if (LInstr.Kind = sikAssign) and (LInstr.Op1.Kind = sokVar) then
          begin
            LUsedVar := LInstr.Op1.Var_.BaseName + '_' + IntToStr(LInstr.Op1.Var_.Version);
            if LManagedTemps.ContainsKey(LUsedVar) then
            begin
              if not LInstr.Dest.BaseName.StartsWith('_t') then
              begin
                // Ownership transfer to local — stop tracking this temp
                LManagedTemps.Remove(LUsedVar);
                LTempLastUse.Remove(LUsedVar);
              end
              else
                LTempLastUse.AddOrSetValue(LUsedVar, LInstrIdx);
            end;
          end
          else
          begin
            // General Op1 tracking
            if LInstr.Op1.Kind = sokVar then
            begin
              LUsedVar := LInstr.Op1.Var_.BaseName + '_' + IntToStr(LInstr.Op1.Var_.Version);
              if LManagedTemps.ContainsKey(LUsedVar) then
                LTempLastUse.AddOrSetValue(LUsedVar, LInstrIdx);
            end;
          end;
          if LInstr.Op2.Kind = sokVar then
          begin
            LUsedVar := LInstr.Op2.Var_.BaseName + '_' + IntToStr(LInstr.Op2.Var_.Version);
            if LManagedTemps.ContainsKey(LUsedVar) then
              LTempLastUse.AddOrSetValue(LUsedVar, LInstrIdx);
          end;
          for LJ := 0 to Length(LInstr.CallArgs) - 1 do
          begin
            if LInstr.CallArgs[LJ].Kind = sokVar then
            begin
              LUsedVar := LInstr.CallArgs[LJ].Var_.BaseName + '_' + IntToStr(LInstr.CallArgs[LJ].Var_.Version);
              if LManagedTemps.ContainsKey(LUsedVar) then
                LTempLastUse.AddOrSetValue(LUsedVar, LInstrIdx);
            end;
          end;
        end;
        
        // Second pass: collect insertions (process in reverse order to preserve indices)
        LInsertions := TList<TPair<Integer, TSSAVar>>.Create();
        try
          for LTempName in LTempLastUse.Keys do
          begin
            if LManagedTemps.TryGetValue(LTempName, LTempVar) then
              LInsertions.Add(TPair<Integer, TSSAVar>.Create(LTempLastUse[LTempName], LTempVar));
          end;
          
          // Sort by instruction index descending (insert from end to start)
          LInsertions.Sort(
            TComparer<TPair<Integer, TSSAVar>>.Construct(
              function(const ALeft, ARight: TPair<Integer, TSSAVar>): Integer
              begin
                Result := ARight.Key - ALeft.Key;
              end
            )
          );
          
          // Insert releases after last use
          for LPair in LInsertions do
          begin
            LTempName := LPair.Value.BaseName + '_' + IntToStr(LPair.Value.Version);
            LReleaseInstr := Default(TSSAInstr);
            LReleaseInstr.Kind := sikCall;
            // Raw pointer temps use FreeMem; managed strings use StrRelease
            if LRawTemps.ContainsKey(LTempName) and (LFreeMemIdx >= 0) then
              LReleaseInstr.CallTarget := TSSAOperand.FromFunc(LFreeMemIdx)
            else
              LReleaseInstr.CallTarget := TSSAOperand.FromFunc(LFuncIdx);
            SetLength(LReleaseInstr.CallArgs, 1);
            LReleaseInstr.CallArgs[0] := TSSAOperand.FromVar(LPair.Value);
            LBlock.InsertInstructionAt(LPair.Key + 1, LReleaseInstr);
          end;
        finally
          LInsertions.Free();
        end;
      finally
        LTempLastUse.Free();
        LRawTemps.Free();
        LManagedTemps.Free();
      end;
    end;
  end;
  
  //----------------------------------------------------------------------------
  // Phase 2: Collect managed locals and globals for cleanup at return
  //----------------------------------------------------------------------------
  LManagedLocals := TList<Integer>.Create();
  LManagedGlobals := TList<Integer>.Create();
  try
    for LLocalIdx := 0 to AFunc.GetLocalCount() - 1 do
    begin
      LLocal := AFunc.GetLocal(LLocalIdx);
      if LLocal.IsManaged and (not LLocal.IsParam) then
        LManagedLocals.Add(LLocalIdx);
    end;
    
    // Check if this is an entry point that needs global cleanup
    LIsEntryPoint := AFunc.GetIsEntryPoint();
    LIsDllEntry := AFunc.GetIsDllEntry();
    
    // Collect managed globals for entry points
    if (LIsEntryPoint or LIsDllEntry) and Assigned(FIR) then
    begin
      for LGlobalIdx := 0 to FIR.GetGlobalCount() - 1 do
      begin
        LGlobal := FIR.GetGlobal(LGlobalIdx);
        if FIR.IsStringType(LGlobal.GlobalTypeRef) then
          LManagedGlobals.Add(LGlobalIdx);
      end;
    end;
    
    // Check if there's anything to do
    // Entry points may still need to report leaks even with no managed vars
    if (LManagedLocals.Count = 0) and (LManagedGlobals.Count = 0) then
    begin
      // Nothing to clean up - but EXE entry points may still report leaks
      if not (LIsEntryPoint and Assigned(FSSABuilder) and (FSSABuilder.GetReportLeaksFuncIdx() >= 0)) then
        Exit;
    end
    else if LFuncIdx < 0 then
      Exit;  // Have managed vars but no Pax_StrRelease - cannot emit cleanup
    
    // Iterate all blocks to find return instructions
    for LBlockIdx := 0 to AFunc.GetBlockCount() - 1 do
    begin
      LBlock := AFunc.GetBlock(LBlockIdx);
      LInstrIdx := 0;
      
      while LInstrIdx < LBlock.GetInstructionCount() do
      begin
        LInstr := LBlock.GetInstruction(LInstrIdx);
        
        // Check for return instructions OR noreturn calls (block ends with call, no successors)
        // Also detect Gny_Halt which calls ExitProcess internally
        LIsNoReturnCall := False;
        if (LInstr.Kind = sikCall) then
        begin
          if (LBlock.GetSuccessorCount() = 0) and
             (LInstrIdx = LBlock.GetInstructionCount() - 1) then
            LIsNoReturnCall := True
          else if (LInstr.CallTarget.Kind = sokFunc) and Assigned(FIR) then
          begin
            LTargetFuncIdx := LInstr.CallTarget.FuncIndex;
            if (LTargetFuncIdx >= 0) and (LTargetFuncIdx < FIR.GetFunctionCount()) then
              LIsNoReturnCall := FIR.GetFunction(LTargetFuncIdx).FuncName = 'Gny_Halt';
          end;
        end;
        
        if (LInstr.Kind in [sikReturn, sikReturnValue]) or LIsNoReturnCall then
        begin
          // Insert Gny_StrRelease/Gny_DynFree calls for each managed local BEFORE the return/noreturn call
          for LI := 0 to LManagedLocals.Count - 1 do
          begin
            LLocal := AFunc.GetLocal(LManagedLocals[LI]);

            // Determine cleanup function: dynarray → DynFree, wstring → FreeMem, string → StrRelease
            LTargetFuncIdx := LFuncIdx;  // Default: Gny_StrRelease
            if Assigned(FIR) then
            begin
              if FIR.IsWStringType(LLocal.LocalTypeRef) then
                LTargetFuncIdx := LFreeMemIdx
              else if (not LLocal.LocalTypeRef.IsPrimitive) and
                 (LLocal.LocalTypeRef.TypeIndex >= 0) and
                 (LLocal.LocalTypeRef.TypeIndex < FIR.GetTypeCount()) and
                 (FIR.GetTypeEntry(LLocal.LocalTypeRef.TypeIndex).Kind = TIR.TIRTypeKind.tkDynArray) then
                LTargetFuncIdx := LDynFreeFuncIdx;
            end;

            if LTargetFuncIdx < 0 then
              Continue;

            // Load the local value first (bypasses SSA versioning to get actual stack value)
            LLoadInstr := Default(TSSAInstr);
            LLoadInstr.Kind := sikLoad;
            LLoadInstr.Dest := AFunc.NewVersion('_t');
            LLoadInstr.Op1 := TSSAOperand.FromLocalIndex(LManagedLocals[LI]);
            LBlock.InsertInstructionAt(LInstrIdx, LLoadInstr);
            Inc(LInstrIdx);
            
            // Create call to cleanup function(loadedValue)
            LReleaseInstr := Default(TSSAInstr);
            LReleaseInstr.Kind := sikCall;
            LReleaseInstr.CallTarget := TSSAOperand.FromFunc(LTargetFuncIdx);
            SetLength(LReleaseInstr.CallArgs, 1);
            LReleaseInstr.CallArgs[0] := TSSAOperand.FromVar(LLoadInstr.Dest);
            
            // Insert before the return instruction
            LBlock.InsertInstructionAt(LInstrIdx, LReleaseInstr);
            Inc(LInstrIdx);
          end;
          
          // For entry points, also release managed globals
          // DLL entry uses Gny_ReleaseOnDetach to check fdwReason before releasing
          if LIsEntryPoint then
          begin
            // EXE entry: unconditionally release all managed globals
            for LI := 0 to LManagedGlobals.Count - 1 do
            begin
              // Load the global value first
              LLoadInstr := Default(TSSAInstr);
              LLoadInstr.Kind := sikLoad;
              LLoadInstr.Dest := AFunc.NewVersion('_t');
              LLoadInstr.Op1 := TSSAOperand.FromGlobal(LManagedGlobals[LI]);
              LBlock.InsertInstructionAt(LInstrIdx, LLoadInstr);
              Inc(LInstrIdx);
              
              // Create call to Gny_StrRelease(globalValue)
              LReleaseInstr := Default(TSSAInstr);
              LReleaseInstr.Kind := sikCall;
              LReleaseInstr.CallTarget := TSSAOperand.FromFunc(LFuncIdx);
              SetLength(LReleaseInstr.CallArgs, 1);
              LReleaseInstr.CallArgs[0] := TSSAOperand.FromVar(LLoadInstr.Dest);
              
              LBlock.InsertInstructionAt(LInstrIdx, LReleaseInstr);
              Inc(LInstrIdx);
            end;
            
            // Call Gny_ReportLeaks after all cleanup (debug mode only)
            // Only for EXE entry points, not DLL entries (DllMain fires on
            // both ATTACH and DETACH, which would produce duplicate reports)
            // Skip if the noreturn call is Gny_Halt (it already calls ReportLeaks)
            if Assigned(FSSABuilder) and (FSSABuilder.GetReportLeaksFuncIdx() >= 0) and (not LIsNoReturnCall) then
            begin
              LReleaseInstr := Default(TSSAInstr);
              LReleaseInstr.Kind := sikCall;
              LReleaseInstr.CallTarget := TSSAOperand.FromFunc(FSSABuilder.GetReportLeaksFuncIdx());
              SetLength(LReleaseInstr.CallArgs, 0);  // No arguments
              LBlock.InsertInstructionAt(LInstrIdx, LReleaseInstr);
              Inc(LInstrIdx);
            end;
          end
          else if LIsDllEntry then
          begin
            // DLL entry: use Gny_ReleaseOnDetach which checks fdwReason
            LReleaseOnDetachFuncIdx := -1;
            if Assigned(FSSABuilder) then
              LReleaseOnDetachFuncIdx := FSSABuilder.GetReleaseOnDetachFuncIdx();
            
            if LReleaseOnDetachFuncIdx >= 0 then
            begin
              // Find fdwReason parameter (2nd parameter, index 1)
              // DllMain signature: DllMain(hinstDLL, fdwReason, lpvReserved)
              LParamCount := 0;
              LReasonVar := TSSAVar.None();
              for LI := 0 to AFunc.GetLocalCount() - 1 do
              begin
                LLocal := AFunc.GetLocal(LI);
                if LLocal.IsParam then
                begin
                  if LParamCount = 1 then  // fdwReason is 2nd param (index 1)
                  begin
                    LReasonVar := TSSAVar.Create(LLocal.LocalName, 0);
                    Break;
                  end;
                  Inc(LParamCount);
                end;
              end;
              
              if LReasonVar.IsValid() then
              begin
                for LI := 0 to LManagedGlobals.Count - 1 do
                begin
                  // Load the global value first
                  LLoadInstr := Default(TSSAInstr);
                  LLoadInstr.Kind := sikLoad;
                  LLoadInstr.Dest := AFunc.NewVersion('_t');
                  LLoadInstr.Op1 := TSSAOperand.FromGlobal(LManagedGlobals[LI]);
                  LBlock.InsertInstructionAt(LInstrIdx, LLoadInstr);
                  Inc(LInstrIdx);
                  
                  // Create call to Gny_ReleaseOnDetach(fdwReason, globalValue)
                  LReleaseInstr := Default(TSSAInstr);
                  LReleaseInstr.Kind := sikCall;
                  LReleaseInstr.CallTarget := TSSAOperand.FromFunc(LReleaseOnDetachFuncIdx);
                  SetLength(LReleaseInstr.CallArgs, 2);
                  LReleaseInstr.CallArgs[0] := TSSAOperand.FromVar(LReasonVar);
                  LReleaseInstr.CallArgs[1] := TSSAOperand.FromVar(LLoadInstr.Dest);
                  
                  LBlock.InsertInstructionAt(LInstrIdx, LReleaseInstr);
                  Inc(LInstrIdx);
                end;
              end;
            end;
          end;
          
          // Skip past the return instruction itself
          Inc(LInstrIdx);
        end
        else
          Inc(LInstrIdx);
      end;
    end;
    
  finally
    LManagedLocals.Free();
    LManagedGlobals.Free();
  end;
end;

//==============================================================================
// TSSABuilder
//==============================================================================

constructor TSSABuilder.Create();
begin
  inherited Create();
  
  FOptions := TSSAOptions.Release();
  FFunctions := TObjectList<TSSAFunc>.Create(True);
  FCurrentFuncIndex := -1;
  FPasses := TObjectList<TSSAPass>.Create(True);
  FExpressionCache := TDictionary<Integer, TSSAVar>.Create();
  
  // Add default optimization passes (order matters!)
  // Level 1: Constant propagation, constant folding, DCE
  // Level 2: + Copy propagation, CSE
  FPasses.Add(TSSAConstantPropagation.Create());   // Level 1
  FPasses.Add(TSSAConstantFolding.Create());       // Level 1
  FPasses.Add(TSSACopyPropagation.Create());       // Level 2
  FPasses.Add(TSSACommonSubexprElim.Create());     // Level 2
  FPasses.Add(TSSACopyPropagation.Create());       // Level 2 - run again to propagate CSE copies
  FPasses.Add(TSSADeadCodeElimination.Create());   // Level 1 (always last)
end;

destructor TSSABuilder.Destroy();
begin
  FExpressionCache.Free();
  FPasses.Free();
  FFunctions.Free();
  
  inherited Destroy();
end;

procedure TSSABuilder.SetOptions(const AOptions: TSSAOptions);
begin
  FOptions := AOptions;
end;

function TSSABuilder.GetOptions(): TSSAOptions;
begin
  Result := FOptions;
end;

procedure TSSABuilder.BuildFrom(const AIR: TIR; const ADebug: Boolean);
var
  LI: Integer;
  LJ: Integer;
  LFunc: TIR.TIRFunc;
  LSSAFunc: TSSAFunc;
  LVar: TIR.TIRVar;
  LVarSize: Integer;
  LVarAlign: Integer;
  LImport: TIR.TIRImport;
  LStr: TIR.TIRString;
  LStrCleanup: TSSAStringCleanup;
begin
  Clear();

  Status('SSA: Building from high-level IR (%d functions)', [AIR.GetFunctionCount()]);
  
  //----------------------------------------------------------------------------
  // Step 1: Initialize import tracking
  //----------------------------------------------------------------------------
  FStrReleaseFuncIdx := -1;  // Initialize to invalid - will search after function conversion
  FFreMemFuncIdx := -1;
  FDynFreeFuncIdx := -1;
  FReportLeaksFuncIdx := -1;
  FReleaseOnDetachFuncIdx := -1;
  for LI := 0 to AIR.GetImportCount() - 1 do
  begin
    LImport := AIR.GetImport(LI);
    Status(ADebug, 'SSA: Import[%d]: %s.%s', [LI, LImport.DllName, LImport.FuncName]);
  end;
  
  //----------------------------------------------------------------------------
  // Step 2: Log string constants
  //----------------------------------------------------------------------------
  for LI := 0 to AIR.GetStringCount() - 1 do
  begin
    LStr := AIR.GetString(LI);
    Status(ADebug, 'SSA: String[%d]: "%s"', [LI, LStr.Value.Replace(#13, '\r').Replace(#10, '\n')]);
  end;
  
  //----------------------------------------------------------------------------
  // Step 3: Convert each function
  //----------------------------------------------------------------------------
  for LI := 0 to AIR.GetFunctionCount() - 1 do
  begin
    LFunc := AIR.GetFunction(LI);
    Status(ADebug, 'SSA: Converting function: %s', [LFunc.FuncName]);
    
    // Create SSA function
    LSSAFunc := TSSAFunc.Create(LFunc.FuncName);
    LSSAFunc.SetReturnType(LFunc.ReturnType, LFunc.ReturnSize, LFunc.ReturnAlignment);
    LSSAFunc.SetIsEntryPoint(LFunc.IsEntryPoint);
    LSSAFunc.SetIsDllEntry(LFunc.IsDllEntry);
    LSSAFunc.SetIsPublic(LFunc.IsPublic);
    LSSAFunc.SetLinkage(LFunc.Linkage);
    LSSAFunc.SetIsVariadic(LFunc.IsVariadic);
    
    // Add params and locals
    for LJ := 0 to LFunc.Vars.Count - 1 do
    begin
      LVar := LFunc.Vars[LJ];
      // Calculate size and alignment for this variable
      if LVar.VarTypeRef.IsPrimitive then
      begin
        LVarSize := 8;   // All primitives use 8 bytes on stack (aligned)
        LVarAlign := 8;  // Primitives align to 8 bytes
      end
      else
      begin
        LVarSize := AIR.GetTypeSize(LVar.VarTypeRef);       // Get composite type size
        LVarAlign := AIR.GetTypeAlignment(LVar.VarTypeRef); // Get composite type alignment
      end;
      LSSAFunc.AddLocal(LVar.VarName, LVar.VarTypeRef, LVarSize, LVarAlign, LVar.IsParam, AIR.IsManagedType(LVar.VarTypeRef), LVar.IsByRef);
    end;
    
    // Create entry block
    LSSAFunc.CreateBlock('entry');
    LSSAFunc.SetCurrentBlock(0);
    
    // Clear expression cache for this function
    FExpressionCache.Clear();
    
    // Convert statements to SSA
    ConvertStatements(AIR, LI, LSSAFunc);
    
    // SSA construction: compute dominators, insert phi nodes, rename
    ComputeDominators(LSSAFunc);
    ComputeDominanceFrontiers(LSSAFunc);
    InsertPhiNodes(LSSAFunc);
    RenameVariables(LSSAFunc);
    
    // Add function to list
    FFunctions.Add(LSSAFunc);
    
    // Track Pax_StrRelease function index for string cleanup pass
    if LFunc.FuncName = 'Gny_StrRelease' then
      FStrReleaseFuncIdx := FFunctions.Count - 1;
    
    // Track Gny_FreeMem function index for raw pointer cleanup
    if LFunc.FuncName = 'Gny_FreeMem' then
      FFreMemFuncIdx := FFunctions.Count - 1;

    // Track Gny_DynFree function index for dynamic array cleanup
    if LFunc.FuncName = 'Gny_DynFree' then
      FDynFreeFuncIdx := FFunctions.Count - 1;
    
    // Track Pax_ReportLeaks function index (debug mode only)
    if LFunc.FuncName = 'Gny_ReportLeaks' then
      FReportLeaksFuncIdx := FFunctions.Count - 1;
    
    // Track Gny_ReleaseOnDetach function index for DLL cleanup
    if LFunc.FuncName = 'Gny_ReleaseOnDetach' then
      FReleaseOnDetachFuncIdx := FFunctions.Count - 1;
  end;
  
  //----------------------------------------------------------------------------
  // Step 4: Run mandatory string cleanup pass
  //----------------------------------------------------------------------------
  if FStrReleaseFuncIdx >= 0 then
  begin
    Status('SSA: Running string cleanup pass');
    LStrCleanup := TSSAStringCleanup.Create(Self, AIR);
    try
      for LI := 0 to FFunctions.Count - 1 do
        LStrCleanup.Run(FFunctions[LI]);
    finally
      LStrCleanup.Free();
    end;
  end;
  
  Status('SSA: Conversion complete (%d functions)', [FFunctions.Count]);
end;

procedure TSSABuilder.ConvertStatements(
  const AIR: TIR;
  const AFuncIndex: Integer;
  const ASSAFunc: TSSAFunc
);
var
  LFunc: TIR.TIRFunc;
  LStmt: TIR.TIRStmt;
  LI: Integer;
  LInstr: TSSAInstr;
  LDestVar: TSSAVar;
  LExprVar: TSSAVar;
  LCondVar: TSSAVar;
  LArgVar: TSSAVar;
  LLeftVar: TSSAVar;
  LRightVar: TSSAVar;
  LTempVar: TSSAVar;
  LDestExprNode: TIR.TIRExprNode;
  LObjectExpr: TIR.TIRExprNode;
  LBlockStack: TStack<Integer>;  // Stack of block indices for control flow
  LForVarStack: TStack<string>;   // Stack of for-loop variable names
  LForDownToStack: TStack<Boolean>; // Stack of for-loop direction flags
  LLoopCtxStack: TStack<TSSALoopCtx>; // Loop context for break/continue
  LLoopCtx: TSSALoopCtx;
  LForVar: string;
  LIsDownTo: Boolean;
  LThenBlock: Integer;
  LElseBlock: Integer;
  LEndBlock: Integer;
  LLoopBlock: Integer;
  LBodyBlock: Integer;
  LLatchBlock: Integer;
  LArgIdx: Integer;
  LFuncIdx: Integer;
  LCallArgs: TArray<TSSAOperand>;
  LCurrentBlockId: Integer;
  LHeaderBlock: Integer;
  LPatchIdx: Integer;
  // Exception handling
  LTryBlock: Integer;
  LExceptBlock: Integer;
  LFinallyBlock: Integer;
  LTryEndBlock: Integer;
  LExcScope: TSSAExceptionScope;
  // Variadic call handling
  LTargetFunc: TIR.TIRFunc;
  LFixedParamCount: Integer;
  LVarArgCount: Integer;
  LJ: Integer;
  LImportIdx: Integer;
  // For by-reference parameter detection in field access
  LIsParam: Boolean;
  LLocalSize: Integer;
  LLocalIdx: Integer;
  LLocalInfo: TSSALocalInfo;
  LByRefInstr: TSSAInstr;
begin
  LFunc := AIR.GetFunction(AFuncIndex);
  LBlockStack := TStack<Integer>.Create();
  LForVarStack := TStack<string>.Create();
  LForDownToStack := TStack<Boolean>.Create();
  LLoopCtxStack := TStack<TSSALoopCtx>.Create();
  try
    //--------------------------------------------------------------------------
    // Inject runtime startup calls at the beginning of entry point functions.
    // EXE entry: InitConsole, InitExceptions, InitCommandLine
    // DLL entry: InitExceptions only (console/cmdline are host responsibility)
    //--------------------------------------------------------------------------
    if LFunc.IsEntryPoint or LFunc.IsDllEntry then
    begin
      SetLength(LCallArgs, 0);

      // Both EXE and DLL need exception TLS init
      LFuncIdx := FindLocalFuncByName(AIR, 'Gny_InitExceptions');
      if LFuncIdx >= 0 then
      begin
        LInstr := Default(TSSAInstr);
        LInstr.Kind := sikCall;
        LInstr.CallArgs := LCallArgs;
        LInstr.CallTarget := TSSAOperand.FromFunc(LFuncIdx);
        ASSAFunc.GetCurrentBlock().AddInstruction(LInstr);
      end;

      // EXE-only init (console + command line)
      if LFunc.IsEntryPoint and (not LFunc.IsDllEntry) then
      begin
        LFuncIdx := FindLocalFuncByName(AIR, 'Gny_InitConsole');
        if LFuncIdx >= 0 then
        begin
          LInstr := Default(TSSAInstr);
          LInstr.Kind := sikCall;
          LInstr.CallArgs := LCallArgs;
          LInstr.CallTarget := TSSAOperand.FromFunc(LFuncIdx);
          ASSAFunc.GetCurrentBlock().AddInstruction(LInstr);
        end;

        LFuncIdx := FindLocalFuncByName(AIR, 'Gny_InitCommandLine');
        if LFuncIdx >= 0 then
        begin
          LInstr := Default(TSSAInstr);
          LInstr.Kind := sikCall;
          LInstr.CallArgs := LCallArgs;
          LInstr.CallTarget := TSSAOperand.FromFunc(LFuncIdx);
          ASSAFunc.GetCurrentBlock().AddInstruction(LInstr);
        end;
      end;
    end;

    for LI := 0 to LFunc.Stmts.Count - 1 do
    begin
      LStmt := LFunc.Stmts[LI];
      
      // Propagate source location to all SSA instructions from this statement
      if LStmt.SourceLine > 0 then
        ASSAFunc.GetCurrentBlock().SetSourceLocation(LStmt.SourceLine, LStmt.SourceColumn, LStmt.SourceFile);

      case LStmt.Kind of
        TIR.TIRStmtKind.skAssign:
          begin
            // Convert source expression
            LExprVar := ConvertExpression(AIR, LStmt.Expr, ASSAFunc);
            
            // Check if destination is an expression (field/index access)
            if LStmt.DestExpr >= 0 then
            begin
              // Get destination expression
              LDestExprNode := AIR.GetExpression(LStmt.DestExpr);
              
              if LDestExprNode.Kind = TIR.TIRExprKind.ekFieldAccess then
              begin
                // Field access: compute address and store
                // Get the inner object expression
                LObjectExpr := AIR.GetExpression(LDestExprNode.ObjectExpr);
                
                // For variable expressions with composite types, we need the address
                if (LObjectExpr.Kind = TIR.TIRExprKind.ekVariable) and 
                   (not LObjectExpr.ResultType.IsPrimitive) then
                begin
                  // Check if this is a parameter passed by reference (composite > 8 bytes)
                  // Win64 ABI: Large structs are passed by pointer, so param value IS the address
                  LIsParam := False;
                  LLocalSize := 0;
                  for LLocalIdx := 0 to ASSAFunc.GetLocalCount() - 1 do
                  begin
                    LLocalInfo := ASSAFunc.GetLocal(LLocalIdx);
                    if LLocalInfo.LocalName = LObjectExpr.VarName then
                    begin
                      LIsParam := LLocalInfo.IsParam;
                      LLocalSize := LLocalInfo.LocalSize;
                      Break;
                    end;
                  end;
                  
                  // Emit AddressOf instruction to get local's/param's stack address
                  LLeftVar := ASSAFunc.NewVersion('_t');
                  LInstr := Default(TSSAInstr);
                  LInstr.Kind := sikAddressOf;
                  LInstr.Dest := LLeftVar;
                  LInstr.Op1 := TSSAOperand.FromVar(ASSAFunc.CurrentVersion(LObjectExpr.VarName));
                  LInstr.Op1.Var_.BaseName := LObjectExpr.VarName;
                  ASSAFunc.GetCurrentBlock().AddInstruction(LInstr);
                  
                  if LIsParam and (LLocalSize > 8) then
                  begin
                    // By-reference parameter: param slot contains pointer to struct
                    // Load the pointer value from the param slot
                    LTempVar := LLeftVar;
                    LLeftVar := ASSAFunc.NewVersion('_t');
                    LInstr := Default(TSSAInstr);
                    LInstr.Kind := sikLoad;
                    LInstr.Dest := LLeftVar;
                    LInstr.Op1 := TSSAOperand.FromVar(LTempVar);
                    ASSAFunc.GetCurrentBlock().AddInstruction(LInstr);
                  end;
                end
                else if (LObjectExpr.Kind = TIR.TIRExprKind.ekUnary) and
                        (LObjectExpr.Op = TIR.TIROpKind.opDeref) then
                begin
                  // For Deref(ptr, TypeName), we want just the pointer value as base.
                  // Don't generate a load - convert only the inner pointer expression.
                  LLeftVar := ConvertExpression(AIR, LObjectExpr.Left, ASSAFunc);
                end
                else
                begin
                  // For other expressions (pointers, etc.), convert normally
                  LLeftVar := ConvertExpression(AIR, LDestExprNode.ObjectExpr, ASSAFunc);
                end;
                
                // Compute field address
                LTempVar := ASSAFunc.NewVersion('_t');
                LInstr := Default(TSSAInstr);
                LInstr.Kind := sikFieldAddr;
                LInstr.Dest := LTempVar;
                LInstr.Op1 := TSSAOperand.FromVar(LLeftVar);
                LInstr.Op2 := TSSAOperand.FromImm(LDestExprNode.FieldOffset);
                LInstr.Op2.FieldName := LDestExprNode.FieldName;
                ASSAFunc.GetCurrentBlock().AddInstruction(LInstr);
                
                // Check if this is a bit field
                if LDestExprNode.BitWidth > 0 then
                begin
                  // Bit field write: read-modify-write
                  // 1. Load current storage unit value
                  LLeftVar := LTempVar;  // Address
                  LRightVar := ASSAFunc.NewVersion('_t');
                  LInstr := Default(TSSAInstr);
                  LInstr.Kind := sikLoad;
                  LInstr.Dest := LRightVar;
                  LInstr.Op1 := TSSAOperand.FromVar(LLeftVar);
                  ASSAFunc.GetCurrentBlock().AddInstruction(LInstr);
                  
                  // 2. Clear target bits: current & ~(mask << BitOffset)
                  // mask = (1 << BitWidth) - 1
                  // clearMask = ~(mask << BitOffset)
                  LTempVar := ASSAFunc.NewVersion('_t');
                  LInstr := Default(TSSAInstr);
                  LInstr.Kind := sikBitAnd;
                  LInstr.Dest := LTempVar;
                  LInstr.Op1 := TSSAOperand.FromVar(LRightVar);
                  LInstr.Op2 := TSSAOperand.FromImm(not (((Int64(1) shl LDestExprNode.BitWidth) - 1) shl LDestExprNode.BitOffset));
                  ASSAFunc.GetCurrentBlock().AddInstruction(LInstr);
                  
                  // 3. Mask new value to BitWidth bits
                  LRightVar := ASSAFunc.NewVersion('_t');
                  LInstr := Default(TSSAInstr);
                  LInstr.Kind := sikBitAnd;
                  LInstr.Dest := LRightVar;
                  LInstr.Op1 := TSSAOperand.FromVar(LExprVar);
                  LInstr.Op2 := TSSAOperand.FromImm((Int64(1) shl LDestExprNode.BitWidth) - 1);
                  ASSAFunc.GetCurrentBlock().AddInstruction(LInstr);
                  
                  // 4. Shift new value left by BitOffset
                  if LDestExprNode.BitOffset > 0 then
                  begin
                    LExprVar := LRightVar;
                    LRightVar := ASSAFunc.NewVersion('_t');
                    LInstr := Default(TSSAInstr);
                    LInstr.Kind := sikShl;
                    LInstr.Dest := LRightVar;
                    LInstr.Op1 := TSSAOperand.FromVar(LExprVar);
                    LInstr.Op2 := TSSAOperand.FromImm(LDestExprNode.BitOffset);
                    ASSAFunc.GetCurrentBlock().AddInstruction(LInstr);
                  end;
                  
                  // 5. OR the shifted value into cleared storage
                  LExprVar := ASSAFunc.NewVersion('_t');
                  LInstr := Default(TSSAInstr);
                  LInstr.Kind := sikBitOr;
                  LInstr.Dest := LExprVar;
                  LInstr.Op1 := TSSAOperand.FromVar(LTempVar);
                  LInstr.Op2 := TSSAOperand.FromVar(LRightVar);
                  ASSAFunc.GetCurrentBlock().AddInstruction(LInstr);
                  
                  // 6. Store the combined value back
                  LInstr := Default(TSSAInstr);
                  LInstr.Kind := sikStore;
                  LInstr.Op1 := TSSAOperand.FromVar(LLeftVar);  // Original address
                  LInstr.Op2 := TSSAOperand.FromVar(LExprVar);
                  ASSAFunc.GetCurrentBlock().AddInstruction(LInstr);
                end
                else
                begin
                  // Normal field: direct store (sized for sub-register fields)
                  LInstr := Default(TSSAInstr);
                  LInstr.Kind := sikStore;
                  LInstr.Op1 := TSSAOperand.FromVar(LTempVar);
                  LInstr.Op2 := TSSAOperand.FromVar(LExprVar);
                  LInstr.MemSize := LDestExprNode.FieldSize;
                  LInstr.MemIsFloat := LDestExprNode.ResultType.IsPrimitive and
                    (LDestExprNode.ResultType.Primitive in [vtFloat32, vtFloat64]);
                  ASSAFunc.GetCurrentBlock().AddInstruction(LInstr);
                end;
              end
              else if LDestExprNode.Kind = TIR.TIRExprKind.ekArrayIndex then
              begin
                // Array index: compute element address and store
                // Get the array expression node
                LObjectExpr := AIR.GetExpression(LDestExprNode.ArrayExpr);
                
                // For variable expressions with composite types (arrays), we need the address
                if (LObjectExpr.Kind = TIR.TIRExprKind.ekVariable) and 
                   (not LObjectExpr.ResultType.IsPrimitive) then
                begin
                  // Dynamic arrays: value IS the data pointer, no addrof needed
                  if (LObjectExpr.ResultType.TypeIndex >= 0) and
                     (AIR.GetTypeEntry(LObjectExpr.ResultType.TypeIndex).Kind = TIR.TIRTypeKind.tkDynArray) then
                  begin
                    LLeftVar := ConvertExpression(AIR, LDestExprNode.ArrayExpr, ASSAFunc);
                  end
                  else
                  begin
                    // Fixed array: emit AddressOf instruction to get local's stack address
                    LLeftVar := ASSAFunc.NewVersion('_t');
                    LInstr := Default(TSSAInstr);
                    LInstr.Kind := sikAddressOf;
                    LInstr.Dest := LLeftVar;
                    LInstr.Op1 := TSSAOperand.FromVar(ASSAFunc.CurrentVersion(LObjectExpr.VarName));
                    LInstr.Op1.Var_.BaseName := LObjectExpr.VarName;
                    ASSAFunc.GetCurrentBlock().AddInstruction(LInstr);
                  end;
                end
                else
                begin
                  // For other expressions (pointers, etc.), convert normally
                  LLeftVar := ConvertExpression(AIR, LDestExprNode.ArrayExpr, ASSAFunc);
                end;
                
                LRightVar := ConvertExpression(AIR, LDestExprNode.IndexExpr, ASSAFunc);
                
                // Compute element address
                LTempVar := ASSAFunc.NewVersion('_t');
                LInstr := Default(TSSAInstr);
                LInstr.Kind := sikIndexAddr;
                LInstr.Dest := LTempVar;
                LInstr.Op1 := TSSAOperand.FromVar(LLeftVar);
                LInstr.Op2 := TSSAOperand.FromVar(LRightVar);
                LInstr.Op2.ElementSize := LDestExprNode.ElementSize;
                ASSAFunc.GetCurrentBlock().AddInstruction(LInstr);
                
                // Store value to element address (sized to element)
                LInstr := Default(TSSAInstr);
                LInstr.Kind := sikStore;
                LInstr.Op1 := TSSAOperand.FromVar(LTempVar);
                LInstr.Op2 := TSSAOperand.FromVar(LExprVar);
                LInstr.MemSize := LDestExprNode.ElementSize;
                LInstr.MemIsFloat := LDestExprNode.ResultType.IsPrimitive and
                  (LDestExprNode.ResultType.Primitive in [vtFloat32, vtFloat64]);
                ASSAFunc.GetCurrentBlock().AddInstruction(LInstr);
              end
              else if (LDestExprNode.Kind = TIR.TIRExprKind.ekUnary) and 
                      (LDestExprNode.Op = TIR.TIROpKind.opDeref) then
              begin
                // Deref: convert pointer expression and store to it
                LLeftVar := ConvertExpression(AIR, LDestExprNode.Left, ASSAFunc);
                
                // Store value to dereferenced address
                LInstr := Default(TSSAInstr);
                LInstr.Kind := sikStore;
                LInstr.Op1 := TSSAOperand.FromVar(LLeftVar);
                LInstr.Op2 := TSSAOperand.FromVar(LExprVar);
                ASSAFunc.GetCurrentBlock().AddInstruction(LInstr);
              end;
            end
            else
            begin
              // Check if destination is a global variable
              LArgIdx := AIR.FindGlobal(LStmt.DestVar);
              if LArgIdx >= 0 then
              begin
                // Global variable - emit store to global address
                LInstr := Default(TSSAInstr);
                LInstr.Kind := sikStore;
                LInstr.Op1 := TSSAOperand.FromGlobal(LArgIdx);
                LInstr.Op2 := TSSAOperand.FromVar(LExprVar);
                ASSAFunc.GetCurrentBlock().AddInstruction(LInstr);
              end
              else
              begin
                // Local variable - assign to new version
                LDestVar := ASSAFunc.NewVersion(LStmt.DestVar);
                
                LInstr := Default(TSSAInstr);
                LInstr.Kind := sikAssign;
                LInstr.Dest := LDestVar;
                LInstr.Op1 := TSSAOperand.FromVar(LExprVar);
                ASSAFunc.GetCurrentBlock().AddInstruction(LInstr);
              end;
            end;
          end;
          
        TIR.TIRStmtKind.skCall:
          begin
            // Convert call arguments
            SetLength(LCallArgs, Length(LStmt.CallArgs));
            for LArgIdx := 0 to High(LStmt.CallArgs) do
            begin
              LArgVar := ConvertExpression(AIR, LStmt.CallArgs[LArgIdx], ASSAFunc);
              LCallArgs[LArgIdx] := TSSAOperand.FromVar(LArgVar);
            end;
            
            LInstr := Default(TSSAInstr);
            LInstr.Kind := sikCall;
            LInstr.CallArgs := LCallArgs;
            
            // Check if this is a local function call first
            LFuncIdx := FindLocalFuncByName(AIR, LStmt.CallTarget);
            if LFuncIdx >= 0 then
            begin
              LInstr.CallTarget := TSSAOperand.FromFunc(LFuncIdx);
              
              // For by-ref params, emit AddressOf and replace arg with address
              LTargetFunc := AIR.GetFunction(LFuncIdx);
              LJ := 0;
              for LArgIdx := 0 to LTargetFunc.Vars.Count - 1 do
              begin
                if LTargetFunc.Vars[LArgIdx].IsParam then
                begin
                  if LTargetFunc.Vars[LArgIdx].IsByRef and (LJ < Length(LCallArgs)) then
                  begin
                    LTempVar := ASSAFunc.NewVersion('_t');
                    LByRefInstr := Default(TSSAInstr);
                    LByRefInstr.Kind := sikAddressOf;
                    LByRefInstr.Dest := LTempVar;
                    LByRefInstr.Op1 := LCallArgs[LJ];
                    ASSAFunc.GetCurrentBlock().AddInstruction(LByRefInstr);
                    LCallArgs[LJ] := TSSAOperand.FromVar(LTempVar);
                  end;
                  Inc(LJ);
                end;
              end;
              LInstr.CallArgs := LCallArgs;

              // For internal variadic functions, prepend vararg count
              if LTargetFunc.IsVariadic then
              begin
                // Count fixed params in target function
                LFixedParamCount := 0;
                for LJ := 0 to LTargetFunc.Vars.Count - 1 do
                  if LTargetFunc.Vars[LJ].IsParam then
                    Inc(LFixedParamCount);
                
                // Calculate vararg count
                LVarArgCount := Length(LStmt.CallArgs) - LFixedParamCount;
                if LVarArgCount < 0 then
                  LVarArgCount := 0;
                
                // Prepend count to args array
                SetLength(LCallArgs, Length(LCallArgs) + 1);
                for LArgIdx := High(LCallArgs) downto 1 do
                  LCallArgs[LArgIdx] := LCallArgs[LArgIdx - 1];
                LCallArgs[0] := TSSAOperand.FromImm(LVarArgCount);
                LInstr.CallArgs := LCallArgs;
              end;
            end
            else
            begin
              LImportIdx := FindImportByName(AIR, LStmt.CallTarget);
              if LImportIdx < 0 then
              begin
                if Assigned(FErrors) then
                  FErrors.Add(esError, ERR_SSA_UNKNOWN_FUNCTION, RSSSAUnknownFunction, [LStmt.CallTarget]);
                Exit;
              end;
              LInstr.CallTarget := TSSAOperand.FromImport(LImportIdx);
            end;
            
            ASSAFunc.GetCurrentBlock().AddInstruction(LInstr);
          end;
          
        TIR.TIRStmtKind.skCallIndirect:
          begin
            // Convert the function pointer expression
            LExprVar := ConvertExpression(AIR, LStmt.IndirectTarget, ASSAFunc);
            
            // Convert call arguments
            SetLength(LCallArgs, Length(LStmt.CallArgs));
            for LArgIdx := 0 to High(LStmt.CallArgs) do
            begin
              LArgVar := ConvertExpression(AIR, LStmt.CallArgs[LArgIdx], ASSAFunc);
              LCallArgs[LArgIdx] := TSSAOperand.FromVar(LArgVar);
            end;
            
            LInstr := Default(TSSAInstr);
            LInstr.Kind := sikIndirectCall;
            LInstr.Op1 := TSSAOperand.FromVar(LExprVar);  // Function pointer
            LInstr.CallArgs := LCallArgs;
            ASSAFunc.GetCurrentBlock().AddInstruction(LInstr);
          end;

        TIR.TIRStmtKind.skReturn:
          begin
            LInstr := Default(TSSAInstr);
            LInstr.Kind := sikReturn;
            ASSAFunc.GetCurrentBlock().AddInstruction(LInstr);
          end;
          
        TIR.TIRStmtKind.skReturnValue:
          begin
            LExprVar := ConvertExpression(AIR, LStmt.Expr, ASSAFunc);
            
            LInstr := Default(TSSAInstr);
            LInstr.Kind := sikReturnValue;
            LInstr.Op1 := TSSAOperand.FromVar(LExprVar);
            ASSAFunc.GetCurrentBlock().AddInstruction(LInstr);
          end;
          
        TIR.TIRStmtKind.skWhenBegin:
          begin
            LCurrentBlockId := ASSAFunc.GetCurrentBlock().GetBlockId();
            
            // Evaluate condition
            LCondVar := ConvertExpression(AIR, LStmt.Expr, ASSAFunc);
            
            // Create then and end blocks
            LThenBlock := ASSAFunc.CreateBlock('if_then');
            LEndBlock := ASSAFunc.CreateBlock('if_end');
            
            // Add edges: current -> then (the false edge will be added later)
            ASSAFunc.GetBlock(LCurrentBlockId).AddSuccessor(LThenBlock);
            ASSAFunc.GetBlock(LThenBlock).AddPredecessor(LCurrentBlockId);
            
            // Jump to then block if condition true
            LInstr := Default(TSSAInstr);
            LInstr.Kind := sikJumpIf;
            LInstr.Op1 := TSSAOperand.FromVar(LCondVar);
            LInstr.Op2 := TSSAOperand.FromBlock(LThenBlock);
            ASSAFunc.GetCurrentBlock().AddInstruction(LInstr);
            
            // Jump to end block if condition false (may be patched to else by skOtherwiseBegin)
            LInstr := Default(TSSAInstr);
            LInstr.Kind := sikJump;
            LInstr.Op1 := TSSAOperand.FromBlock(LEndBlock);
            ASSAFunc.GetCurrentBlock().AddInstruction(LInstr);
            
            // Add edge: current -> end (false path, may be updated if else exists)
            ASSAFunc.GetBlock(LCurrentBlockId).AddSuccessor(LEndBlock);
            ASSAFunc.GetBlock(LEndBlock).AddPredecessor(LCurrentBlockId);
            
            // Push condition block id and end block for later
            LBlockStack.Push(LCurrentBlockId);  // Need this to patch the jump if else exists
            LBlockStack.Push(LEndBlock);
            
            // Continue in then block
            ASSAFunc.SetCurrentBlock(LThenBlock);
          end;
          
        TIR.TIRStmtKind.skOtherwiseBegin:
          begin
            LCurrentBlockId := ASSAFunc.GetCurrentBlock().GetBlockId();
            
            // Pop end block and condition block from stack
            LEndBlock := LBlockStack.Pop();
            LHeaderBlock := LBlockStack.Pop();  // This is the condition block
            
            // Jump to end from current (then) block
            LInstr := Default(TSSAInstr);
            LInstr.Kind := sikJump;
            LInstr.Op1 := TSSAOperand.FromBlock(LEndBlock);
            ASSAFunc.GetCurrentBlock().AddInstruction(LInstr);
            
            // Add edge: then -> end
            ASSAFunc.GetBlock(LCurrentBlockId).AddSuccessor(LEndBlock);
            ASSAFunc.GetBlock(LEndBlock).AddPredecessor(LCurrentBlockId);
            
            // Create else block
            LElseBlock := ASSAFunc.CreateBlock('if_else');
            
            // Patch the condition block's Jump instruction to point to else instead of end
            // The Jump is the last instruction in the condition block
            LPatchIdx := ASSAFunc.GetBlock(LHeaderBlock).GetInstructionCount() - 1;
            LInstr := ASSAFunc.GetBlock(LHeaderBlock).GetInstruction(LPatchIdx);
            if LInstr.Kind = sikJump then
            begin
              LInstr.Op1 := TSSAOperand.FromBlock(LElseBlock);
              ASSAFunc.GetBlock(LHeaderBlock).SetInstruction(LPatchIdx, LInstr);
            end;
            
            // Update edges: remove condition -> end, add condition -> else
            // Note: We can't easily remove edges, so we'll have duplicate edges
            // The dominator algorithm handles this, but let's add the correct edge
            ASSAFunc.GetBlock(LHeaderBlock).AddSuccessor(LElseBlock);
            ASSAFunc.GetBlock(LElseBlock).AddPredecessor(LHeaderBlock);
            
            // Push only end block back (marker that else was processed)
            LBlockStack.Push(-1);  // Marker: else exists
            LBlockStack.Push(LEndBlock);
            
            // Continue in else block
            ASSAFunc.SetCurrentBlock(LElseBlock);
          end;
          
        TIR.TIRStmtKind.skWhenEnd:
          begin
            LCurrentBlockId := ASSAFunc.GetCurrentBlock().GetBlockId();
            
            // Pop end block
            LEndBlock := LBlockStack.Pop();
            
            // Pop marker (else was processed)
            LBlockStack.Pop();
            
            // Jump to end block from current
            LInstr := Default(TSSAInstr);
            LInstr.Kind := sikJump;
            LInstr.Op1 := TSSAOperand.FromBlock(LEndBlock);
            ASSAFunc.GetCurrentBlock().AddInstruction(LInstr);
            
            // Add edge: current -> end
            ASSAFunc.GetBlock(LCurrentBlockId).AddSuccessor(LEndBlock);
            ASSAFunc.GetBlock(LEndBlock).AddPredecessor(LCurrentBlockId);
            
            // If LHeaderBlock is -1, else was processed (nothing more to do)
            // If LHeaderBlock >= 0, it's the condition block ID (no else case)
            // In no-else case, the condition->end edge was already added in skWhenBegin
            
            // Continue in end block
            ASSAFunc.SetCurrentBlock(LEndBlock);
          end;
          
        TIR.TIRStmtKind.skLoopBegin:
          begin
            LCurrentBlockId := ASSAFunc.GetCurrentBlock().GetBlockId();
            
            // Create header, body and end blocks
            LLoopBlock := ASSAFunc.CreateBlock('while_header');
            LBodyBlock := ASSAFunc.CreateBlock('while_body');
            LEndBlock := ASSAFunc.CreateBlock('while_end');
            
            // Add edge: entry -> header
            ASSAFunc.GetBlock(LCurrentBlockId).AddSuccessor(LLoopBlock);
            ASSAFunc.GetBlock(LLoopBlock).AddPredecessor(LCurrentBlockId);
            
            // Jump to header from entry
            LInstr := Default(TSSAInstr);
            LInstr.Kind := sikJump;
            LInstr.Op1 := TSSAOperand.FromBlock(LLoopBlock);
            ASSAFunc.GetCurrentBlock().AddInstruction(LInstr);
            
            // Switch to header: evaluate condition
            ASSAFunc.SetCurrentBlock(LLoopBlock);
            LCondVar := ConvertExpression(AIR, LStmt.Expr, ASSAFunc);
            
            // Add edges: header -> body (true), header -> end (false)
            ASSAFunc.GetBlock(LLoopBlock).AddSuccessor(LBodyBlock);
            ASSAFunc.GetBlock(LLoopBlock).AddSuccessor(LEndBlock);
            ASSAFunc.GetBlock(LBodyBlock).AddPredecessor(LLoopBlock);
            ASSAFunc.GetBlock(LEndBlock).AddPredecessor(LLoopBlock);
            
            // Jump to body if true
            LInstr := Default(TSSAInstr);
            LInstr.Kind := sikJumpIf;
            LInstr.Op1 := TSSAOperand.FromVar(LCondVar);
            LInstr.Op2 := TSSAOperand.FromBlock(LBodyBlock);
            ASSAFunc.GetCurrentBlock().AddInstruction(LInstr);
            
            // Jump to end if false
            LInstr := Default(TSSAInstr);
            LInstr.Kind := sikJump;
            LInstr.Op1 := TSSAOperand.FromBlock(LEndBlock);
            ASSAFunc.GetCurrentBlock().AddInstruction(LInstr);
            
            // Push loop header and end for WhileEnd
            LBlockStack.Push(LEndBlock);
            LBlockStack.Push(LLoopBlock);

            // Push loop context for break/continue
            LLoopCtx := Default(TSSALoopCtx);
            LLoopCtx.Kind := slkWhile;
            LLoopCtx.HeaderBlock := LLoopBlock;
            LLoopCtx.LatchBlock := LLoopBlock;  // continue jumps to header
            LLoopCtx.EndBlock := LEndBlock;
            LLoopCtxStack.Push(LLoopCtx);
            
            // Continue in body
            ASSAFunc.SetCurrentBlock(LBodyBlock);
          end;
          
        TIR.TIRStmtKind.skLoopEnd:
          begin
            LCurrentBlockId := ASSAFunc.GetCurrentBlock().GetBlockId();
            
            // Pop header and end blocks
            LLoopBlock := LBlockStack.Pop();
            LEndBlock := LBlockStack.Pop();
            LLoopCtxStack.Pop();
            
            // Add edge: body -> header (back edge)
            ASSAFunc.GetBlock(LCurrentBlockId).AddSuccessor(LLoopBlock);
            ASSAFunc.GetBlock(LLoopBlock).AddPredecessor(LCurrentBlockId);
            
            // Jump back to header
            LInstr := Default(TSSAInstr);
            LInstr.Kind := sikJump;
            LInstr.Op1 := TSSAOperand.FromBlock(LLoopBlock);
            ASSAFunc.GetCurrentBlock().AddInstruction(LInstr);
            
            // Continue in end block
            ASSAFunc.SetCurrentBlock(LEndBlock);
          end;
          
        TIR.TIRStmtKind.skCountBegin:
          begin
            LCurrentBlockId := ASSAFunc.GetCurrentBlock().GetBlockId();
            
            // Evaluate from and to expressions in current block (before loop)
            LExprVar := ConvertExpression(AIR, LStmt.ForFrom, ASSAFunc);
            LRightVar := ConvertExpression(AIR, LStmt.ForTo, ASSAFunc);
            
            // Assign loop variable = from value
            LDestVar := ASSAFunc.NewVersion(LStmt.ForVar);
            LInstr := Default(TSSAInstr);
            LInstr.Kind := sikAssign;
            LInstr.Dest := LDestVar;
            LInstr.Op1 := TSSAOperand.FromVar(LExprVar);
            ASSAFunc.GetCurrentBlock().AddInstruction(LInstr);
            
            // Create header, body, and end blocks
            LLoopBlock := ASSAFunc.CreateBlock('for_header');
            LBodyBlock := ASSAFunc.CreateBlock('for_body');
            LEndBlock := ASSAFunc.CreateBlock('for_end');
            
            // Add edge: current -> header
            ASSAFunc.GetBlock(LCurrentBlockId).AddSuccessor(LLoopBlock);
            ASSAFunc.GetBlock(LLoopBlock).AddPredecessor(LCurrentBlockId);
            
            // Jump to header
            LInstr := Default(TSSAInstr);
            LInstr.Kind := sikJump;
            LInstr.Op1 := TSSAOperand.FromBlock(LLoopBlock);
            ASSAFunc.GetCurrentBlock().AddInstruction(LInstr);
            
            // Switch to header block: emit comparison
            ASSAFunc.SetCurrentBlock(LLoopBlock);
            
            // Compare loop variable with to-value
            LCondVar := ASSAFunc.NewVersion('_t');
            LInstr := Default(TSSAInstr);
            if not LStmt.ForDownTo then
              LInstr.Kind := sikCmpLe   // forVar <= to (ascending)
            else
              LInstr.Kind := sikCmpGe;  // forVar >= to (descending)
            LInstr.Dest := LCondVar;
            LInstr.Op1 := TSSAOperand.FromVar(ASSAFunc.CurrentVersion(LStmt.ForVar));
            LInstr.Op2 := TSSAOperand.FromVar(LRightVar);
            ASSAFunc.GetCurrentBlock().AddInstruction(LInstr);
            
            // Add edges: header -> body (true), header -> end (false)
            ASSAFunc.GetBlock(LLoopBlock).AddSuccessor(LBodyBlock);
            ASSAFunc.GetBlock(LLoopBlock).AddSuccessor(LEndBlock);
            ASSAFunc.GetBlock(LBodyBlock).AddPredecessor(LLoopBlock);
            ASSAFunc.GetBlock(LEndBlock).AddPredecessor(LLoopBlock);
            
            // Branch: if condition true -> body, else -> end
            LInstr := Default(TSSAInstr);
            LInstr.Kind := sikJumpIf;
            LInstr.Op1 := TSSAOperand.FromVar(LCondVar);
            LInstr.Op2 := TSSAOperand.FromBlock(LBodyBlock);
            ASSAFunc.GetCurrentBlock().AddInstruction(LInstr);
            
            // Fall through to end
            LInstr := Default(TSSAInstr);
            LInstr.Kind := sikJump;
            LInstr.Op1 := TSSAOperand.FromBlock(LEndBlock);
            ASSAFunc.GetCurrentBlock().AddInstruction(LInstr);
            
            // Push blocks and loop info for ForEnd
            LBlockStack.Push(LEndBlock);
            LBlockStack.Push(LLoopBlock);
            LForVarStack.Push(LStmt.ForVar);
            LForDownToStack.Push(LStmt.ForDownTo);

            // Push loop context for break/continue
            LLoopCtx := Default(TSSALoopCtx);
            LLoopCtx.Kind := slkFor;
            LLoopCtx.HeaderBlock := LLoopBlock;
            LLoopCtx.LatchBlock := -1;  // for: inline increment at continue site
            LLoopCtx.EndBlock := LEndBlock;
            LLoopCtx.ForVar := LStmt.ForVar;
            LLoopCtx.ForDownTo := LStmt.ForDownTo;
            LLoopCtxStack.Push(LLoopCtx);
            
            // Continue in body block
            ASSAFunc.SetCurrentBlock(LBodyBlock);
          end;
          
        TIR.TIRStmtKind.skCountEnd:
          begin
            LCurrentBlockId := ASSAFunc.GetCurrentBlock().GetBlockId();
            
            // Pop loop info
            LLoopBlock := LBlockStack.Pop();
            LEndBlock := LBlockStack.Pop();
            LForVar := LForVarStack.Pop();
            LIsDownTo := LForDownToStack.Pop();
            LLoopCtxStack.Pop();
            
            // Increment (or decrement) loop variable
            LTempVar := ASSAFunc.NewVersion('_t');
            LInstr := Default(TSSAInstr);
            if not LIsDownTo then
              LInstr.Kind := sikAdd
            else
              LInstr.Kind := sikSub;
            LInstr.Dest := LTempVar;
            LInstr.Op1 := TSSAOperand.FromVar(ASSAFunc.CurrentVersion(LForVar));
            LInstr.Op2 := TSSAOperand.FromImm(Int64(1));
            ASSAFunc.GetCurrentBlock().AddInstruction(LInstr);
            
            // Assign new version of loop variable
            LDestVar := ASSAFunc.NewVersion(LForVar);
            LInstr := Default(TSSAInstr);
            LInstr.Kind := sikAssign;
            LInstr.Dest := LDestVar;
            LInstr.Op1 := TSSAOperand.FromVar(LTempVar);
            ASSAFunc.GetCurrentBlock().AddInstruction(LInstr);
            
            // Add edge: body -> header (back edge)
            ASSAFunc.GetBlock(LCurrentBlockId).AddSuccessor(LLoopBlock);
            ASSAFunc.GetBlock(LLoopBlock).AddPredecessor(LCurrentBlockId);
            
            // Jump back to header
            LInstr := Default(TSSAInstr);
            LInstr.Kind := sikJump;
            LInstr.Op1 := TSSAOperand.FromBlock(LLoopBlock);
            ASSAFunc.GetCurrentBlock().AddInstruction(LInstr);
            
            // Continue in end block
            ASSAFunc.SetCurrentBlock(LEndBlock);
          end;
          
        TIR.TIRStmtKind.skDoRepeatBegin:
          begin
            LCurrentBlockId := ASSAFunc.GetCurrentBlock().GetBlockId();
            
            // Create body, latch (condition check), and end blocks
            LBodyBlock := ASSAFunc.CreateBlock('repeat_body');
            LLatchBlock := ASSAFunc.CreateBlock('repeat_latch');
            LEndBlock := ASSAFunc.CreateBlock('repeat_end');
            
            // Add edge: entry -> body
            ASSAFunc.GetBlock(LCurrentBlockId).AddSuccessor(LBodyBlock);
            ASSAFunc.GetBlock(LBodyBlock).AddPredecessor(LCurrentBlockId);
            
            // Jump to body
            LInstr := Default(TSSAInstr);
            LInstr.Kind := sikJump;
            LInstr.Op1 := TSSAOperand.FromBlock(LBodyBlock);
            ASSAFunc.GetCurrentBlock().AddInstruction(LInstr);
            
            // Push body block for RepeatEnd (existing stack contract)
            LBlockStack.Push(LEndBlock);
            LBlockStack.Push(LLatchBlock);
            LBlockStack.Push(LBodyBlock);

            // Push loop context for break/continue
            LLoopCtx := Default(TSSALoopCtx);
            LLoopCtx.Kind := slkRepeat;
            LLoopCtx.HeaderBlock := LBodyBlock;
            LLoopCtx.LatchBlock := LLatchBlock;
            LLoopCtx.EndBlock := LEndBlock;
            LLoopCtxStack.Push(LLoopCtx);
            
            // Continue in body
            ASSAFunc.SetCurrentBlock(LBodyBlock);
          end;
          
        TIR.TIRStmtKind.skDoRepeatEnd:
          begin
            LCurrentBlockId := ASSAFunc.GetCurrentBlock().GetBlockId();
            
            // Pop blocks (pushed in order: end, latch, body)
            LBodyBlock := LBlockStack.Pop();
            LLatchBlock := LBlockStack.Pop();
            LEndBlock := LBlockStack.Pop();
            LLoopCtxStack.Pop();

            // Jump from body end to latch (condition check)
            ASSAFunc.GetBlock(LCurrentBlockId).AddSuccessor(LLatchBlock);
            ASSAFunc.GetBlock(LLatchBlock).AddPredecessor(LCurrentBlockId);

            LInstr := Default(TSSAInstr);
            LInstr.Kind := sikJump;
            LInstr.Op1 := TSSAOperand.FromBlock(LLatchBlock);
            ASSAFunc.GetCurrentBlock().AddInstruction(LInstr);

            // Switch to latch block: evaluate until condition
            ASSAFunc.SetCurrentBlock(LLatchBlock);
            LCondVar := ConvertExpression(AIR, LStmt.Expr, ASSAFunc);
            
            // Add edges: latch -> body (back edge if false), latch -> end (if true)
            ASSAFunc.GetBlock(LLatchBlock).AddSuccessor(LBodyBlock);
            ASSAFunc.GetBlock(LLatchBlock).AddSuccessor(LEndBlock);
            ASSAFunc.GetBlock(LBodyBlock).AddPredecessor(LLatchBlock);
            ASSAFunc.GetBlock(LEndBlock).AddPredecessor(LLatchBlock);
            
            // Jump back to body if condition false (until = exit when true)
            LInstr := Default(TSSAInstr);
            LInstr.Kind := sikJumpIfNot;
            LInstr.Op1 := TSSAOperand.FromVar(LCondVar);
            LInstr.Op2 := TSSAOperand.FromBlock(LBodyBlock);
            ASSAFunc.GetCurrentBlock().AddInstruction(LInstr);
            
            // Jump to end if condition true
            LInstr := Default(TSSAInstr);
            LInstr.Kind := sikJump;
            LInstr.Op1 := TSSAOperand.FromBlock(LEndBlock);
            ASSAFunc.GetCurrentBlock().AddInstruction(LInstr);
            
            // Continue in end block
            ASSAFunc.SetCurrentBlock(LEndBlock);
          end;

        TIR.TIRStmtKind.skLoopBreak:
          begin
            LCurrentBlockId := ASSAFunc.GetCurrentBlock().GetBlockId();
            LLoopCtx := LLoopCtxStack.Peek();

            // Jump to end block (exit the loop)
            ASSAFunc.GetBlock(LCurrentBlockId).AddSuccessor(LLoopCtx.EndBlock);
            ASSAFunc.GetBlock(LLoopCtx.EndBlock).AddPredecessor(LCurrentBlockId);

            LInstr := Default(TSSAInstr);
            LInstr.Kind := sikJump;
            LInstr.Op1 := TSSAOperand.FromBlock(LLoopCtx.EndBlock);
            ASSAFunc.GetCurrentBlock().AddInstruction(LInstr);

            // Create unreachable continuation block (code after break)
            LBodyBlock := ASSAFunc.CreateBlock('after_break');
            ASSAFunc.SetCurrentBlock(LBodyBlock);
          end;

        TIR.TIRStmtKind.skLoopContinue:
          begin
            LCurrentBlockId := ASSAFunc.GetCurrentBlock().GetBlockId();
            LLoopCtx := LLoopCtxStack.Peek();

            if LLoopCtx.Kind = slkFor then
            begin
              // For loops: emit increment before jumping to header
              LTempVar := ASSAFunc.NewVersion('_t');
              LInstr := Default(TSSAInstr);
              if not LLoopCtx.ForDownTo then
                LInstr.Kind := sikAdd
              else
                LInstr.Kind := sikSub;
              LInstr.Dest := LTempVar;
              LInstr.Op1 := TSSAOperand.FromVar(ASSAFunc.CurrentVersion(LLoopCtx.ForVar));
              LInstr.Op2 := TSSAOperand.FromImm(Int64(1));
              ASSAFunc.GetCurrentBlock().AddInstruction(LInstr);

              LDestVar := ASSAFunc.NewVersion(LLoopCtx.ForVar);
              LInstr := Default(TSSAInstr);
              LInstr.Kind := sikAssign;
              LInstr.Dest := LDestVar;
              LInstr.Op1 := TSSAOperand.FromVar(LTempVar);
              ASSAFunc.GetCurrentBlock().AddInstruction(LInstr);

              // Jump to header (condition check)
              ASSAFunc.GetBlock(LCurrentBlockId).AddSuccessor(LLoopCtx.HeaderBlock);
              ASSAFunc.GetBlock(LLoopCtx.HeaderBlock).AddPredecessor(LCurrentBlockId);

              LInstr := Default(TSSAInstr);
              LInstr.Kind := sikJump;
              LInstr.Op1 := TSSAOperand.FromBlock(LLoopCtx.HeaderBlock);
              ASSAFunc.GetCurrentBlock().AddInstruction(LInstr);
            end
            else if LLoopCtx.Kind = slkRepeat then
            begin
              // Repeat loops: jump to latch (condition check)
              ASSAFunc.GetBlock(LCurrentBlockId).AddSuccessor(LLoopCtx.LatchBlock);
              ASSAFunc.GetBlock(LLoopCtx.LatchBlock).AddPredecessor(LCurrentBlockId);

              LInstr := Default(TSSAInstr);
              LInstr.Kind := sikJump;
              LInstr.Op1 := TSSAOperand.FromBlock(LLoopCtx.LatchBlock);
              ASSAFunc.GetCurrentBlock().AddInstruction(LInstr);
            end
            else
            begin
              // While loops: jump to header (condition re-check)
              ASSAFunc.GetBlock(LCurrentBlockId).AddSuccessor(LLoopCtx.HeaderBlock);
              ASSAFunc.GetBlock(LLoopCtx.HeaderBlock).AddPredecessor(LCurrentBlockId);

              LInstr := Default(TSSAInstr);
              LInstr.Kind := sikJump;
              LInstr.Op1 := TSSAOperand.FromBlock(LLoopCtx.HeaderBlock);
              ASSAFunc.GetCurrentBlock().AddInstruction(LInstr);
            end;

            // Create unreachable continuation block (code after continue)
            LBodyBlock := ASSAFunc.CreateBlock('after_continue');
            ASSAFunc.SetCurrentBlock(LBodyBlock);
          end;
          
        TIR.TIRStmtKind.skMatchBegin:
          begin
            // Evaluate selector
            LCondVar := ConvertExpression(AIR, LStmt.Expr, ASSAFunc);
            
            // Create end block
            LEndBlock := ASSAFunc.CreateBlock('case_end');
            
            // Push: end block, selector expression index, marker (-1 = first case)
            LBlockStack.Push(LEndBlock);
            LBlockStack.Push(LStmt.Expr);
            LBlockStack.Push(-1);
          end;
          
        TIR.TIRStmtKind.skOn:
          begin
            LCurrentBlockId := ASSAFunc.GetCurrentBlock().GetBlockId();
            
            // Pop state
            LPatchIdx := LBlockStack.Pop();
            LHeaderBlock := LBlockStack.Pop();
            LEndBlock := LBlockStack.Pop();
            
            // End previous body if not first CaseOf
            if LPatchIdx >= 0 then
            begin
              LInstr := Default(TSSAInstr);
              LInstr.Kind := sikJump;
              LInstr.Op1 := TSSAOperand.FromBlock(LEndBlock);
              ASSAFunc.GetCurrentBlock().AddInstruction(LInstr);
              
              ASSAFunc.GetBlock(LCurrentBlockId).AddSuccessor(LEndBlock);
              ASSAFunc.GetBlock(LEndBlock).AddPredecessor(LCurrentBlockId);
              
              ASSAFunc.SetCurrentBlock(LPatchIdx);
            end;
            
            // Create body and next test blocks
            LBodyBlock := ASSAFunc.CreateBlock('case_body');
            LThenBlock := ASSAFunc.CreateBlock('case_test');
            
            // Re-evaluate selector
            LCondVar := ConvertExpression(AIR, LHeaderBlock, ASSAFunc);
            
            // For each value: compare and jump to body if match
            for LArgIdx := 0 to High(LStmt.CaseValues) do
            begin
              // CaseValues contains raw integers, not expression indices
              // Create comparison: selector == caseValue
              LDestVar := ASSAFunc.NewVersion('_casecmp');
              LInstr := Default(TSSAInstr);
              LInstr.Kind := sikCmpEq;
              LInstr.Dest := LDestVar;
              LInstr.Op1 := TSSAOperand.FromVar(LCondVar);
              LInstr.Op2 := TSSAOperand.FromImm(LStmt.CaseValues[LArgIdx]);
              ASSAFunc.GetCurrentBlock().AddInstruction(LInstr);
              
              LInstr := Default(TSSAInstr);
              LInstr.Kind := sikJumpIf;
              LInstr.Op1 := TSSAOperand.FromVar(LDestVar);
              LInstr.Op2 := TSSAOperand.FromBlock(LBodyBlock);
              ASSAFunc.GetCurrentBlock().AddInstruction(LInstr);
              
              ASSAFunc.GetCurrentBlock().AddSuccessor(LBodyBlock);
              ASSAFunc.GetBlock(LBodyBlock).AddPredecessor(ASSAFunc.GetCurrentBlock().GetBlockId());
            end;
            
            // Fall through to next test
            LInstr := Default(TSSAInstr);
            LInstr.Kind := sikJump;
            LInstr.Op1 := TSSAOperand.FromBlock(LThenBlock);
            ASSAFunc.GetCurrentBlock().AddInstruction(LInstr);
            
            ASSAFunc.GetCurrentBlock().AddSuccessor(LThenBlock);
            ASSAFunc.GetBlock(LThenBlock).AddPredecessor(ASSAFunc.GetCurrentBlock().GetBlockId());
            
            // Push state
            LBlockStack.Push(LEndBlock);
            LBlockStack.Push(LHeaderBlock);
            LBlockStack.Push(LThenBlock);
            
            ASSAFunc.SetCurrentBlock(LBodyBlock);
          end;
          
        TIR.TIRStmtKind.skOnElse:
          begin
            LCurrentBlockId := ASSAFunc.GetCurrentBlock().GetBlockId();
            
            LPatchIdx := LBlockStack.Pop();
            LBlockStack.Pop();
            LEndBlock := LBlockStack.Pop();
            
            LInstr := Default(TSSAInstr);
            LInstr.Kind := sikJump;
            LInstr.Op1 := TSSAOperand.FromBlock(LEndBlock);
            ASSAFunc.GetCurrentBlock().AddInstruction(LInstr);
            
            ASSAFunc.GetBlock(LCurrentBlockId).AddSuccessor(LEndBlock);
            ASSAFunc.GetBlock(LEndBlock).AddPredecessor(LCurrentBlockId);
            
            LElseBlock := ASSAFunc.CreateBlock('case_else');
            
            ASSAFunc.SetCurrentBlock(LPatchIdx);
            LInstr := Default(TSSAInstr);
            LInstr.Kind := sikJump;
            LInstr.Op1 := TSSAOperand.FromBlock(LElseBlock);
            ASSAFunc.GetCurrentBlock().AddInstruction(LInstr);
            
            ASSAFunc.GetBlock(LPatchIdx).AddSuccessor(LElseBlock);
            ASSAFunc.GetBlock(LElseBlock).AddPredecessor(LPatchIdx);
            
            LBlockStack.Push(LEndBlock);
            LBlockStack.Push(-2);
            LBlockStack.Push(-2);
            
            ASSAFunc.SetCurrentBlock(LElseBlock);
          end;
          
        TIR.TIRStmtKind.skMatchEnd:
          begin
            LCurrentBlockId := ASSAFunc.GetCurrentBlock().GetBlockId();
            
            LPatchIdx := LBlockStack.Pop();
            LHeaderBlock := LBlockStack.Pop();
            LEndBlock := LBlockStack.Pop();
            
            LInstr := Default(TSSAInstr);
            LInstr.Kind := sikJump;
            LInstr.Op1 := TSSAOperand.FromBlock(LEndBlock);
            ASSAFunc.GetCurrentBlock().AddInstruction(LInstr);
            
            ASSAFunc.GetBlock(LCurrentBlockId).AddSuccessor(LEndBlock);
            ASSAFunc.GetBlock(LEndBlock).AddPredecessor(LCurrentBlockId);
            
            // If no else, previous test falls through to end
            if (LPatchIdx >= 0) and (LHeaderBlock >= 0) then
            begin
              ASSAFunc.SetCurrentBlock(LPatchIdx);
              LInstr := Default(TSSAInstr);
              LInstr.Kind := sikJump;
              LInstr.Op1 := TSSAOperand.FromBlock(LEndBlock);
              ASSAFunc.GetCurrentBlock().AddInstruction(LInstr);
              
              ASSAFunc.GetBlock(LPatchIdx).AddSuccessor(LEndBlock);
              ASSAFunc.GetBlock(LEndBlock).AddPredecessor(LPatchIdx);
            end;
            
            ASSAFunc.SetCurrentBlock(LEndBlock);
          end;
          
        //----------------------------------------------------------------------
        // Exception Handling Statements
        //----------------------------------------------------------------------
        
        TIR.TIRStmtKind.skGuardBegin:
          begin
            LCurrentBlockId := ASSAFunc.GetCurrentBlock().GetBlockId();
            
            // Create blocks: try body, except handler (placeholder), finally (placeholder), end
            LTryBlock := ASSAFunc.CreateBlock('try_body');
            LEndBlock := ASSAFunc.CreateBlock('try_end');
            
            // Jump to try body
            LInstr := Default(TSSAInstr);
            LInstr.Kind := sikJump;
            LInstr.Op1 := TSSAOperand.FromBlock(LTryBlock);
            ASSAFunc.GetCurrentBlock().AddInstruction(LInstr);
            
            ASSAFunc.GetBlock(LCurrentBlockId).AddSuccessor(LTryBlock);
            ASSAFunc.GetBlock(LTryBlock).AddPredecessor(LCurrentBlockId);
            
            // Push: try_block, end_block, except_block (-1), finally_block (-1)
            LBlockStack.Push(LTryBlock);       // Try body start
            LBlockStack.Push(LEndBlock);       // End block
            LBlockStack.Push(-1);              // Except block (filled by skCatchBegin)
            LBlockStack.Push(-1);              // Finally block (filled by skEnsureBegin)
            
            ASSAFunc.SetCurrentBlock(LTryBlock);
          end;
          
        TIR.TIRStmtKind.skCatchBegin:
          begin
            LCurrentBlockId := ASSAFunc.GetCurrentBlock().GetBlockId();
            
            // Pop stack to get context
            LFinallyBlock := LBlockStack.Pop();  // Finally block (-1 or set)
            LBlockStack.Pop();                    // Except block (-1)
            LEndBlock := LBlockStack.Pop();       // End block
            LTryBlock := LBlockStack.Pop();       // Try body start
            
            // Create the except block
            LExceptBlock := ASSAFunc.CreateBlock('except_handler');
            
            // Normal path: try body jumps OVER except to end (or finally if present)
            LInstr := Default(TSSAInstr);
            LInstr.Kind := sikJump;
            LInstr.Op1 := TSSAOperand.FromBlock(LEndBlock);  // Will be patched if finally exists
            ASSAFunc.GetCurrentBlock().AddInstruction(LInstr);
            
            ASSAFunc.GetBlock(LCurrentBlockId).AddSuccessor(LEndBlock);
            ASSAFunc.GetBlock(LEndBlock).AddPredecessor(LCurrentBlockId);
            
            // Add fake edge for CFG connectivity (SEH handles actual dispatch at runtime)
            // Without this edge, except_handler is unreachable and breaks dominator computation
            ASSAFunc.GetBlock(LCurrentBlockId).AddSuccessor(LExceptBlock);
            ASSAFunc.GetBlock(LExceptBlock).AddPredecessor(LCurrentBlockId);
            
            // Push back with except block set
            LBlockStack.Push(LTryBlock);
            LBlockStack.Push(LEndBlock);
            LBlockStack.Push(LExceptBlock);
            LBlockStack.Push(LFinallyBlock);
            LBlockStack.Push(LCurrentBlockId);  // Save try-end block for scope tracking
            
            ASSAFunc.SetCurrentBlock(LExceptBlock);
          end;
          
        TIR.TIRStmtKind.skEnsureBegin:
          begin
            LCurrentBlockId := ASSAFunc.GetCurrentBlock().GetBlockId();
            
            // Pop stack - might have extra item if except was processed
            if LBlockStack.Count >= 5 then
              LTryEndBlock := LBlockStack.Pop()  // Try-end block from except
            else
              LTryEndBlock := -1;
            
            LBlockStack.Pop();                    // Finally block (-1)
            LExceptBlock := LBlockStack.Pop();    // Except block (may be valid)
            LEndBlock := LBlockStack.Pop();       // End block
            LTryBlock := LBlockStack.Pop();       // Try body start
            
            // Create the finally block
            LFinallyBlock := ASSAFunc.CreateBlock('finally_handler');
            
            // Normal path jumps through finally
            LInstr := Default(TSSAInstr);
            LInstr.Kind := sikJump;
            LInstr.Op1 := TSSAOperand.FromBlock(LFinallyBlock);
            ASSAFunc.GetCurrentBlock().AddInstruction(LInstr);
            
            ASSAFunc.GetBlock(LCurrentBlockId).AddSuccessor(LFinallyBlock);
            ASSAFunc.GetBlock(LFinallyBlock).AddPredecessor(LCurrentBlockId);
            
            // If except was present, patch its jump to also go through finally
            if (LExceptBlock >= 0) and (LTryEndBlock >= 0) then
            begin
              // Patch the jump in try-end block to go to finally instead of end
              LPatchIdx := ASSAFunc.GetBlock(LTryEndBlock).GetInstructionCount() - 1;
              LInstr := ASSAFunc.GetBlock(LTryEndBlock).GetInstruction(LPatchIdx);
              if LInstr.Kind = sikJump then
              begin
                LInstr.Op1 := TSSAOperand.FromBlock(LFinallyBlock);
                ASSAFunc.GetBlock(LTryEndBlock).SetInstruction(LPatchIdx, LInstr);
                // Update edges
                ASSAFunc.GetBlock(LTryEndBlock).AddSuccessor(LFinallyBlock);
                ASSAFunc.GetBlock(LFinallyBlock).AddPredecessor(LTryEndBlock);
              end;
            end;
            
            // Push back with finally block set
            LBlockStack.Push(LTryBlock);
            LBlockStack.Push(LEndBlock);
            LBlockStack.Push(LExceptBlock);
            LBlockStack.Push(LFinallyBlock);
            if LTryEndBlock >= 0 then
              LBlockStack.Push(LTryEndBlock)
            else
              LBlockStack.Push(LCurrentBlockId);  // Save current block for scope
            
            ASSAFunc.SetCurrentBlock(LFinallyBlock);
          end;
          
        TIR.TIRStmtKind.skGuardEnd:
          begin
            LCurrentBlockId := ASSAFunc.GetCurrentBlock().GetBlockId();
            
            // Pop everything
            if LBlockStack.Count >= 5 then
              LTryEndBlock := LBlockStack.Pop()
            else
              LTryEndBlock := -1;
            
            LFinallyBlock := LBlockStack.Pop();
            LExceptBlock := LBlockStack.Pop();
            LEndBlock := LBlockStack.Pop();
            LTryBlock := LBlockStack.Pop();
            
            // Jump to end block
            LInstr := Default(TSSAInstr);
            LInstr.Kind := sikJump;
            LInstr.Op1 := TSSAOperand.FromBlock(LEndBlock);
            ASSAFunc.GetCurrentBlock().AddInstruction(LInstr);
            
            ASSAFunc.GetBlock(LCurrentBlockId).AddSuccessor(LEndBlock);
            ASSAFunc.GetBlock(LEndBlock).AddPredecessor(LCurrentBlockId);
            
            // Record exception scope for backend
            LExcScope.TryBlockIndex := LTryBlock;
            LExcScope.TryEndBlockIndex := LTryEndBlock;
            LExcScope.ExceptBlockIndex := LExceptBlock;
            LExcScope.FinallyBlockIndex := LFinallyBlock;
            LExcScope.EndBlockIndex := LEndBlock;
            ASSAFunc.AddExceptionScope(LExcScope);
            
            ASSAFunc.SetCurrentBlock(LEndBlock);
          end;
          
        TIR.TIRStmtKind.skThrow:
          begin
            // Convert: raiseexception(msg) -> call Pax_Raise(msg)
            LExprVar := ConvertExpression(AIR, LStmt.RaiseMsg, ASSAFunc);
            
            LInstr := Default(TSSAInstr);
            LInstr.Kind := sikCall;
            SetLength(LCallArgs, 1);
            LCallArgs[0] := TSSAOperand.FromVar(LExprVar);
            LInstr.CallArgs := LCallArgs;
            LInstr.CallTarget := TSSAOperand.FromFunc(FindLocalFuncByName(AIR, 'Gny_Raise'));
            ASSAFunc.GetCurrentBlock().AddInstruction(LInstr);
          end;
          
        TIR.TIRStmtKind.skThrowCode:
          begin
            // Convert: raiseexceptioncode(code, msg) -> call Pax_RaiseCode(code, msg)
            LCondVar := ConvertExpression(AIR, LStmt.RaiseCode, ASSAFunc);
            LExprVar := ConvertExpression(AIR, LStmt.RaiseMsg, ASSAFunc);
            
            LInstr := Default(TSSAInstr);
            LInstr.Kind := sikCall;
            SetLength(LCallArgs, 2);
            LCallArgs[0] := TSSAOperand.FromVar(LCondVar);
            LCallArgs[1] := TSSAOperand.FromVar(LExprVar);
            LInstr.CallArgs := LCallArgs;
            LInstr.CallTarget := TSSAOperand.FromFunc(FindLocalFuncByName(AIR, 'Gny_RaiseCode'));
            ASSAFunc.GetCurrentBlock().AddInstruction(LInstr);
          end;
      end;
    end;
  finally
    LLoopCtxStack.Free();
    LForDownToStack.Free();
    LForVarStack.Free();
    LBlockStack.Free();
  end;
end;

function TSSABuilder.FindImportByName(const AIR: TIR; const AName: string): Integer;
var
  LI: Integer;
  LImport: TIR.TIRImport;
begin
  for LI := 0 to AIR.GetImportCount() - 1 do
  begin
    LImport := AIR.GetImport(LI);
    if SameText(LImport.FuncName, AName) then
      Exit(LI);
  end;
  Result := -1;
end;

function TSSABuilder.FindImportBySignature(
  const AIR: TIR;
  const AName: string;
  const AArgTypes: TArray<TTypeRef>
): Integer;
var
  LI:      Integer;
  LJ:      Integer;
  LImport: TIR.TIRImport;
  LMatch:  Boolean;
begin
  for LI := 0 to AIR.GetImportCount() - 1 do
  begin
    LImport := AIR.GetImport(LI);
    if not SameText(LImport.FuncName, AName) then
      Continue;

    // Check param count
    if Length(LImport.ParamTypes) <> Length(AArgTypes) then
      Continue;

    // Compare each param type
    LMatch := True;
    for LJ := 0 to High(AArgTypes) do
    begin
      if AArgTypes[LJ].IsPrimitive then
      begin
        if AArgTypes[LJ].Primitive <> LImport.ParamTypes[LJ] then
        begin
          LMatch := False;
          Break;
        end;
      end
      else
      begin
        // Composite type vs primitive — no match
        LMatch := False;
        Break;
      end;
    end;

    if LMatch then
      Exit(LI);
  end;
  Result := -1;
end;

function TSSABuilder.FindLocalFuncByName(const AIR: TIR; const AName: string): Integer;
var
  LI: Integer;
  LFunc: TIR.TIRFunc;
begin
  for LI := 0 to AIR.GetFunctionCount() - 1 do
  begin
    LFunc := AIR.GetFunction(LI);
    if SameText(LFunc.FuncName, AName) then
      Exit(LI);
  end;
  Result := -1;
end;

function TSSABuilder.FindLocalFuncBySignature(
  const AIR: TIR;
  const AName: string;
  const AArgTypes: TArray<TTypeRef>
): Integer;
var
  LI: Integer;
  LJ: Integer;
  LFunc: TIR.TIRFunc;
  LFuncParams: TArray<TTypeRef>;
  LParamCount: Integer;
  LMatch: Boolean;
begin
  for LI := 0 to AIR.GetFunctionCount() - 1 do
  begin
    LFunc := AIR.GetFunction(LI);
    if not SameText(LFunc.FuncName, AName) then
      Continue;

    // Extract param types from function
    LParamCount := 0;
    for LJ := 0 to LFunc.Vars.Count - 1 do
    begin
      if LFunc.Vars[LJ].IsParam then
        Inc(LParamCount);
    end;

    // Check param count match
    if LParamCount <> Length(AArgTypes) then
      Continue;

    // Build param type array
    SetLength(LFuncParams, LParamCount);
    LParamCount := 0;
    for LJ := 0 to LFunc.Vars.Count - 1 do
    begin
      if LFunc.Vars[LJ].IsParam then
      begin
        LFuncParams[LParamCount] := LFunc.Vars[LJ].VarTypeRef;
        Inc(LParamCount);
      end;
    end;

    // Compare types
    LMatch := True;
    for LJ := 0 to High(AArgTypes) do
    begin
      if LFuncParams[LJ] <> AArgTypes[LJ] then
      begin
        LMatch := False;
        Break;
      end;
    end;

    if LMatch then
      Exit(LI);
  end;
  Result := -1;
end;

function TSSABuilder.ConvertExpression(
  const AIR: TIR;
  const AExprIndex: Integer;
  const ASSAFunc: TSSAFunc
): TSSAVar;
var
  LExpr: TIR.TIRExprNode;
  LObjectExpr: TIR.TIRExprNode;
  LInnerExpr: TIR.TIRExprNode;
  LArgExpr: TIR.TIRExprNode;
  LInstr: TSSAInstr;
  LLeftVar: TSSAVar;
  LRightVar: TSSAVar;
  LResultVar: TSSAVar;
  LArgVar: TSSAVar;
  LArgIdx: Integer;
  LFuncIndex: Integer;
  LCallArgs: TArray<TSSAOperand>;
  LArgTypes: TArray<TTypeRef>;
  // Variadic call handling
  LTargetFunc: TIR.TIRFunc;
  LFixedParamCount: Integer;
  LVarArgCount: Integer;
  LJ: Integer;
  LImportIdx: Integer;
  // For by-reference parameter detection in field access
  LIsParam: Boolean;
  LLocalSize: Integer;
  LLocalIdx: Integer;
  LLocalInfo: TSSALocalInfo;
  LTempVar: TSSAVar;
  LByRefInstr: TSSAInstr;
begin
  if AExprIndex < 0 then
  begin
    Result := TSSAVar.None();
    Exit;
  end;
  
  // Check cache first - if already converted, return cached result
  if FExpressionCache.TryGetValue(AExprIndex, Result) then
    Exit;
  
  LExpr := AIR.GetExpression(AExprIndex);
  
  case LExpr.Kind of
    TIR.TIRExprKind.ekConstInt:
      begin
        // Create temp variable and assign constant
        LResultVar := ASSAFunc.NewVersion('_t');
        
        LInstr := Default(TSSAInstr);
        LInstr.Kind := sikAssign;
        LInstr.Dest := LResultVar;
        LInstr.Op1 := TSSAOperand.FromImm(LExpr.ConstInt);
        ASSAFunc.GetCurrentBlock().AddInstruction(LInstr);
        
        Result := LResultVar;
      end;
      
    TIR.TIRExprKind.ekConstFloat:
      begin
        LResultVar := ASSAFunc.NewVersion('_t');
        
        LInstr := Default(TSSAInstr);
        LInstr.Kind := sikAssign;
        LInstr.Dest := LResultVar;
        LInstr.Op1 := TSSAOperand.FromImm(LExpr.ConstFloat);
        ASSAFunc.GetCurrentBlock().AddInstruction(LInstr);
        
        Result := LResultVar;
      end;
      
    TIR.TIRExprKind.ekConstString:
      begin
        LResultVar := ASSAFunc.NewVersion('_t');
        
        LInstr := Default(TSSAInstr);
        LInstr.Kind := sikAssign;
        LInstr.Dest := LResultVar;
        LInstr.Op1 := TSSAOperand.FromData(LExpr.StringIndex);
        ASSAFunc.GetCurrentBlock().AddInstruction(LInstr);
        
        Result := LResultVar;
      end;
      
    TIR.TIRExprKind.ekVariable:
      begin
        // Check if it's a global variable first
        LArgIdx := AIR.FindGlobal(LExpr.VarName);
        if LArgIdx >= 0 then
        begin
          // Global variable - emit load from global address
          LResultVar := ASSAFunc.NewVersion('_t');
          
          LInstr := Default(TSSAInstr);
          LInstr.Kind := sikLoad;
          LInstr.Dest := LResultVar;
          LInstr.Op1 := TSSAOperand.FromGlobal(LArgIdx);
          ASSAFunc.GetCurrentBlock().AddInstruction(LInstr);
          
          Result := LResultVar;
        end
        else
        begin
          // Check if it's an imported variable (from DLL)
          LArgIdx := AIR.FindImport(LExpr.VarName);
          if LArgIdx >= 0 then
          begin
            // Imported variable — double indirection through IAT
            // Step 1: Load the variable's address from the IAT slot
            LResultVar := ASSAFunc.NewVersion('_t');
            LInstr := Default(TSSAInstr);
            LInstr.Kind := sikAssign;
            LInstr.Dest := LResultVar;
            LInstr.Op1 := TSSAOperand.FromImport(LArgIdx);
            ASSAFunc.GetCurrentBlock().AddInstruction(LInstr);

            // Step 2: Dereference the pointer to get the actual value
            LLeftVar := LResultVar;
            LResultVar := ASSAFunc.NewVersion('_t');
            LInstr := Default(TSSAInstr);
            LInstr.Kind := sikLoad;
            LInstr.Dest := LResultVar;
            LInstr.Op1 := TSSAOperand.FromVar(LLeftVar);
            // Set MemSize based on variable type
            case LExpr.ResultType.Primitive of
              vtInt8, vtUInt8:   LInstr.MemSize := 1;
              vtInt16, vtUInt16: LInstr.MemSize := 2;
              vtInt32, vtUInt32, vtFloat32: LInstr.MemSize := 4;
            else
              LInstr.MemSize := 0;  // 0 = full 64-bit (default)
            end;
            LInstr.MemIsFloat := LExpr.ResultType.Primitive in [vtFloat32, vtFloat64];
            ASSAFunc.GetCurrentBlock().AddInstruction(LInstr);

            Result := LResultVar;
          end
          else
          begin
            // Local variable - return current version
            Result := ASSAFunc.CurrentVersion(LExpr.VarName);
            
            // If no version exists yet (first use), create version 0
            if not Result.IsValid() then
            begin
              Result := ASSAFunc.NewVersion(LExpr.VarName);
            end;
          end;
        end;
      end;
      
    TIR.TIRExprKind.ekBinary:
      begin
        // Convert left and right operands
        LLeftVar := ConvertExpression(AIR, LExpr.Left, ASSAFunc);
        LRightVar := ConvertExpression(AIR, LExpr.Right, ASSAFunc);
        
        // Create result variable
        LResultVar := ASSAFunc.NewVersion('_t');
        
        // Emit binary operation
        LInstr := Default(TSSAInstr);
        LInstr.Dest := LResultVar;
        LInstr.Op1 := TSSAOperand.FromVar(LLeftVar);
        LInstr.Op2 := TSSAOperand.FromVar(LRightVar);
        
        case LExpr.Op of
          TIR.TIROpKind.opAdd:    LInstr.Kind := sikAdd;
          TIR.TIROpKind.opSub:    LInstr.Kind := sikSub;
          TIR.TIROpKind.opMul:    LInstr.Kind := sikMul;
          TIR.TIROpKind.opDiv:    LInstr.Kind := sikDiv;
          TIR.TIROpKind.opMod:    LInstr.Kind := sikMod;
          TIR.TIROpKind.opFAdd:   LInstr.Kind := sikFAdd;
          TIR.TIROpKind.opFSub:   LInstr.Kind := sikFSub;
          TIR.TIROpKind.opFMul:   LInstr.Kind := sikFMul;
          TIR.TIROpKind.opFDiv:   LInstr.Kind := sikFDiv;
          TIR.TIROpKind.opBitAnd: LInstr.Kind := sikBitAnd;
          TIR.TIROpKind.opBitOr:  LInstr.Kind := sikBitOr;
          TIR.TIROpKind.opBitXor: LInstr.Kind := sikBitXor;
          TIR.TIROpKind.opShl:    LInstr.Kind := sikShl;
          TIR.TIROpKind.opShr:    LInstr.Kind := sikShr;
          TIR.TIROpKind.opCmpEq:  LInstr.Kind := sikCmpEq;
          TIR.TIROpKind.opCmpNe:  LInstr.Kind := sikCmpNe;
          TIR.TIROpKind.opCmpLt:  LInstr.Kind := sikCmpLt;
          TIR.TIROpKind.opCmpLe:  LInstr.Kind := sikCmpLe;
          TIR.TIROpKind.opCmpGt:  LInstr.Kind := sikCmpGt;
          TIR.TIROpKind.opCmpGe:  LInstr.Kind := sikCmpGe;
          TIR.TIROpKind.opFCmpEq: LInstr.Kind := sikFCmpEq;
          TIR.TIROpKind.opFCmpNe: LInstr.Kind := sikFCmpNe;
          TIR.TIROpKind.opFCmpLt: LInstr.Kind := sikFCmpLt;
          TIR.TIROpKind.opFCmpLe: LInstr.Kind := sikFCmpLe;
          TIR.TIROpKind.opFCmpGt: LInstr.Kind := sikFCmpGt;
          TIR.TIROpKind.opFCmpGe: LInstr.Kind := sikFCmpGe;
          TIR.TIROpKind.opAnd:    LInstr.Kind := sikBitAnd;  // Logical and
          TIR.TIROpKind.opOr:     LInstr.Kind := sikBitOr;   // Logical or
          // Set operations
          TIR.TIROpKind.opSetUnion:    LInstr.Kind := sikSetUnion;
          TIR.TIROpKind.opSetDiff:     LInstr.Kind := sikSetDiff;
          TIR.TIROpKind.opSetInter:    LInstr.Kind := sikSetInter;
          TIR.TIROpKind.opSetIn:       LInstr.Kind := sikSetIn;
          TIR.TIROpKind.opSetEq:       LInstr.Kind := sikSetEq;
          TIR.TIROpKind.opSetNe:       LInstr.Kind := sikSetNe;
          TIR.TIROpKind.opSetSubset:   LInstr.Kind := sikSetSubset;
          TIR.TIROpKind.opSetSuperset: LInstr.Kind := sikSetSuperset;
        else
          LInstr.Kind := sikNop;
        end;
        
        // Extract LowBound for SetIn
        if LExpr.Op = TIR.TIROpKind.opSetIn then
        begin
          // Prefer explicit LowBound from IR expression (set by ViperLang codegen)
          if LExpr.SetLowBound <> 0 then
            LInstr.SetLowBound := LExpr.SetLowBound
          else
          begin
            // Fallback: infer from right operand's set type
            var LRightExpr := AIR.GetExpression(LExpr.Right);
            if (not LRightExpr.ResultType.IsPrimitive) and (LRightExpr.ResultType.TypeIndex >= 0) then
            begin
              var LTypeEntry := AIR.GetTypeEntry(LRightExpr.ResultType.TypeIndex);
              if LTypeEntry.Kind = TIR.TIRTypeKind.tkSet then
                LInstr.SetLowBound := LTypeEntry.SetType.LowBound;
            end;
          end;
        end;
        
        ASSAFunc.GetCurrentBlock().AddInstruction(LInstr);
        Result := LResultVar;
      end;
      
    TIR.TIRExprKind.ekUnary:
      begin
        // Special handling for address-of operations
        if LExpr.Op = TIR.TIROpKind.opAddrOf then
        begin
          LResultVar := ASSAFunc.NewVersion('_t');
          
          if LExpr.Left < 0 then
          begin
            // AddrOf(varname) - take address of named variable
            // Check if it's a global first
            LArgIdx := AIR.FindGlobal(LExpr.VarName);
            if LArgIdx >= 0 then
            begin
              // Global variable - sokGlobal operand IS the address (backend emits LEA)
              LInstr := Default(TSSAInstr);
              LInstr.Kind := sikAssign;
              LInstr.Dest := LResultVar;
              LInstr.Op1 := TSSAOperand.FromGlobal(LArgIdx);
              ASSAFunc.GetCurrentBlock().AddInstruction(LInstr);
            end
            else
            begin
              // Local variable - use sikAddressOf
              LInstr := Default(TSSAInstr);
              LInstr.Kind := sikAddressOf;
              LInstr.Dest := LResultVar;
              LInstr.Op1 := TSSAOperand.FromVar(ASSAFunc.CurrentVersion(LExpr.VarName));
              LInstr.Op1.Var_.BaseName := LExpr.VarName;
              ASSAFunc.GetCurrentBlock().AddInstruction(LInstr);
            end;
          end
          else
          begin
            // AddrOfExpr(expr) - take address of expression result
            LObjectExpr := AIR.GetExpression(LExpr.Left);
            
            if LObjectExpr.Kind = TIR.TIRExprKind.ekFieldAccess then
            begin
              // Get address of field: compute base address + field offset
              LInnerExpr := AIR.GetExpression(LObjectExpr.ObjectExpr);
              
              if (LInnerExpr.Kind = TIR.TIRExprKind.ekVariable) and 
                 (not LInnerExpr.ResultType.IsPrimitive) then
              begin
                LLeftVar := ASSAFunc.NewVersion('_t');
                LInstr := Default(TSSAInstr);

                LArgIdx := AIR.FindGlobal(LInnerExpr.VarName);
                if LArgIdx >= 0 then
                begin
                  LInstr.Kind := sikAssign;
                  LInstr.Dest := LLeftVar;
                  LInstr.Op1 := TSSAOperand.FromGlobal(LArgIdx);
                end
                else
                begin
                  LInstr.Kind := sikAddressOf;
                  LInstr.Dest := LLeftVar;
                  LInstr.Op1 := TSSAOperand.FromVar(ASSAFunc.CurrentVersion(LInnerExpr.VarName));
                  LInstr.Op1.Var_.BaseName := LInnerExpr.VarName;
                end;
                ASSAFunc.GetCurrentBlock().AddInstruction(LInstr);
              end
              else if (LInnerExpr.Kind = TIR.TIRExprKind.ekUnary) and
                      (LInnerExpr.Op = TIR.TIROpKind.opDeref) then
              begin
                // For Deref(ptr, TypeName), we want just the pointer value as base.
                LLeftVar := ConvertExpression(AIR, LInnerExpr.Left, ASSAFunc);
              end
              else
              begin
                LLeftVar := ConvertExpression(AIR, LObjectExpr.ObjectExpr, ASSAFunc);
              end;
              
              // Compute field address
              LInstr := Default(TSSAInstr);
              LInstr.Kind := sikFieldAddr;
              LInstr.Dest := LResultVar;
              LInstr.Op1 := TSSAOperand.FromVar(LLeftVar);
              LInstr.Op2 := TSSAOperand.FromImm(LObjectExpr.FieldOffset);
              LInstr.Op2.FieldName := LObjectExpr.FieldName;
              ASSAFunc.GetCurrentBlock().AddInstruction(LInstr);
            end
            else if LObjectExpr.Kind = TIR.TIRExprKind.ekArrayIndex then
            begin
              // Get address of array element
              LInnerExpr := AIR.GetExpression(LObjectExpr.ArrayExpr);
              
              if (LInnerExpr.Kind = TIR.TIRExprKind.ekVariable) and 
                 (not LInnerExpr.ResultType.IsPrimitive) then
              begin
                LLeftVar := ASSAFunc.NewVersion('_t');
                LInstr := Default(TSSAInstr);

                LArgIdx := AIR.FindGlobal(LInnerExpr.VarName);
                if LArgIdx >= 0 then
                begin
                  LInstr.Kind := sikAssign;
                  LInstr.Dest := LLeftVar;
                  LInstr.Op1 := TSSAOperand.FromGlobal(LArgIdx);
                end
                else
                begin
                  LInstr.Kind := sikAddressOf;
                  LInstr.Dest := LLeftVar;
                  LInstr.Op1 := TSSAOperand.FromVar(ASSAFunc.CurrentVersion(LInnerExpr.VarName));
                  LInstr.Op1.Var_.BaseName := LInnerExpr.VarName;
                end;
                ASSAFunc.GetCurrentBlock().AddInstruction(LInstr);
              end
              else
              begin
                LLeftVar := ConvertExpression(AIR, LObjectExpr.ArrayExpr, ASSAFunc);
              end;
              
              LRightVar := ConvertExpression(AIR, LObjectExpr.IndexExpr, ASSAFunc);
              
              LInstr := Default(TSSAInstr);
              LInstr.Kind := sikIndexAddr;
              LInstr.Dest := LResultVar;
              LInstr.Op1 := TSSAOperand.FromVar(LLeftVar);
              LInstr.Op2 := TSSAOperand.FromVar(LRightVar);
              LInstr.Op2.ElementSize := LObjectExpr.ElementSize;
              ASSAFunc.GetCurrentBlock().AddInstruction(LInstr);
            end
            else if LObjectExpr.Kind = TIR.TIRExprKind.ekVariable then
            begin
              // Take address of a variable through expression
              LInstr := Default(TSSAInstr);

              LArgIdx := AIR.FindGlobal(LObjectExpr.VarName);
              if LArgIdx >= 0 then
              begin
                LInstr.Kind := sikAssign;
                LInstr.Dest := LResultVar;
                LInstr.Op1 := TSSAOperand.FromGlobal(LArgIdx);
              end
              else
              begin
                LInstr.Kind := sikAddressOf;
                LInstr.Dest := LResultVar;
                LInstr.Op1 := TSSAOperand.FromVar(ASSAFunc.CurrentVersion(LObjectExpr.VarName));
                LInstr.Op1.Var_.BaseName := LObjectExpr.VarName;
              end;
              ASSAFunc.GetCurrentBlock().AddInstruction(LInstr);
            end;
          end;
          
          Result := LResultVar;
        end
        else
        begin
          // Other unary operations (neg, not, deref)
          LLeftVar := ConvertExpression(AIR, LExpr.Left, ASSAFunc);
          
          LResultVar := ASSAFunc.NewVersion('_t');
          
          LInstr := Default(TSSAInstr);
          LInstr.Dest := LResultVar;
          LInstr.Op1 := TSSAOperand.FromVar(LLeftVar);
          
          case LExpr.Op of
            TIR.TIROpKind.opNeg:    LInstr.Kind := sikNeg;
            TIR.TIROpKind.opFNeg:   LInstr.Kind := sikFNeg;
            TIR.TIROpKind.opIntToFloat: LInstr.Kind := sikIntToFloat;
            TIR.TIROpKind.opFloatToInt: LInstr.Kind := sikFloatToInt;
            TIR.TIROpKind.opBitNot: LInstr.Kind := sikBitNot;
            TIR.TIROpKind.opNot:
            begin
              LInstr.Kind := sikCmpEq;
              LInstr.Op2 := TSSAOperand.FromImm(0);
            end;
            TIR.TIROpKind.opDeref:  LInstr.Kind := sikLoad;
          else
            LInstr.Kind := sikNop;
          end;
          
          ASSAFunc.GetCurrentBlock().AddInstruction(LInstr);
          Result := LResultVar;
        end;
      end;
      
    TIR.TIRExprKind.ekCall:
      begin
        // Build argument types array for overload resolution
        SetLength(LArgTypes, Length(LExpr.CallArgs));
        for LArgIdx := 0 to High(LExpr.CallArgs) do
        begin
          LArgExpr := AIR.GetExpression(LExpr.CallArgs[LArgIdx]);
          LArgTypes[LArgIdx] := LArgExpr.ResultType;
        end;

        // Convert call arguments
        SetLength(LCallArgs, Length(LExpr.CallArgs));
        for LArgIdx := 0 to High(LExpr.CallArgs) do
        begin
          LArgVar := ConvertExpression(AIR, LExpr.CallArgs[LArgIdx], ASSAFunc);
          LCallArgs[LArgIdx] := TSSAOperand.FromVar(LArgVar);
        end;
        
        LResultVar := ASSAFunc.NewVersion('_t');
        
        LInstr := Default(TSSAInstr);
        LInstr.Kind := sikCallAssign;
        LInstr.Dest := LResultVar;
        LInstr.CallArgs := LCallArgs;
        
        // Try signature-based lookup first for overload resolution
        LFuncIndex := FindLocalFuncBySignature(AIR, LExpr.CallTarget, LArgTypes);
        if LFuncIndex < 0 then
          // Fall back to name-only lookup (for non-overloaded functions)
          LFuncIndex := FindLocalFuncByName(AIR, LExpr.CallTarget);
        
        if LFuncIndex >= 0 then
        begin
          LInstr.CallTarget := TSSAOperand.FromFunc(LFuncIndex);
          
          // For by-ref params, emit AddressOf and replace arg with address
          LTargetFunc := AIR.GetFunction(LFuncIndex);
          LJ := 0;
          for LArgIdx := 0 to LTargetFunc.Vars.Count - 1 do
          begin
            if LTargetFunc.Vars[LArgIdx].IsParam then
            begin
              if LTargetFunc.Vars[LArgIdx].IsByRef and (LJ < Length(LCallArgs)) then
              begin
                LTempVar := ASSAFunc.NewVersion('_t');
                LByRefInstr := Default(TSSAInstr);
                LByRefInstr.Kind := sikAddressOf;
                LByRefInstr.Dest := LTempVar;
                LByRefInstr.Op1 := LCallArgs[LJ];
                ASSAFunc.GetCurrentBlock().AddInstruction(LByRefInstr);
                LCallArgs[LJ] := TSSAOperand.FromVar(LTempVar);
              end;
              Inc(LJ);
            end;
          end;
          LInstr.CallArgs := LCallArgs;

          // For internal variadic functions, prepend vararg count
          if LTargetFunc.IsVariadic then
          begin
            // Count fixed params in target function
            LFixedParamCount := 0;
            for LJ := 0 to LTargetFunc.Vars.Count - 1 do
              if LTargetFunc.Vars[LJ].IsParam then
                Inc(LFixedParamCount);
            
            // Calculate vararg count
            LVarArgCount := Length(LExpr.CallArgs) - LFixedParamCount;
            if LVarArgCount < 0 then
              LVarArgCount := 0;
            
            // Prepend count to args array
            SetLength(LCallArgs, Length(LCallArgs) + 1);
            for LArgIdx := High(LCallArgs) downto 1 do
              LCallArgs[LArgIdx] := LCallArgs[LArgIdx - 1];
            LCallArgs[0] := TSSAOperand.FromImm(LVarArgCount);
            LInstr.CallArgs := LCallArgs;
          end;
        end
        else
        begin
          // Try signature-based import lookup first (for overloaded imports)
          LImportIdx := FindImportBySignature(AIR, LExpr.CallTarget, LArgTypes);
          if LImportIdx < 0 then
            // Fall back to name-only lookup (for non-overloaded imports)
            LImportIdx := FindImportByName(AIR, LExpr.CallTarget);
          if LImportIdx < 0 then
          begin
            if Assigned(FErrors) then
              FErrors.Add(esError, ERR_SSA_UNKNOWN_FUNCTION, RSSSAUnknownFunction, [LExpr.CallTarget]);
            Result := TSSAVar.None();
            Exit;
          end;
          LInstr.CallTarget := TSSAOperand.FromImport(LImportIdx);
        end;
        
        ASSAFunc.GetCurrentBlock().AddInstruction(LInstr);
        
        Result := LResultVar;
      end;
      
    TIR.TIRExprKind.ekFuncAddr:
      begin
        // Get address of a function
        LResultVar := ASSAFunc.NewVersion('_t');
        
        LInstr := Default(TSSAInstr);
        LInstr.Kind := sikFuncAddr;
        LInstr.Dest := LResultVar;
        // Store function name in Op1 - will be resolved to function index at emit time
        LInstr.Op1 := TSSAOperand.FromFunc(FindLocalFuncByName(AIR, LExpr.FuncAddrName));
        ASSAFunc.GetCurrentBlock().AddInstruction(LInstr);
        
        Result := LResultVar;
      end;
      
    TIR.TIRExprKind.ekCallIndirect:
      begin
        // Indirect call through function pointer
        // First, evaluate the function pointer expression
        LLeftVar := ConvertExpression(AIR, LExpr.IndirectTarget, ASSAFunc);
        
        // Convert call arguments
        SetLength(LCallArgs, Length(LExpr.CallArgs));
        for LArgIdx := 0 to High(LExpr.CallArgs) do
        begin
          LArgVar := ConvertExpression(AIR, LExpr.CallArgs[LArgIdx], ASSAFunc);
          LCallArgs[LArgIdx] := TSSAOperand.FromVar(LArgVar);
        end;
        
        LResultVar := ASSAFunc.NewVersion('_t');
        
        LInstr := Default(TSSAInstr);
        LInstr.Kind := sikIndirectCallAssign;
        LInstr.Dest := LResultVar;
        LInstr.Op1 := TSSAOperand.FromVar(LLeftVar);  // Function pointer
        LInstr.CallArgs := LCallArgs;
        ASSAFunc.GetCurrentBlock().AddInstruction(LInstr);
        
        Result := LResultVar;
      end;
      
    TIR.TIRExprKind.ekFieldAccess:
      begin
        // Get the object expression node
        LObjectExpr := AIR.GetExpression(LExpr.ObjectExpr);
        
        // For variable expressions with composite types, we need the address, not the value
        if (LObjectExpr.Kind = TIR.TIRExprKind.ekVariable) and 
           (not LObjectExpr.ResultType.IsPrimitive) then
        begin
          // Check if this is a parameter passed by reference (composite > 8 bytes)
          // Win64 ABI: Large structs are passed by pointer, so param value IS the address
          LIsParam := False;
          LLocalSize := 0;
          for LLocalIdx := 0 to ASSAFunc.GetLocalCount() - 1 do
          begin
            LLocalInfo := ASSAFunc.GetLocal(LLocalIdx);
            if LLocalInfo.LocalName = LObjectExpr.VarName then
            begin
              LIsParam := LLocalInfo.IsParam;
              LLocalSize := LLocalInfo.LocalSize;
              Break;
            end;
          end;
          
          // Emit AddressOf instruction to get local's/param's stack address
          LLeftVar := ASSAFunc.NewVersion('_t');
          LInstr := Default(TSSAInstr);
          LInstr.Kind := sikAddressOf;
          LInstr.Dest := LLeftVar;
          LInstr.Op1 := TSSAOperand.FromVar(ASSAFunc.CurrentVersion(LObjectExpr.VarName));
          LInstr.Op1.Var_.BaseName := LObjectExpr.VarName;  // Store base name for local lookup
          ASSAFunc.GetCurrentBlock().AddInstruction(LInstr);
          
          if LIsParam and (LLocalSize > 8) then
          begin
            // By-reference parameter: param slot contains pointer to struct
            // Load the pointer value from the param slot
            LTempVar := LLeftVar;
            LLeftVar := ASSAFunc.NewVersion('_t');
            LInstr := Default(TSSAInstr);
            LInstr.Kind := sikLoad;
            LInstr.Dest := LLeftVar;
            LInstr.Op1 := TSSAOperand.FromVar(LTempVar);
            ASSAFunc.GetCurrentBlock().AddInstruction(LInstr);
          end;
        end
        else if (LObjectExpr.Kind = TIR.TIRExprKind.ekUnary) and
                (LObjectExpr.Op = TIR.TIROpKind.opDeref) then
        begin
          // For Deref(ptr, TypeName), we want just the pointer value as base.
          // Don't generate a load - convert only the inner pointer expression.
          LLeftVar := ConvertExpression(AIR, LObjectExpr.Left, ASSAFunc);
        end
        else
        begin
          // For other expressions (pointers, etc.), convert normally
          LLeftVar := ConvertExpression(AIR, LExpr.ObjectExpr, ASSAFunc);
        end;
        
        // Create temp for field address
        LResultVar := ASSAFunc.NewVersion('_t');
        
        // Emit field address calculation using pre-computed offset
        LInstr := Default(TSSAInstr);
        LInstr.Kind := sikFieldAddr;
        LInstr.Dest := LResultVar;
        LInstr.Op1 := TSSAOperand.FromVar(LLeftVar);
        LInstr.Op2 := TSSAOperand.FromImm(LExpr.FieldOffset);  // Use pre-computed offset
        LInstr.Op2.FieldName := LExpr.FieldName;
        ASSAFunc.GetCurrentBlock().AddInstruction(LInstr);
        
        // For composite (embedded struct) fields, the fieldaddr result IS the
        // address we need for chaining further field accesses - do NOT load.
        // Only load for primitive fields to get the actual scalar value.
        if LExpr.ResultType.IsPrimitive then
        begin
          LLeftVar := LResultVar;
          LResultVar := ASSAFunc.NewVersion('_t');
          
          LInstr := Default(TSSAInstr);
          LInstr.Kind := sikLoad;
          LInstr.Dest := LResultVar;
          LInstr.Op1 := TSSAOperand.FromVar(LLeftVar);
          LInstr.MemSize := LExpr.FieldSize;
          LInstr.MemIsFloat := LExpr.ResultType.IsPrimitive and
            (LExpr.ResultType.Primitive in [vtFloat32, vtFloat64]);
          ASSAFunc.GetCurrentBlock().AddInstruction(LInstr);
        end;
        
        // If bit field, extract the bits
        if LExpr.BitWidth > 0 then
        begin
          // Shift right by BitOffset to move bits to position 0
          if LExpr.BitOffset > 0 then
          begin
            LLeftVar := LResultVar;
            LResultVar := ASSAFunc.NewVersion('_t');
            
            LInstr := Default(TSSAInstr);
            LInstr.Kind := sikShr;
            LInstr.Dest := LResultVar;
            LInstr.Op1 := TSSAOperand.FromVar(LLeftVar);
            LInstr.Op2 := TSSAOperand.FromImm(LExpr.BitOffset);
            ASSAFunc.GetCurrentBlock().AddInstruction(LInstr);
          end;
          
          // Mask to extract only BitWidth bits
          LLeftVar := LResultVar;
          LResultVar := ASSAFunc.NewVersion('_t');
          
          LInstr := Default(TSSAInstr);
          LInstr.Kind := sikBitAnd;
          LInstr.Dest := LResultVar;
          LInstr.Op1 := TSSAOperand.FromVar(LLeftVar);
          LInstr.Op2 := TSSAOperand.FromImm((Int64(1) shl LExpr.BitWidth) - 1);  // Mask with BitWidth bits
          ASSAFunc.GetCurrentBlock().AddInstruction(LInstr);
        end;
        
        Result := LResultVar;
      end;
      
    TIR.TIRExprKind.ekArrayIndex:
      begin
        // Get the array expression node
        LObjectExpr := AIR.GetExpression(LExpr.ArrayExpr);
        
        // For variable expressions with composite types (arrays), we need the address
        if (LObjectExpr.Kind = TIR.TIRExprKind.ekVariable) and 
           (not LObjectExpr.ResultType.IsPrimitive) then
        begin
          LLeftVar := ASSAFunc.NewVersion('_t');
          LInstr := Default(TSSAInstr);

          // Check if it's a global variable first
          LArgIdx := AIR.FindGlobal(LObjectExpr.VarName);
          if LArgIdx >= 0 then
          begin
            // Global variable - sokGlobal operand IS the address (backend emits LEA)
            LInstr.Kind := sikAssign;
            LInstr.Dest := LLeftVar;
            LInstr.Op1 := TSSAOperand.FromGlobal(LArgIdx);
            ASSAFunc.GetCurrentBlock().AddInstruction(LInstr);
          end
          else if (LObjectExpr.ResultType.TypeIndex >= 0) and
                  (AIR.GetTypeEntry(LObjectExpr.ResultType.TypeIndex).Kind = TIR.TIRTypeKind.tkDynArray) then
          begin
            // Dynamic array: variable holds the data pointer, use value directly
            LLeftVar := ASSAFunc.CurrentVersion(LObjectExpr.VarName);
          end
          else
          begin
            // Fixed array local - emit AddressOf to get stack address
            LInstr.Kind := sikAddressOf;
            LInstr.Dest := LLeftVar;
            LInstr.Op1 := TSSAOperand.FromVar(ASSAFunc.CurrentVersion(LObjectExpr.VarName));
            LInstr.Op1.Var_.BaseName := LObjectExpr.VarName;
            ASSAFunc.GetCurrentBlock().AddInstruction(LInstr);
          end;
        end
        else
        begin
          // For other expressions (pointers, etc.), convert normally
          LLeftVar := ConvertExpression(AIR, LExpr.ArrayExpr, ASSAFunc);
        end;
        
        // Convert index expression
        LRightVar := ConvertExpression(AIR, LExpr.IndexExpr, ASSAFunc);
        
        // Create temp for element address
        LResultVar := ASSAFunc.NewVersion('_t');
        
        // Emit index address calculation using pre-computed element size
        LInstr := Default(TSSAInstr);
        LInstr.Kind := sikIndexAddr;
        LInstr.Dest := LResultVar;
        LInstr.Op1 := TSSAOperand.FromVar(LLeftVar);
        LInstr.Op2 := TSSAOperand.FromVar(LRightVar);
        LInstr.Op2.ElementSize := LExpr.ElementSize;  // Use pre-computed element size
        ASSAFunc.GetCurrentBlock().AddInstruction(LInstr);
        
        // For composite (embedded array/record) elements, the indexaddr result IS
        // the address we need for chaining further indexing — do NOT load.
        // Only load for primitive elements to get the actual scalar value.
        if LExpr.ResultType.IsPrimitive then
        begin
          // Load scalar value from element address
          LLeftVar := LResultVar;
          LResultVar := ASSAFunc.NewVersion('_t');
          
          LInstr := Default(TSSAInstr);
          LInstr.Kind := sikLoad;
          LInstr.Dest := LResultVar;
          LInstr.Op1 := TSSAOperand.FromVar(LLeftVar);
          LInstr.MemSize := LExpr.ElementSize;
          LInstr.MemIsFloat := LExpr.ResultType.Primitive in [vtFloat32, vtFloat64];
          ASSAFunc.GetCurrentBlock().AddInstruction(LInstr);
        end;
        
        Result := LResultVar;
      end;
      
    TIR.TIRExprKind.ekGetExceptionCode:
      begin
        // Call Pax_GetExceptionCode() and store result
        LResultVar := ASSAFunc.NewVersion('_t');
        
        LInstr := Default(TSSAInstr);
        LInstr.Kind := sikCallAssign;
        LInstr.Dest := LResultVar;
        LInstr.CallTarget := TSSAOperand.FromFunc(FindLocalFuncByName(AIR, 'Gny_GetExceptionCode'));
        SetLength(LInstr.CallArgs, 0);
        ASSAFunc.GetCurrentBlock().AddInstruction(LInstr);
        
        Result := LResultVar;
      end;
      
    TIR.TIRExprKind.ekGetExceptionMsg:
      begin
        // Call Pax_GetExceptionMessage() and store result
        LResultVar := ASSAFunc.NewVersion('_t');
        
        LInstr := Default(TSSAInstr);
        LInstr.Kind := sikCallAssign;
        LInstr.Dest := LResultVar;
        LInstr.CallTarget := TSSAOperand.FromFunc(FindLocalFuncByName(AIR, 'Gny_GetExceptionMessage'));
        SetLength(LInstr.CallArgs, 0);
        ASSAFunc.GetCurrentBlock().AddInstruction(LInstr);
        
        Result := LResultVar;
      end;
      
    TIR.TIRExprKind.ekSetLiteral:
      begin
        // Create temp variable for set value
        LResultVar := ASSAFunc.NewVersion('_t');
        
        LInstr := Default(TSSAInstr);
        LInstr.Kind := sikSetLiteral;
        LInstr.Dest := LResultVar;
        LInstr.SetTypeIndex := LExpr.SetTypeIndex;
        LInstr.SetElements := Copy(LExpr.SetElements);
        // Store type info for emission phase
        LInstr.SetLowBound := AIR.GetTypeEntry(LExpr.SetTypeIndex).SetType.LowBound;
        LInstr.SetStorageSize := AIR.GetTypeEntry(LExpr.SetTypeIndex).SetType.StorageSize;
        ASSAFunc.GetCurrentBlock().AddInstruction(LInstr);
        
        Result := LResultVar;
      end;
      
    TIR.TIRExprKind.ekVaCount:
      begin
        // Get vararg count - backend reads from stack
        LResultVar := ASSAFunc.NewVersion('_t');
        
        LInstr := Default(TSSAInstr);
        LInstr.Kind := sikVaCount;
        LInstr.Dest := LResultVar;
        ASSAFunc.GetCurrentBlock().AddInstruction(LInstr);
        
        Result := LResultVar;
      end;
      
    TIR.TIRExprKind.ekVaArgAt:
      begin
        // Convert index expression
        LLeftVar := ConvertExpression(AIR, LExpr.VaArgIndex, ASSAFunc);
        
        LResultVar := ASSAFunc.NewVersion('_t');
        
        LInstr := Default(TSSAInstr);
        LInstr.Kind := sikVaArgAt;
        LInstr.Dest := LResultVar;
        LInstr.Op1 := TSSAOperand.FromVar(LLeftVar);  // Index
        LInstr.VaArgType := LExpr.VaArgType;  // Type to read as
        ASSAFunc.GetCurrentBlock().AddInstruction(LInstr);
        
        Result := LResultVar;
      end;

  else
    Result := TSSAVar.None();
  end;
  
  // Cache the result for reuse
  if Result.IsValid() then
    FExpressionCache.AddOrSetValue(AExprIndex, Result);
end;

procedure TSSABuilder.ComputeDominators(const AFunc: TSSAFunc);
var
  LNumBlocks: Integer;
  LDom: TArray<TList<Integer>>;  // Dom[i] = set of blocks that dominate block i
  LChanged: Boolean;
  LI: Integer;
  LJ: Integer;
  LK: Integer;
  LBlock: TSSABlock;
  LNewDom: TList<Integer>;
  LIntersect: TList<Integer>;
  LFirstPred: Boolean;
begin
  LNumBlocks := AFunc.GetBlockCount();
  if LNumBlocks = 0 then
    Exit;
  
  // Initialize Dom sets
  SetLength(LDom, LNumBlocks);
  for LI := 0 to LNumBlocks - 1 do
  begin
    LDom[LI] := TList<Integer>.Create();
    if LI = 0 then
    begin
      // Entry block dominates only itself
      LDom[LI].Add(0);
    end
    else
    begin
      // All other blocks: initialize with all blocks (will be narrowed)
      for LJ := 0 to LNumBlocks - 1 do
        LDom[LI].Add(LJ);
    end;
  end;
  
  // Iterate until fixed point
  LChanged := True;
  while LChanged do
  begin
    LChanged := False;
    
    for LI := 1 to LNumBlocks - 1 do  // Skip entry block
    begin
      LBlock := AFunc.GetBlock(LI);
      if LBlock.GetPredecessorCount() = 0 then
        Continue;
      
      // Compute intersection of Dom sets of all predecessors
      LNewDom := TList<Integer>.Create();
      try
        LFirstPred := True;
        
        for LJ := 0 to LBlock.GetPredecessorCount() - 1 do
        begin
          if LFirstPred then
          begin
            // Start with first predecessor's dom set
            for LK := 0 to LDom[LBlock.GetPredecessor(LJ)].Count - 1 do
              LNewDom.Add(LDom[LBlock.GetPredecessor(LJ)][LK]);
            LFirstPred := False;
          end
          else
          begin
            // Intersect with this predecessor's dom set
            LIntersect := TList<Integer>.Create();
            try
              for LK := 0 to LNewDom.Count - 1 do
              begin
                if LDom[LBlock.GetPredecessor(LJ)].Contains(LNewDom[LK]) then
                  LIntersect.Add(LNewDom[LK]);
              end;
              LNewDom.Clear();
              for LK := 0 to LIntersect.Count - 1 do
                LNewDom.Add(LIntersect[LK]);
            finally
              LIntersect.Free();
            end;
          end;
        end;
        
        // Add self
        if not LNewDom.Contains(LI) then
          LNewDom.Add(LI);
        
        // Check if changed
        if LNewDom.Count <> LDom[LI].Count then
          LChanged := True
        else
        begin
          for LK := 0 to LNewDom.Count - 1 do
          begin
            if not LDom[LI].Contains(LNewDom[LK]) then
            begin
              LChanged := True;
              Break;
            end;
          end;
        end;
        
        // Update Dom set
        if LChanged then
        begin
          LDom[LI].Clear();
          for LK := 0 to LNewDom.Count - 1 do
            LDom[LI].Add(LNewDom[LK]);
        end;
        
      finally
        LNewDom.Free();
      end;
    end;
  end;
  
  // Compute immediate dominators from Dom sets
  for LI := 0 to LNumBlocks - 1 do
  begin
    LBlock := AFunc.GetBlock(LI);
    
    if LI = 0 then
    begin
      LBlock.SetImmediateDominator(-1);  // Entry has no dominator
    end
    else
    begin
      // Immediate dominator is the dominator closest to this block
      // (dominates this block but doesn't dominate any other dominator)
      for LJ := 0 to LDom[LI].Count - 1 do
      begin
        if LDom[LI][LJ] = LI then
          Continue;  // Skip self
        
        // Check if LDom[LI][LJ] is the immediate dominator
        // It must not dominate any other dominator (except itself)
        LFirstPred := True;  // Reuse as "is immediate" flag
        for LK := 0 to LDom[LI].Count - 1 do
        begin
          if (LDom[LI][LK] <> LI) and (LDom[LI][LK] <> LDom[LI][LJ]) then
          begin
            // Check if LDom[LI][LJ] dominates LDom[LI][LK]
            if LDom[LDom[LI][LK]].Contains(LDom[LI][LJ]) then
            begin
              LFirstPred := False;  // Not immediate
              Break;
            end;
          end;
        end;
        
        if LFirstPred then
        begin
          LBlock.SetImmediateDominator(LDom[LI][LJ]);
          // Add this block to the dominator's children
          AFunc.GetBlock(LDom[LI][LJ]).AddDominatedBlock(LI);
          Break;
        end;
      end;
    end;
  end;
  
  // Clean up
  for LI := 0 to LNumBlocks - 1 do
    LDom[LI].Free();
end;

procedure TSSABuilder.ComputeDominanceFrontiers(const AFunc: TSSAFunc);
var
  LI: Integer;
  LJ: Integer;
  LBlock: TSSABlock;
  LPredIdx: Integer;
  LRunner: Integer;
  LIdom: Integer;
begin
  // Clear existing frontiers
  for LI := 0 to AFunc.GetBlockCount() - 1 do
    AFunc.GetBlock(LI).ClearDominanceFrontier();
  
  // For each block B with multiple predecessors (join point)
  for LI := 0 to AFunc.GetBlockCount() - 1 do
  begin
    LBlock := AFunc.GetBlock(LI);
    
    if LBlock.GetPredecessorCount() < 2 then
      Continue;
    
    // For each predecessor P of B
    for LJ := 0 to LBlock.GetPredecessorCount() - 1 do
    begin
      LPredIdx := LBlock.GetPredecessor(LJ);
      LRunner := LPredIdx;
      
      // Walk up the dominator tree from P to idom(B)
      // Adding B to the dominance frontier of each node along the way
      LIdom := LBlock.GetImmediateDominator();
      
      while (LRunner <> LIdom) and (LRunner >= 0) do
      begin
        AFunc.GetBlock(LRunner).AddDominanceFrontier(LI);
        LRunner := AFunc.GetBlock(LRunner).GetImmediateDominator();
      end;
    end;
  end;
end;

procedure TSSABuilder.EliminatePhiNodes(const AFunc: TSSAFunc);
var
  LI: Integer;
  LJ: Integer;
  LK: Integer;
  LM: Integer;
  LBlock: TSSABlock;
  LPredBlock: TSSABlock;
  LInstr: TSSAInstr;
  LCopyInstr: TSSAInstr;
  LTermInstr: TSSAInstr;
  LPhiIndices: TList<Integer>;
  LPhiEntry: TSSAPhiEntry;
begin
  // For each block, find phi nodes and convert to copies in predecessors
  for LI := 0 to AFunc.GetBlockCount() - 1 do
  begin
    LBlock := AFunc.GetBlock(LI);
    LPhiIndices := TList<Integer>.Create();
    try
      // Find all phi instructions
      for LJ := 0 to LBlock.GetInstructionCount() - 1 do
      begin
        LInstr := LBlock.GetInstruction(LJ);
        if LInstr.Kind = sikPhi then
          LPhiIndices.Add(LJ)
        else
          Break;  // Phi nodes are at the beginning
      end;
      
      // Process each phi node
      for LJ := LPhiIndices.Count - 1 downto 0 do
      begin
        LInstr := LBlock.GetInstruction(LPhiIndices[LJ]);
        
        // For each phi operand, insert a copy at end of predecessor
        for LK := 0 to High(LInstr.PhiEntries) do
        begin
          LPhiEntry := LInstr.PhiEntries[LK];
          LPredBlock := AFunc.GetBlock(LPhiEntry.BlockIndex);
          
          // Create copy instruction: dest = source
          LCopyInstr := Default(TSSAInstr);
          LCopyInstr.Kind := sikAssign;
          LCopyInstr.Dest := LInstr.Dest;
          LCopyInstr.Op1 := TSSAOperand.FromVar(LPhiEntry.Var_);
          
          // Insert before the terminator (jump instruction)
          // Find terminator position
          for LM := LPredBlock.GetInstructionCount() - 1 downto 0 do
          begin
            LTermInstr := LPredBlock.GetInstruction(LM);
            if LTermInstr.Kind in [sikJump, sikJumpIf, sikJumpIfNot, sikReturn, sikReturnValue] then
            begin
              LPredBlock.InsertInstructionAt(LM, LCopyInstr);
              Break;
            end;
          end;
        end;
        
        // Mark phi as nop (will be skipped during emission)
        LInstr.Kind := sikNop;
        LBlock.SetInstruction(LPhiIndices[LJ], LInstr);
      end;
      
    finally
      LPhiIndices.Free();
    end;
  end;
end;

procedure TSSABuilder.InsertPhiNodes(const AFunc: TSSAFunc);
var
  LVarName: string;
  LDefBlocks: TList<Integer>;       // Blocks where variable is defined
  LPhiBlocks: TDictionary<string, TList<Integer>>; // Blocks with phi for each var
  LWorkList: TList<Integer>;
  LI: Integer;
  LJ: Integer;
  LK: Integer;
  LBlock: TSSABlock;
  LInstr: TSSAInstr;
  LPhiInstr: TSSAInstr;
  LDFBlock: Integer;
  LVarList: TList<string>;
  LBlockPhis: TList<Integer>;
begin
  // Collect all variables that are assigned
  LVarList := TList<string>.Create();
  LPhiBlocks := TDictionary<string, TList<Integer>>.Create();
  try
    // Find all assigned variables and their definition blocks
    for LI := 0 to AFunc.GetBlockCount() - 1 do
    begin
      LBlock := AFunc.GetBlock(LI);
      for LJ := 0 to LBlock.GetInstructionCount() - 1 do
      begin
        LInstr := LBlock.GetInstruction(LJ);
        if (LInstr.Kind = sikAssign) and (LInstr.Dest.BaseName <> '') and 
           (not LInstr.Dest.BaseName.StartsWith('_t')) then
        begin
          LVarName := LInstr.Dest.BaseName;
          if not LVarList.Contains(LVarName) then
            LVarList.Add(LVarName);
          LBlock.AddDefinedVar(LVarName);
        end;
      end;
    end;
    
    // For each variable, compute where phi nodes are needed
    for LI := 0 to LVarList.Count - 1 do
    begin
      LVarName := LVarList[LI];
      LPhiBlocks.Add(LVarName, TList<Integer>.Create());
      
      // Get blocks where this variable is defined
      LDefBlocks := TList<Integer>.Create();
      LWorkList := TList<Integer>.Create();
      try
        for LJ := 0 to AFunc.GetBlockCount() - 1 do
        begin
          if AFunc.GetBlock(LJ).HasDefinedVar(LVarName) then
          begin
            LDefBlocks.Add(LJ);
            LWorkList.Add(LJ);
          end;
        end;
        
        // Iterate: add phi nodes at dominance frontiers
        while LWorkList.Count > 0 do
        begin
          LJ := LWorkList[0];
          LWorkList.Delete(0);
          LBlock := AFunc.GetBlock(LJ);
          
          // For each block in dominance frontier
          for LK := 0 to LBlock.GetDominanceFrontierCount() - 1 do
          begin
            LDFBlock := LBlock.GetDominanceFrontier(LK);
            LBlockPhis := LPhiBlocks[LVarName];
            
            // If we haven't already inserted a phi here
            if not LBlockPhis.Contains(LDFBlock) then
            begin
              LBlockPhis.Add(LDFBlock);
              
              // If this block wasn't already a def block, add to worklist
              if not LDefBlocks.Contains(LDFBlock) then
              begin
                LDefBlocks.Add(LDFBlock);
                LWorkList.Add(LDFBlock);
              end;
            end;
          end;
        end;
      finally
        LWorkList.Free();
        LDefBlocks.Free();
      end;
    end;
    
    // Now actually insert phi instructions at the beginning of blocks
    for LI := 0 to LVarList.Count - 1 do
    begin
      LVarName := LVarList[LI];
      LBlockPhis := LPhiBlocks[LVarName];
      
      for LJ := 0 to LBlockPhis.Count - 1 do
      begin
        LBlock := AFunc.GetBlock(LBlockPhis[LJ]);
        
        // Create phi instruction
        LPhiInstr := Default(TSSAInstr);
        LPhiInstr.Kind := sikPhi;
        LPhiInstr.Dest := TSSAVar.Create(LVarName, 0); // Version assigned during rename
        
        // Pre-allocate phi entries for each predecessor
        SetLength(LPhiInstr.PhiEntries, LBlock.GetPredecessorCount());
        for LK := 0 to LBlock.GetPredecessorCount() - 1 do
        begin
          LPhiInstr.PhiEntries[LK].BlockIndex := LBlock.GetPredecessor(LK);
          LPhiInstr.PhiEntries[LK].Var_ := TSSAVar.Create(LVarName, 0); // Filled during rename
        end;
        
        // Insert at beginning of block
        LBlock.InsertInstructionAt(0, LPhiInstr);
      end;
    end;
    
  finally
    // Clean up phi block lists
    for LVarName in LPhiBlocks.Keys do
      LPhiBlocks[LVarName].Free();
    LPhiBlocks.Free();
    LVarList.Free();
  end;
end;

procedure TSSABuilder.RenameVariables(const AFunc: TSSAFunc);
var
  LVarStacks: TDictionary<string, TStack<Integer>>;
  LVarCounters: TDictionary<string, Integer>;
  
  function GetNewVersion(const AVarName: string): Integer;
  var
    LCounter: Integer;
  begin
    if LVarCounters.TryGetValue(AVarName, LCounter) then
    begin
      Result := LCounter;
      LVarCounters[AVarName] := LCounter + 1;
    end
    else
    begin
      Result := 0;
      LVarCounters.Add(AVarName, 1);
    end;
  end;
  
  function GetCurrentVersion(const AVarName: string): Integer;
  var
    LStack: TStack<Integer>;
  begin
    if LVarStacks.TryGetValue(AVarName, LStack) and (LStack.Count > 0) then
      Result := LStack.Peek()
    else
      Result := 0;
  end;
  
  procedure PushVersion(const AVarName: string; const AVersion: Integer);
  var
    LStack: TStack<Integer>;
  begin
    if not LVarStacks.TryGetValue(AVarName, LStack) then
    begin
      LStack := TStack<Integer>.Create();
      LVarStacks.Add(AVarName, LStack);
    end;
    LStack.Push(AVersion);
  end;
  
  procedure RenameBlock(const ABlockIndex: Integer);
  var
    LBlock: TSSABlock;
    LInstr: TSSAInstr;
    LI: Integer;
    LJ: Integer;
    LK: Integer;
    LNewVersion: Integer;
    LPushedVars: TList<string>;
    LSuccBlock: TSSABlock;
    LSuccInstr: TSSAInstr;
    LPredIdx: Integer;
    LVarName: string;
    LChildIdx: Integer;
  begin
    LBlock := AFunc.GetBlock(ABlockIndex);
    LPushedVars := TList<string>.Create();
    try
      // Process each instruction in the block
      for LI := 0 to LBlock.GetInstructionCount() - 1 do
      begin
        LInstr := LBlock.GetInstruction(LI);
        
        // For phi nodes, only rename the destination
        if LInstr.Kind = sikPhi then
        begin
          LVarName := LInstr.Dest.BaseName;
          LNewVersion := GetNewVersion(LVarName);
          LInstr.Dest := TSSAVar.Create(LVarName, LNewVersion);
          PushVersion(LVarName, LNewVersion);
          LPushedVars.Add(LVarName);
          LBlock.SetInstruction(LI, LInstr);
          Continue;
        end;
        
        // Rename uses (Op1, Op2) - get current version from stack
        // Skip compiler-generated temps (start with '_')
        if (LInstr.Op1.Kind = sokVar) and (not LInstr.Op1.Var_.BaseName.StartsWith('_')) then
        begin
          LVarName := LInstr.Op1.Var_.BaseName;
          LInstr.Op1.Var_ := TSSAVar.Create(LVarName, GetCurrentVersion(LVarName));
        end;
        
        if (LInstr.Op2.Kind = sokVar) and (not LInstr.Op2.Var_.BaseName.StartsWith('_')) then
        begin
          LVarName := LInstr.Op2.Var_.BaseName;
          LInstr.Op2.Var_ := TSSAVar.Create(LVarName, GetCurrentVersion(LVarName));
        end;
        
        // Rename call arguments
        for LJ := 0 to High(LInstr.CallArgs) do
        begin
          if (LInstr.CallArgs[LJ].Kind = sokVar) and 
             (not LInstr.CallArgs[LJ].Var_.BaseName.StartsWith('_')) then
          begin
            LVarName := LInstr.CallArgs[LJ].Var_.BaseName;
            LInstr.CallArgs[LJ].Var_ := TSSAVar.Create(LVarName, GetCurrentVersion(LVarName));
          end;
        end;
        
        // Rename definition (Dest) - create new version
        if (LInstr.Kind = sikAssign) and (LInstr.Dest.BaseName <> '') and
           (not LInstr.Dest.BaseName.StartsWith('_')) then
        begin
          LVarName := LInstr.Dest.BaseName;
          LNewVersion := GetNewVersion(LVarName);
          LInstr.Dest := TSSAVar.Create(LVarName, LNewVersion);
          PushVersion(LVarName, LNewVersion);
          LPushedVars.Add(LVarName);
        end;
        
        LBlock.SetInstruction(LI, LInstr);
      end;
      
      // Fill in phi operands in successor blocks
      for LI := 0 to LBlock.GetSuccessorCount() - 1 do
      begin
        LSuccBlock := AFunc.GetBlock(LBlock.GetSuccessor(LI));
        
        // Find which predecessor index we are
        LPredIdx := -1;
        for LJ := 0 to LSuccBlock.GetPredecessorCount() - 1 do
        begin
          if LSuccBlock.GetPredecessor(LJ) = ABlockIndex then
          begin
            LPredIdx := LJ;
            Break;
          end;
        end;
        
        if LPredIdx < 0 then
          Continue;
        
        // Update phi instructions
        for LJ := 0 to LSuccBlock.GetInstructionCount() - 1 do
        begin
          LSuccInstr := LSuccBlock.GetInstruction(LJ);
          if LSuccInstr.Kind <> sikPhi then
            Break; // Phi nodes are at the beginning
          
          // Find the phi entry for this predecessor
          for LK := 0 to High(LSuccInstr.PhiEntries) do
          begin
            if LSuccInstr.PhiEntries[LK].BlockIndex = ABlockIndex then
            begin
              LVarName := LSuccInstr.Dest.BaseName;
              LSuccInstr.PhiEntries[LK].Var_ := TSSAVar.Create(
                LVarName, GetCurrentVersion(LVarName)
              );
              Break;
            end;
          end;
          
          LSuccBlock.SetInstruction(LJ, LSuccInstr);
        end;
      end;
      
      // Recurse to dominated blocks (children in dominator tree)
      for LI := 0 to LBlock.GetDominatedBlockCount() - 1 do
      begin
        LChildIdx := LBlock.GetDominatedBlock(LI);
        RenameBlock(LChildIdx);
      end;
      
      // Pop versions pushed in this block
      for LI := LPushedVars.Count - 1 downto 0 do
      begin
        LVarName := LPushedVars[LI];
        if LVarStacks.ContainsKey(LVarName) then
          LVarStacks[LVarName].Pop();
      end;
      
    finally
      LPushedVars.Free();
    end;
  end;
  
var
  LVarName: string;
  LI: Integer;
begin
  LVarStacks := TDictionary<string, TStack<Integer>>.Create();
  LVarCounters := TDictionary<string, Integer>.Create();
  try
    // Initialize parameters with version 0 (they come in defined)
    for LI := 0 to AFunc.GetLocalCount() - 1 do
    begin
      if AFunc.GetLocal(LI).IsParam then
      begin
        LVarName := AFunc.GetLocal(LI).LocalName;
        PushVersion(LVarName, 0);
        LVarCounters.Add(LVarName, 1);
      end;
    end;
    
    // Start renaming from entry block (block 0)
    if AFunc.GetBlockCount() > 0 then
      RenameBlock(0);
      
  finally
    // Clean up stacks
    for LVarName in LVarStacks.Keys do
      LVarStacks[LVarName].Free();
    LVarStacks.Free();
    LVarCounters.Free();
  end;
end;

procedure TSSABuilder.Optimize(const ALevel: Integer);
var
  LI: Integer;
  LJ: Integer;
  LPass: TSSAPass;
  LFunc: TSSAFunc;
  LPassCount: Integer;
begin
  // Skip optimization if level is 0
  if ALevel = 0 then
  begin
    Status('SSA: Optimization skipped (level 0)');
    Exit;
  end;
  
  // Count how many passes will run at this level
  LPassCount := 0;
  for LI := 0 to FPasses.Count - 1 do
  begin
    if FPasses[LI].GetMinLevel() <= ALevel then
      Inc(LPassCount);
  end;
  
  Status('SSA: Running %d optimization passes (level %d)', [LPassCount, ALevel]);
  
  for LI := 0 to FPasses.Count - 1 do
  begin
    LPass := FPasses[LI];
    
    // Skip passes that require higher level
    if LPass.GetMinLevel() > ALevel then
      Continue;
    
    Status('SSA: Running pass: %s', [LPass.GetPassName()]);
    
    for LJ := 0 to FFunctions.Count - 1 do
    begin
      LFunc := FFunctions[LJ];
      LPass.Run(LFunc);
    end;
  end;

  // Function-level DCE - remove unreferenced functions
  RemoveUnreferencedFunctions();
end;

procedure TSSABuilder.RemoveUnreferencedFunctions();
var
  LLive: array of Boolean;
  LIndexMap: array of Integer;  // Old index -> New index (-1 if removed)
  LChanged: Boolean;
  LI: Integer;
  LJ: Integer;
  LK: Integer;
  //LM: Integer;
  LFunc: TSSAFunc;
  LBlock: TSSABlock;
  LInstr: TSSAInstr;
  LTargetIdx: Integer;
  LNewIdx: Integer;
  LRemovedCount: Integer;
  LNewFunctions: TObjectList<TSSAFunc>;
begin
  if FFunctions.Count = 0 then
    Exit;

  //----------------------------------------------------------------------------
  // Step 1: Initialize live set - mark entry points
  //----------------------------------------------------------------------------
  SetLength(LLive, FFunctions.Count);
  for LI := 0 to FFunctions.Count - 1 do
  begin
    LFunc := FFunctions[LI];
    LLive[LI] := LFunc.GetIsEntryPoint() or LFunc.GetIsDllEntry() or LFunc.GetIsPublic();
  end;

  //----------------------------------------------------------------------------
  // Step 1b: Mark exception runtime functions as live if any function uses SEH
  //----------------------------------------------------------------------------
  for LI := 0 to FFunctions.Count - 1 do
  begin
    LFunc := FFunctions[LI];
    if LFunc.GetExceptionScopeCount() > 0 then
    begin
      // This function uses try/except/finally - mark runtime functions as live
      for LJ := 0 to FFunctions.Count - 1 do
      begin
        LFunc := FFunctions[LJ];
        if (LFunc.GetFuncName() = 'Gny_InitExceptions') or
           (LFunc.GetFuncName() = 'Gny_SetException') or
           (LFunc.GetFuncName() = 'Gny_Raise') or
           (LFunc.GetFuncName() = 'Gny_RaiseCode') or
           (LFunc.GetFuncName() = 'Gny_GetExceptionCode') or
           (LFunc.GetFuncName() = 'Gny_GetExceptionMessage') or
           (LFunc.GetFuncName() = 'Gny_SEHFilter') or
           // Linux64-specific: called by backend-generated code, not IR
           (LFunc.GetFuncName() = 'Gny_PushExceptFrame') or
           (LFunc.GetFuncName() = 'Gny_PopExceptFrame') or
           (LFunc.GetFuncName() = 'Gny_InitSignals') or
           (LFunc.GetFuncName() = 'Gny_SignalHandler') or
           (LFunc.GetFuncName() = 'Gny_GetExceptFrame') then
          LLive[LJ] := True;
      end;
      Break;  // Only need to check once
    end;
  end;

  //----------------------------------------------------------------------------
  // Step 2: Transitively mark all functions called by live functions
  //----------------------------------------------------------------------------
  repeat
    LChanged := False;

    for LI := 0 to FFunctions.Count - 1 do
    begin
      if not LLive[LI] then
        Continue;

      LFunc := FFunctions[LI];

      // Scan all blocks
      for LJ := 0 to LFunc.GetBlockCount() - 1 do
      begin
        LBlock := LFunc.GetBlock(LJ);

        // Scan all instructions
        for LK := 0 to LBlock.GetInstructionCount() - 1 do
        begin
          LInstr := LBlock.GetInstruction(LK);

          // Check for function calls
          if (LInstr.Kind in [sikCall, sikCallAssign]) and
             (LInstr.CallTarget.Kind = sokFunc) then
          begin
            LTargetIdx := LInstr.CallTarget.FuncIndex;
            if (LTargetIdx >= 0) and (LTargetIdx < Length(LLive)) and (not LLive[LTargetIdx]) then
            begin
              LLive[LTargetIdx] := True;
              LChanged := True;
            end;
          end;

          // Check for function address (indirect calls)
          if (LInstr.Kind = sikFuncAddr) and (LInstr.Op1.Kind = sokFunc) then
          begin
            LTargetIdx := LInstr.Op1.FuncIndex;
            if (LTargetIdx >= 0) and (LTargetIdx < Length(LLive)) and (not LLive[LTargetIdx]) then
            begin
              LLive[LTargetIdx] := True;
              LChanged := True;
            end;
          end;
        end;
      end;
    end;
  until not LChanged;

  //----------------------------------------------------------------------------
  // Step 3: Count removed functions and build index mapping
  //----------------------------------------------------------------------------
  LRemovedCount := 0;
  SetLength(LIndexMap, FFunctions.Count);
  LNewIdx := 0;
  for LI := 0 to FFunctions.Count - 1 do
  begin
    if LLive[LI] then
    begin
      LIndexMap[LI] := LNewIdx;
      Inc(LNewIdx);
    end
    else
    begin
      LIndexMap[LI] := -1;
      Inc(LRemovedCount);
    end;
  end;

  if LRemovedCount = 0 then
  begin
    Status('SSA: Function DCE - no unreferenced functions');
    Exit;
  end;

  Status('SSA: Function DCE - removing %d unreferenced function(s)', [LRemovedCount]);

  //----------------------------------------------------------------------------
  // Step 4: Update function indices in all remaining instructions
  //----------------------------------------------------------------------------
  for LI := 0 to FFunctions.Count - 1 do
  begin
    if not LLive[LI] then
      Continue;

    LFunc := FFunctions[LI];

    for LJ := 0 to LFunc.GetBlockCount() - 1 do
    begin
      LBlock := LFunc.GetBlock(LJ);

      for LK := 0 to LBlock.GetInstructionCount() - 1 do
      begin
        LInstr := LBlock.GetInstruction(LK);

        // Update function call targets
        if (LInstr.Kind in [sikCall, sikCallAssign]) and
           (LInstr.CallTarget.Kind = sokFunc) then
        begin
          LTargetIdx := LInstr.CallTarget.FuncIndex;
          if (LTargetIdx >= 0) and (LTargetIdx < Length(LIndexMap)) then
          begin
            LInstr.CallTarget.FuncIndex := LIndexMap[LTargetIdx];
            LBlock.SetInstruction(LK, LInstr);
          end;
        end;

        // Update function address references
        if (LInstr.Kind = sikFuncAddr) and (LInstr.Op1.Kind = sokFunc) then
        begin
          LTargetIdx := LInstr.Op1.FuncIndex;
          if (LTargetIdx >= 0) and (LTargetIdx < Length(LIndexMap)) then
          begin
            LInstr.Op1.FuncIndex := LIndexMap[LTargetIdx];
            LBlock.SetInstruction(LK, LInstr);
          end;
        end;
      end;
    end;
  end;

  //----------------------------------------------------------------------------
  // Step 5: Build new function list with only live functions
  //----------------------------------------------------------------------------
  LNewFunctions := TObjectList<TSSAFunc>.Create(True);
  try
    // Iterate backwards to avoid index shifting issues when extracting
    for LI := FFunctions.Count - 1 downto 0 do
    begin
      if LLive[LI] then
      begin
        LFunc := FFunctions[LI];
        FFunctions.Extract(LFunc);  // Remove ownership without freeing
        LNewFunctions.Insert(0, LFunc);  // Insert at front to maintain order
      end;
    end;

    // Swap lists - dead functions in FFunctions will be freed
    FFunctions.Free();
    FFunctions := LNewFunctions;
    LNewFunctions := nil;  // Prevent double-free in finally
  finally
    LNewFunctions.Free();
  end;
end;

function TSSABuilder.DumpSSA(): string;
var
  LFuncIdx: Integer;
  LBlockIdx: Integer;
  LInstrIdx: Integer;
  LFunc: TSSAFunc;
  LBlock: TSSABlock;
  LInstr: TSSAInstr;
  LPhiIdx: Integer;
  LArgIdx: Integer;
  LLine: string;
  LResult: TStringBuilder;
begin
  LResult := TStringBuilder.Create();
  try
    LResult.AppendLine('=== SSA Dump ===');
    
    for LFuncIdx := 0 to FFunctions.Count - 1 do
    begin
      LFunc := FFunctions[LFuncIdx];
      LResult.AppendLine('Function: ' + LFunc.GetFuncName());
      LResult.AppendLine('  Locals: ' + IntToStr(LFunc.GetLocalCount()));
      LResult.AppendLine('  Blocks: ' + IntToStr(LFunc.GetBlockCount()));
      
      for LBlockIdx := 0 to LFunc.GetBlockCount() - 1 do
      begin
        LBlock := LFunc.GetBlock(LBlockIdx);
        LResult.AppendLine('  Block ' + IntToStr(LBlockIdx) + ' (' + LBlock.GetBlockName() + ')');
        LResult.AppendLine('    Preds: ' + IntToStr(LBlock.GetPredecessorCount()) + ', Succs: ' + IntToStr(LBlock.GetSuccessorCount()));
        LResult.AppendLine('    IDom: ' + IntToStr(LBlock.GetImmediateDominator()));
        
        for LInstrIdx := 0 to LBlock.GetInstructionCount() - 1 do
        begin
          LInstr := LBlock.GetInstruction(LInstrIdx);
          
          case LInstr.Kind of
            sikNop: LLine := 'nop';
            sikAssign: LLine := Format('%s = %s', [LInstr.Dest.ToString(), LInstr.Op1.ToString()]);
            sikAdd: LLine := Format('%s = %s + %s', [LInstr.Dest.ToString(), LInstr.Op1.ToString(), LInstr.Op2.ToString()]);
            sikSub: LLine := Format('%s = %s - %s', [LInstr.Dest.ToString(), LInstr.Op1.ToString(), LInstr.Op2.ToString()]);
            sikMul: LLine := Format('%s = %s * %s', [LInstr.Dest.ToString(), LInstr.Op1.ToString(), LInstr.Op2.ToString()]);
            sikDiv: LLine := Format('%s = %s / %s', [LInstr.Dest.ToString(), LInstr.Op1.ToString(), LInstr.Op2.ToString()]);
            sikFAdd: LLine := Format('%s = float(%s + %s)', [LInstr.Dest.ToString(), LInstr.Op1.ToString(), LInstr.Op2.ToString()]);
            sikFSub: LLine := Format('%s = float(%s - %s)', [LInstr.Dest.ToString(), LInstr.Op1.ToString(), LInstr.Op2.ToString()]);
            sikFMul: LLine := Format('%s = float(%s * %s)', [LInstr.Dest.ToString(), LInstr.Op1.ToString(), LInstr.Op2.ToString()]);
            sikFDiv: LLine := Format('%s = float(%s / %s)', [LInstr.Dest.ToString(), LInstr.Op1.ToString(), LInstr.Op2.ToString()]);
            sikFNeg: LLine := Format('%s = float(-%s)', [LInstr.Dest.ToString(), LInstr.Op1.ToString()]);
            sikIntToFloat: LLine := Format('%s = int_to_float(%s)', [LInstr.Dest.ToString(), LInstr.Op1.ToString()]);
            sikFloatToInt: LLine := Format('%s = float_to_int(%s)', [LInstr.Dest.ToString(), LInstr.Op1.ToString()]);
            sikCmpEq: LLine := Format('%s = %s == %s', [LInstr.Dest.ToString(), LInstr.Op1.ToString(), LInstr.Op2.ToString()]);
            sikCmpNe: LLine := Format('%s = %s != %s', [LInstr.Dest.ToString(), LInstr.Op1.ToString(), LInstr.Op2.ToString()]);
            sikCmpLt: LLine := Format('%s = %s < %s', [LInstr.Dest.ToString(), LInstr.Op1.ToString(), LInstr.Op2.ToString()]);
            sikCmpLe: LLine := Format('%s = %s <= %s', [LInstr.Dest.ToString(), LInstr.Op1.ToString(), LInstr.Op2.ToString()]);
            sikCmpGt: LLine := Format('%s = %s > %s', [LInstr.Dest.ToString(), LInstr.Op1.ToString(), LInstr.Op2.ToString()]);
            sikCmpGe: LLine := Format('%s = %s >= %s', [LInstr.Dest.ToString(), LInstr.Op1.ToString(), LInstr.Op2.ToString()]);
            sikJump: LLine := Format('jump block_%d', [LInstr.Op1.BlockIndex]);
            sikJumpIf: LLine := Format('jumpif %s block_%d', [LInstr.Op1.ToString(), LInstr.Op2.BlockIndex]);
            sikJumpIfNot: LLine := Format('jumpifnot %s block_%d', [LInstr.Op1.ToString(), LInstr.Op2.BlockIndex]);
            sikCall:
              begin
                if LInstr.CallTarget.Kind = sokFunc then
                  LLine := Format('call func_%d(', [LInstr.CallTarget.FuncIndex])
                else
                  LLine := Format('call import_%d(', [LInstr.CallTarget.ImportIndex]);
                for LArgIdx := 0 to High(LInstr.CallArgs) do
                begin
                  if LArgIdx > 0 then LLine := LLine + ', ';
                  LLine := LLine + LInstr.CallArgs[LArgIdx].ToString();
                end;
                LLine := LLine + ')';
              end;
            sikCallAssign:
              begin
                if LInstr.CallTarget.Kind = sokFunc then
                  LLine := Format('%s = call func_%d(', [LInstr.Dest.ToString(), LInstr.CallTarget.FuncIndex])
                else
                  LLine := Format('%s = call import_%d(', [LInstr.Dest.ToString(), LInstr.CallTarget.ImportIndex]);
                for LArgIdx := 0 to High(LInstr.CallArgs) do
                begin
                  if LArgIdx > 0 then LLine := LLine + ', ';
                  LLine := LLine + LInstr.CallArgs[LArgIdx].ToString();
                end;
                LLine := LLine + ')';
              end;
            sikReturn: LLine := 'return';
            sikReturnValue: LLine := Format('return %s', [LInstr.Op1.ToString()]);
            sikPhi:
              begin
                LLine := Format('%s = phi(', [LInstr.Dest.ToString()]);
                for LPhiIdx := 0 to High(LInstr.PhiEntries) do
                begin
                  if LPhiIdx > 0 then LLine := LLine + ', ';
                  LLine := LLine + Format('[block_%d: %s]', [
                    LInstr.PhiEntries[LPhiIdx].BlockIndex,
                    LInstr.PhiEntries[LPhiIdx].Var_.ToString()
                  ]);
                end;
                LLine := LLine + ')';
              end;
            sikLoad: LLine := Format('%s = load(%s)', [LInstr.Dest.ToString(), LInstr.Op1.ToString()]);
            sikStore: LLine := Format('store(%s, %s)', [LInstr.Op1.ToString(), LInstr.Op2.ToString()]);
            sikAddressOf: LLine := Format('%s = addrof(%s)', [LInstr.Dest.ToString(), LInstr.Op1.ToString()]);
            sikFieldAddr: LLine := Format('%s = fieldaddr(%s, %s[off=%d])', [LInstr.Dest.ToString(), LInstr.Op1.ToString(), LInstr.Op2.FieldName, LInstr.Op2.ImmInt]);
            sikIndexAddr: LLine := Format('%s = indexaddr(%s, %s, size=%d)', [LInstr.Dest.ToString(), LInstr.Op1.ToString(), LInstr.Op2.ToString(), LInstr.Op2.ElementSize]);
            sikSetLiteral: LLine := Format('%s = setliteral[%d elements]', [LInstr.Dest.ToString(), Length(LInstr.SetElements)]);
            sikSetUnion: LLine := Format('%s = %s + %s', [LInstr.Dest.ToString(), LInstr.Op1.ToString(), LInstr.Op2.ToString()]);
            sikSetDiff: LLine := Format('%s = %s - %s', [LInstr.Dest.ToString(), LInstr.Op1.ToString(), LInstr.Op2.ToString()]);
            sikSetInter: LLine := Format('%s = %s * %s', [LInstr.Dest.ToString(), LInstr.Op1.ToString(), LInstr.Op2.ToString()]);
            sikSetIn: LLine := Format('%s = %s in %s', [LInstr.Dest.ToString(), LInstr.Op1.ToString(), LInstr.Op2.ToString()]);
            sikSetEq: LLine := Format('%s = %s =set %s', [LInstr.Dest.ToString(), LInstr.Op1.ToString(), LInstr.Op2.ToString()]);
            sikSetNe: LLine := Format('%s = %s <>set %s', [LInstr.Dest.ToString(), LInstr.Op1.ToString(), LInstr.Op2.ToString()]);
            sikSetSubset: LLine := Format('%s = %s <=set %s', [LInstr.Dest.ToString(), LInstr.Op1.ToString(), LInstr.Op2.ToString()]);
            sikSetSuperset: LLine := Format('%s = %s >=set %s', [LInstr.Dest.ToString(), LInstr.Op1.ToString(), LInstr.Op2.ToString()]);
            sikFuncAddr: LLine := Format('%s = funcaddr(%s)', [LInstr.Dest.ToString(), LInstr.Op1.ToString()]);
            sikMod: LLine := Format('%s = %s %% %s', [LInstr.Dest.ToString(), LInstr.Op1.ToString(), LInstr.Op2.ToString()]);
            sikNeg: LLine := Format('%s = -%s', [LInstr.Dest.ToString(), LInstr.Op1.ToString()]);
            sikBitAnd: LLine := Format('%s = %s & %s', [LInstr.Dest.ToString(), LInstr.Op1.ToString(), LInstr.Op2.ToString()]);
            sikBitOr: LLine := Format('%s = %s | %s', [LInstr.Dest.ToString(), LInstr.Op1.ToString(), LInstr.Op2.ToString()]);
            sikBitXor: LLine := Format('%s = %s ^ %s', [LInstr.Dest.ToString(), LInstr.Op1.ToString(), LInstr.Op2.ToString()]);
            sikBitNot: LLine := Format('%s = ~%s', [LInstr.Dest.ToString(), LInstr.Op1.ToString()]);
            sikShl: LLine := Format('%s = %s << %s', [LInstr.Dest.ToString(), LInstr.Op1.ToString(), LInstr.Op2.ToString()]);
            sikShr: LLine := Format('%s = %s >> %s', [LInstr.Dest.ToString(), LInstr.Op1.ToString(), LInstr.Op2.ToString()]);
          else
            LLine := Format('unknown_%d', [Ord(LInstr.Kind)]);
          end;
          
          LResult.AppendLine('      ' + IntToStr(LInstrIdx) + ': ' + LLine);
        end;
      end;
      LResult.AppendLine('');
    end;
    
    LResult.AppendLine('=== End SSA Dump ===');
    Result := LResult.ToString();
  finally
    LResult.Free();
  end;
end;

procedure TSSABuilder.AddPass(const APass: TSSAPass);
begin
  FPasses.Add(APass);
end;

procedure TSSABuilder.ClearPasses();
begin
  FPasses.Clear();
end;

function TSSABuilder.GetFunctionCount(): Integer;
begin
  Result := FFunctions.Count;
end;

function TSSABuilder.GetFunction(const AIndex: Integer): TSSAFunc;
begin
  Result := FFunctions[AIndex];
end;

function TSSABuilder.GetStrReleaseFuncIdx(): Integer;
begin
  Result := FStrReleaseFuncIdx;
end;

function TSSABuilder.GetFreeMemFuncIdx(): Integer;
begin
  Result := FFreMemFuncIdx;
end;

function TSSABuilder.GetDynFreeFuncIdx(): Integer;
begin
  Result := FDynFreeFuncIdx;
end;

function TSSABuilder.GetReportLeaksFuncIdx(): Integer;
begin
  Result := FReportLeaksFuncIdx;
end;

function TSSABuilder.GetReleaseOnDetachFuncIdx(): Integer;
begin
  Result := FReleaseOnDetachFuncIdx;
end;

procedure TSSABuilder.Clear();
begin
  FFunctions.Clear();
  FCurrentFuncIndex := -1;
  FStrReleaseFuncIdx := -1;
  FFreMemFuncIdx := -1;
  FDynFreeFuncIdx := -1;
  FReportLeaksFuncIdx := -1;
  FReleaseOnDetachFuncIdx := -1;
  FExpressionCache.Clear();
end;

end.
