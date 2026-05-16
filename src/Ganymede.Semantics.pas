{===============================================================================
  Ganymede™ - Embeddable Native Scripting Engine

  Copyright © 2026-present tinyBigGAMES™ LLC
  All Rights Reserved.

  See LICENSE for license information
===============================================================================}

unit Ganymede.Semantics;

{$I Ganymede.Defines.inc}

interface

uses
  System.SysUtils,
  System.Generics.Collections,
  Ganymede.Utils,
  Ganymede.Resources,
  Ganymede.Lexer,
  Ganymede.Parser;

type
  { TGnyScriptSymbolKind }
  TGnyScriptSymbolKind = (
    skRoutine,
    skParam,
    skVariable,
    skConst,
    skType,
    skModule
  );

  { TGnyScriptSymbol }
  TGnyScriptSymbol = record
    SymbolName: string;
    Kind: TGnyScriptSymbolKind;
    TypeName: string;            // resolved type (e.g. 'int32')
    ReturnType: string;          // for routines
    ParamCount: Integer;         // for routines
    NodeIndex: Integer;          // AST node that declared this symbol
  end;

  { TGnyScriptRecordFieldInfo — field metadata for record types }
  TGnyScriptRecordFieldInfo = record
    FieldName: string;
    FieldTypeName: string;
  end;

  { TGnyScriptArrayTypeInfo — metadata for array types }
  TGnyScriptArrayTypeInfo = record
    ElementTypeName: string;
    IsStatic: Boolean;
    LowBound: Integer;
    HighBound: Integer;
  end;

  { TGnyScriptScope — one level of the scope stack }
  TGnyScriptScope = class
  private
    FSymbols: TDictionary<string, TGnyScriptSymbol>;
  public
    constructor Create();
    destructor Destroy(); override;
    function Declare(const ASymbol: TGnyScriptSymbol): Boolean;
    function Lookup(const AName: string; var ASymbol: TGnyScriptSymbol): Boolean;
    function FindKeysWithPrefix(const APrefix: string;
      var AKeys: TArray<string>): Boolean;
  end;

  { TGnyScriptSemantics }
  TGnyScriptSemantics = class(TGnyBaseObject)
  private
    FNodes: TList<TGnyScriptNode>;
    FScopes: TObjectList<TGnyScriptScope>;
    FExterns: TList<TGnyScriptSymbol>;
    FModuleExports: TObjectDictionary<string, TList<TGnyScriptSymbol>>;
    FRecordTypes: TDictionary<string, TArray<TGnyScriptRecordFieldInfo>>;
    FArrayTypes: TDictionary<string, TGnyScriptArrayTypeInfo>;
    FLoopDepth: Integer;

    // Scope management
    procedure PushScope();
    procedure PopScope();
    function FindSymbol(const AName: string; var ASymbol: TGnyScriptSymbol): Boolean;
    function DeclareSymbol(const ASymbol: TGnyScriptSymbol): Boolean;
    function FindModuleExport(const AModuleName: string;
      const ASymbolName: string; var ASymbol: TGnyScriptSymbol): Boolean;

    // AST walkers
    procedure AnalyzeModule(const AIndex: Integer);
    procedure AnalyzeRoutineDecl(const AIndex: Integer);
    procedure AnalyzeBlock(const AIndex: Integer);
    procedure AnalyzeStatement(const AIndex: Integer);
    procedure AnalyzeVarDecl(const AIndex: Integer);
    procedure AnalyzeConstDecl(const AIndex: Integer);
    procedure AnalyzeTypeDecl(const AIndex: Integer);
    procedure AnalyzeAssign(const AIndex: Integer);
    function  ResolveExprType(const AIndex: Integer): string;

  public
    constructor Create(); override;
    destructor Destroy(); override;

    // Main entry point
    function Analyze(const ANodes: TList<TGnyScriptNode>;
      const ARoot: Integer): Boolean;

    // Pre-register an external function (e.g. host API) so the analyzer
    // accepts calls to it without a source-level declaration.
    procedure RegisterExtern(const AName: string;
      const AParamTypes: TArray<string>; const AReturnType: string);

    // Register an imported module with its exported symbols
    procedure RegisterModule(const AModuleName: string;
      const AExports: TArray<TGnyScriptSymbol>);

    // Symbol lookup for emitter
    function LookupSymbol(const AName: string;
      var ASymbol: TGnyScriptSymbol): Boolean;

    // Find all symbol keys matching a prefix (for overload resolution)
    function FindSymbolsWithPrefix(const APrefix: string;
      var AKeys: TArray<string>): Boolean;

    // Record type field lookup (for emitter)
    function FindRecordField(const ATypeName: string;
      const AFieldName: string; var AFieldTypeName: string): Boolean;
    function GetRecordFields(const ATypeName: string): TArray<TGnyScriptRecordFieldInfo>;

    // Array type lookup (for emitter)
    function FindArrayElementType(const ATypeName: string;
      var AElementTypeName: string): Boolean;
    function GetArrayTypeInfo(const ATypeName: string;
      var AInfo: TGnyScriptArrayTypeInfo): Boolean;
    function IsArrayType(const ATypeName: string): Boolean;
  end;

