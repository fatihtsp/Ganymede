{===============================================================================
  Ganymede™ - Embeddable Native Scripting Engine

  Copyright © 2026-present tinyBigGAMES™ LLC
  All Rights Reserved.

  See LICENSE for license information
===============================================================================}

unit Ganymede.Emitter;

{$I Ganymede.Defines.inc}

interface

uses
  System.SysUtils,
  System.Generics.Collections,
  Ganymede.Utils,
  Ganymede.Resources,
  Ganymede.Lexer,
  Ganymede.Parser,
  Ganymede.Semantics,
  Ganymede.Native;

type
  { TGnyScriptEmitter }
  TGnyScriptEmitter = class(TGnyBaseObject)
  private
    FNodes: TList<TGnyScriptNode>;
    FBackend: TGnyNativeBackend;
    FSemantics: TGnyScriptSemantics;
    FTempIndex: Integer;

    // Type resolution
    function ResolveValueType(const ATypeName: string): TGnyValueType;

    // Helper — check if a routine has an nkExternalDecl child
    function HasExternalChild(const AIndex: Integer): Boolean;

    // Helper — resolve linkage from nkDirective child ("C" → plC, else plDefault)
    function ResolveLinkage(const AIndex: Integer): TGnyLinkage;

    // Register external declaration on backend (ImportLib/ImportDll)
    procedure EmitExternalDecl(const AIndex: Integer);

    // AST walkers
    procedure EmitModule(const AIndex: Integer);
    procedure EmitRoutineDecl(const AIndex: Integer);
    procedure EmitTypeDecl(const AIndex: Integer);
    procedure EmitBlock(const AIndex: Integer);
    procedure EmitStatement(const AIndex: Integer);
    procedure EmitIf(const AIndex: Integer);
    procedure EmitWhile(const AIndex: Integer);
    procedure EmitFor(const AIndex: Integer);
    procedure EmitRepeat(const AIndex: Integer);
    procedure EmitMatch(const AIndex: Integer);
    procedure EmitReturn(const AIndex: Integer);
    procedure EmitLeave();
    procedure EmitSkip();
    procedure EmitWrite(const AIndex: Integer);
    procedure EmitVarDecl(const AIndex: Integer);
    procedure EmitConstDecl(const AIndex: Integer);
    procedure EmitAssign(const AIndex: Integer);
    function  EmitExpr(const AIndex: Integer): TGnyExpr;

  public
    constructor Create(); override;
    destructor Destroy(); override;

    // Main entry point
    function Emit(const ANodes: TList<TGnyScriptNode>;
      const ARoot: Integer;
      const ABackend: TGnyNativeBackend;
      const ASemantics: TGnyScriptSemantics): Boolean;
  end;

const
  GNY_ERROR_SCRIPT_EMIT_MATCH = 'SE0001';

implementation

{ TGnyScriptEmitter }

constructor TGnyScriptEmitter.Create();
begin
  inherited Create();
end;

destructor TGnyScriptEmitter.Destroy();
begin
  inherited Destroy();
end;

//------------------------------------------------------------------------------
// Type resolution
//------------------------------------------------------------------------------

function TGnyScriptEmitter.ResolveValueType(const ATypeName: string): TGnyValueType;
begin
  if ATypeName = 'int8' then
    Result := gvtInt8
  else if ATypeName = 'int16' then
    Result := gvtInt16
  else if ATypeName = 'int32' then
    Result := gvtInt32
  else if ATypeName = 'int64' then
    Result := gvtInt64
  else if ATypeName = 'uint8' then
    Result := gvtUInt8
  else if ATypeName = 'uint16' then
    Result := gvtUInt16
  else if ATypeName = 'uint32' then
    Result := gvtUInt32
  else if ATypeName = 'uint64' then
    Result := gvtUInt64
  else if ATypeName = 'float32' then
    Result := gvtFloat32
  else if ATypeName = 'float64' then
    Result := gvtFloat64
  else if ATypeName = 'boolean' then
    Result := gvtInt8  // boolean maps to int8 (0/1); backend Bool() creates these
  else if ATypeName = 'char' then
    Result := gvtInt8  // 8-bit character
  else if ATypeName = 'wchar' then
    Result := gvtInt16 // 16-bit wide character
  else if ATypeName = 'string' then
    Result := gvtPointer  // managed UTF-8 string (pointer to TStringRec)
  else if ATypeName = 'wstring' then
    Result := gvtPointer  // managed UTF-16 string (raw wchar_t pointer)
  else if ATypeName = 'pointer' then
    Result := gvtPointer
  else
    Result := gvtVoid;
end;

function TGnyScriptEmitter.HasExternalChild(const AIndex: Integer): Boolean;
var
  LNode: TGnyScriptNode;
  LI: Integer;
begin
  Result := False;
  LNode := FNodes[AIndex];
  for LI := 0 to Length(LNode.Children) - 1 do
  begin
    if FNodes[LNode.Children[LI]].Kind = nkExternalDecl then
    begin
      Result := True;
      Exit;
    end;
  end;
end;

function TGnyScriptEmitter.ResolveLinkage(const AIndex: Integer): TGnyLinkage;
var
  LNode: TGnyScriptNode;
  LI: Integer;
begin
  Result := plC; // C linkage by default (no mangling)
  LNode := FNodes[AIndex];
  for LI := 0 to Length(LNode.Children) - 1 do
  begin
    if (FNodes[LNode.Children[LI]].Kind = nkDirective) and
       (FNodes[LNode.Children[LI]].Text = 'cpplink') then
    begin
      Result := plDefault; // C++ Itanium mangling
      Exit;
    end;
  end;
end;

procedure TGnyScriptEmitter.EmitExternalDecl(const AIndex: Integer);
var
  LNode: TGnyScriptNode;
  LChild: TGnyScriptNode;
  LFuncName: string;
  LRetType: TGnyValueType;
  LParamTypes: TArray<TGnyValueType>;
  LParamCount: Integer;
  LExternalName: string;
  LLinkage: TGnyLinkage;
  LI: Integer;
