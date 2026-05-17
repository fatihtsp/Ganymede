{===============================================================================
  Ganymede™ - Embeddable Native Scripting Engine

  Copyright © 2026-present tinyBigGAMES™ LLC
  All Rights Reserved.

  See LICENSE for license information
===============================================================================}

unit Ganymede.Parser;

{$I Ganymede.Defines.inc}

interface

uses
  System.SysUtils,
  System.TypInfo,
  System.Generics.Collections,
  Ganymede.Utils,
  Ganymede.Resources,
  Ganymede.Lexer;

type
  { TGnyScriptNodeKind — full set, only fib-relevant ones implemented now }
  TGnyScriptNodeKind = (
    // Program structure
    nkProgram,
    nkModule,

    // Declarations
    nkImport, nkExported,
    nkConstBlock, nkConstDecl,
    nkTypeBlock, nkTypeDecl,
    nkVarBlock, nkVarDecl,
    nkRoutineDecl, nkMethodDecl, nkParamDecl, nkExternalDecl,
    nkRecordType, nkObjectType, nkOverlayType, nkFieldDecl,
    nkArrayType, nkPointerType, nkSetType, nkChoicesType, nkRoutineType,

    // Statements
    nkBlock, nkAssign, nkCall,
    nkIf, nkWhile, nkFor, nkRepeat, nkMatch, nkMatchArm,
    nkReturn, nkLeave, nkSkip,
    nkCreate, nkDestroy,
    nkGetMem, nkFreeMem, nkResizeMem, nkSetLength,
    nkWrite, nkWriteLn,

    // Expressions
    nkIntLit, nkFloatLit, nkStringLit, nkWStringLit,
    nkBoolLit, nkNilLit,
    nkIdent, nkSelf, nkParent, nkVarArgs,
    nkBinary, nkUnary, nkGrouped,
    nkFieldAccess, nkArrayIndex, nkDeref, nkAddressOf,
    nkFuncCall, nkTypeCast,
    nkSetLiteral, nkRecordLiteral, nkFieldInit,

    // Intrinsics
    nkLen, nkSize, nkUtf8, nkParamCount, nkParamStr,

    // Directives
    nkDirective
  );

  { TGnyScriptNode }
  TGnyScriptNode = record
    Kind: TGnyScriptNodeKind;
    Text: string;              // primary: name, literal value, operator
    Extra: string;             // secondary: type name, return type
    IsPublic: Boolean;         // declared with 'public' modifier
    Children: TArray<Integer>; // child node indices into flat array
    Range: TGnySourceRange;
  end;

  { TGnyScriptParser }
  TGnyScriptParser = class(TGnyBaseObject)
  private
    // Token stream
    FTokens: TList<TGnyScriptToken>;
    FPos: Integer;

    // AST node storage (flat array)
    FNodes: TList<TGnyScriptNode>;
    FRoot: Integer;

    // Token stream helpers
    function Peek(): TGnyScriptToken;
    function PeekKind(): TGnyScriptTokenKind;
    function AtEnd(): Boolean;
    function Advance(): TGnyScriptToken;
    function Match(const AKind: TGnyScriptTokenKind): Boolean;
    function Expect(const AKind: TGnyScriptTokenKind): TGnyScriptToken;

    // Node creation
    function AddNode(const AKind: TGnyScriptNodeKind;
      const ARange: TGnySourceRange): Integer;
    procedure AddChild(const AParent, AChild: Integer);

    // Parsers — module structure
    function ParseModule(): Integer;
    function ParseImportClause(): Integer;
    function ParseRoutineDecl(): Integer;
    function ParseParamList(): TArray<Integer>;
    function ParseTypeExpr(): string;
    function ParseBlock(): Integer;

    // Parsers — statements
    function ParseStatement(): Integer;
    function ParseIfStatement(): Integer;
    function ParseWhileStatement(): Integer;
    function ParseForStatement(): Integer;
    function ParseRepeatStatement(): Integer;
    function ParseMatchStatement(): Integer;
    function ParseReturnStatement(): Integer;
    function ParseLeaveStatement(): Integer;
    function ParseSkipStatement(): Integer;
    function ParseWriteStatement(): Integer;
    function ParseSetLengthStatement(): Integer;
    function ParseVarBlock(const AParentNode: Integer): Integer;
    function ParseConstBlock(const AParentNode: Integer): Integer;
    function ParseTypeBlock(const AParentNode: Integer): Integer;
    function ParseRecordType(): Integer;
    function ParseArrayType(): Integer;
    function ParsePointerType(): Integer;
    function ParseChoicesType(): Integer;
    function ParseSetType(): Integer;
    function ParseOverlayType(): Integer;
    function TryParseAssign(const ALhs: Integer): Integer;

    // Parsers — expressions (Pratt)
    function ParseExpression(const AMinBP: Integer = 0): Integer;
    function GetInfixBP(const AKind: TGnyScriptTokenKind): Integer;

  public
    constructor Create(); override;
    destructor Destroy(); override;

    // Main entry point — parses token list, returns True if no errors
    function Parse(const ATokens: TList<TGnyScriptToken>): Boolean;

    // AST access
    function GetNodeCount(): Integer;
    function GetNode(const AIndex: Integer): TGnyScriptNode;
    function GetRoot(): Integer;
    property Nodes: TList<TGnyScriptNode> read FNodes;
    property Root: Integer read FRoot;
  end;

const
  //--------------------------------------------------------------------------
  // Script Parser Error Codes
  //--------------------------------------------------------------------------
  GNY_ERROR_SCRIPT_EXPECTED_TOKEN  = 'SP0001';
  GNY_ERROR_SCRIPT_UNEXPECTED      = 'SP0002';

  //--------------------------------------------------------------------------
  // Pratt binding powers (higher = tighter)
  //--------------------------------------------------------------------------
  BP_NONE        = 0;
  BP_COMPARE     = 2;   // = <> < > <= >= in
  BP_ADDITIVE    = 4;   // + - or xor
  BP_MULTIPLY    = 6;   // * / div mod and shl shr
  BP_UNARY       = 9;   // not - + (prefix)
  BP_POSTFIX     = 10;  // call, field, index, deref

implementation

{ TGnyScriptParser }

constructor TGnyScriptParser.Create();
begin
  inherited Create();
  try
    FNodes := TList<TGnyScriptNode>.Create();
  except
    on E: Exception do
    begin
      FErrors.Add(esFatal, '', RSFatalInternalError, [E.Message]);
      Exit;
    end;
  end;
  FRoot := -1;
end;

destructor TGnyScriptParser.Destroy();
begin
  FNodes.Free();
  inherited Destroy();
end;

//------------------------------------------------------------------------------
// Token stream helpers
//------------------------------------------------------------------------------

function TGnyScriptParser.Peek(): TGnyScriptToken;
begin
  if FPos < FTokens.Count then
    Result := FTokens[FPos]
  else
    Result := FTokens[FTokens.Count - 1]; // EOF token
end;

function TGnyScriptParser.PeekKind(): TGnyScriptTokenKind;
begin
  Result := Peek().Kind;
end;

function TGnyScriptParser.AtEnd(): Boolean;
begin
  Result := PeekKind() = tkEOF;
end;

function TGnyScriptParser.Advance(): TGnyScriptToken;
begin
  Result := Peek();
  if FPos < FTokens.Count then
    Inc(FPos);
end;

function TGnyScriptParser.Match(const AKind: TGnyScriptTokenKind): Boolean;
begin
  if PeekKind() = AKind then
  begin
    Advance();
    Result := True;
  end
  else
    Result := False;
end;

function TGnyScriptParser.Expect(const AKind: TGnyScriptTokenKind): TGnyScriptToken;
var
  LTok: TGnyScriptToken;
begin
  LTok := Peek();
  if LTok.Kind = AKind then
    Result := Advance()
  else
  begin
    FErrors.Add(LTok.Range, esError, GNY_ERROR_SCRIPT_EXPECTED_TOKEN,
      RSScriptExpected, [GetEnumName(TypeInfo(TGnyScriptTokenKind),
      Ord(AKind)), LTok.Text]);
    Result := LTok;
  end;