const
  GNY_ERROR_SCRIPT_SEM_UNDECLARED   = 'SS0001';
  GNY_ERROR_SCRIPT_SEM_DUPLICATE    = 'SS0002';
  GNY_ERROR_SCRIPT_SEM_TYPE         = 'SS0003';
  GNY_ERROR_SCRIPT_SEM_CONST_ASSIGN = 'SS0004';
  GNY_ERROR_SCRIPT_SEM_NOT_IN_LOOP  = 'SS0005';
  GNY_ERROR_SCRIPT_SEM_UNKNOWN_FIELD = 'SS0006';
  GNY_ERROR_SCRIPT_SEM_UNKNOWN_TYPE  = 'SS0007';

implementation

{ TGnyScriptScope }

constructor TGnyScriptScope.Create();
begin
  inherited Create();
  FSymbols := TDictionary<string, TGnyScriptSymbol>.Create();
end;

destructor TGnyScriptScope.Destroy();
begin
  FSymbols.Free();
  inherited Destroy();
end;

function TGnyScriptScope.Declare(const ASymbol: TGnyScriptSymbol): Boolean;
begin
  if FSymbols.ContainsKey(ASymbol.SymbolName) then
    Result := False
  else
  begin
    FSymbols.Add(ASymbol.SymbolName, ASymbol);
    Result := True;
  end;
end;

function TGnyScriptScope.Lookup(const AName: string;
  var ASymbol: TGnyScriptSymbol): Boolean;
begin
  Result := FSymbols.TryGetValue(AName, ASymbol);
end;

function TGnyScriptScope.FindKeysWithPrefix(const APrefix: string;
  var AKeys: TArray<string>): Boolean;
var
  LKey: string;
  LCount: Integer;
begin
  LCount := 0;
  SetLength(AKeys, FSymbols.Count);
  for LKey in FSymbols.Keys do
  begin
    if LKey.StartsWith(APrefix) then
    begin
      AKeys[LCount] := LKey;
      Inc(LCount);
    end;
  end;
  SetLength(AKeys, LCount);
  Result := LCount > 0;
end;

{ TGnyScriptSemantics }

constructor TGnyScriptSemantics.Create();
begin
  inherited Create();
  try
    FScopes := TObjectList<TGnyScriptScope>.Create(True);
    FExterns := TList<TGnyScriptSymbol>.Create();
    FModuleExports := TObjectDictionary<string, TList<TGnyScriptSymbol>>.Create([doOwnsValues]);
    FRecordTypes := TDictionary<string, TArray<TGnyScriptRecordFieldInfo>>.Create();
    FArrayTypes := TDictionary<string, TGnyScriptArrayTypeInfo>.Create();
  except
    on E: Exception do
    begin
      FErrors.Add(esFatal, '', RSFatalInternalError, [E.Message]);
      Exit;
    end;
  end;
end;

destructor TGnyScriptSemantics.Destroy();
begin
  FArrayTypes.Free();
  FRecordTypes.Free();
  FModuleExports.Free();
  FExterns.Free();
  FScopes.Free();
  inherited Destroy();
end;

//------------------------------------------------------------------------------
// Scope management
//------------------------------------------------------------------------------

procedure TGnyScriptSemantics.PushScope();
begin
  FScopes.Add(TGnyScriptScope.Create());
end;

procedure TGnyScriptSemantics.PopScope();
begin
  if FScopes.Count > 0 then
    FScopes.Delete(FScopes.Count - 1);
end;

function TGnyScriptSemantics.FindSymbol(const AName: string;
  var ASymbol: TGnyScriptSymbol): Boolean;
var
  LI: Integer;
begin
  // Search from innermost scope outward
  for LI := FScopes.Count - 1 downto 0 do
  begin
    if FScopes[LI].Lookup(AName, ASymbol) then
    begin
      Result := True;
      Exit;
    end;
  end;
  Result := False;
end;

function TGnyScriptSemantics.DeclareSymbol(
  const ASymbol: TGnyScriptSymbol): Boolean;
begin
  Result := False;
  if FScopes.Count = 0 then
    Exit;
  Result := FScopes[FScopes.Count - 1].Declare(ASymbol);
end;

function TGnyScriptSemantics.LookupSymbol(const AName: string;
  var ASymbol: TGnyScriptSymbol): Boolean;
begin
  Result := FindSymbol(AName, ASymbol);
end;

function TGnyScriptSemantics.FindSymbolsWithPrefix(const APrefix: string;
  var AKeys: TArray<string>): Boolean;
var
  LI: Integer;
  LJ: Integer;
  LScopeKeys: TArray<string>;