begin
  LNode := FNodes[AIndex];
  LFuncName := LNode.Text;
  LLinkage := ResolveLinkage(AIndex);

  // Resolve return type
  if LNode.Extra <> '' then
    LRetType := ResolveValueType(LNode.Extra)
  else
    LRetType := gvtVoid;

  // Extract parameter types and external name from children
  LParamCount := 0;
  SetLength(LParamTypes, Length(LNode.Children));
  LExternalName := '';

  for LI := 0 to Length(LNode.Children) - 1 do
  begin
    LChild := FNodes[LNode.Children[LI]];
    if LChild.Kind = nkParamDecl then
    begin
      LParamTypes[LParamCount] := ResolveValueType(LChild.Extra);
      Inc(LParamCount);
    end
    else if LChild.Kind = nkExternalDecl then
      LExternalName := LChild.Text;
  end;
  SetLength(LParamTypes, LParamCount);

  // Dispatch by external name extension
  if LExternalName.EndsWith('.lib', True) then
    FBackend.ImportLib(
      LExternalName.Substring(0, LExternalName.Length - 4),
      LFuncName, LParamTypes, LRetType, False, LLinkage)
  else if LExternalName.EndsWith('.dll', True) then
    FBackend.ImportDll(LExternalName, LFuncName, LParamTypes, LRetType, False, LLinkage)
  else if LExternalName <> '' then
    // Bare name → DLL
    FBackend.ImportDll(LExternalName + '.dll', LFuncName, LParamTypes, LRetType, False, LLinkage);
end;

//------------------------------------------------------------------------------
// Main entry point
//------------------------------------------------------------------------------

function TGnyScriptEmitter.Emit(const ANodes: TList<TGnyScriptNode>;
  const ARoot: Integer; const ABackend: TGnyNativeBackend;
  const ASemantics: TGnyScriptSemantics): Boolean;
begin
  FNodes := ANodes;
  FBackend := ABackend;
  FSemantics := ASemantics;

  if (ARoot >= 0) and (ARoot < FNodes.Count) then
    EmitModule(ARoot);

  Result := FErrors.ErrorCount() = 0;
end;

//------------------------------------------------------------------------------
// AST walkers
//------------------------------------------------------------------------------

procedure TGnyScriptEmitter.EmitModule(const AIndex: Integer);
var
  LNode: TGnyScriptNode;
  LChild: TGnyScriptNode;
  LI: Integer;
begin
  LNode := FNodes[AIndex];

  // DLL modules need a DllMain entry point — Windows calls it on load/unload
  if LNode.Extra = 'dll' then
    FBackend.DllMain();

  for LI := 0 to Length(LNode.Children) - 1 do
  begin
    LChild := FNodes[LNode.Children[LI]];
    if LChild.Kind = nkRoutineDecl then
    begin
      if HasExternalChild(LNode.Children[LI]) then
        EmitExternalDecl(LNode.Children[LI])  // register on backend
      else
        EmitRoutineDecl(LNode.Children[LI]);  // compile function body
    end
    else if LChild.Kind = nkVarDecl then
    begin
      // Module-level variable → global
      FBackend.Global(LChild.Text, ResolveValueType(LChild.Extra));
    end
    else if LChild.Kind = nkConstDecl then
    begin
      // Module-level constant → global with initializer
      if Length(LChild.Children) > 0 then
        FBackend.Global(LChild.Text, ResolveValueType(LChild.Extra),
          EmitExpr(LChild.Children[0]));
    end
    else if LChild.Kind = nkTypeDecl then
      EmitTypeDecl(LNode.Children[LI])
    else if LChild.Kind = nkBlock then
      EmitBlock(LNode.Children[LI]);
  end;
end;

procedure TGnyScriptEmitter.EmitRoutineDecl(const AIndex: Integer);
var
  LNode: TGnyScriptNode;
  LChild: TGnyScriptNode;
  LRetType: TGnyValueType;
  LI: Integer;
begin
  LNode := FNodes[AIndex];

  // Resolve return type
  if LNode.Extra <> '' then
    LRetType := ResolveValueType(LNode.Extra)
  else
    LRetType := gvtVoid;

  // Begin function definition — cpplink routines use OverloadFunc to allow
  // duplicate names with Itanium mangling; C linkage uses Func (unique names)
  if ResolveLinkage(AIndex) = plDefault then
    FBackend.OverloadFunc(LNode.Text, LRetType, False, LNode.IsPublic)
  else
    FBackend.Func(LNode.Text, LRetType, False, ResolveLinkage(AIndex), LNode.IsPublic);
  FTempIndex := 0;

  // Emit parameters
  for LI := 0 to Length(LNode.Children) - 1 do
  begin
    LChild := FNodes[LNode.Children[LI]];
    if LChild.Kind = nkParamDecl then
      FBackend.Arg(LChild.Text, ResolveValueType(LChild.Extra));
  end;

  // Emit type declarations first (records must be defined before use)
  for LI := 0 to Length(LNode.Children) - 1 do
  begin
    LChild := FNodes[LNode.Children[LI]];
    if LChild.Kind = nkTypeDecl then
      EmitTypeDecl(LNode.Children[LI]);
  end;

  // Emit local variable and constant declarations
  for LI := 0 to Length(LNode.Children) - 1 do
  begin
    LChild := FNodes[LNode.Children[LI]];
    if LChild.Kind = nkVarDecl then
      EmitVarDecl(LNode.Children[LI])
    else if LChild.Kind = nkConstDecl then
      EmitConstDecl(LNode.Children[LI]);
  end;

  // Emit body (last child should be the block)
  for LI := 0 to Length(LNode.Children) - 1 do
  begin
    LChild := FNodes[LNode.Children[LI]];
    if LChild.Kind = nkBlock then
      EmitBlock(LNode.Children[LI]);
  end;

  FBackend.EndFunc();
end;

procedure TGnyScriptEmitter.EmitTypeDecl(const AIndex: Integer);
var
  LNode: TGnyScriptNode;
  LRecNode: TGnyScriptNode;
  LFieldNode: TGnyScriptNode;
  LTypeName: string;
  LIsPacked: Boolean;
  LExplicitAlign: Integer;
  LBaseType: string;
  LExtra: string;
  LAlignPos: Integer;
  LI: Integer;
begin
  LNode := FNodes[AIndex];
  LTypeName := LNode.Text;

  // Only record types supported for now
  if (Length(LNode.Children) = 0) or
     (FNodes[LNode.Children[0]].Kind <> nkRecordType) then
    Exit;

  LRecNode := FNodes[LNode.Children[0]];

  // Parse record flags from Extra: "packed", "align=N", or "packed,align=N"
  LExtra := LRecNode.Extra;
  LIsPacked := LExtra.Contains('packed');
  LExplicitAlign := 0;
  LAlignPos := LExtra.IndexOf('align=');
  if LAlignPos >= 0 then
    LExplicitAlign := StrToIntDef(
      LExtra.Substring(LAlignPos + 6).Split([','])[0], 0);

  // Base type from record node Text (set by parser for inheritance)
  LBaseType := LRecNode.Text;

  // Define the record on the backend
  FBackend.DefineRecord(LTypeName, LIsPacked, LExplicitAlign, LBaseType);

  // Emit fields
  for LI := 0 to Length(LRecNode.Children) - 1 do
  begin
    LFieldNode := FNodes[LRecNode.Children[LI]];
    if LFieldNode.Kind = nkFieldDecl then
    begin
      // Try primitive type first, fall back to named type
      if ResolveValueType(LFieldNode.Extra) <> gvtVoid then
        FBackend.Field(LFieldNode.Text, ResolveValueType(LFieldNode.Extra))
      else
        FBackend.Field(LFieldNode.Text, LFieldNode.Extra);
    end;
  end;

  FBackend.EndRecord();