end;

//------------------------------------------------------------------------------
// Node creation
//------------------------------------------------------------------------------

function TGnyScriptParser.AddNode(const AKind: TGnyScriptNodeKind;
  const ARange: TGnySourceRange): Integer;
var
  LNode: TGnyScriptNode;
begin
  LNode := Default(TGnyScriptNode);
  LNode.Kind := AKind;
  LNode.Range := ARange;
  Result := FNodes.Count;
  FNodes.Add(LNode);
end;

procedure TGnyScriptParser.AddChild(const AParent, AChild: Integer);
var
  LNode: TGnyScriptNode;
  LLen: Integer;
begin
  LNode := FNodes[AParent];
  LLen := Length(LNode.Children);
  SetLength(LNode.Children, LLen + 1);
  LNode.Children[LLen] := AChild;
  FNodes[AParent] := LNode;
end;

//------------------------------------------------------------------------------
// Main entry point
//------------------------------------------------------------------------------

function TGnyScriptParser.Parse(const ATokens: TList<TGnyScriptToken>): Boolean;
begin
  FTokens := ATokens;
  FPos := 0;
  FNodes.Clear();
  FRoot := -1;

  Status(RSParserStatusStart, [FTokens.Count]);

  FRoot := ParseModule();

  Status(RSParserStatusComplete, [FNodes.Count, FErrors.ErrorCount()]);

  Result := FErrors.ErrorCount() = 0;
end;

//------------------------------------------------------------------------------
// Module parsing
//------------------------------------------------------------------------------

function TGnyScriptParser.ParseModule(): Integer;
var
  LModTok: TGnyScriptToken;
  LKindTok: TGnyScriptToken;
  LNameTok: TGnyScriptToken;
  LModNode: Integer;
  LDeclNode: Integer;
  LBlockNode: Integer;
  LNode: TGnyScriptNode;
  LIsPublic: Boolean;
begin
  // module ModuleKind ident ;
  LModTok := Expect(tkModule);
  LModNode := AddNode(nkModule, LModTok.Range);

  // Module kind: exe | dll | lib | unit | mem
  LKindTok := Advance();
  LNode := FNodes[LModNode];
  LNode.Extra := LKindTok.Text; // store module kind
  FNodes[LModNode] := LNode;

  // Module name
  LNameTok := Expect(tkIdent);
  LNode := FNodes[LModNode];
  LNode.Text := LNameTok.Text; // store module name
  FNodes[LModNode] := LNode;

  Expect(tkSemicolon);

  // Parse declarations until we hit 'begin' or 'end'
  while (not AtEnd()) and (PeekKind() <> tkBegin) and (PeekKind() <> tkEnd) do
  begin
    // Check for 'public' modifier
    LIsPublic := PeekKind() = tkPublic;
    if LIsPublic then
      Advance();

    if PeekKind() = tkImport then
    begin
      LDeclNode := ParseImportClause();
      if LDeclNode >= 0 then
        AddChild(LModNode, LDeclNode);
    end
    else if PeekKind() = tkRoutine then
    begin
      LDeclNode := ParseRoutineDecl();
      if (LDeclNode >= 0) and LIsPublic then
      begin
        LNode := FNodes[LDeclNode];
        LNode.IsPublic := True;
        FNodes[LDeclNode] := LNode;
      end;
      if LDeclNode >= 0 then
        AddChild(LModNode, LDeclNode);
    end
    else if PeekKind() = tkVar then
    begin
      ParseVarBlock(LModNode);
    end
    else if PeekKind() = tkConst then
    begin
      ParseConstBlock(LModNode);
    end
    else if PeekKind() = tkType then
    begin
      ParseTypeBlock(LModNode);
    end
    else
    begin
      FErrors.Add(Peek().Range, esError, GNY_ERROR_SCRIPT_UNEXPECTED,
        RSScriptUnexpectedToken, [Peek().Text]);
      Advance(); // skip to recover
    end;
  end;

  // Optional module body: begin ... end
  if PeekKind() = tkBegin then
  begin
    LBlockNode := ParseBlock();
    if LBlockNode >= 0 then
      AddChild(LModNode, LBlockNode);
  end;

  // end .
  Expect(tkEnd);
  Match(tkDot);

  Result := LModNode;
end;

//------------------------------------------------------------------------------
// Import clause: import ident {, ident} ;
//------------------------------------------------------------------------------

function TGnyScriptParser.ParseImportClause(): Integer;
var
  LTok: TGnyScriptToken;
  LImportNode: Integer;
  LNode: TGnyScriptNode;
  LChildNode: Integer;
begin
  LTok := Expect(tkImport);
  LImportNode := AddNode(nkImport, LTok.Range);

  // First module name (stored in node Text)
  LTok := Expect(tkIdent);
  LNode := FNodes[LImportNode];
  LNode.Text := LTok.Text;
  FNodes[LImportNode] := LNode;

  // Additional module names as child nkIdent nodes
  while Match(tkComma) do
  begin
    LTok := Expect(tkIdent);
    LChildNode := AddNode(nkIdent, LTok.Range);
    LNode := FNodes[LChildNode];
    LNode.Text := LTok.Text;
    FNodes[LChildNode] := LNode;
    AddChild(LImportNode, LChildNode);
  end;

  Expect(tkSemicolon);

  Result := LImportNode;
end;

//------------------------------------------------------------------------------
// Routine parsing
//------------------------------------------------------------------------------

function TGnyScriptParser.ParseRoutineDecl(): Integer;
var
  LTok: TGnyScriptToken;
  LRoutNode: Integer;
  LNode: TGnyScriptNode;
  LParams: TArray<Integer>;
  LBlockNode: Integer;
  LLinkageNode: Integer;
  LI: Integer;
begin
  // routine [ LinkageSpec ] ident ( params ) [ : ReturnType ] ;
  LTok := Expect(tkRoutine);
  LRoutNode := AddNode(nkRoutineDecl, LTok.Range);

  // Optional linkage spec: cpplink
  if PeekKind() = tkCppLink then
  begin
    LTok := Advance();
    LLinkageNode := AddNode(nkDirective, LTok.Range);
    LNode := FNodes[LLinkageNode];
    LNode.Text := 'cpplink';
    FNodes[LLinkageNode] := LNode;
    AddChild(LRoutNode, LLinkageNode);
  end;

  // Routine name
  LTok := Expect(tkIdent);
  LNode := FNodes[LRoutNode];
  LNode.Text := LTok.Text;
  FNodes[LRoutNode] := LNode;

  // Optional parameter list
  if PeekKind() = tkLParen then
  begin
    LParams := ParseParamList();
    for LI := 0 to Length(LParams) - 1 do
      AddChild(LRoutNode, LParams[LI]);
  end;

  // Optional return type
  if Match(tkColon) then
  begin
    LNode := FNodes[LRoutNode];
    LNode.Extra := ParseTypeExpr();
    FNodes[LRoutNode] := LNode;
  end;

  Expect(tkSemicolon);

  // External declaration: external ["libname"] ;
  if PeekKind() = tkExternal then
  begin
    LTok := Advance(); // consume 'external'
    LBlockNode := AddNode(nkExternalDecl, LTok.Range);

    // Optional library name (string literal or identifier)
    if PeekKind() = tkStringLit then
    begin
      LNode := FNodes[LBlockNode];
      LNode.Text := Advance().Text;
      FNodes[LBlockNode] := LNode;
    end
    else if PeekKind() = tkIdent then
    begin
      LNode := FNodes[LBlockNode];
      LNode.Text := Advance().Text;
      FNodes[LBlockNode] := LNode;
    end;

    Expect(tkSemicolon);
    AddChild(LRoutNode, LBlockNode);
    Result := LRoutNode;
    Exit;
  end;

  // Optional type/var/const blocks before begin (interleaved, any order)
  while (not AtEnd()) and ((PeekKind() = tkVar) or (PeekKind() = tkConst) or
    (PeekKind() = tkType)) do
  begin
    if PeekKind() = tkVar then
      ParseVarBlock(LRoutNode)
    else if PeekKind() = tkConst then
      ParseConstBlock(LRoutNode)
    else
      ParseTypeBlock(LRoutNode);
  end;

  // Routine body: begin ... end ;
  if PeekKind() = tkBegin then
  begin
    LBlockNode := ParseBlock();
    if LBlockNode >= 0 then
      AddChild(LRoutNode, LBlockNode);
  end;

  Result := LRoutNode;