begin
  AKeys := nil;
  // Search from innermost scope outward
  for LI := FScopes.Count - 1 downto 0 do
  begin
    if FScopes[LI].FindKeysWithPrefix(APrefix, LScopeKeys) then
    begin
      for LJ := 0 to Length(LScopeKeys) - 1 do
      begin
        SetLength(AKeys, Length(AKeys) + 1);
        AKeys[Length(AKeys) - 1] := LScopeKeys[LJ];
      end;
    end;
  end;
  Result := Length(AKeys) > 0;
end;

procedure TGnyScriptSemantics.RegisterExtern(const AName: string;
  const AParamTypes: TArray<string>; const AReturnType: string);
var
  LSym: TGnyScriptSymbol;
  LSignature: string;
  LI: Integer;
begin
  // Build signature key: "funcName(type1,type2,...)"
  LSignature := AName + '(';
  for LI := 0 to Length(AParamTypes) - 1 do
  begin
    if LI > 0 then
      LSignature := LSignature + ',';
    LSignature := LSignature + AParamTypes[LI];
  end;
  LSignature := LSignature + ')';

  LSym := Default(TGnyScriptSymbol);
  LSym.SymbolName := LSignature;
  LSym.Kind := skRoutine;
  LSym.ReturnType := AReturnType;
  LSym.ParamCount := Length(AParamTypes);
  LSym.NodeIndex := -1;

  FExterns.Add(LSym);
end;

procedure TGnyScriptSemantics.RegisterModule(const AModuleName: string;
  const AExports: TArray<TGnyScriptSymbol>);
var
  LModSym: TGnyScriptSymbol;
  LExportList: TList<TGnyScriptSymbol>;
  LI: Integer;
begin
  // Register module as a symbol so it can be found in scope
  LModSym := Default(TGnyScriptSymbol);
  LModSym.SymbolName := AModuleName;
  LModSym.Kind := skModule;
  LModSym.NodeIndex := -1;
  FExterns.Add(LModSym);

  // Store exported symbols for qualified lookup
  LExportList := TList<TGnyScriptSymbol>.Create();
  for LI := 0 to Length(AExports) - 1 do
    LExportList.Add(AExports[LI]);

  // doOwnsValues handles freeing the old list on replacement
  FModuleExports.AddOrSetValue(AModuleName, LExportList);
end;

function TGnyScriptSemantics.FindModuleExport(const AModuleName: string;
  const ASymbolName: string; var ASymbol: TGnyScriptSymbol): Boolean;
var
  LExportList: TList<TGnyScriptSymbol>;
  LPrefix: string;
  LI: Integer;
begin
  Result := False;
  if not FModuleExports.TryGetValue(AModuleName, LExportList) then
    Exit;
  // Match by signature prefix: "funcName(" matches "funcName(int64)" etc.
  LPrefix := ASymbolName + '(';
  for LI := 0 to LExportList.Count - 1 do
  begin
    if LExportList[LI].SymbolName.StartsWith(LPrefix) then
    begin
      ASymbol := LExportList[LI];
      Result := True;
      Exit;
    end;
  end;
end;

//------------------------------------------------------------------------------
// Main entry point
//------------------------------------------------------------------------------

function TGnyScriptSemantics.Analyze(const ANodes: TList<TGnyScriptNode>;
  const ARoot: Integer): Boolean;
var
  LI: Integer;
begin
  FNodes := ANodes;
  FScopes.Clear();
  FRecordTypes.Clear();
  FArrayTypes.Clear();

  Status(RSSemStatusStart);

  // Global scope
  PushScope();

  // Inject pre-registered external functions into global scope
  for LI := 0 to FExterns.Count - 1 do
    DeclareSymbol(FExterns[LI]);

  if (ARoot >= 0) and (ARoot < FNodes.Count) then
    AnalyzeModule(ARoot);

  Status(RSSemStatusComplete, [FErrors.ErrorCount()]);

  Result := FErrors.ErrorCount() = 0;
end;

//------------------------------------------------------------------------------
// AST walkers
//------------------------------------------------------------------------------

procedure TGnyScriptSemantics.AnalyzeModule(const AIndex: Integer);
var
  LNode: TGnyScriptNode;
  LChild: TGnyScriptNode;
  LI: Integer;
begin
  LNode := FNodes[AIndex];

  for LI := 0 to Length(LNode.Children) - 1 do
  begin
    LChild := FNodes[LNode.Children[LI]];
    if LChild.Kind = nkRoutineDecl then
      AnalyzeRoutineDecl(LNode.Children[LI])
    else if LChild.Kind = nkVarDecl then
      AnalyzeVarDecl(LNode.Children[LI])
    else if LChild.Kind = nkConstDecl then
      AnalyzeConstDecl(LNode.Children[LI])
    else if LChild.Kind = nkTypeDecl then
      AnalyzeTypeDecl(LNode.Children[LI])
    else if LChild.Kind = nkBlock then
      AnalyzeBlock(LNode.Children[LI]);
  end;