end;

procedure TGnyScriptEmitter.EmitBlock(const AIndex: Integer);
var
  LNode: TGnyScriptNode;
  LI: Integer;
begin
  LNode := FNodes[AIndex];
  for LI := 0 to Length(LNode.Children) - 1 do
    EmitStatement(LNode.Children[LI]);
end;

procedure TGnyScriptEmitter.EmitStatement(const AIndex: Integer);
var
  LNode: TGnyScriptNode;
  LCallee: TGnyScriptNode;
  LFuncName: string;
  LArgs: array of TGnyExpr;
  LParamTypes: TArray<TGnyValueType>;
  LI: Integer;
begin
  if AIndex < 0 then
    Exit;
  LNode := FNodes[AIndex];

  if LNode.Kind = nkIf then
    EmitIf(AIndex)
  else if LNode.Kind = nkWhile then
    EmitWhile(AIndex)
  else if LNode.Kind = nkFor then
    EmitFor(AIndex)
  else if LNode.Kind = nkRepeat then
    EmitRepeat(AIndex)
  else if LNode.Kind = nkMatch then
    EmitMatch(AIndex)
  else if LNode.Kind = nkReturn then
    EmitReturn(AIndex)
  else if LNode.Kind = nkLeave then
    EmitLeave()
  else if LNode.Kind = nkSkip then
    EmitSkip()
  else if (LNode.Kind = nkWrite) or (LNode.Kind = nkWriteLn) then
    EmitWrite(AIndex)
  else if LNode.Kind = nkAssign then
    EmitAssign(AIndex)
  else if LNode.Kind = nkFuncCall then
  begin
    // Void call statement — use Call to ensure side effects execute
    if Length(LNode.Children) > 0 then
    begin
      LCallee := FNodes[LNode.Children[0]];

      // Resolve function name: direct ident or module.func field access
      LFuncName := '';
      if LCallee.Kind = nkIdent then
        LFuncName := LCallee.Text
      else if (LCallee.Kind = nkFieldAccess) then
        LFuncName := LCallee.Text; // bare function name from field access

      if LFuncName <> '' then
      begin
        SetLength(LArgs, Length(LNode.Children) - 1);
        for LI := 1 to Length(LNode.Children) - 1 do
          LArgs[LI - 1] := EmitExpr(LNode.Children[LI]);

        // Int→float argument coercion: only wrap integer LITERALS with IntToFloat64
        // when the import parameter expects float32/float64.
        LParamTypes := FBackend.GetImportParamTypes(LFuncName);
        for LI := 0 to High(LArgs) do
        begin
          if (LI < Length(LParamTypes)) and
             (LParamTypes[LI] in [gvtFloat32, gvtFloat64]) and
             (FNodes[LNode.Children[LI + 1]].Kind = nkIntLit) then
            LArgs[LI] := FBackend.IntToFloat64(LArgs[LI]);
        end;

        if Length(LArgs) > 0 then
          FBackend.Call(LFuncName, LArgs)
        else
          FBackend.Call(LFuncName);
      end;
    end;
  end
  else if LNode.Kind = nkBinary then
  begin
    // Could be an expression statement
    EmitExpr(AIndex);
  end;
end;

procedure TGnyScriptEmitter.EmitIf(const AIndex: Integer);
var
  LNode: TGnyScriptNode;
  LCondExpr: TGnyExpr;
begin
  LNode := FNodes[AIndex];

  // children[0] = condition, children[1] = then block, [2] = else block
  if Length(LNode.Children) < 2 then
    Exit;

  LCondExpr := EmitExpr(LNode.Children[0]);
  FBackend.When(LCondExpr);

  EmitBlock(LNode.Children[1]); // then block

  if Length(LNode.Children) > 2 then
  begin
    FBackend.Otherwise();
    EmitBlock(LNode.Children[2]); // else block
  end;

  FBackend.EndWhen();
end;

procedure TGnyScriptEmitter.EmitWhile(const AIndex: Integer);
var
  LNode: TGnyScriptNode;
  LCondExpr: TGnyExpr;
begin
  LNode := FNodes[AIndex];

  // children[0] = condition, children[1] = body block
  if Length(LNode.Children) < 2 then
    Exit;

  LCondExpr := EmitExpr(LNode.Children[0]);
  FBackend.Loop(LCondExpr);
  EmitBlock(LNode.Children[1]);
  FBackend.EndLoop();
end;

procedure TGnyScriptEmitter.EmitFor(const AIndex: Integer);
var
  LNode: TGnyScriptNode;
  LFromExpr: TGnyExpr;
  LToExpr: TGnyExpr;
begin
  LNode := FNodes[AIndex];

  // Text = var name, Extra = "to"/"downto"
  // children[0] = from, children[1] = to, children[2] = body block
  if Length(LNode.Children) < 3 then
    Exit;

  LFromExpr := EmitExpr(LNode.Children[0]);
  LToExpr := EmitExpr(LNode.Children[1]);

  // Declare the for loop variable (int32)
  FBackend.VarDecl(LNode.Text, gvtInt32);

  if LNode.Extra = 'downto' then
    FBackend.CountDown(LNode.Text, LFromExpr, LToExpr)
  else
    FBackend.Count(LNode.Text, LFromExpr, LToExpr);

  EmitBlock(LNode.Children[2]);
  FBackend.EndCount();
end;

procedure TGnyScriptEmitter.EmitRepeat(const AIndex: Integer);
var
  LNode: TGnyScriptNode;
  LCondExpr: TGnyExpr;
begin
  LNode := FNodes[AIndex];

  // children[0] = body block, children[1] = until condition
  if Length(LNode.Children) < 2 then
    Exit;

  FBackend.DoRepeat();
  EmitBlock(LNode.Children[0]);
  LCondExpr := EmitExpr(LNode.Children[1]);
  FBackend.StopWhen(LCondExpr);
end;

procedure TGnyScriptEmitter.EmitMatch(const AIndex: Integer);
var
  LNode: TGnyScriptNode;
  LArmNode: TGnyScriptNode;
  LLabelNode: TGnyScriptNode;
  LSelectorExpr: TGnyExpr;
  LValues: TArray<TGnyExpr>;
  LValueCount: Integer;
  LLowVal: Int64;
  LHighVal: Int64;
  LChildIdx: Integer;
  LI: Integer;
  LV: Int64;