end;

function TGnyScriptParser.ParseParamList(): TArray<Integer>;
var
  LParamNode: Integer;
  LNode: TGnyScriptNode;
  LNameTok: TGnyScriptToken;
begin
  Result := nil;
  Expect(tkLParen);

  while (not AtEnd()) and (PeekKind() <> tkRParen) do
  begin
    // paramName : TypeExpr
    LNameTok := Expect(tkIdent);
    LParamNode := AddNode(nkParamDecl, LNameTok.Range);
    LNode := FNodes[LParamNode];
    LNode.Text := LNameTok.Text;
    FNodes[LParamNode] := LNode;

    Expect(tkColon);

    LNode := FNodes[LParamNode];
    LNode.Extra := ParseTypeExpr();
    FNodes[LParamNode] := LNode;

    // Add to result array
    SetLength(Result, Length(Result) + 1);
    Result[Length(Result) - 1] := LParamNode;

    // Separator
    if PeekKind() = tkSemicolon then
      Advance()
    else if PeekKind() <> tkRParen then
    begin
      FErrors.Add(Peek().Range, esError, GNY_ERROR_SCRIPT_EXPECTED_TOKEN,
        RSScriptExpected, [''')'' or '';''', Peek().Text]);
      Break;
    end;
  end;

  Expect(tkRParen);
end;

function TGnyScriptParser.ParseTypeExpr(): string;
var
  LTok: TGnyScriptToken;
  LLowTok: TGnyScriptToken;
  LHighTok: TGnyScriptToken;
begin
  LTok := Peek();

  // Array type: array [ "[" ArrayBounds "]" ] of TypeExpr
  if LTok.Kind = tkArray then
  begin
    Advance(); // consume 'array'

    // Static array: array[low..high] of T
    if PeekKind() = tkLBracket then
    begin
      Advance(); // consume '['
      LLowTok := Expect(tkIntLit);
      Expect(tkRange); // '..'
      LHighTok := Expect(tkIntLit);
      Expect(tkRBracket);
      Expect(tkOf);
      Result := 'array[' + LLowTok.Text + '..' + LHighTok.Text + '] of ' +
        ParseTypeExpr();
    end
    else
    begin
      // Dynamic array: array of T
      Expect(tkOf);
      Result := 'array of ' + ParseTypeExpr();
    end;
  end
  // Pointer type: pointer [to TypeExpr]
  else if LTok.Kind = tkPointer then
  begin
    Advance(); // consume 'pointer'

    if PeekKind() = tkTo then
    begin
      Advance(); // consume 'to'
      Result := 'pointer to ' + ParseTypeExpr();
    end
    else
      Result := 'pointer';
  end
  // Set type: set [of (integer .. integer | TypeExpr)]
  else if LTok.Kind = tkSet then
  begin
    Advance(); // consume 'set'
    if PeekKind() = tkOf then
    begin
      Advance(); // consume 'of'
      // Check for integer range: set of 0..255
      if (PeekKind() = tkIntLit) and (FPos + 1 < FTokens.Count) and
         (FTokens[FPos + 1].Kind = tkRange) then
      begin
        LLowTok := Expect(tkIntLit);
        Expect(tkRange);
        LHighTok := Expect(tkIntLit);
        Result := 'set of ' + LLowTok.Text + '..' + LHighTok.Text;
      end
      else
        Result := 'set of ' + ParseTypeExpr();
    end
    else
      Result := 'set';
  end
  // Routine type: routine [ "C" ] ( [paramTypes] ) [ : returnType ]
  else if LTok.Kind = tkRoutine then
  begin
    Advance(); // consume 'routine'
    Result := 'routine';

    // Optional linkage spec: "C"
    if PeekKind() = tkStringLit then
      Result := Result + ' ' + Advance().Text;

    Expect(tkLParen);

    // Parse comma-separated parameter types (just types, no names)
    if PeekKind() <> tkRParen then
    begin
      Result := Result + '(' + ParseTypeExpr();
      while Match(tkComma) do
        Result := Result + ',' + ParseTypeExpr();
      Result := Result + ')';
    end
    else
      Result := Result + '()';

    Expect(tkRParen);

    // Optional return type
    if Match(tkColon) then
      Result := Result + ':' + ParseTypeExpr();
  end
  else
  begin
    // Simple type name (identifier or built-in keyword)
    LTok := Advance();
    Result := LTok.Text;
  end;
end;

//------------------------------------------------------------------------------
// Block and statement parsing
//------------------------------------------------------------------------------

function TGnyScriptParser.ParseBlock(): Integer;
var
  LTok: TGnyScriptToken;
  LBlockNode: Integer;
  LStmtNode: Integer;
begin
  LTok := Expect(tkBegin);
  LBlockNode := AddNode(nkBlock, LTok.Range);

  while (not AtEnd()) and (PeekKind() <> tkEnd) do
  begin
    // Skip stray semicolons
    if PeekKind() = tkSemicolon then
    begin
      Advance();
      Continue;
    end;

    LStmtNode := ParseStatement();
    if LStmtNode >= 0 then
      AddChild(LBlockNode, LStmtNode)
    else
      Break;
  end;

  Expect(tkEnd);
  Match(tkSemicolon); // optional trailing semicolon

  Result := LBlockNode;
end;

function TGnyScriptParser.ParseStatement(): Integer;
var
  LExprNode: Integer;
  LAssignNode: Integer;
begin
  if PeekKind() = tkIf then
    Result := ParseIfStatement()
  else if PeekKind() = tkWhile then
    Result := ParseWhileStatement()
  else if PeekKind() = tkFor then
    Result := ParseForStatement()
  else if PeekKind() = tkRepeat then
    Result := ParseRepeatStatement()
  else if PeekKind() = tkMatch then
    Result := ParseMatchStatement()
  else if PeekKind() = tkReturn then
    Result := ParseReturnStatement()
  else if PeekKind() = tkLeave then
    Result := ParseLeaveStatement()
  else if PeekKind() = tkSkip then
    Result := ParseSkipStatement()
  else if (PeekKind() = tkWrite) or (PeekKind() = tkWriteLn) then
    Result := ParseWriteStatement()
  else if PeekKind() = tkSetLength then
    Result := ParseSetLengthStatement()
  else
  begin
    // Expression — then check for assignment operator
    LExprNode := ParseExpression();
    LAssignNode := TryParseAssign(LExprNode);
    if LAssignNode >= 0 then
      Result := LAssignNode
    else
      Result := LExprNode;
    Match(tkSemicolon);
  end;
end;

//------------------------------------------------------------------------------
// If statement: if expr then stmts [else stmts] end ;
//------------------------------------------------------------------------------

function TGnyScriptParser.ParseIfStatement(): Integer;
var
  LTok: TGnyScriptToken;
  LIfNode: Integer;
  LCondNode: Integer;
  LThenBlock: Integer;
  LElseBlock: Integer;
  LStmtNode: Integer;
begin
  LTok := Expect(tkIf);
  LIfNode := AddNode(nkIf, LTok.Range);

  // Condition expression
  LCondNode := ParseExpression();
  AddChild(LIfNode, LCondNode);

  Expect(tkThen);

  // Then block — parse statements inline until end/else
  LThenBlock := AddNode(nkBlock, Peek().Range);
  while (not AtEnd()) and (PeekKind() <> tkEnd) and (PeekKind() <> tkElse) do
  begin
    if PeekKind() = tkSemicolon then
    begin
      Advance();
      Continue;
    end;
    LStmtNode := ParseStatement();
    if LStmtNode >= 0 then
      AddChild(LThenBlock, LStmtNode)
    else
      Break;
  end;
  AddChild(LIfNode, LThenBlock);

  // Optional else block
  if PeekKind() = tkElse then
  begin
    Advance(); // consume else
    LElseBlock := AddNode(nkBlock, Peek().Range);
    while (not AtEnd()) and (PeekKind() <> tkEnd) do
    begin
      if PeekKind() = tkSemicolon then
      begin
        Advance();
        Continue;
      end;
      LStmtNode := ParseStatement();
      if LStmtNode >= 0 then
        AddChild(LElseBlock, LStmtNode)
      else
        Break;
    end;
    AddChild(LIfNode, LElseBlock);
  end;

  Expect(tkEnd);
  Match(tkSemicolon);

  Result := LIfNode;