end;

procedure TGnyScriptSemantics.AnalyzeRoutineDecl(const AIndex: Integer);
var
  LNode: TGnyScriptNode;
  LChild: TGnyScriptNode;
  LSym: TGnyScriptSymbol;
  LParamSym: TGnyScriptSymbol;
  LI: Integer;
  LParamCount: Integer;
  LSignature: string;
  LFirst: Boolean;
begin
  LNode := FNodes[AIndex];

  // Build signature key: "routineName(type1,type2,...)"
  // Each overload gets a unique key based on its parameter types
  LSignature := LNode.Text + '(';
  LFirst := True;
  LParamCount := 0;
  for LI := 0 to Length(LNode.Children) - 1 do
  begin
    if FNodes[LNode.Children[LI]].Kind = nkParamDecl then
    begin
      if not LFirst then
        LSignature := LSignature + ',';
      LSignature := LSignature + FNodes[LNode.Children[LI]].Extra;
      LFirst := False;
      Inc(LParamCount);
    end;
  end;
  LSignature := LSignature + ')';

  // Register routine in current scope with signature key
  LSym := Default(TGnyScriptSymbol);
  LSym.SymbolName := LSignature;
  LSym.Kind := skRoutine;
  LSym.ReturnType := LNode.Extra;
  LSym.ParamCount := LParamCount;
  LSym.NodeIndex := AIndex;

  if not DeclareSymbol(LSym) then
    FErrors.Add(LNode.Range, esError, GNY_ERROR_SCRIPT_SEM_DUPLICATE,
      RSScriptDuplicateDecl, [LSignature]);

  // Push routine scope for params and body
  PushScope();

  // Register parameters
  for LI := 0 to Length(LNode.Children) - 1 do
  begin
    LChild := FNodes[LNode.Children[LI]];
    if LChild.Kind = nkParamDecl then
    begin
      LParamSym := Default(TGnyScriptSymbol);
      LParamSym.SymbolName := LChild.Text;
      LParamSym.Kind := skParam;
      LParamSym.TypeName := LChild.Extra;
      LParamSym.NodeIndex := LNode.Children[LI];

      if not DeclareSymbol(LParamSym) then
        FErrors.Add(LChild.Range, esError, GNY_ERROR_SCRIPT_SEM_DUPLICATE,
          RSScriptDuplicateDecl, [LChild.Text]);
    end
    else if LChild.Kind = nkVarDecl then
      AnalyzeVarDecl(LNode.Children[LI])
    else if LChild.Kind = nkConstDecl then
      AnalyzeConstDecl(LNode.Children[LI])
    else if LChild.Kind = nkTypeDecl then
      AnalyzeTypeDecl(LNode.Children[LI])
    else if LChild.Kind = nkBlock then
      AnalyzeBlock(LNode.Children[LI]);
  end;

  PopScope();
end;

procedure TGnyScriptSemantics.AnalyzeBlock(const AIndex: Integer);
var
  LNode: TGnyScriptNode;
  LI: Integer;
begin
  LNode := FNodes[AIndex];
  for LI := 0 to Length(LNode.Children) - 1 do
    AnalyzeStatement(LNode.Children[LI]);
end;

procedure TGnyScriptSemantics.AnalyzeStatement(const AIndex: Integer);
var
  LNode: TGnyScriptNode;
  LChild: TGnyScriptNode;
  LSym: TGnyScriptSymbol;
  LI: Integer;
  LJ: Integer;