begin
  LNode := FNodes[AIndex];

  // children[0] = selector expression
  if Length(LNode.Children) < 1 then
    Exit;

  LSelectorExpr := EmitExpr(LNode.Children[0]);
  FBackend.Match(LSelectorExpr);

  // children[1..N] = nkMatchArm nodes, optionally last = nkBlock (else)
  for LChildIdx := 1 to Length(LNode.Children) - 1 do
  begin
    LArmNode := FNodes[LNode.Children[LChildIdx]];

    if LArmNode.Kind = nkMatchArm then
    begin
      // Collect all label values for this arm
      // Last child of the arm is always the body block (nkBlock)
      LValueCount := 0;
      SetLength(LValues, 0);

      for LI := 0 to Length(LArmNode.Children) - 2 do // all except last (body)
      begin
        LLabelNode := FNodes[LArmNode.Children[LI]];

        if (LLabelNode.Kind = nkBinary) and (LLabelNode.Text = '..') then
        begin
          // Range label: expand low..high into discrete values
          if Length(LLabelNode.Children) >= 2 then
          begin
            // Validate both endpoints are integer literals
            if (FNodes[LLabelNode.Children[0]].Kind <> nkIntLit) or
               (FNodes[LLabelNode.Children[1]].Kind <> nkIntLit) then
            begin
              FErrors.Add(LLabelNode.Range, esError, GNY_ERROR_SCRIPT_EMIT_MATCH,
                RSScriptMatchLabelNotConst, []);
              Exit;
            end;
            LLowVal := StrToInt64Def(FNodes[LLabelNode.Children[0]].Text, 0);
            LHighVal := StrToInt64Def(FNodes[LLabelNode.Children[1]].Text, 0);
            for LV := LLowVal to LHighVal do
            begin
              SetLength(LValues, LValueCount + 1);
              LValues[LValueCount] := FBackend.Int64(LV);
              Inc(LValueCount);
            end;
          end;
        end
        else
        begin
          // Single value label — must be an integer literal
          if LLabelNode.Kind <> nkIntLit then
          begin
            FErrors.Add(LLabelNode.Range, esError, GNY_ERROR_SCRIPT_EMIT_MATCH,
              RSScriptMatchLabelNotConst, []);
            Exit;
          end;
          SetLength(LValues, LValueCount + 1);
          LValues[LValueCount] := EmitExpr(LArmNode.Children[LI]);
          Inc(LValueCount);
        end;
      end;

      // Emit On with collected values
      FBackend.On(LValues);

      // Emit arm body (last child)
      if Length(LArmNode.Children) > 0 then
        EmitBlock(LArmNode.Children[Length(LArmNode.Children) - 1]);
    end
    else if LArmNode.Kind = nkBlock then
    begin
      // Else block
      FBackend.OnElse();
      EmitBlock(LNode.Children[LChildIdx]);
    end;
  end;

  FBackend.EndMatch();
end;

procedure TGnyScriptEmitter.EmitLeave();
begin
  FBackend.LoopBreak();
end;

procedure TGnyScriptEmitter.EmitSkip();
begin
  FBackend.LoopContinue();
end;

//------------------------------------------------------------------------------
// Write/WriteLn emission — forwards all arguments to printf (variadic).
// First argument is the format string, remaining are values.
// WriteLn appends a newline after the printf call.
//------------------------------------------------------------------------------

procedure TGnyScriptEmitter.EmitWrite(const AIndex: Integer);
var
  LNode: TGnyScriptNode;
  LChildNode: TGnyScriptNode;
  LArgs: TArray<TGnyExpr>;
  LI: Integer;