end;

//------------------------------------------------------------------------------
// While statement: while expr do stmts end ;
//------------------------------------------------------------------------------

function TGnyScriptParser.ParseWhileStatement(): Integer;
var
  LTok: TGnyScriptToken;
  LWhileNode: Integer;
  LCondNode: Integer;
  LBodyBlock: Integer;
  LStmtNode: Integer;
begin
  LTok := Expect(tkWhile);
  LWhileNode := AddNode(nkWhile, LTok.Range);

  // Condition expression
  LCondNode := ParseExpression();
  AddChild(LWhileNode, LCondNode);

  Expect(tkDo);

  // Body block — parse statements until end
  LBodyBlock := AddNode(nkBlock, Peek().Range);
  while (not AtEnd()) and (PeekKind() <> tkEnd) do
  begin
    if PeekKind() = tkSemicolon then
    begin
      Advance();
      Continue;
    end;
    LStmtNode := ParseStatement();
    if LStmtNode >= 0 then
      AddChild(LBodyBlock, LStmtNode)
    else
      Break;
  end;
  AddChild(LWhileNode, LBodyBlock);

  Expect(tkEnd);
  Match(tkSemicolon);

  Result := LWhileNode;
end;

//------------------------------------------------------------------------------
// For statement: for ident := expr (to|downto) expr do stmts end ;
//------------------------------------------------------------------------------

function TGnyScriptParser.ParseForStatement(): Integer;
var
  LTok: TGnyScriptToken;
  LVarTok: TGnyScriptToken;
  LForNode: Integer;
  LFromNode: Integer;
  LToNode: Integer;
  LBodyBlock: Integer;
  LStmtNode: Integer;
begin
  LTok := Expect(tkFor);
  LForNode := AddNode(nkFor, LTok.Range);

  // Loop variable name
  LVarTok := Expect(tkIdent);
  FNodes.List[LForNode].Text := LVarTok.Text;

  // :=
  Expect(tkAssign);

  // From expression
  LFromNode := ParseExpression();
  AddChild(LForNode, LFromNode);

  // Direction: to or downto
  if PeekKind() = tkTo then
  begin
    Advance();
    FNodes.List[LForNode].Extra := 'to';
  end
  else if PeekKind() = tkDownto then
  begin
    Advance();
    FNodes.List[LForNode].Extra := 'downto';
  end
  else
  begin
    FErrors.Add(Peek().Range, esError, GNY_ERROR_SCRIPT_EXPECTED_TOKEN,
      RSScriptExpected, ['to or downto', Peek().Text]);
    Exit(-1);
  end;

  // To expression
  LToNode := ParseExpression();
  AddChild(LForNode, LToNode);

  Expect(tkDo);

  // Body block
  LBodyBlock := AddNode(nkBlock, Peek().Range);
  while (not AtEnd()) and (PeekKind() <> tkEnd) do
  begin
    if PeekKind() = tkSemicolon then
    begin
      Advance();
      Continue;
    end;
    LStmtNode := ParseStatement();
    if LStmtNode >= 0 then
      AddChild(LBodyBlock, LStmtNode)
    else
      Break;
  end;
  AddChild(LForNode, LBodyBlock);

  Expect(tkEnd);
  Match(tkSemicolon);

  Result := LForNode;
end;

//------------------------------------------------------------------------------
// Repeat statement: repeat stmts until expr ;
//------------------------------------------------------------------------------

function TGnyScriptParser.ParseRepeatStatement(): Integer;
var
  LTok: TGnyScriptToken;
  LRepeatNode: Integer;
  LBodyBlock: Integer;
  LCondNode: Integer;
  LStmtNode: Integer;
begin
  LTok := Expect(tkRepeat);
  LRepeatNode := AddNode(nkRepeat, LTok.Range);

  // Body block — parse statements until 'until'
  LBodyBlock := AddNode(nkBlock, Peek().Range);
  while (not AtEnd()) and (PeekKind() <> tkUntil) do
  begin
    if PeekKind() = tkSemicolon then
    begin
      Advance();
      Continue;
    end;
    LStmtNode := ParseStatement();
    if LStmtNode >= 0 then
      AddChild(LBodyBlock, LStmtNode)
    else
      Break;
  end;
  AddChild(LRepeatNode, LBodyBlock);

  Expect(tkUntil);

  // Until condition
  LCondNode := ParseExpression();
  AddChild(LRepeatNode, LCondNode);

  Match(tkSemicolon);

  Result := LRepeatNode;
end;

//------------------------------------------------------------------------------
// Match statement: match expr of { label {, label} : stmts } [else stmts] end ;
//------------------------------------------------------------------------------

function TGnyScriptParser.ParseMatchStatement(): Integer;
var
  LTok: TGnyScriptToken;
  LMatchNode: Integer;
  LSelectorNode: Integer;
  LArmNode: Integer;
  LLabelNode: Integer;
  LHighNode: Integer;
  LBodyBlock: Integer;
  LElseBlock: Integer;
  LStmtNode: Integer;
  LNode: TGnyScriptNode;
begin
  LTok := Expect(tkMatch);
  LMatchNode := AddNode(nkMatch, LTok.Range);

  // Selector expression
  LSelectorNode := ParseExpression();
  AddChild(LMatchNode, LSelectorNode);

  Expect(tkOf);

  // Parse match arms until 'else' or 'end'
  while (not AtEnd()) and (PeekKind() <> tkElse) and (PeekKind() <> tkEnd) do
  begin
    // Skip stray semicolons between arms
    if PeekKind() = tkSemicolon then
    begin
      Advance();
      Continue;
    end;

    LArmNode := AddNode(nkMatchArm, Peek().Range);

    // Parse comma-separated labels: expr [".." expr] { "," expr [".." expr] }
    repeat
      LLabelNode := ParseExpression();

      // Check for range: label ".." label
      if PeekKind() = tkRange then
      begin
        Advance(); // consume '..'
        LHighNode := ParseExpression();

        // Wrap as a binary ".." node with low and high children
        LTok := Default(TGnyScriptToken);
        LTok.Range := FNodes[LLabelNode].Range;
        LStmtNode := AddNode(nkBinary, LTok.Range);
        LNode := FNodes[LStmtNode];
        LNode.Text := '..';
        FNodes[LStmtNode] := LNode;
        AddChild(LStmtNode, LLabelNode);
        AddChild(LStmtNode, LHighNode);
        AddChild(LArmNode, LStmtNode);
      end
      else
        AddChild(LArmNode, LLabelNode);

    until (AtEnd()) or (PeekKind() <> tkComma) or (Advance().Kind <> tkComma);
    // Note: the Advance in the until condition consumes the comma

    // Expect ':' after labels
    Expect(tkColon);

    // Parse arm body statements until next label, else, or end
    LBodyBlock := AddNode(nkBlock, Peek().Range);
    while (not AtEnd()) and (PeekKind() <> tkElse) and (PeekKind() <> tkEnd) do
    begin
      // Stop if we see what looks like the start of a new match arm:
      // an integer/expression followed by ':' or ',' (lookahead heuristic)
      // We detect this by checking if the current token is a potential label start
      // and breaking to let the outer loop handle it
      if (PeekKind() in [tkIntLit, tkIdent, tkTrue, tkFalse]) then
      begin
        // Peek ahead: if after an expression there's a colon, comma, or dotdot,
        // this is likely a new arm — break out
        // Simple heuristic: integer/ident followed by ':', ',', or '..'
        if (FPos + 1 < FTokens.Count) and
           (FTokens[FPos + 1].Kind in [tkColon, tkComma, tkRange]) then
          Break;
      end;

      if PeekKind() = tkSemicolon then
      begin
        Advance();
        Continue;
      end;

      LStmtNode := ParseStatement();
      if LStmtNode >= 0 then
        AddChild(LBodyBlock, LStmtNode)
      else
        Break;
    end;
    AddChild(LArmNode, LBodyBlock);

    AddChild(LMatchNode, LArmNode);
  end;

  // Optional else block
  if PeekKind() = tkElse then
  begin
    Advance(); // consume 'else'
    LElseBlock := AddNode(nkBlock, Peek().Range);
    while (not AtEnd()) and (PeekKind() <> tkEnd) do
    begin
      if PeekKind() = tkSemicolon then
      begin
        Advance();
        Continue;
      end;
      LStmtNode := ParseStatement();
      if LStmtNode >= 0 then
        AddChild(LElseBlock, LStmtNode)
      else
        Break;
    end;
    // Mark the match node to indicate an else clause is present
    LNode := FNodes[LMatchNode];
    LNode.Extra := 'else';
    FNodes[LMatchNode] := LNode;
    AddChild(LMatchNode, LElseBlock);
  end;

  Expect(tkEnd);
  Match(tkSemicolon);

  Result := LMatchNode;