begin
  if AIndex < 0 then
    Exit;
  LNode := FNodes[AIndex];

  if LNode.Kind = nkIf then
  begin
    // Analyze condition and blocks
    if Length(LNode.Children) > 0 then
      ResolveExprType(LNode.Children[0]); // condition
    if Length(LNode.Children) > 1 then
      AnalyzeBlock(LNode.Children[1]);    // then block
    if Length(LNode.Children) > 2 then
      AnalyzeBlock(LNode.Children[2]);    // else block
  end
  else if LNode.Kind = nkWhile then
  begin
    // children[0] = condition, children[1] = body block
    if Length(LNode.Children) > 0 then
      ResolveExprType(LNode.Children[0]);
    Inc(FLoopDepth);
    if Length(LNode.Children) > 1 then
      AnalyzeBlock(LNode.Children[1]);
    Dec(FLoopDepth);
  end
  else if LNode.Kind = nkFor then
  begin
    // Text = var name, children[0] = from, children[1] = to, children[2] = body
    PushScope();
    // Declare loop variable
    LSym := Default(TGnyScriptSymbol);
    LSym.SymbolName := LNode.Text;
    LSym.Kind := skVariable;
    LSym.TypeName := 'int32';
    LSym.NodeIndex := AIndex;
    DeclareSymbol(LSym);
    if Length(LNode.Children) > 0 then
      ResolveExprType(LNode.Children[0]); // from
    if Length(LNode.Children) > 1 then
      ResolveExprType(LNode.Children[1]); // to
    Inc(FLoopDepth);
    if Length(LNode.Children) > 2 then
      AnalyzeBlock(LNode.Children[2]);    // body
    Dec(FLoopDepth);
    PopScope();
  end
  else if LNode.Kind = nkRepeat then
  begin
    // children[0] = body block, children[1] = until condition
    Inc(FLoopDepth);
    if Length(LNode.Children) > 0 then
      AnalyzeBlock(LNode.Children[0]);
    Dec(FLoopDepth);
    if Length(LNode.Children) > 1 then
      ResolveExprType(LNode.Children[1]);
  end
  else if LNode.Kind = nkMatch then
  begin
    // children[0] = selector expression
    // children[1..N] = nkMatchArm nodes (each: labels + body block)
    // children[N+1] = optional else block (when Extra = 'else')
    if Length(LNode.Children) > 0 then
      ResolveExprType(LNode.Children[0]); // selector

    for LI := 1 to Length(LNode.Children) - 1 do
    begin
      LChild := FNodes[LNode.Children[LI]];
      if LChild.Kind = nkMatchArm then
      begin
        // Analyze all children: labels are expressions, last child is body block
        for LJ := 0 to Length(LChild.Children) - 1 do
        begin
          if FNodes[LChild.Children[LJ]].Kind = nkBlock then
            AnalyzeBlock(LChild.Children[LJ])
          else
            ResolveExprType(LChild.Children[LJ]);
        end;
      end
      else if LChild.Kind = nkBlock then
        AnalyzeBlock(LNode.Children[LI]); // else block
    end;
  end
  else if LNode.Kind = nkLeave then
  begin
    if FLoopDepth <= 0 then
      FErrors.Add(LNode.Range, esError, GNY_ERROR_SCRIPT_SEM_NOT_IN_LOOP,
        RSScriptBreakOutsideLoop, []);
  end
  else if LNode.Kind = nkSkip then
  begin
    if FLoopDepth <= 0 then
      FErrors.Add(LNode.Range, esError, GNY_ERROR_SCRIPT_SEM_NOT_IN_LOOP,
        RSScriptContinueOutsideLoop, []);
  end
  else if LNode.Kind = nkReturn then
  begin
    if Length(LNode.Children) > 0 then
      ResolveExprType(LNode.Children[0]);
  end
  else if LNode.Kind = nkAssign then
    AnalyzeAssign(AIndex)
  else if (LNode.Kind = nkWrite) or (LNode.Kind = nkWriteLn) then
  begin
    // Analyze all argument expressions
    for LI := 0 to Length(LNode.Children) - 1 do
      ResolveExprType(LNode.Children[LI]);
  end
  else
    // Expression statement (call, etc.)
    ResolveExprType(AIndex);
end;

//------------------------------------------------------------------------------
// Var declaration analysis
//------------------------------------------------------------------------------

procedure TGnyScriptSemantics.AnalyzeVarDecl(const AIndex: Integer);
var
  LNode: TGnyScriptNode;
  LSym: TGnyScriptSymbol;
  LArrayInfo: TGnyScriptArrayTypeInfo;
  LTypeName: string;
  LBracketPos: Integer;
  LDotDotPos: Integer;
  LOfPos: Integer;
begin
  LNode := FNodes[AIndex];

  // Register variable in current scope
  LSym := Default(TGnyScriptSymbol);
  LSym.SymbolName := LNode.Text;
  LSym.Kind := skVariable;
  LSym.TypeName := LNode.Extra;
  LSym.NodeIndex := AIndex;

  if not DeclareSymbol(LSym) then
    FErrors.Add(LNode.Range, esError, GNY_ERROR_SCRIPT_SEM_DUPLICATE,
      RSScriptDuplicateDecl, [LNode.Text]);

  // Auto-register inline array types (e.g., "array[0..9] of int32")
  LTypeName := LNode.Extra;
  if LTypeName.StartsWith('array') and (not FArrayTypes.ContainsKey(LTypeName)) then
  begin
    LArrayInfo := Default(TGnyScriptArrayTypeInfo);

    // Static array: "array[low..high] of elemType"
    LBracketPos := Pos('[', LTypeName);
    if LBracketPos > 0 then
    begin
      LArrayInfo.IsStatic := True;
      LDotDotPos := Pos('..', LTypeName);
      LArrayInfo.LowBound := StrToIntDef(
        Copy(LTypeName, LBracketPos + 1, LDotDotPos - LBracketPos - 1), 0);
      LArrayInfo.HighBound := StrToIntDef(
        Copy(LTypeName, LDotDotPos + 2,
          Pos(']', LTypeName) - LDotDotPos - 2), 0);
    end;

    // Extract element type after " of "
    LOfPos := Pos(' of ', LTypeName);
    if LOfPos > 0 then
      LArrayInfo.ElementTypeName := Copy(LTypeName, LOfPos + 4, MaxInt);

    FArrayTypes.AddOrSetValue(LTypeName, LArrayInfo);
  end;

  // Analyze initializer expression if present
  if Length(LNode.Children) > 0 then
    ResolveExprType(LNode.Children[0]);