begin
  LNode := FNodes[AIndex];

  // Build argument array — all expressions forwarded directly to printf
  SetLength(LArgs, Length(LNode.Children));
  for LI := 0 to Length(LNode.Children) - 1 do
  begin
    LChildNode := FNodes[LNode.Children[LI]];
    LArgs[LI] := EmitExpr(LNode.Children[LI]);

    // Managed string args (not literals) need StrData to get raw char* for printf.
    // String literals already produce raw char* via FBackend.Str — no wrapping needed.
    if (LChildNode.Extra = 'string') and (LChildNode.Kind <> nkStringLit) then
      LArgs[LI] := FBackend.Invoke('Gny_StrData', [LArgs[LI]]);
  end;

  // Emit printf call with all args
  if Length(LArgs) > 0 then
    FBackend.Call('printf', LArgs);

  // WriteLn appends a newline
  if LNode.Kind = nkWriteLn then
    FBackend.Call('printf', [FBackend.Str(#10)]);
end;

procedure TGnyScriptEmitter.EmitReturn(const AIndex: Integer);
var
  LNode: TGnyScriptNode;
begin
  LNode := FNodes[AIndex];
  if Length(LNode.Children) > 0 then
    FBackend.Ret(EmitExpr(LNode.Children[0]))
  else
    FBackend.Ret();
end;

//------------------------------------------------------------------------------
// Variable declaration emission
//------------------------------------------------------------------------------

procedure TGnyScriptEmitter.EmitVarDecl(const AIndex: Integer);
var
  LNode: TGnyScriptNode;
  LChild: TGnyScriptNode;
  LInitExpr: TGnyExpr;
  LVarIsFloat: Boolean;
  LInitIsFloat: Boolean;

  // Recursive float type check matching EmitExpr.ChildIsFloat
  function IsFloatNode(const AIdx: Integer): Boolean;
  var
    LInner: TGnyScriptNode;
  begin
    LInner := FNodes[AIdx];
    Result := (LInner.Extra = 'float32') or (LInner.Extra = 'float64');
    if Result then
      Exit;
    if (LInner.Kind = nkBinary) and (Length(LInner.Children) >= 2) then
    begin
      if LInner.Text = '/' then
        Result := True
      else
        Result := IsFloatNode(LInner.Children[0]) or IsFloatNode(LInner.Children[1]);
    end
    else if (LInner.Kind = nkUnary) and (Length(LInner.Children) >= 1) then
      Result := IsFloatNode(LInner.Children[0]);
  end;

begin
  LNode := FNodes[AIndex];

  //----------------------------------------------------------------------------
  // Managed string variable — use named-type VarDecl for SSA tracking
  //----------------------------------------------------------------------------
  if LNode.Extra = 'string' then
  begin
    FBackend.VarDecl(LNode.Text, 'string');
    FBackend.Let(LNode.Text, FBackend.Null());

    if Length(LNode.Children) > 0 then
    begin
      LChild := FNodes[LNode.Children[0]];

      if LChild.Kind = nkStringLit then
      begin
        // Init from literal — new string, refcount 1
        FBackend.Let(LNode.Text, FBackend.Invoke('Gny_StrFromLiteral',
          [FBackend.Str(LChild.Text), FBackend.Int64(Length(LChild.Text))]));
      end
      else if LChild.Kind = nkIdent then
      begin
        // Init from existing string var — share via addref
        LInitExpr := EmitExpr(LNode.Children[0]);
        FBackend.Call('Gny_StrAssign',
          [FBackend.AddrOf(LNode.Text), LInitExpr]);
      end
      else
      begin
        // Init from expression (concat, func call) — direct ownership
        LInitExpr := EmitExpr(LNode.Children[0]);
        FBackend.Let(LNode.Text, LInitExpr);
      end;
    end;
    Exit;
  end;

  //----------------------------------------------------------------------------
  // Non-string variable — existing path
  //----------------------------------------------------------------------------
  // Record-typed variables use the string overload of VarDecl
  if ResolveValueType(LNode.Extra) = gvtVoid then
    FBackend.VarDecl(LNode.Text, LNode.Extra)
  else
    FBackend.VarDecl(LNode.Text, ResolveValueType(LNode.Extra));

  // If initializer present (child[0]), emit assignment
  if Length(LNode.Children) > 0 then
  begin
    LInitExpr := EmitExpr(LNode.Children[0]);
    // Promote int→float when initializing float variable with integer
    LVarIsFloat := (LNode.Extra = 'float32') or (LNode.Extra = 'float64');
    LInitIsFloat := IsFloatNode(LNode.Children[0]);
    if LVarIsFloat and (not LInitIsFloat) then
      LInitExpr := FBackend.IntToFloat64(LInitExpr);
    FBackend.Let(LNode.Text, LInitExpr);
  end;
end;

//------------------------------------------------------------------------------
// Constant declaration emission — backend local + initializer;
// immutability is enforced by semantic analysis, not codegen
//------------------------------------------------------------------------------

procedure TGnyScriptEmitter.EmitConstDecl(const AIndex: Integer);
var
  LNode: TGnyScriptNode;
begin
  LNode := FNodes[AIndex];

  // Declare as a local variable in the backend
  FBackend.VarDecl(LNode.Text, ResolveValueType(LNode.Extra));

  // Emit initializer (always present for constants)
  if Length(LNode.Children) > 0 then
    FBackend.Let(LNode.Text, EmitExpr(LNode.Children[0]));
end;

//------------------------------------------------------------------------------
// Assignment emission
//------------------------------------------------------------------------------

procedure TGnyScriptEmitter.EmitAssign(const AIndex: Integer);
var
  LNode: TGnyScriptNode;
  LLhsNode: TGnyScriptNode;
  LRhsNode: TGnyScriptNode;
  LRhsExpr: TGnyExpr;
  LConcatExpr: TGnyExpr;
  LOp: string;
  LLhsFloat: Boolean;
  LI: Integer;
  LRhsFloat: Boolean;

  // Recursive float type check matching EmitExpr.ChildIsFloat
  function IsFloatNode(const AIdx: Integer): Boolean;
  var
    LChild: TGnyScriptNode;
  begin
    LChild := FNodes[AIdx];
    Result := (LChild.Extra = 'float32') or (LChild.Extra = 'float64');
    if Result then
      Exit;
    if (LChild.Kind = nkBinary) and (Length(LChild.Children) >= 2) then
    begin
      if LChild.Text = '/' then
        Result := True
      else
        Result := IsFloatNode(LChild.Children[0]) or IsFloatNode(LChild.Children[1]);
    end
    else if (LChild.Kind = nkUnary) and (Length(LChild.Children) >= 1) then
      Result := IsFloatNode(LChild.Children[0]);
  end;

begin
  LNode := FNodes[AIndex];
  if Length(LNode.Children) < 2 then
    Exit;

  LLhsNode := FNodes[LNode.Children[0]];
  LOp := LNode.Text;

  //----------------------------------------------------------------------------
  // Record field assignment — rec.field := value (must be FIRST)
  //----------------------------------------------------------------------------
  if LLhsNode.Kind = nkFieldAccess then
  begin
    if (LOp = ':=') and (Length(LLhsNode.Children) > 0) then
    begin
      LRhsNode := FNodes[LNode.Children[1]];

      // String-typed field — use StrAssign for atomic refcount management
      // (SetVal triggers backend auto-release that corrupts the new value)
      if LLhsNode.Extra = 'string' then
      begin
        if LRhsNode.Kind = nkStringLit then
        begin
          // Create managed string from literal, assign via StrAssign, release temp
          LRhsExpr := FBackend.Invoke('Gny_StrFromLiteral',
            [FBackend.Str(LRhsNode.Text),
             FBackend.Int64(Length(LRhsNode.Text))]);
          FBackend.Call('Gny_StrAssign',
            [FBackend.AddrOfVal(
               FBackend.GetField(EmitExpr(LLhsNode.Children[0]), LLhsNode.Text)),
             LRhsExpr]);
          FBackend.Call('Gny_StrRelease', [LRhsExpr]);
        end
        else
        begin
          // General expression (concat, ident, etc.) — StrAssign handles refcounting
          LRhsExpr := EmitExpr(LNode.Children[1]);
          FBackend.Call('Gny_StrAssign',
            [FBackend.AddrOfVal(
               FBackend.GetField(EmitExpr(LLhsNode.Children[0]), LLhsNode.Text)),
             LRhsExpr]);
        end;
      end
      // Char field + string literal → emit ordinal value
      else if (LRhsNode.Kind = nkStringLit) and (Length(LRhsNode.Text) = 1) and
              (LLhsNode.Extra = 'char') then
      begin
        FBackend.SetVal(
          FBackend.GetField(EmitExpr(LLhsNode.Children[0]), LLhsNode.Text),
          FBackend.Int8(Int8(Ord(LRhsNode.Text[1]))));
      end
      // Wchar field + wstring literal → emit ordinal value
      else if (LRhsNode.Kind = nkWStringLit) and (Length(LRhsNode.Text) = 1) and
              (LLhsNode.Extra = 'wchar') then
      begin
        FBackend.SetVal(
          FBackend.GetField(EmitExpr(LLhsNode.Children[0]), LLhsNode.Text),
          FBackend.Int16(Int16(Ord(LRhsNode.Text[1]))));
      end
      else
      begin
        // Default: emit RHS and store to field
        LRhsExpr := EmitExpr(LNode.Children[1]);
        FBackend.SetVal(
          FBackend.GetField(EmitExpr(LLhsNode.Children[0]), LLhsNode.Text),
          LRhsExpr);
      end;
    end;
    Exit;
  end;

  //----------------------------------------------------------------------------
  // Managed string assignment (standalone variable, not field access)
  //----------------------------------------------------------------------------
  if LLhsNode.Extra = 'string' then
  begin
    LRhsNode := FNodes[LNode.Children[1]];

    if LOp = ':=' then
    begin
      if LRhsNode.Kind = nkStringLit then
      begin
        // Assign from literal — release old, store new (refcount 1)
        FBackend.Call('Gny_StrRelease', [FBackend.Get(LLhsNode.Text)]);
        FBackend.Let(LLhsNode.Text, FBackend.Invoke('Gny_StrFromLiteral',
          [FBackend.Str(LRhsNode.Text),
           FBackend.Int64(Length(LRhsNode.Text))]));
      end
      else if LRhsNode.Kind = nkIdent then
      begin
        // Assign from existing string var — StrAssign handles release+addref
        LRhsExpr := EmitExpr(LNode.Children[1]);
        FBackend.Call('Gny_StrAssign',
          [FBackend.AddrOf(LLhsNode.Text), LRhsExpr]);
      end
      else
      begin
        // Assign from expression (concat, func call) — own new, release old.
        // Must capture old pointer in a temp BEFORE Let, because Get(varname)
        // resolves to the SSA version current at that instruction.
        FBackend.VarDecl(Format('__t%d', [FTempIndex]), gvtPointer);
        FBackend.Let(Format('__t%d', [FTempIndex]), FBackend.Get(LLhsNode.Text));
        LRhsExpr := EmitExpr(LNode.Children[1]);
        FBackend.Let(LLhsNode.Text, LRhsExpr);
        FBackend.Call('Gny_StrRelease', [FBackend.Get(Format('__t%d', [FTempIndex]))]);
        Inc(FTempIndex);
      end;
    end
    else if LOp = '+=' then
    begin
      // Concat-assign: concat old with rhs, store result, release old + temp.
      // Must capture old pointer in a temp BEFORE Let, because Get(varname)
      // resolves to the SSA version current at that instruction. After Let
      // creates a new version, Get would return the new value, not the old.
      if LRhsNode.Kind = nkStringLit then
      begin
        FBackend.VarDecl(Format('__t%d', [FTempIndex]), gvtPointer);
        FBackend.Let(Format('__t%d', [FTempIndex]), FBackend.Invoke('Gny_StrFromLiteral',
          [FBackend.Str(LRhsNode.Text),
           FBackend.Int64(Length(LRhsNode.Text))]));
        LRhsExpr := FBackend.Get(Format('__t%d', [FTempIndex]));
        Inc(FTempIndex);
      end
      else
        LRhsExpr := EmitExpr(LNode.Children[1]);

      // Capture old string pointer in a temp before Let overwrites the version
      FBackend.VarDecl(Format('__t%d', [FTempIndex]), gvtPointer);
      FBackend.Let(Format('__t%d', [FTempIndex]), FBackend.Get(LLhsNode.Text));

      LConcatExpr := FBackend.Invoke('Gny_StrConcat',
        [FBackend.Get(Format('__t%d', [FTempIndex])), LRhsExpr]);
      FBackend.Let(LLhsNode.Text, LConcatExpr);

      // Release old string and literal temp via their named temps
      FBackend.Call('Gny_StrRelease', [FBackend.Get(Format('__t%d', [FTempIndex]))]);
      Inc(FTempIndex);
      if LRhsNode.Kind = nkStringLit then
        FBackend.Call('Gny_StrRelease', [LRhsExpr]);
    end;
    Exit;
  end;

  //----------------------------------------------------------------------------
  // Non-string assignment — existing path
  //----------------------------------------------------------------------------
  LLhsFloat := (LLhsNode.Extra = 'float32') or (LLhsNode.Extra = 'float64');
  LRhsFloat := IsFloatNode(LNode.Children[1]);

  // For simple assignment, emit directly
  if LOp = ':=' then
  begin
    LRhsNode := FNodes[LNode.Children[1]];

    // Record literal RHS — emit field-by-field directly into LHS variable
    // (avoids temp var + struct copy which fails for structs > 8 bytes)
    if LRhsNode.Kind = nkRecordLiteral then
    begin
      for LI := 0 to Length(LRhsNode.Children) - 1 do
      begin
        if (FNodes[LRhsNode.Children[LI]].Kind = nkFieldInit) and
           (Length(FNodes[LRhsNode.Children[LI]].Children) > 0) then
        begin
          LRhsExpr := EmitExpr(FNodes[LRhsNode.Children[LI]].Children[0]);
          FBackend.SetVal(
            FBackend.GetField(FBackend.Get(LLhsNode.Text),
              FNodes[LRhsNode.Children[LI]].Text),
            LRhsExpr);
        end;
      end;
    end
    else
    begin
      LRhsExpr := EmitExpr(LNode.Children[1]);
      // Promote int→float when assigning integer to float variable
      if LLhsFloat and (not LRhsFloat) then
        LRhsExpr := FBackend.IntToFloat64(LRhsExpr);
      FBackend.Let(LLhsNode.Text, LRhsExpr);
    end;
  end
  else
  begin
    // Compound assignment: desugar x += e → x := x + e
    // Use float ops when LHS is float-typed
    LRhsExpr := EmitExpr(LNode.Children[1]);
    if LLhsFloat and (not LRhsFloat) then
      LRhsExpr := FBackend.IntToFloat64(LRhsExpr);

    if LOp = '+=' then
    begin
      if LLhsFloat then
        FBackend.Let(LLhsNode.Text, FBackend.FAdd(FBackend.Get(LLhsNode.Text), LRhsExpr))
      else
        FBackend.Let(LLhsNode.Text, FBackend.Add(FBackend.Get(LLhsNode.Text), LRhsExpr));
    end
    else if LOp = '-=' then
    begin
      if LLhsFloat then
        FBackend.Let(LLhsNode.Text, FBackend.FSub(FBackend.Get(LLhsNode.Text), LRhsExpr))
      else
        FBackend.Let(LLhsNode.Text, FBackend.Sub(FBackend.Get(LLhsNode.Text), LRhsExpr));
    end
    else if LOp = '*=' then
    begin
      if LLhsFloat then
        FBackend.Let(LLhsNode.Text, FBackend.FMul(FBackend.Get(LLhsNode.Text), LRhsExpr))
      else
        FBackend.Let(LLhsNode.Text, FBackend.Mul(FBackend.Get(LLhsNode.Text), LRhsExpr));
    end
    else if LOp = '/=' then
    begin
      if LLhsFloat then
        FBackend.Let(LLhsNode.Text, FBackend.FDiv(FBackend.Get(LLhsNode.Text), LRhsExpr))
      else
        FBackend.Let(LLhsNode.Text, FBackend.IDiv(FBackend.Get(LLhsNode.Text), LRhsExpr));
    end;
  end;
end;

//------------------------------------------------------------------------------
// Expression emission — returns a TGnyExpr for the backend
//------------------------------------------------------------------------------

function TGnyScriptEmitter.EmitExpr(const AIndex: Integer): TGnyExpr;
var
  LNode: TGnyScriptNode;
  LLeft: TGnyExpr;
  LRight: TGnyExpr;
  LArgs: TArray<TGnyExpr>;
  LCallee: TGnyScriptNode;
  LFuncName: string;
  LTempName: string;
  LFieldInitNode: TGnyScriptNode;
  LI: Integer;
  LIsFloat: Boolean;
  LLeftFloat: Boolean;
  LRightFloat: Boolean;
  LFmt: TFormatSettings;

  // Check if a child expression node resolved to a float type.
  // Recurses into binary/unary nodes whose result type isn't annotated.
  function ChildIsFloat(const AChildIndex: Integer): Boolean;
  var
    LChild: TGnyScriptNode;
  begin
    LChild := FNodes[AChildIndex];
    // Direct type annotation from semantic analysis
    Result := (LChild.Extra = 'float32') or (LChild.Extra = 'float64');
    if Result then
      Exit;
    // Binary expressions: / always returns float; others float if either operand is
    if (LChild.Kind = nkBinary) and (Length(LChild.Children) >= 2) then
    begin
      if LChild.Text = '/' then
        Result := True
      else
        Result := ChildIsFloat(LChild.Children[0]) or ChildIsFloat(LChild.Children[1]);
    end
    // Unary expressions: float if operand is float
    else if (LChild.Kind = nkUnary) and (Length(LChild.Children) >= 1) then
      Result := ChildIsFloat(LChild.Children[0]);
  end;

  // Promote an integer expression to float64
  function Promote(const AExpr: TGnyExpr; const AChildIndex: Integer): TGnyExpr;
  begin
    if not ChildIsFloat(AChildIndex) then
      Result := FBackend.IntToFloat64(AExpr)
    else
      Result := AExpr;
  end;

begin
  Result := Default(TGnyExpr);
  if AIndex < 0 then
    Exit;
  LNode := FNodes[AIndex];

  // Integer literal
  if LNode.Kind = nkIntLit then
    Result := FBackend.Int32(StrToIntDef(LNode.Text, 0))

  // Float literal (locale-safe: source always uses '.' decimal separator)
  else if LNode.Kind = nkFloatLit then
  begin
    LFmt := Default(TFormatSettings);
    LFmt.DecimalSeparator := '.';
    Result := FBackend.Float64(StrToFloat(LNode.Text, LFmt));
  end

  // String literal
  else if LNode.Kind = nkStringLit then
    Result := FBackend.Str(LNode.Text)

  // Wide string literal
  else if LNode.Kind = nkWStringLit then
    Result := FBackend.WStr(LNode.Text)

  // Boolean literal
  else if LNode.Kind = nkBoolLit then
    Result := FBackend.Bool(LNode.Text = 'true')

  // Identifier — variable/param reference
  else if LNode.Kind = nkIdent then
    Result := FBackend.Get(LNode.Text)

  // Unary operator
  else if LNode.Kind = nkUnary then
  begin
    if Length(LNode.Children) > 0 then
    begin
      LRight := EmitExpr(LNode.Children[0]);
      if LNode.Text = '-' then
      begin
        if ChildIsFloat(LNode.Children[0]) then
          Result := FBackend.FNeg(LRight)
        else
          Result := FBackend.Neg(LRight);
      end
      else if LNode.Text = 'not' then
        Result := FBackend.LogNot(LRight)
      else
        Result := LRight;
    end;
  end

  // Binary operator
  else if LNode.Kind = nkBinary then
  begin
    if Length(LNode.Children) >= 2 then
    begin
      //----------------------------------------------------------------------
      // String binary operators — dispatch before numeric path
      //----------------------------------------------------------------------
      if FNodes[LNode.Children[0]].Extra = 'string' then
      begin
        // Emit operands as TStringRec* (wrap raw literals with StrFromLiteral)
        if FNodes[LNode.Children[0]].Kind = nkStringLit then
          LLeft := FBackend.Invoke('Gny_StrFromLiteral',
            [FBackend.Str(FNodes[LNode.Children[0]].Text),
             FBackend.Int64(Length(FNodes[LNode.Children[0]].Text))])
        else
          LLeft := EmitExpr(LNode.Children[0]);

        if FNodes[LNode.Children[1]].Kind = nkStringLit then
          LRight := FBackend.Invoke('Gny_StrFromLiteral',
            [FBackend.Str(FNodes[LNode.Children[1]].Text),
             FBackend.Int64(Length(FNodes[LNode.Children[1]].Text))])
        else
          LRight := EmitExpr(LNode.Children[1]);

        if LNode.Text = '+' then
        begin
          // String concat — result is new TStringRec* (refcount 1)
          Result := FBackend.Invoke('Gny_StrConcat', [LLeft, LRight]);
          // Release literal temps after concat consumes them
          if FNodes[LNode.Children[0]].Kind = nkStringLit then
            FBackend.Call('Gny_StrRelease', [LLeft]);
          if FNodes[LNode.Children[1]].Kind = nkStringLit then
            FBackend.Call('Gny_StrRelease', [LRight]);
        end
        else if (LNode.Text = '=') or (LNode.Text = '<>') then
        begin
          // Materialize literal operands and comparison result into unique
          // named temps so everything executes eagerly before releases.
          if FNodes[LNode.Children[0]].Kind = nkStringLit then
          begin
            FBackend.VarDecl(Format('__t%d', [FTempIndex]), gvtPointer);
            FBackend.Let(Format('__t%d', [FTempIndex]), LLeft);
            LLeft := FBackend.Get(Format('__t%d', [FTempIndex]));
            Inc(FTempIndex);
          end;
          if FNodes[LNode.Children[1]].Kind = nkStringLit then
          begin
            FBackend.VarDecl(Format('__t%d', [FTempIndex]), gvtPointer);
            FBackend.Let(Format('__t%d', [FTempIndex]), LRight);
            LRight := FBackend.Get(Format('__t%d', [FTempIndex]));
            Inc(FTempIndex);
          end;

          // Materialize comparison result so StrCompare executes before releases
          FBackend.VarDecl(Format('__t%d', [FTempIndex]), gvtInt8);
          if LNode.Text = '=' then
            FBackend.Let(Format('__t%d', [FTempIndex]), FBackend.Eq(
              FBackend.Invoke('Gny_StrCompare', [LLeft, LRight]),
              FBackend.Int64(0)))
          else
            FBackend.Let(Format('__t%d', [FTempIndex]), FBackend.Ne(
              FBackend.Invoke('Gny_StrCompare', [LLeft, LRight]),
              FBackend.Int64(0)));
          Result := FBackend.Get(Format('__t%d', [FTempIndex]));
          Inc(FTempIndex);

          // Release literal temps
          if FNodes[LNode.Children[0]].Kind = nkStringLit then
            FBackend.Call('Gny_StrRelease', [LLeft]);
          if FNodes[LNode.Children[1]].Kind = nkStringLit then
            FBackend.Call('Gny_StrRelease', [LRight]);
        end;
      end
      else
      begin
      //----------------------------------------------------------------------
      // Numeric/boolean binary operators — existing path
      //----------------------------------------------------------------------
      LLeft := EmitExpr(LNode.Children[0]);
      LRight := EmitExpr(LNode.Children[1]);
      LLeftFloat := ChildIsFloat(LNode.Children[0]);
      LRightFloat := ChildIsFloat(LNode.Children[1]);
      LIsFloat := LLeftFloat or LRightFloat;

      // Arithmetic — type-aware dispatch
      if LNode.Text = '+' then
      begin
        if LIsFloat then
          Result := FBackend.FAdd(Promote(LLeft, LNode.Children[0]),
                                  Promote(LRight, LNode.Children[1]))
        else
          Result := FBackend.Add(LLeft, LRight);
      end
      else if LNode.Text = '-' then
      begin
        if LIsFloat then
          Result := FBackend.FSub(Promote(LLeft, LNode.Children[0]),
                                  Promote(LRight, LNode.Children[1]))
        else
          Result := FBackend.Sub(LLeft, LRight);
      end
      else if LNode.Text = '*' then
      begin
        if LIsFloat then
          Result := FBackend.FMul(Promote(LLeft, LNode.Children[0]),
                                  Promote(LRight, LNode.Children[1]))
        else
          Result := FBackend.Mul(LLeft, LRight);
      end

      // / always returns float64 (language design)
      else if LNode.Text = '/' then
        Result := FBackend.FDiv(Promote(LLeft, LNode.Children[0]),
                                Promote(LRight, LNode.Children[1]))

      // Integer-only operators
      else if LNode.Text = 'div' then
        Result := FBackend.IDiv(LLeft, LRight)
      else if LNode.Text = 'mod' then
        Result := FBackend.IMod(LLeft, LRight)

      // Bitwise operators
      else if (LNode.Text = 'xor') or (LNode.Text = '^') then
        Result := FBackend.BitXor(LLeft, LRight)
      else if LNode.Text = 'shl' then
        Result := FBackend.ShiftL(LLeft, LRight)
      else if LNode.Text = 'shr' then
        Result := FBackend.ShiftR(LLeft, LRight)

      // Comparison — type-aware dispatch
      else if LNode.Text = '=' then
      begin
        if LIsFloat then
          Result := FBackend.FEq(Promote(LLeft, LNode.Children[0]),
                                 Promote(LRight, LNode.Children[1]))
        else
          Result := FBackend.Eq(LLeft, LRight);
      end
      else if LNode.Text = '<>' then
      begin
        if LIsFloat then
          Result := FBackend.FNe(Promote(LLeft, LNode.Children[0]),
                                 Promote(LRight, LNode.Children[1]))
        else
          Result := FBackend.Ne(LLeft, LRight);
      end
      else if LNode.Text = '<' then
      begin
        if LIsFloat then
          Result := FBackend.FLt(Promote(LLeft, LNode.Children[0]),
                                 Promote(LRight, LNode.Children[1]))
        else
          Result := FBackend.Lt(LLeft, LRight);
      end
      else if LNode.Text = '>' then
      begin
        if LIsFloat then
          Result := FBackend.FGt(Promote(LLeft, LNode.Children[0]),
                                 Promote(LRight, LNode.Children[1]))
        else
          Result := FBackend.Gt(LLeft, LRight);
      end
      else if LNode.Text = '<=' then
      begin
        if LIsFloat then
          Result := FBackend.FLe(Promote(LLeft, LNode.Children[0]),
                                 Promote(LRight, LNode.Children[1]))
        else
          Result := FBackend.Le(LLeft, LRight);
      end
      else if LNode.Text = '>=' then
      begin
        if LIsFloat then
          Result := FBackend.FGe(Promote(LLeft, LNode.Children[0]),
                                 Promote(LRight, LNode.Children[1]))
        else
          Result := FBackend.Ge(LLeft, LRight);
      end

      // Logical
      else if LNode.Text = 'and' then
        Result := FBackend.LogAnd(LLeft, LRight)
      else if LNode.Text = 'or' then
        Result := FBackend.LogOr(LLeft, LRight);
      end; // else (numeric/boolean path)
    end;
  end

  // Function call
  else if LNode.Kind = nkFuncCall then
  begin
    // children[0] = callee, children[1..n] = args
    if Length(LNode.Children) > 0 then
    begin
      LCallee := FNodes[LNode.Children[0]];

      // Resolve function name: direct ident or module.func field access
      LFuncName := '';
      if LCallee.Kind = nkIdent then
        LFuncName := LCallee.Text
      else if LCallee.Kind = nkFieldAccess then
        LFuncName := LCallee.Text; // bare function name

      if LFuncName <> '' then
      begin
        // Build argument array
        SetLength(LArgs, Length(LNode.Children) - 1);
        for LI := 1 to Length(LNode.Children) - 1 do
          LArgs[LI - 1] := EmitExpr(LNode.Children[LI]);

        // Emit as Invoke (returns a value)
        Result := FBackend.Invoke(LFuncName, LArgs);
      end;
    end;
  end

  // Field access — record.field
  else if LNode.Kind = nkFieldAccess then
  begin
    // children[0] = LHS expression (record variable), Text = field name
    if Length(LNode.Children) > 0 then
    begin
      LLeft := EmitExpr(LNode.Children[0]);
      Result := FBackend.GetField(LLeft, LNode.Text);
    end;
  end

  // Record literal — TypeName(field1: val1, field2: val2, ...)
  else if LNode.Kind = nkRecordLiteral then
  begin
    // Declare a temp variable of the record type, set each field, return it
    LTempName := Format('__r%d', [FTempIndex]);
    Inc(FTempIndex);
    FBackend.VarDecl(LTempName, LNode.Text);

    // Set each field from the initializer list
    for LI := 0 to Length(LNode.Children) - 1 do
    begin
      LFieldInitNode := FNodes[LNode.Children[LI]];
      if (LFieldInitNode.Kind = nkFieldInit) and
         (Length(LFieldInitNode.Children) > 0) then
      begin
        LRight := EmitExpr(LFieldInitNode.Children[0]);
        FBackend.SetVal(
          FBackend.GetField(FBackend.Get(LTempName), LFieldInitNode.Text),
          LRight);
      end;
    end;

    Result := FBackend.Get(LTempName);
  end;
end;

end.