end;

//------------------------------------------------------------------------------
// Leave statement (break): leave ;
//------------------------------------------------------------------------------

function TGnyScriptParser.ParseLeaveStatement(): Integer;
var
  LTok: TGnyScriptToken;
begin
  LTok := Expect(tkLeave);
  Result := AddNode(nkLeave, LTok.Range);
  Match(tkSemicolon);
end;

//------------------------------------------------------------------------------
// Skip statement (continue): skip ;
//------------------------------------------------------------------------------

function TGnyScriptParser.ParseSkipStatement(): Integer;
var
  LTok: TGnyScriptToken;
begin
  LTok := Expect(tkSkip);
  Result := AddNode(nkSkip, LTok.Range);
  Match(tkSemicolon);
end;

//------------------------------------------------------------------------------
// Write/WriteLn statement: write(expr, ...) ; | writeln(expr, ...) ;
//------------------------------------------------------------------------------

function TGnyScriptParser.ParseWriteStatement(): Integer;
var
  LTok: TGnyScriptToken;
  LNodeKind: TGnyScriptNodeKind;
  LArgNode: Integer;
begin
  LTok := Advance();
  if LTok.Kind = tkWriteLn then
    LNodeKind := nkWriteLn
  else
    LNodeKind := nkWrite;

  Result := AddNode(LNodeKind, LTok.Range);

  // Parentheses required per BNF: write/writeln "(" [ ArgList ] ")"
  Expect(tkLParen);
  while (not AtEnd()) and (PeekKind() <> tkRParen) do
  begin
    LArgNode := ParseExpression();
    if LArgNode >= 0 then
      AddChild(Result, LArgNode);
    if PeekKind() = tkComma then
      Advance()
    else if PeekKind() <> tkRParen then
    begin
      FErrors.Add(Peek().Range, esError, GNY_ERROR_SCRIPT_EXPECTED_TOKEN,
        RSScriptExpected, [''')'' or '',''', Peek().Text]);
      Break;
    end;
  end;
  Expect(tkRParen);

  Match(tkSemicolon);
end;

//------------------------------------------------------------------------------
// SetLength statement: setlength(arr, newlen) ;
//------------------------------------------------------------------------------

function TGnyScriptParser.ParseSetLengthStatement(): Integer;
var
  LTok: TGnyScriptToken;
  LArgNode: Integer;
begin
  LTok := Advance(); // consume 'setlength'
  Result := AddNode(nkSetLength, LTok.Range);

  Expect(tkLParen);

  // First argument: array variable
  LArgNode := ParseExpression(BP_NONE);
  AddChild(Result, LArgNode);

  Expect(tkComma);

  // Second argument: new length
  LArgNode := ParseExpression(BP_NONE);
  AddChild(Result, LArgNode);

  Expect(tkRParen);
  Match(tkSemicolon);
end;

//------------------------------------------------------------------------------
// Return statement: return [expr] ;
//------------------------------------------------------------------------------

function TGnyScriptParser.ParseReturnStatement(): Integer;
var
  LTok: TGnyScriptToken;
  LRetNode: Integer;
  LExprNode: Integer;
begin
  LTok := Expect(tkReturn);
  LRetNode := AddNode(nkReturn, LTok.Range);

  // Return value expression (if not immediately followed by ; or end)
  if (not AtEnd()) and (PeekKind() <> tkSemicolon) and (PeekKind() <> tkEnd) then
  begin
    LExprNode := ParseExpression();
    AddChild(LRetNode, LExprNode);
  end;

  Match(tkSemicolon);
  Result := LRetNode;
end;

//------------------------------------------------------------------------------
// Var block: var { ident : TypeExpr [ = Expression ] ; }
//------------------------------------------------------------------------------

function TGnyScriptParser.ParseVarBlock(const AParentNode: Integer): Integer;
var
  LNameTok: TGnyScriptToken;
  LVarNode: Integer;
  LNode: TGnyScriptNode;
  LInitNode: Integer;
begin
  Expect(tkVar);
  Result := 0; // count of vars parsed

  // Parse var declarations until we hit something that isn't an identifier
  while (not AtEnd()) and (PeekKind() = tkIdent) do
  begin
    LNameTok := Expect(tkIdent);
    LVarNode := AddNode(nkVarDecl, LNameTok.Range);
    LNode := FNodes[LVarNode];
    LNode.Text := LNameTok.Text;
    FNodes[LVarNode] := LNode;

    // : TypeExpr
    Expect(tkColon);
    LNode := FNodes[LVarNode];
    LNode.Extra := ParseTypeExpr();
    FNodes[LVarNode] := LNode;

    // Optional initializer: = Expression
    if Match(tkEq) then
    begin
      LInitNode := ParseExpression();
      AddChild(LVarNode, LInitNode);
    end;

    Expect(tkSemicolon);
    AddChild(AParentNode, LVarNode);
    Inc(Result);
  end;
end;

//------------------------------------------------------------------------------
// Const block: const { ident : TypeExpr = Expression ; }
//------------------------------------------------------------------------------

function TGnyScriptParser.ParseConstBlock(const AParentNode: Integer): Integer;
var
  LNameTok: TGnyScriptToken;
  LConstNode: Integer;
  LNode: TGnyScriptNode;
  LInitNode: Integer;
begin
  Expect(tkConst);
  Result := 0;

  // Parse const declarations until we hit something that isn't an identifier
  while (not AtEnd()) and (PeekKind() = tkIdent) do
  begin
    LNameTok := Expect(tkIdent);
    LConstNode := AddNode(nkConstDecl, LNameTok.Range);
    LNode := FNodes[LConstNode];
    LNode.Text := LNameTok.Text;
    FNodes[LConstNode] := LNode;

    // : TypeExpr (required)
    Expect(tkColon);
    LNode := FNodes[LConstNode];
    LNode.Extra := ParseTypeExpr();
    FNodes[LConstNode] := LNode;

    // = Expression (required for constants)
    Expect(tkEq);
    LInitNode := ParseExpression();
    AddChild(LConstNode, LInitNode);

    Expect(tkSemicolon);
    AddChild(AParentNode, LConstNode);
    Inc(Result);
  end;
end;

//------------------------------------------------------------------------------
// Type block: type { ident = RecordType ; }
//------------------------------------------------------------------------------

function TGnyScriptParser.ParseTypeBlock(const AParentNode: Integer): Integer;
var
  LNameTok: TGnyScriptToken;
  LTypeDeclNode: Integer;
  LNode: TGnyScriptNode;
  LTypeDefNode: Integer;