end;

//------------------------------------------------------------------------------
// Const declaration analysis
//------------------------------------------------------------------------------

procedure TGnyScriptSemantics.AnalyzeConstDecl(const AIndex: Integer);
var
  LNode: TGnyScriptNode;
  LSym: TGnyScriptSymbol;
begin
  LNode := FNodes[AIndex];

  // Register constant in current scope
  LSym := Default(TGnyScriptSymbol);
  LSym.SymbolName := LNode.Text;
  LSym.Kind := skConst;
  LSym.TypeName := LNode.Extra;
  LSym.NodeIndex := AIndex;

  if not DeclareSymbol(LSym) then
    FErrors.Add(LNode.Range, esError, GNY_ERROR_SCRIPT_SEM_DUPLICATE,
      RSScriptDuplicateDecl, [LNode.Text]);

  // Analyze initializer expression (always present for constants)
  if Length(LNode.Children) > 0 then
    ResolveExprType(LNode.Children[0]);
end;

//------------------------------------------------------------------------------
// Type declaration analysis
//------------------------------------------------------------------------------

procedure TGnyScriptSemantics.AnalyzeTypeDecl(const AIndex: Integer);
var
  LNode: TGnyScriptNode;
  LRecNode: TGnyScriptNode;
  LFieldNode: TGnyScriptNode;
  LSym: TGnyScriptSymbol;
  LFields: TArray<TGnyScriptRecordFieldInfo>;
  LFieldInfo: TGnyScriptRecordFieldInfo;
  LArrayInfo: TGnyScriptArrayTypeInfo;
  LFieldCount: Integer;
  LDotPos: Integer;
  LI: Integer;
begin
  LNode := FNodes[AIndex];

  // Register type name as a symbol
  LSym := Default(TGnyScriptSymbol);
  LSym.SymbolName := LNode.Text;
  LSym.Kind := skType;
  LSym.TypeName := LNode.Text;
  LSym.NodeIndex := AIndex;

  if not DeclareSymbol(LSym) then
  begin
    FErrors.Add(LNode.Range, esError, GNY_ERROR_SCRIPT_SEM_DUPLICATE,
      RSScriptDuplicateDecl, [LNode.Text]);
    Exit;
  end;

  // If child is nkRecordType, collect field metadata
  if (Length(LNode.Children) > 0) and
     (FNodes[LNode.Children[0]].Kind = nkRecordType) then
  begin
    LRecNode := FNodes[LNode.Children[0]];
    LFieldCount := 0;
    SetLength(LFields, Length(LRecNode.Children));

    for LI := 0 to Length(LRecNode.Children) - 1 do
    begin
      LFieldNode := FNodes[LRecNode.Children[LI]];
      if LFieldNode.Kind = nkFieldDecl then
      begin
        LFieldInfo := Default(TGnyScriptRecordFieldInfo);
        LFieldInfo.FieldName := LFieldNode.Text;
        LFieldInfo.FieldTypeName := LFieldNode.Extra;
        LFields[LFieldCount] := LFieldInfo;
        Inc(LFieldCount);
      end;
    end;
    SetLength(LFields, LFieldCount);

    FRecordTypes.AddOrSetValue(LNode.Text, LFields);
  end

  // If child is nkArrayType, collect array metadata
  else if (Length(LNode.Children) > 0) and
     (FNodes[LNode.Children[0]].Kind = nkArrayType) then
  begin
    LRecNode := FNodes[LNode.Children[0]]; // reuse variable for array node
    LArrayInfo := Default(TGnyScriptArrayTypeInfo);
    LArrayInfo.ElementTypeName := LRecNode.Extra;
    LArrayInfo.IsStatic := LRecNode.Text <> '';

    // Parse bounds from Text: "low..high"
    if LArrayInfo.IsStatic then
    begin
      LDotPos := Pos('..', LRecNode.Text);
      if LDotPos > 0 then
      begin
        LArrayInfo.LowBound := StrToIntDef(Copy(LRecNode.Text, 1, LDotPos - 1), 0);
        LArrayInfo.HighBound := StrToIntDef(Copy(LRecNode.Text, LDotPos + 2, MaxInt), 0);
      end;
    end;

    FArrayTypes.AddOrSetValue(LNode.Text, LArrayInfo);
  end;
end;

//------------------------------------------------------------------------------
// Assignment analysis
//------------------------------------------------------------------------------

procedure TGnyScriptSemantics.AnalyzeAssign(const AIndex: Integer);
var
  LNode: TGnyScriptNode;
  LLhsNode: TGnyScriptNode;
  LSym: TGnyScriptSymbol;
begin
  LNode := FNodes[AIndex];

  // child[0] = LHS designator, child[1] = RHS expression
  if Length(LNode.Children) >= 2 then
  begin
    // Check if LHS is a constant — assignment to constants is forbidden
    LLhsNode := FNodes[LNode.Children[0]];
    if (LLhsNode.Kind = nkIdent) and FindSymbol(LLhsNode.Text, LSym) then
    begin
      if LSym.Kind = skConst then
      begin
        FErrors.Add(LNode.Range, esError, GNY_ERROR_SCRIPT_SEM_CONST_ASSIGN,
          RSScriptConstAssign, [LLhsNode.Text]);
        Exit;
      end;
    end;

    ResolveExprType(LNode.Children[0]); // validates LHS is declared
    ResolveExprType(LNode.Children[1]); // validates RHS types
  end;
end;

function TGnyScriptSemantics.ResolveExprType(const AIndex: Integer): string;
var
  LNode: TGnyScriptNode;
  LSym: TGnyScriptSymbol;
  LLeftType: string;
  LRightType: string;
  LKeys: TArray<string>;
  LI: Integer;

  function IsFloatType(const AType: string): Boolean;
  begin
    Result := (AType = 'float32') or (AType = 'float64');
  end;

  // Store resolved type on the expression node for the emitter
  procedure StoreType(const AType: string);
  begin
    LNode := FNodes[AIndex];
    LNode.Extra := AType;
    FNodes[AIndex] := LNode;
  end;

begin
  Result := '';
  if AIndex < 0 then
    Exit;
  LNode := FNodes[AIndex];

  if LNode.Kind = nkIntLit then
    Result := 'int32'

  else if LNode.Kind = nkFloatLit then
    Result := 'float64'

  else if LNode.Kind = nkStringLit then
    Result := 'string'

  else if LNode.Kind = nkWStringLit then
    Result := 'wstring'

  else if LNode.Kind = nkBoolLit then
    Result := 'boolean'

  else if LNode.Kind = nkIdent then
  begin
    if FindSymbol(LNode.Text, LSym) then
      Result := LSym.TypeName
    else
      FErrors.Add(LNode.Range, esError, GNY_ERROR_SCRIPT_SEM_UNDECLARED,
        RSScriptUndeclaredIdent, [LNode.Text]);
  end

  else if LNode.Kind = nkBinary then
  begin
    if Length(LNode.Children) >= 2 then
    begin
      LLeftType := ResolveExprType(LNode.Children[0]);
      LRightType := ResolveExprType(LNode.Children[1]);

      // Comparison operators always produce boolean
      if (LNode.Text = '=') or (LNode.Text = '<>') or
         (LNode.Text = '<') or (LNode.Text = '>') or
         (LNode.Text = '<=') or (LNode.Text = '>=') then
        Result := 'boolean'

      // / always produces float64 (by language design)
      else if LNode.Text = '/' then
        Result := 'float64'

      // div, mod, bitwise/shift — always integer
      else if (LNode.Text = 'div') or (LNode.Text = 'mod') or
              (LNode.Text = 'shl') or (LNode.Text = 'shr') or
              (LNode.Text = 'xor') or (LNode.Text = '^') or
              (LNode.Text = 'and') or (LNode.Text = 'or') then
        Result := LLeftType

      // Arithmetic (+, -, *): promote to float if either operand is float
      else if IsFloatType(LLeftType) or IsFloatType(LRightType) then
        Result := 'float64'
      else
        Result := LLeftType;
    end;
  end

  else if LNode.Kind = nkUnary then
  begin
    if Length(LNode.Children) > 0 then
      Result := ResolveExprType(LNode.Children[0]);
  end

  else if LNode.Kind = nkFieldAccess then
  begin
    // children[0] = LHS (object/module/record var), Text = field name
    if Length(LNode.Children) > 0 then
    begin
      if (FNodes[LNode.Children[0]].Kind = nkIdent) and
         FindSymbol(FNodes[LNode.Children[0]].Text, LSym) and
         (LSym.Kind = skModule) then
      begin
        // Module-qualified access: module.symbol
        if FindModuleExport(FNodes[LNode.Children[0]].Text, LNode.Text, LSym) then
          Result := LSym.ReturnType
        else
          FErrors.Add(LNode.Range, esError, GNY_ERROR_SCRIPT_SEM_UNDECLARED,
            RSScriptUndeclaredIdent, [FNodes[LNode.Children[0]].Text + '.' + LNode.Text]);
      end
      else
      begin
        // Resolve LHS type — could be a record variable
        LLeftType := ResolveExprType(LNode.Children[0]);

        // Try record field access: if LHS is a record type, look up the field
        if (LLeftType <> '') and FindRecordField(LLeftType, LNode.Text, LRightType) then
          Result := LRightType;
      end;
    end;
  end

  else if LNode.Kind = nkArrayIndex then
  begin
    // children[0] = array expression, children[1] = index expression
    if Length(LNode.Children) >= 2 then
    begin
      LLeftType := ResolveExprType(LNode.Children[0]); // array type
      ResolveExprType(LNode.Children[1]);               // index expression

      // Look up element type from array type info
      if (LLeftType <> '') and FindArrayElementType(LLeftType, LRightType) then
        Result := LRightType;
    end;
  end

  else if LNode.Kind = nkRecordLiteral then
  begin
    // Text = record type name, children = nkFieldInit nodes
    // Validate the type exists
    if FindSymbol(LNode.Text, LSym) and (LSym.Kind = skType) then
    begin
      Result := LNode.Text;

      // Resolve all field initializer expressions
      for LI := 0 to Length(LNode.Children) - 1 do
      begin
        if FNodes[LNode.Children[LI]].Kind = nkFieldInit then
        begin
          if Length(FNodes[LNode.Children[LI]].Children) > 0 then
            ResolveExprType(FNodes[LNode.Children[LI]].Children[0]);
        end;
      end;
    end
    else
      FErrors.Add(LNode.Range, esError, GNY_ERROR_SCRIPT_SEM_UNKNOWN_TYPE,
        RSScriptUndeclaredIdent, [LNode.Text]);
  end

  else if LNode.Kind = nkFuncCall then
  begin
    // children[0] = callee, children[1..n] = args
    if Length(LNode.Children) > 0 then
    begin
      LNode := FNodes[LNode.Children[0]];

      // Module-qualified call: module.func(args)
      if (LNode.Kind = nkFieldAccess) and (Length(LNode.Children) > 0) and
         (FNodes[LNode.Children[0]].Kind = nkIdent) and
         FindSymbol(FNodes[LNode.Children[0]].Text, LSym) and
         (LSym.Kind = skModule) then
      begin
        if FindModuleExport(FNodes[LNode.Children[0]].Text, LNode.Text, LSym) then
          Result := LSym.ReturnType
        else
          FErrors.Add(LNode.Range, esError, GNY_ERROR_SCRIPT_SEM_UNDECLARED,
            RSScriptUndeclaredIdent, [FNodes[LNode.Children[0]].Text + '.' + LNode.Text]);
      end
      // Direct call: func(args) — resolve via signature prefix matching
      else if (LNode.Kind = nkIdent) and
              FindSymbolsWithPrefix(LNode.Text + '(', LKeys) then
      begin
        if FindSymbol(LKeys[0], LSym) then
          Result := LSym.ReturnType;
      end
      else if LNode.Kind = nkIdent then
        FErrors.Add(LNode.Range, esError, GNY_ERROR_SCRIPT_SEM_UNDECLARED,
          RSScriptUndeclaredIdent, [LNode.Text]);
    end;
  end;

  // Store resolved type on the node for the emitter to read
  if Result <> '' then
    StoreType(Result);