begin
  Expect(tkType);
  Result := 0;

  // Parse type declarations until we hit something that isn't an identifier
  while (not AtEnd()) and (PeekKind() = tkIdent) do
  begin
    LNameTok := Expect(tkIdent);
    LTypeDeclNode := AddNode(nkTypeDecl, LNameTok.Range);
    LNode := FNodes[LTypeDeclNode];
    LNode.Text := LNameTok.Text;
    FNodes[LTypeDeclNode] := LNode;

    // = TypeDef
    Expect(tkEq);

    // Record type
    if PeekKind() = tkRecord then
    begin
      LTypeDefNode := ParseRecordType();
      if LTypeDefNode >= 0 then
        AddChild(LTypeDeclNode, LTypeDefNode);
    end
    // Array type
    else if PeekKind() = tkArray then
    begin
      LTypeDefNode := ParseArrayType();
      if LTypeDefNode >= 0 then
        AddChild(LTypeDeclNode, LTypeDefNode);
    end
    // Pointer type
    else if PeekKind() = tkPointer then
    begin
      LTypeDefNode := ParsePointerType();
      if LTypeDefNode >= 0 then
        AddChild(LTypeDeclNode, LTypeDefNode);
    end
    // Choices (enum) type
    else if PeekKind() = tkChoices then
    begin
      LTypeDefNode := ParseChoicesType();
      if LTypeDefNode >= 0 then
        AddChild(LTypeDeclNode, LTypeDefNode);
    end
    // Set type
    else if PeekKind() = tkSet then
    begin
      LTypeDefNode := ParseSetType();
      if LTypeDefNode >= 0 then
        AddChild(LTypeDeclNode, LTypeDefNode);
    end
    // Overlay (union) type
    else if PeekKind() = tkOverlay then
    begin
      LTypeDefNode := ParseOverlayType();
      if LTypeDefNode >= 0 then
        AddChild(LTypeDeclNode, LTypeDefNode);
    end
    // Routine type: routine [ "C" ] ( [paramTypes] ) [ : returnType ]
    else if PeekKind() = tkRoutine then
    begin
      LNode := FNodes[LTypeDeclNode];
      LNode.Extra := ParseTypeExpr();
      FNodes[LTypeDeclNode] := LNode;
    end
    else
    begin
      FErrors.Add(Peek().Range, esError, GNY_ERROR_SCRIPT_UNEXPECTED,
        RSScriptUnexpectedToken, [Peek().Text]);
      Advance();
    end;

    Expect(tkSemicolon);
    AddChild(AParentNode, LTypeDeclNode);
    Inc(Result);
  end;
end;

//------------------------------------------------------------------------------
// Record type: record [packed] [align(N)] [(BaseType)] { FieldDecl } end
//------------------------------------------------------------------------------

function TGnyScriptParser.ParseRecordType(): Integer;
var
  LTok: TGnyScriptToken;
  LRecNode: Integer;
  LNode: TGnyScriptNode;
  LFieldNode: Integer;
  LFieldNameTok: TGnyScriptToken;
begin
  LTok := Expect(tkRecord);
  LRecNode := AddNode(nkRecordType, LTok.Range);

  // Optional 'packed'
  if PeekKind() = tkPacked then
  begin
    Advance();
    LNode := FNodes[LRecNode];
    LNode.Extra := 'packed';
    FNodes[LRecNode] := LNode;
  end;

  // Optional 'align(N)'
  if PeekKind() = tkAlign then
  begin
    Advance();
    Expect(tkLParen);
    LTok := Expect(tkIntLit);
    // Store alignment in Text (Extra may already hold 'packed')
    LNode := FNodes[LRecNode];
    if LNode.Extra <> '' then
      LNode.Extra := LNode.Extra + ',align=' + LTok.Text
    else
      LNode.Extra := 'align=' + LTok.Text;
    FNodes[LRecNode] := LNode;
    Expect(tkRParen);
  end;

  // Optional inheritance: (BaseType)
  if PeekKind() = tkLParen then
  begin
    Advance();
    LTok := Expect(tkIdent);
    LNode := FNodes[LRecNode];
    LNode.Text := LTok.Text; // base type name stored in Text
    FNodes[LRecNode] := LNode;
    Expect(tkRParen);
  end;

  // Parse field declarations and anonymous overlays until 'end'
  while (not AtEnd()) and (PeekKind() <> tkEnd) do
  begin
    // Anonymous overlay inside record
    if PeekKind() = tkOverlay then
    begin
      LFieldNode := ParseOverlayType();
      if LFieldNode >= 0 then
        AddChild(LRecNode, LFieldNode);
      // Anonymous overlays require trailing semicolon
      Expect(tkSemicolon);
    end
    else
    begin
      LFieldNameTok := Expect(tkIdent);
      LFieldNode := AddNode(nkFieldDecl, LFieldNameTok.Range);
      LNode := FNodes[LFieldNode];
      LNode.Text := LFieldNameTok.Text;
      FNodes[LFieldNode] := LNode;

      Expect(tkColon);

      LNode := FNodes[LFieldNode];
      LNode.Extra := ParseTypeExpr();
      FNodes[LFieldNode] := LNode;

      Expect(tkSemicolon);
      AddChild(LRecNode, LFieldNode);
    end;
  end;

  Expect(tkEnd);

  Result := LRecNode;
end;

//------------------------------------------------------------------------------
// Overlay (union) type: overlay { FieldDecl | AnonRecord } end
// AnonRecord = record [packed] { FieldDecl | AnonOverlay } end ;
//------------------------------------------------------------------------------

function TGnyScriptParser.ParseOverlayType(): Integer;
var
  LTok: TGnyScriptToken;
  LOvlNode: Integer;
  LNode: TGnyScriptNode;
  LFieldNode: Integer;
  LFieldNameTok: TGnyScriptToken;
  LAnonRecNode: Integer;
begin
  LTok := Expect(tkOverlay);
  LOvlNode := AddNode(nkOverlayType, LTok.Range);

  // Parse field declarations and anonymous records until 'end'
  while (not AtEnd()) and (PeekKind() <> tkEnd) do
  begin
    // Anonymous record inside overlay
    if PeekKind() = tkRecord then
    begin
      LAnonRecNode := ParseRecordType();
      if LAnonRecNode >= 0 then
        AddChild(LOvlNode, LAnonRecNode);
      // Anonymous records require trailing semicolon
      Expect(tkSemicolon);
    end
    else
    begin
      // Field declaration: ident : TypeExpr ;
      LFieldNameTok := Expect(tkIdent);
      LFieldNode := AddNode(nkFieldDecl, LFieldNameTok.Range);
      LNode := FNodes[LFieldNode];
      LNode.Text := LFieldNameTok.Text;
      FNodes[LFieldNode] := LNode;

      Expect(tkColon);

      LNode := FNodes[LFieldNode];
      LNode.Extra := ParseTypeExpr();
      FNodes[LFieldNode] := LNode;

      Expect(tkSemicolon);
      AddChild(LOvlNode, LFieldNode);
    end;
  end;

  Expect(tkEnd);

  Result := LOvlNode;
end;

//------------------------------------------------------------------------------
// Array type: array [ "[" ArrayBounds "]" ] of TypeExpr
//------------------------------------------------------------------------------

function TGnyScriptParser.ParseArrayType(): Integer;
var
  LTok: TGnyScriptToken;
  LArrNode: Integer;
  LNode: TGnyScriptNode;
begin
  LTok := Expect(tkArray);
  LArrNode := AddNode(nkArrayType, LTok.Range);

  // Static array: array[low..high] of T
  if PeekKind() = tkLBracket then
  begin
    Advance(); // consume '['
    LTok := Expect(tkIntLit);
    LNode := FNodes[LArrNode];
    LNode.Text := LTok.Text; // low bound

    Expect(tkRange); // '..'

    LTok := Expect(tkIntLit);
    LNode.Text := LNode.Text + '..' + LTok.Text; // "low..high"
    FNodes[LArrNode] := LNode;

    Expect(tkRBracket);
  end;
  // else: dynamic array (Text remains empty)

  Expect(tkOf);

  // Element type
  LNode := FNodes[LArrNode];
  LNode.Extra := ParseTypeExpr();
  FNodes[LArrNode] := LNode;

  Result := LArrNode;
end;

//------------------------------------------------------------------------------
// Pointer type: pointer [to [const] TypeExpr]
//------------------------------------------------------------------------------