end;

//------------------------------------------------------------------------------
// Record type field lookup (for emitter)
//------------------------------------------------------------------------------

function TGnyScriptSemantics.FindRecordField(const ATypeName: string;
  const AFieldName: string; var AFieldTypeName: string): Boolean;
var
  LFields: TArray<TGnyScriptRecordFieldInfo>;
  LI: Integer;
begin
  Result := False;
  if not FRecordTypes.TryGetValue(ATypeName, LFields) then
    Exit;

  for LI := 0 to Length(LFields) - 1 do
  begin
    if LFields[LI].FieldName = AFieldName then
    begin
      AFieldTypeName := LFields[LI].FieldTypeName;
      Result := True;
      Exit;
    end;
  end;
end;

function TGnyScriptSemantics.GetRecordFields(
  const ATypeName: string): TArray<TGnyScriptRecordFieldInfo>;
begin
  if not FRecordTypes.TryGetValue(ATypeName, Result) then
    Result := nil;
end;

//------------------------------------------------------------------------------
// Array type lookup
//------------------------------------------------------------------------------

function TGnyScriptSemantics.FindArrayElementType(const ATypeName: string;
  var AElementTypeName: string): Boolean;
var
  LInfo: TGnyScriptArrayTypeInfo;
begin
  Result := FArrayTypes.TryGetValue(ATypeName, LInfo);
  if Result then
    AElementTypeName := LInfo.ElementTypeName;
end;

function TGnyScriptSemantics.GetArrayTypeInfo(const ATypeName: string;
  var AInfo: TGnyScriptArrayTypeInfo): Boolean;
begin
  Result := FArrayTypes.TryGetValue(ATypeName, AInfo);
end;

function TGnyScriptSemantics.IsArrayType(const ATypeName: string): Boolean;
begin
  Result := FArrayTypes.ContainsKey(ATypeName);
end;

end.