function TGnyScriptParser.ParsePointerType(): Integer;
var
  LTok: TGnyScriptToken;
  LPtrNode: Integer;
  LNode: TGnyScriptNode;
begin
  LTok := Expect(tkPointer);
  LPtrNode := AddNode(nkPointerType, LTok.Range);

  // Optional 'to TypeExpr' — typed pointer
  if PeekKind() = tkTo then
  begin
    Advance(); // consume 'to'
    LNode := FNodes[LPtrNode];
    LNode.Extra := ParseTypeExpr(); // pointee type name
    FNodes[LPtrNode] := LNode;
  end;
  // else: untyped pointer (Extra remains empty)

  Result := LPtrNode;
end;

//------------------------------------------------------------------------------
// Choices (enum) type: choices(red, green = 5, blue)
//------------------------------------------------------------------------------

function TGnyScriptParser.ParseChoicesType(): Integer;
var
  LTok: TGnyScriptToken;
  LChoicesNode: Integer;
  LValueNode: Integer;
  LNode: TGnyScriptNode;
  LExprNode: Integer;
begin
  LTok := Expect(tkChoices);
  LChoicesNode := AddNode(nkChoicesType, LTok.Range);

  Expect(tkLParen);

  // Parse comma-separated values: ident [ = expr ]
  while (not AtEnd()) and (PeekKind() <> tkRParen) do
  begin
    LTok := Expect(tkIdent);
    LValueNode := AddNode(nkConstDecl, LTok.Range);
    LNode := FNodes[LValueNode];
    LNode.Text := LTok.Text;
    FNodes[LValueNode] := LNode;

    // Optional explicit ordinal: = Expression
    if Match(tkEq) then
    begin
      LExprNode := ParseExpression(BP_NONE);
      AddChild(LValueNode, LExprNode);
    end;

    AddChild(LChoicesNode, LValueNode);

    if PeekKind() = tkComma then
      Advance()
    else if PeekKind() <> tkRParen then
    begin
      FErrors.Add(Peek().Range, esError, GNY_ERROR_SCRIPT_EXPECTED_TOKEN,
        RSScriptExpected, [''')'' or '',''', Peek().Text]);
      Break;
    end;
  end;

  Expect(tkRParen);

  Result := LChoicesNode;
end;

//------------------------------------------------------------------------------
// Set type: set [of (integer .. integer | TypeExpr)]
//------------------------------------------------------------------------------

function TGnyScriptParser.ParseSetType(): Integer;
var
  LTok: TGnyScriptToken;
  LSetNode: Integer;
  LNode: TGnyScriptNode;
  LLowTok: TGnyScriptToken;
  LHighTok: TGnyScriptToken;
begin
  LTok := Expect(tkSet);
  LSetNode := AddNode(nkSetType, LTok.Range);

  if PeekKind() = tkOf then
  begin
    Advance(); // consume 'of'

    // Check for integer range: set of 0..255
    if (PeekKind() = tkIntLit) and (FPos + 1 < FTokens.Count) and
       (FTokens[FPos + 1].Kind = tkRange) then
    begin
      LLowTok := Expect(tkIntLit);
      Expect(tkRange);
      LHighTok := Expect(tkIntLit);
      LNode := FNodes[LSetNode];
      LNode.Text := LLowTok.Text + '..' + LHighTok.Text;
      FNodes[LSetNode] := LNode;
    end
    else
    begin
      // Set of enum type: set of TMyEnum
      LNode := FNodes[LSetNode];
      LNode.Extra := ParseTypeExpr();
      FNodes[LSetNode] := LNode;
    end;
  end;
  // else: bare 'set' — untyped set (Text and Extra remain empty)

  Result := LSetNode;
end;

//------------------------------------------------------------------------------
// Assignment: Designator ( := | += | -= | *= | /= ) Expression
//------------------------------------------------------------------------------

function TGnyScriptParser.TryParseAssign(const ALhs: Integer): Integer;
var
  LTok: TGnyScriptToken;
  LAssignNode: Integer;
  LNode: TGnyScriptNode;
  LRhsNode: Integer;
begin
  Result := -1;

  // Check for assignment operator
  if (PeekKind() <> tkAssign) and (PeekKind() <> tkPlusAssign) and
     (PeekKind() <> tkMinusAssign) and (PeekKind() <> tkMulAssign) and
     (PeekKind() <> tkDivAssign) then
    Exit;

  LTok := Advance(); // consume the assignment operator
  LAssignNode := AddNode(nkAssign, LTok.Range);
  LNode := FNodes[LAssignNode];
  LNode.Text := LTok.Text; // ':=', '+=', '-=', '*=', '/='
  FNodes[LAssignNode] := LNode;

  // child[0] = LHS (already parsed), child[1] = RHS
  AddChild(LAssignNode, ALhs);
  LRhsNode := ParseExpression();
  AddChild(LAssignNode, LRhsNode);

  Result := LAssignNode;
end;

//------------------------------------------------------------------------------
// Pratt expression parser
//------------------------------------------------------------------------------

function TGnyScriptParser.GetInfixBP(const AKind: TGnyScriptTokenKind): Integer;
begin
  // Return LEFT binding power for infix operators
  if (AKind = tkEq) or (AKind = tkNotEq) or (AKind = tkLt) or
     (AKind = tkGt) or (AKind = tkLtEq) or (AKind = tkGtEq) or
     (AKind = tkIn) then
    Result := BP_COMPARE
  else if (AKind = tkPlus) or (AKind = tkMinus) or
          (AKind = tkOr) or (AKind = tkXor) then
    Result := BP_ADDITIVE
  else if (AKind = tkStar) or (AKind = tkSlash) or
          (AKind = tkDiv) or (AKind = tkMod) or
          (AKind = tkAnd) or (AKind = tkShl) or (AKind = tkShr) then
    Result := BP_MULTIPLY
  else if AKind = tkLParen then
    Result := BP_POSTFIX  // function call
  else if AKind = tkDot then
    Result := BP_POSTFIX  // field access
  else if AKind = tkLBracket then
    Result := BP_POSTFIX  // array indexing
  else if AKind = tkCaret then
    Result := BP_POSTFIX  // pointer dereference
  else
    Result := BP_NONE;
end;

function TGnyScriptParser.ParseExpression(const AMinBP: Integer): Integer;
var
  LTok: TGnyScriptToken;
  LLeft: Integer;
  LRight: Integer;
  LNode: TGnyScriptNode;
  LOpNode: Integer;
  LCallNode: Integer;
  LArgNode: Integer;
  LFieldInitNode: Integer;
  LBP: Integer;
begin
  // --- NUD: prefix / atoms ---
  LTok := Peek();

  // Integer literal
  if LTok.Kind = tkIntLit then
  begin
    Advance();
    LLeft := AddNode(nkIntLit, LTok.Range);
    LNode := FNodes[LLeft];
    LNode.Text := LTok.Text;
    FNodes[LLeft] := LNode;
  end

  // Float literal
  else if LTok.Kind = tkFloatLit then
  begin
    Advance();
    LLeft := AddNode(nkFloatLit, LTok.Range);
    LNode := FNodes[LLeft];
    LNode.Text := LTok.Text;
    FNodes[LLeft] := LNode;
  end

  // Identifier
  else if LTok.Kind = tkIdent then
  begin
    Advance();
    LLeft := AddNode(nkIdent, LTok.Range);
    LNode := FNodes[LLeft];
    LNode.Text := LTok.Text;
    FNodes[LLeft] := LNode;
  end

  // String literal
  else if LTok.Kind = tkStringLit then
  begin
    Advance();
    LLeft := AddNode(nkStringLit, LTok.Range);
    LNode := FNodes[LLeft];
    LNode.Text := LTok.Text;
    FNodes[LLeft] := LNode;
  end

  // Wide string literal
  else if LTok.Kind = tkWStringLit then
  begin
    Advance();
    LLeft := AddNode(nkWStringLit, LTok.Range);
    LNode := FNodes[LLeft];
    LNode.Text := LTok.Text;
    FNodes[LLeft] := LNode;
  end

  // Boolean literals
  else if LTok.Kind = tkTrue then
  begin
    Advance();
    LLeft := AddNode(nkBoolLit, LTok.Range);
    LNode := FNodes[LLeft];
    LNode.Text := 'true';
    FNodes[LLeft] := LNode;
  end
  else if LTok.Kind = tkFalse then
  begin
    Advance();
    LLeft := AddNode(nkBoolLit, LTok.Range);
    LNode := FNodes[LLeft];
    LNode.Text := 'false';
    FNodes[LLeft] := LNode;
  end

  // Grouped expression: ( expr )
  else if LTok.Kind = tkLParen then
  begin
    Advance();
    LLeft := ParseExpression(BP_NONE);
    Expect(tkRParen);
  end

  // Unary minus / plus / not
  else if (LTok.Kind = tkMinus) or (LTok.Kind = tkPlus) or
          (LTok.Kind = tkNot) then
  begin
    Advance();
    LLeft := AddNode(nkUnary, LTok.Range);
    LNode := FNodes[LLeft];
    LNode.Text := LTok.Text;
    FNodes[LLeft] := LNode;
    LRight := ParseExpression(BP_UNARY);
    AddChild(LLeft, LRight);
  end

  // len() intrinsic
  else if LTok.Kind = tkLen then
  begin
    Advance();
    LLeft := AddNode(nkLen, LTok.Range);
    Expect(tkLParen);
    LRight := ParseExpression(BP_NONE);
    AddChild(LLeft, LRight);
    Expect(tkRParen);
  end

  // nil literal
  else if LTok.Kind = tkNil then
  begin
    Advance();
    LLeft := AddNode(nkNilLit, LTok.Range);
  end

  // address of expr
  else if LTok.Kind = tkAddress then
  begin
    Advance(); // consume 'address'
    Expect(tkOf);
    LLeft := AddNode(nkAddressOf, LTok.Range);
    LRight := ParseExpression(BP_UNARY);
    AddChild(LLeft, LRight);
  end

  // &expr — short form of address of
  else if LTok.Kind = tkAmpersand then
  begin
    Advance(); // consume '&'
    LLeft := AddNode(nkAddressOf, LTok.Range);
    LRight := ParseExpression(BP_UNARY);
    AddChild(LLeft, LRight);
  end

  // Set literal: [ expr [.. expr] { , expr [.. expr] } ]
  else if LTok.Kind = tkLBracket then
  begin
    Advance(); // consume '['
    LLeft := AddNode(nkSetLiteral, LTok.Range);
    if PeekKind() <> tkRBracket then
    begin
      repeat
        LRight := ParseExpression(BP_NONE);
        // Check for range element: expr .. expr
        if PeekKind() = tkRange then
        begin
          Advance(); // consume '..'
          LArgNode := ParseExpression(BP_NONE);
          LOpNode := AddNode(nkBinary, FNodes[LRight].Range);
          LNode := FNodes[LOpNode];
          LNode.Text := '..';
          FNodes[LOpNode] := LNode;
          AddChild(LOpNode, LRight);
          AddChild(LOpNode, LArgNode);
          AddChild(LLeft, LOpNode);
        end
        else
          AddChild(LLeft, LRight);
      until (AtEnd()) or (PeekKind() <> tkComma) or
            (Advance().Kind <> tkComma);
    end;
    Expect(tkRBracket);
  end

  else
  begin
    FErrors.Add(LTok.Range, esError, GNY_ERROR_SCRIPT_UNEXPECTED,
      RSScriptExpectedExpr, [LTok.Text]);
    Result := -1;
    Exit;
  end;

  // --- LED: infix / postfix loop ---
  while not AtEnd() do
  begin
    LTok := Peek();
    LBP := GetInfixBP(LTok.Kind);

    // Stop if this operator binds less tightly than our minimum
    if LBP <= AMinBP then
      Break;

    // Function call or record literal: ident ( ... )
    if LTok.Kind = tkLParen then
    begin
      Advance(); // consume (

      // Record literal: ident(fieldName: expr, ...)
      // Detect by checking if first token is ident followed by ':'
      if (FNodes[LLeft].Kind = nkIdent) and
         (PeekKind() = tkIdent) and
         (FPos + 1 < FTokens.Count) and
         (FTokens[FPos + 1].Kind = tkColon) then
      begin
        // Parse as record literal
        LCallNode := AddNode(nkRecordLiteral, FNodes[LLeft].Range);
        LNode := FNodes[LCallNode];
        LNode.Text := FNodes[LLeft].Text; // record type name
        FNodes[LCallNode] := LNode;

        // Parse field initializers: ident : expr { , ident : expr }
        while (not AtEnd()) and (PeekKind() <> tkRParen) do
        begin
          LFieldInitNode := AddNode(nkFieldInit, Peek().Range);
          LNode := FNodes[LFieldInitNode];
          LNode.Text := Expect(tkIdent).Text; // field name
          FNodes[LFieldInitNode] := LNode;

          Expect(tkColon);

          LArgNode := ParseExpression(BP_NONE);
          AddChild(LFieldInitNode, LArgNode);
          AddChild(LCallNode, LFieldInitNode);

          if PeekKind() = tkComma then
            Advance()
          else if PeekKind() <> tkRParen then
          begin
            FErrors.Add(Peek().Range, esError, GNY_ERROR_SCRIPT_EXPECTED_TOKEN,
              RSScriptExpected, [''')'' or '',''', Peek().Text]);
            Break;
          end;
        end;

        Expect(tkRParen);
        LLeft := LCallNode;
      end
      else
      begin
        // Parse as function call
        LCallNode := AddNode(nkFuncCall, LTok.Range);
        AddChild(LCallNode, LLeft); // callee

        // Parse argument list
        if PeekKind() <> tkRParen then
        begin
          LArgNode := ParseExpression(BP_NONE);
          AddChild(LCallNode, LArgNode);
          while Match(tkComma) do
          begin
            LArgNode := ParseExpression(BP_NONE);
            AddChild(LCallNode, LArgNode);
          end;
        end;

        Expect(tkRParen);
        LLeft := LCallNode;
      end;
    end
    else if LTok.Kind = tkDot then
    begin
      // Field access: expr . ident
      Advance(); // consume .
      LTok := Expect(tkIdent);
      LOpNode := AddNode(nkFieldAccess, LTok.Range);
      LNode := FNodes[LOpNode];
      LNode.Text := LTok.Text; // field name
      FNodes[LOpNode] := LNode;
      AddChild(LOpNode, LLeft); // object/module being accessed
      LLeft := LOpNode;
    end
    else if LTok.Kind = tkLBracket then
    begin
      // Array indexing: expr [ index_expr ]
      Advance(); // consume [
      LRight := ParseExpression(BP_NONE);
      Expect(tkRBracket);
      LOpNode := AddNode(nkArrayIndex, LTok.Range);
      AddChild(LOpNode, LLeft);  // array expression
      AddChild(LOpNode, LRight); // index expression
      LLeft := LOpNode;
    end
    else if LTok.Kind = tkCaret then
    begin
      // Pointer dereference: expr ^
      Advance(); // consume ^
      LOpNode := AddNode(nkDeref, LTok.Range);
      AddChild(LOpNode, LLeft); // pointer expression
      LLeft := LOpNode;
    end
    else
    begin
      // Binary operator
      Advance(); // consume operator
      LOpNode := AddNode(nkBinary, LTok.Range);
      LNode := FNodes[LOpNode];
      LNode.Text := LTok.Text;
      FNodes[LOpNode] := LNode;

      // Right side — LBP+1 for left-associativity
      LRight := ParseExpression(LBP);
      AddChild(LOpNode, LLeft);
      AddChild(LOpNode, LRight);
      LLeft := LOpNode;
    end;
  end;

  Result := LLeft;
end;

//------------------------------------------------------------------------------
// Public accessors
//------------------------------------------------------------------------------

function TGnyScriptParser.GetNodeCount(): Integer;
begin
  Result := FNodes.Count;
end;

function TGnyScriptParser.GetNode(const AIndex: Integer): TGnyScriptNode;
begin
  Result := FNodes[AIndex];
end;

function TGnyScriptParser.GetRoot(): Integer;
begin
  Result := FRoot;
end;

end.
