{===============================================================================
  Ganymede™ - Embeddable Native Scripting Engine

  Copyright © 2026-present tinyBigGAMES™ LLC
  All Rights Reserved.

  See LICENSE for license information
===============================================================================}

unit Ganymede.Lexer;

{$I Ganymede.Defines.inc}

interface

uses
  System.SysUtils,
  System.Generics.Collections,
  Ganymede.Utils,
  Ganymede.Resources;

type
  { TGnyScriptTokenKind }
  TGnyScriptTokenKind = (
    // Keywords — Module structure
    tkModule, tkImport, tkPublic, tkExternal,

    // Keywords — Block / Control flow
    tkBegin, tkEnd, tkIf, tkThen, tkElse,
    tkWhile, tkDo, tkFor, tkTo, tkDownto,
    tkRepeat, tkUntil, tkReturn, tkMatch,
    tkLeave, tkSkip,

    // Keywords — Declarations
    tkVar, tkConst, tkType, tkRoutine, tkMethod,

    // Keywords — Type definitions
    tkRecord, tkObject, tkOverlay, tkChoices,
    tkPacked, tkAlign, tkArray, tkOf, tkSet, tkPointer,

    // Keywords — Logical / bitwise operators
    tkAnd, tkOr, tkNot, tkXor,
    tkDiv, tkMod, tkShl, tkShr, tkIn, tkIs,

    // Keywords — Literals
    tkTrue, tkFalse, tkNil,

    // Keywords — Pointer / Address
    tkAddress,

    // Keywords — Self / Parent
    tkSelf, tkParent,

    // Keywords — Exception handling
    tkGuard, tkExcept, tkFinally,
    tkRaiseException, tkRaiseExceptionCode,
    tkGetExceptionCode, tkGetExceptionMessage,

    // Keywords — Memory management
    tkCreate, tkDestroy,
    tkGetMem, tkFreeMem, tkResizeMem, tkSetLength,

    // Keywords — I/O
    tkWrite, tkWriteLn,

    // Keywords — Intrinsics
    tkLen, tkSize, tkUtf8, tkParamCount, tkParamStr,

    // Keywords — Variadic
    tkVarArgs,

    // Keywords — Contextual (module kind)
    tkDll, tkLib, tkMem,

    // Keywords — Linkage
    tkCppLink,

    // Built-in type keywords
    tkInt8, tkInt16, tkInt32, tkInt64,
    tkUInt8, tkUInt16, tkUInt32, tkUInt64,
    tkFloat32, tkFloat64,
    tkBoolean, tkChar, tkWChar,
    tkString, tkWString,

    // Test keywords
    tkTest, tkTestAssert, tkTestAssertTrue, tkTestAssertFalse,
    tkTestAssertEqualInt, tkTestAssertEqualUInt, tkTestAssertEqualFloat,
    tkTestAssertEqualStr, tkTestAssertEqualBool, tkTestAssertEqualPtr,
    tkTestAssertNil, tkTestAssertNotNil, tkTestFail,

    // Multi-char operators
    tkAssign,       // :=
    tkPlusAssign,   // +=
    tkMinusAssign,  // -=
    tkMulAssign,    // *=
    tkDivAssign,    // /=
    tkNotEq,        // <>
    tkLtEq,         // <=
    tkGtEq,         // >=
    tkEllipsis,     // ...
    tkRange,        // ..

    // Single-char operators
    tkEq,           // =
    tkLt,           // <
    tkGt,           // >
    tkPlus,         // +
    tkMinus,        // -
    tkStar,         // *
    tkSlash,        // /
    tkCaret,        // ^
    tkPipe,         // |
    tkAmpersand,    // &

    // Delimiters
    tkLParen,       // (
    tkRParen,       // )
    tkLBracket,     // [
    tkRBracket,     // ]
    tkComma,        // ,
    tkColon,        // :
    tkSemicolon,    // ;
    tkDot,          // .

    // Literals
    tkIntLit,
    tkHexLit,
    tkFloatLit,
    tkStringLit,
    tkWStringLit,

    // Directive
    tkDirective,

    // Identifier
    tkIdent,

    // End of file
    tkEOF
  );

  { TGnyScriptToken }
  TGnyScriptToken = record
    Kind: TGnyScriptTokenKind;
    Text: string;
    Range: TGnySourceRange;
  end;

  { TGnyScriptLexer }
  TGnyScriptLexer = class(TGnyBaseObject)
  private
    // Source state
    FSource: string;
    FSourceLen: Integer;
    FPos: Integer;
    FLine: Integer;
    FCol: Integer;
    FFilename: string;

    // Token output
    FTokens: TList<TGnyScriptToken>;

    // Keyword lookup
    FKeywords: TDictionary<string, TGnyScriptTokenKind>;

    // Initialization
    procedure InitKeywords();

    // Character access
    function Peek(): Char;
    function PeekAt(const AOffset: Integer): Char;
    function IsAtEnd(): Boolean;
    function Advance(): Char;

    // Whitespace and comments
    procedure SkipWhitespace();
    function SkipLineComment(): Boolean;
    function SkipBlockComment(): Boolean;

    // Scanners
    function ScanIdentOrKeyword(): Boolean;
    function ScanNumber(): Boolean;
    function ScanString(): Boolean;
    function ScanWideString(): Boolean;
    function ScanEscapeChar(var AResult: string): Boolean;
    function ScanDirective(): Boolean;
    function ScanOperatorOrDelimiter(): Boolean;

    // Helpers
    function MakeRange(const AStartLine, AStartCol, AStartPos: Integer): TGnySourceRange;
    procedure EmitToken(const AKind: TGnyScriptTokenKind; const AText: string;
      const ARange: TGnySourceRange);

  public
    constructor Create(); override;
    destructor Destroy(); override;

    // Main entry point — tokenizes source, returns True if no errors
    function Tokenize(const ASource: string; const AFilename: string = ''): Boolean;

    // Token access for parser
    function GetTokenCount(): Integer;
    function GetToken(const AIndex: Integer): TGnyScriptToken;
    property Tokens: TList<TGnyScriptToken> read FTokens;
  end;

const
  //--------------------------------------------------------------------------
  // Script Lexer Error Codes
  //--------------------------------------------------------------------------
  GNY_ERROR_SCRIPT_UNEXPECTED_CHAR      = 'SL0001';
  GNY_ERROR_SCRIPT_UNTERMINATED_STRING   = 'SL0002';
  GNY_ERROR_SCRIPT_UNTERMINATED_COMMENT  = 'SL0003';
  GNY_ERROR_SCRIPT_INVALID_ESCAPE        = 'SL0004';
  GNY_ERROR_SCRIPT_INVALID_HEX           = 'SL0005';
  GNY_ERROR_SCRIPT_INVALID_NUMBER        = 'SL0006';
  GNY_ERROR_SCRIPT_INVALID_DIRECTIVE     = 'SL0007';

implementation

{ TGnyScriptLexer }

constructor TGnyScriptLexer.Create();
begin
  inherited Create();
  try
    FTokens := TList<TGnyScriptToken>.Create();
    FKeywords := TDictionary<string, TGnyScriptTokenKind>.Create();
  except
    on E: Exception do
    begin
      FErrors.Add(esFatal, '', RSFatalInternalError, [E.Message]);
      Exit;
    end;
  end;
  InitKeywords();
end;

destructor TGnyScriptLexer.Destroy();
begin
  FKeywords.Free();
  FTokens.Free();
  inherited Destroy();
end;

procedure TGnyScriptLexer.InitKeywords();
begin
  // Module structure
  FKeywords.Add('module', tkModule);
  FKeywords.Add('import', tkImport);
  FKeywords.Add('public', tkPublic);
  FKeywords.Add('external', tkExternal);

  // Block / Control flow
  FKeywords.Add('begin', tkBegin);
  FKeywords.Add('end', tkEnd);
  FKeywords.Add('if', tkIf);
  FKeywords.Add('then', tkThen);
  FKeywords.Add('else', tkElse);
  FKeywords.Add('while', tkWhile);
  FKeywords.Add('do', tkDo);
  FKeywords.Add('for', tkFor);
  FKeywords.Add('to', tkTo);
  FKeywords.Add('downto', tkDownto);
  FKeywords.Add('repeat', tkRepeat);
  FKeywords.Add('until', tkUntil);
  FKeywords.Add('return', tkReturn);
  FKeywords.Add('match', tkMatch);
  FKeywords.Add('leave', tkLeave);
  FKeywords.Add('skip', tkSkip);

  // Declarations
  FKeywords.Add('var', tkVar);
  FKeywords.Add('const', tkConst);
  FKeywords.Add('type', tkType);
  FKeywords.Add('routine', tkRoutine);
  FKeywords.Add('method', tkMethod);

  // Type definitions
  FKeywords.Add('record', tkRecord);
  FKeywords.Add('object', tkObject);
  FKeywords.Add('overlay', tkOverlay);
  FKeywords.Add('choices', tkChoices);
  FKeywords.Add('packed', tkPacked);
  FKeywords.Add('align', tkAlign);
  FKeywords.Add('array', tkArray);
  FKeywords.Add('of', tkOf);
  FKeywords.Add('set', tkSet);
  FKeywords.Add('pointer', tkPointer);

  // Logical / bitwise operators
  FKeywords.Add('and', tkAnd);
  FKeywords.Add('or', tkOr);
  FKeywords.Add('not', tkNot);
  FKeywords.Add('xor', tkXor);
  FKeywords.Add('div', tkDiv);
  FKeywords.Add('mod', tkMod);
  FKeywords.Add('shl', tkShl);
  FKeywords.Add('shr', tkShr);
  FKeywords.Add('in', tkIn);
  FKeywords.Add('is', tkIs);

  // Literals
  FKeywords.Add('true', tkTrue);
  FKeywords.Add('false', tkFalse);
  FKeywords.Add('nil', tkNil);

  // Pointer / Address
  FKeywords.Add('address', tkAddress);

  // Self / Parent
  FKeywords.Add('self', tkSelf);
  FKeywords.Add('parent', tkParent);

  // Exception handling
  FKeywords.Add('guard', tkGuard);
  FKeywords.Add('except', tkExcept);
  FKeywords.Add('finally', tkFinally);
  FKeywords.Add('raiseexception', tkRaiseException);
  FKeywords.Add('raiseexceptioncode', tkRaiseExceptionCode);
  FKeywords.Add('getexceptioncode', tkGetExceptionCode);
  FKeywords.Add('getexceptionmessage', tkGetExceptionMessage);

  // Memory management
  FKeywords.Add('create', tkCreate);
  FKeywords.Add('destroy', tkDestroy);
  FKeywords.Add('getmem', tkGetMem);
  FKeywords.Add('freemem', tkFreeMem);
  FKeywords.Add('resizemem', tkResizeMem);
  FKeywords.Add('setlength', tkSetLength);

  // I/O
  FKeywords.Add('write', tkWrite);
  FKeywords.Add('writeln', tkWriteLn);

  // Intrinsics
  FKeywords.Add('len', tkLen);
  FKeywords.Add('size', tkSize);
  FKeywords.Add('utf8', tkUtf8);
  FKeywords.Add('paramcount', tkParamCount);
  FKeywords.Add('paramstr', tkParamStr);

  // Variadic
  FKeywords.Add('varargs', tkVarArgs);

  // Contextual (module kind)
  FKeywords.Add('dll', tkDll);
  FKeywords.Add('lib', tkLib);
  FKeywords.Add('mem', tkMem);

  // Linkage
  FKeywords.Add('cpplink', tkCppLink);

  // Built-in type keywords
  FKeywords.Add('int8', tkInt8);
  FKeywords.Add('int16', tkInt16);
  FKeywords.Add('int32', tkInt32);
  FKeywords.Add('int64', tkInt64);
  FKeywords.Add('uint8', tkUInt8);
  FKeywords.Add('uint16', tkUInt16);
  FKeywords.Add('uint32', tkUInt32);
  FKeywords.Add('uint64', tkUInt64);
  FKeywords.Add('float32', tkFloat32);
  FKeywords.Add('float64', tkFloat64);
  FKeywords.Add('boolean', tkBoolean);
  FKeywords.Add('char', tkChar);
  FKeywords.Add('wchar', tkWChar);
  FKeywords.Add('string', tkString);
  FKeywords.Add('wstring', tkWString);

  // Test keywords (case-sensitive camelCase)
  FKeywords.Add('test', tkTest);
  FKeywords.Add('testAssert', tkTestAssert);
  FKeywords.Add('testAssertTrue', tkTestAssertTrue);
  FKeywords.Add('testAssertFalse', tkTestAssertFalse);
  FKeywords.Add('testAssertEqualInt', tkTestAssertEqualInt);
  FKeywords.Add('testAssertEqualUInt', tkTestAssertEqualUInt);
  FKeywords.Add('testAssertEqualFloat', tkTestAssertEqualFloat);
  FKeywords.Add('testAssertEqualStr', tkTestAssertEqualStr);
  FKeywords.Add('testAssertEqualBool', tkTestAssertEqualBool);
  FKeywords.Add('testAssertEqualPtr', tkTestAssertEqualPtr);
  FKeywords.Add('testAssertNil', tkTestAssertNil);
  FKeywords.Add('testAssertNotNil', tkTestAssertNotNil);
  FKeywords.Add('testFail', tkTestFail);
end;

//------------------------------------------------------------------------------
// Character access
//------------------------------------------------------------------------------

function TGnyScriptLexer.Peek(): Char;
begin
  if FPos <= FSourceLen then
    Result := FSource[FPos]
  else
    Result := #0;
end;

function TGnyScriptLexer.PeekAt(const AOffset: Integer): Char;
var
  LIdx: Integer;
begin
  LIdx := FPos + AOffset;
  if (LIdx >= 1) and (LIdx <= FSourceLen) then
    Result := FSource[LIdx]
  else
    Result := #0;
end;

function TGnyScriptLexer.IsAtEnd(): Boolean;
begin
  Result := FPos > FSourceLen;
end;

function TGnyScriptLexer.Advance(): Char;
begin
  Result := Peek();
  if Result = #10 then
  begin
    Inc(FLine);
    FCol := 1;
  end
  else
    Inc(FCol);
  Inc(FPos);
end;

//------------------------------------------------------------------------------
// Helpers
//------------------------------------------------------------------------------

function TGnyScriptLexer.MakeRange(const AStartLine, AStartCol,
  AStartPos: Integer): TGnySourceRange;
begin
  Result := Default(TGnySourceRange);
  Result.Filename := FFilename;
  Result.StartLine := AStartLine;
  Result.StartColumn := AStartCol;
  Result.EndLine := FLine;
  Result.EndColumn := FCol;
  Result.StartByteOffset := AStartPos;
  Result.EndByteOffset := FPos;
end;

procedure TGnyScriptLexer.EmitToken(const AKind: TGnyScriptTokenKind;
  const AText: string; const ARange: TGnySourceRange);
var
  LToken: TGnyScriptToken;
begin
  LToken := Default(TGnyScriptToken);
  LToken.Kind := AKind;
  LToken.Text := AText;
  LToken.Range := ARange;
  FTokens.Add(LToken);
end;

//------------------------------------------------------------------------------
// Whitespace and comments
//------------------------------------------------------------------------------

procedure TGnyScriptLexer.SkipWhitespace();
var
  LCh: Char;
begin
  while not IsAtEnd() do
  begin
    LCh := Peek();
    if CharInSet(LCh, [' ', #9, #13, #10]) then
      Advance()
    else
      Break;
  end;
end;

function TGnyScriptLexer.SkipLineComment(): Boolean;
begin
  Result := False;
  if (Peek() = '/') and (PeekAt(1) = '/') then
  begin
    // Consume // and everything until end of line
    Advance();
    Advance();
    while (not IsAtEnd()) and (Peek() <> #10) do
      Advance();
    Result := True;
  end;
end;

function TGnyScriptLexer.SkipBlockComment(): Boolean;
var
  LDepth: Integer;
  LStartLine: Integer;
  LStartCol: Integer;
  LStartPos: Integer;
begin
  Result := False;
  if (Peek() = '/') and (PeekAt(1) = '*') then
  begin
    LStartLine := FLine;
    LStartCol := FCol;
    LStartPos := FPos;
    Advance(); // consume /
    Advance(); // consume *
    LDepth := 1;
    while (not IsAtEnd()) and (LDepth > 0) do
    begin
      if (Peek() = '/') and (PeekAt(1) = '*') then
      begin
        Advance();
        Advance();
        Inc(LDepth);
      end
      else if (Peek() = '*') and (PeekAt(1) = '/') then
      begin
        Advance();
        Advance();
        Dec(LDepth);
      end
      else
        Advance();
    end;

    if LDepth > 0 then
      FErrors.Add(MakeRange(LStartLine, LStartCol, LStartPos), esError,
        GNY_ERROR_SCRIPT_UNTERMINATED_COMMENT, RSScriptUnterminatedComment);

    Result := True;
  end;
end;

//------------------------------------------------------------------------------
// Scanners
//------------------------------------------------------------------------------

function TGnyScriptLexer.ScanIdentOrKeyword(): Boolean;
var
  LStartLine: Integer;
  LStartCol: Integer;
  LStartPos: Integer;
  LText: string;
  LKind: TGnyScriptTokenKind;
begin
  Result := False;
  if not (CharInSet(Peek(), ['a'..'z', 'A'..'Z', '_'])) then
    Exit;

  LStartLine := FLine;
  LStartCol := FCol;
  LStartPos := FPos;

  // Consume identifier characters
  while (not IsAtEnd()) and CharInSet(Peek(), ['a'..'z', 'A'..'Z', '0'..'9', '_']) do
    Advance();

  LText := Copy(FSource, LStartPos, FPos - LStartPos);

  // Check keyword dictionary (case-sensitive)
  if FKeywords.TryGetValue(LText, LKind) then
    EmitToken(LKind, LText, MakeRange(LStartLine, LStartCol, LStartPos))
  else
    EmitToken(tkIdent, LText, MakeRange(LStartLine, LStartCol, LStartPos));

  Result := True;
end;

function TGnyScriptLexer.ScanNumber(): Boolean;
var
  LStartLine: Integer;
  LStartCol: Integer;
  LStartPos: Integer;
  LKind: TGnyScriptTokenKind;
  LText: string;
begin
  Result := False;
  if not CharInSet(Peek(), ['0'..'9']) then
    Exit;

  LStartLine := FLine;
  LStartCol := FCol;
  LStartPos := FPos;
  LKind := tkIntLit;

  // Check for hex literal: 0x or 0X
  if (Peek() = '0') and CharInSet(PeekAt(1), ['x', 'X']) then
  begin
    Advance(); // consume 0
    Advance(); // consume x/X
    LKind := tkHexLit;

    if not CharInSet(Peek(), ['0'..'9', 'a'..'f', 'A'..'F']) then
    begin
      FErrors.Add(MakeRange(LStartLine, LStartCol, LStartPos), esError,
        GNY_ERROR_SCRIPT_INVALID_HEX, RSScriptInvalidHexLiteral);
      Exit;
    end;

    while (not IsAtEnd()) and CharInSet(Peek(), ['0'..'9', 'a'..'f', 'A'..'F']) do
      Advance();
  end
  else
  begin
    // Consume integer digits
    while (not IsAtEnd()) and CharInSet(Peek(), ['0'..'9']) do
      Advance();

    // Check for float: dot followed by digit (but NOT ".." range)
    if (Peek() = '.') and (PeekAt(1) <> '.') then
    begin
      LKind := tkFloatLit;
      Advance(); // consume .

      // Consume fractional digits
      while (not IsAtEnd()) and CharInSet(Peek(), ['0'..'9']) do
        Advance();
    end;

    // Check for exponent: e/E [+/-] digits
    if CharInSet(Peek(), ['e', 'E']) then
    begin
      LKind := tkFloatLit;
      Advance(); // consume e/E

      // Optional sign
      if CharInSet(Peek(), ['+', '-']) then
        Advance();

      if not CharInSet(Peek(), ['0'..'9']) then
      begin
        FErrors.Add(MakeRange(LStartLine, LStartCol, LStartPos), esError,
          GNY_ERROR_SCRIPT_INVALID_NUMBER, RSScriptInvalidNumberLit);
        Exit;
      end;

      while (not IsAtEnd()) and CharInSet(Peek(), ['0'..'9']) do
        Advance();
    end;

    // Check for float32 suffix: f/F
    if CharInSet(Peek(), ['f', 'F']) then
    begin
      LKind := tkFloatLit;
      Advance(); // consume f/F
    end;
  end;

  LText := Copy(FSource, LStartPos, FPos - LStartPos);
  EmitToken(LKind, LText, MakeRange(LStartLine, LStartCol, LStartPos));
  Result := True;
end;

//------------------------------------------------------------------------------
// String scanning
//------------------------------------------------------------------------------

function TGnyScriptLexer.ScanEscapeChar(var AResult: string): Boolean;
var
  LCh: Char;
  LHex: string;
  LCode: Integer;
begin
  Result := True;

  // Consume the backslash
  Advance();

  if IsAtEnd() then
  begin
    Result := False;
    Exit;
  end;

  LCh := Advance();

  if LCh = 'n' then
    AResult := AResult + #10
  else if LCh = 't' then
    AResult := AResult + #9
  else if LCh = 'r' then
    AResult := AResult + #13
  else if LCh = '0' then
    AResult := AResult + #0
  else if LCh = '\' then
    AResult := AResult + '\'
  else if LCh = '''' then
    AResult := AResult + ''''
  else if LCh = '"' then
    AResult := AResult + '"'
  else if LCh = 'x' then
  begin
    // Hex escape: \xHH
    if (not IsAtEnd()) and CharInSet(Peek(), ['0'..'9', 'a'..'f', 'A'..'F']) then
    begin
      LHex := Advance();
      if (not IsAtEnd()) and CharInSet(Peek(), ['0'..'9', 'a'..'f', 'A'..'F']) then
        LHex := LHex + Advance();
      LCode := StrToIntDef('$' + LHex, -1);
      if LCode >= 0 then
        AResult := AResult + Char(LCode)
      else
        Result := False;
    end
    else
      Result := False;
  end
  else
    Result := False;
end;

function TGnyScriptLexer.ScanString(): Boolean;
var
  LStartLine: Integer;
  LStartCol: Integer;
  LStartPos: Integer;
  LValue: string;
begin
  Result := False;
  if Peek() <> '"' then
    Exit;

  LStartLine := FLine;
  LStartCol := FCol;
  LStartPos := FPos;
  LValue := '';

  Advance(); // consume opening "

  while (not IsAtEnd()) and (Peek() <> '"') do
  begin
    if Peek() = '\' then
    begin
      if not ScanEscapeChar(LValue) then
      begin
        FErrors.Add(MakeRange(LStartLine, LStartCol, LStartPos), esError,
          GNY_ERROR_SCRIPT_INVALID_ESCAPE, RSScriptInvalidEscape,
          [FSource[FPos - 1]]);
        Exit;
      end;
    end
    else if Peek() = #10 then
    begin
      // Newlines not allowed in string literals
      FErrors.Add(MakeRange(LStartLine, LStartCol, LStartPos), esError,
        GNY_ERROR_SCRIPT_UNTERMINATED_STRING, RSScriptUnterminatedString);
      Exit;
    end
    else
      LValue := LValue + Advance();
  end;

  if IsAtEnd() then
  begin
    FErrors.Add(MakeRange(LStartLine, LStartCol, LStartPos), esError,
      GNY_ERROR_SCRIPT_UNTERMINATED_STRING, RSScriptUnterminatedString);
    Exit;
  end;

  Advance(); // consume closing "

  EmitToken(tkStringLit, LValue, MakeRange(LStartLine, LStartCol, LStartPos));
  Result := True;
end;

function TGnyScriptLexer.ScanWideString(): Boolean;
var
  LStartLine: Integer;
  LStartCol: Integer;
  LStartPos: Integer;
  LValue: string;
begin
  Result := False;

  // Wide string starts with w"
  if (Peek() <> 'w') or (PeekAt(1) <> '"') then
    Exit;

  LStartLine := FLine;
  LStartCol := FCol;
  LStartPos := FPos;
  LValue := '';

  Advance(); // consume w
  Advance(); // consume opening "

  while (not IsAtEnd()) and (Peek() <> '"') do
  begin
    if Peek() = '\' then
    begin
      if not ScanEscapeChar(LValue) then
      begin
        FErrors.Add(MakeRange(LStartLine, LStartCol, LStartPos), esError,
          GNY_ERROR_SCRIPT_INVALID_ESCAPE, RSScriptInvalidEscape,
          [FSource[FPos - 1]]);
        Exit;
      end;
    end
    else if Peek() = #10 then
    begin
      FErrors.Add(MakeRange(LStartLine, LStartCol, LStartPos), esError,
        GNY_ERROR_SCRIPT_UNTERMINATED_STRING, RSScriptUnterminatedString);
      Exit;
    end
    else
      LValue := LValue + Advance();
  end;

  if IsAtEnd() then
  begin
    FErrors.Add(MakeRange(LStartLine, LStartCol, LStartPos), esError,
      GNY_ERROR_SCRIPT_UNTERMINATED_STRING, RSScriptUnterminatedString);
    Exit;
  end;

  Advance(); // consume closing "

  EmitToken(tkWStringLit, LValue, MakeRange(LStartLine, LStartCol, LStartPos));
  Result := True;
end;

//------------------------------------------------------------------------------
// Directive scanning
//------------------------------------------------------------------------------

function TGnyScriptLexer.ScanDirective(): Boolean;
var
  LStartLine: Integer;
  LStartCol: Integer;
  LStartPos: Integer;
  LName: string;
begin
  Result := False;
  if Peek() <> '@' then
    Exit;

  LStartLine := FLine;
  LStartCol := FCol;
  LStartPos := FPos;

  Advance(); // consume @

  // Directive name must start with a letter
  if (not IsAtEnd()) and CharInSet(Peek(), ['a'..'z', 'A'..'Z', '_']) then
  begin
    while (not IsAtEnd()) and CharInSet(Peek(), ['a'..'z', 'A'..'Z', '0'..'9', '_']) do
      Advance();

    LName := Copy(FSource, LStartPos, FPos - LStartPos);
    EmitToken(tkDirective, LName, MakeRange(LStartLine, LStartCol, LStartPos));
    Result := True;
  end
  else
  begin
    FErrors.Add(MakeRange(LStartLine, LStartCol, LStartPos), esError,
      GNY_ERROR_SCRIPT_INVALID_DIRECTIVE, RSScriptInvalidDirective);
    Exit;
  end;
end;

//------------------------------------------------------------------------------
// Operator and delimiter scanning
//------------------------------------------------------------------------------

function TGnyScriptLexer.ScanOperatorOrDelimiter(): Boolean;
var
  LStartLine: Integer;
  LStartCol: Integer;
  LStartPos: Integer;
  LCh: Char;
  LNext: Char;
begin
  Result := True;
  LStartLine := FLine;
  LStartCol := FCol;
  LStartPos := FPos;
  LCh := Peek();
  LNext := PeekAt(1);

  // Multi-char operators (longest match first)
  if (LCh = ':') and (LNext = '=') then
  begin
    Advance(); Advance();
    EmitToken(tkAssign, ':=', MakeRange(LStartLine, LStartCol, LStartPos));
  end
  else if (LCh = '+') and (LNext = '=') then
  begin
    Advance(); Advance();
    EmitToken(tkPlusAssign, '+=', MakeRange(LStartLine, LStartCol, LStartPos));
  end
  else if (LCh = '-') and (LNext = '=') then
  begin
    Advance(); Advance();
    EmitToken(tkMinusAssign, '-=', MakeRange(LStartLine, LStartCol, LStartPos));
  end
  else if (LCh = '*') and (LNext = '=') then
  begin
    Advance(); Advance();
    EmitToken(tkMulAssign, '*=', MakeRange(LStartLine, LStartCol, LStartPos));
  end
  else if (LCh = '/') and (LNext = '=') then
  begin
    Advance(); Advance();
    EmitToken(tkDivAssign, '/=', MakeRange(LStartLine, LStartCol, LStartPos));
  end
  else if (LCh = '<') and (LNext = '>') then
  begin
    Advance(); Advance();
    EmitToken(tkNotEq, '<>', MakeRange(LStartLine, LStartCol, LStartPos));
  end
  else if (LCh = '<') and (LNext = '=') then
  begin
    Advance(); Advance();
    EmitToken(tkLtEq, '<=', MakeRange(LStartLine, LStartCol, LStartPos));
  end
  else if (LCh = '>') and (LNext = '=') then
  begin
    Advance(); Advance();
    EmitToken(tkGtEq, '>=', MakeRange(LStartLine, LStartCol, LStartPos));
  end
  else if (LCh = '.') and (LNext = '.') and (PeekAt(2) = '.') then
  begin
    Advance(); Advance(); Advance();
    EmitToken(tkEllipsis, '...', MakeRange(LStartLine, LStartCol, LStartPos));
  end
  else if (LCh = '.') and (LNext = '.') then
  begin
    Advance(); Advance();
    EmitToken(tkRange, '..', MakeRange(LStartLine, LStartCol, LStartPos));
  end

  // Single-char operators
  else if LCh = '=' then
  begin
    Advance();
    EmitToken(tkEq, '=', MakeRange(LStartLine, LStartCol, LStartPos));
  end
  else if LCh = '<' then
  begin
    Advance();
    EmitToken(tkLt, '<', MakeRange(LStartLine, LStartCol, LStartPos));
  end
  else if LCh = '>' then
  begin
    Advance();
    EmitToken(tkGt, '>', MakeRange(LStartLine, LStartCol, LStartPos));
  end
  else if LCh = '+' then
  begin
    Advance();
    EmitToken(tkPlus, '+', MakeRange(LStartLine, LStartCol, LStartPos));
  end
  else if LCh = '-' then
  begin
    Advance();
    EmitToken(tkMinus, '-', MakeRange(LStartLine, LStartCol, LStartPos));
  end
  else if LCh = '*' then
  begin
    Advance();
    EmitToken(tkStar, '*', MakeRange(LStartLine, LStartCol, LStartPos));
  end
  else if LCh = '/' then
  begin
    Advance();
    EmitToken(tkSlash, '/', MakeRange(LStartLine, LStartCol, LStartPos));
  end
  else if LCh = '^' then
  begin
    Advance();
    EmitToken(tkCaret, '^', MakeRange(LStartLine, LStartCol, LStartPos));
  end
  else if LCh = '|' then
  begin
    Advance();
    EmitToken(tkPipe, '|', MakeRange(LStartLine, LStartCol, LStartPos));
  end
  else if LCh = '&' then
  begin
    Advance();
    EmitToken(tkAmpersand, '&', MakeRange(LStartLine, LStartCol, LStartPos));
  end

  // Delimiters
  else if LCh = '(' then
  begin
    Advance();
    EmitToken(tkLParen, '(', MakeRange(LStartLine, LStartCol, LStartPos));
  end
  else if LCh = ')' then
  begin
    Advance();
    EmitToken(tkRParen, ')', MakeRange(LStartLine, LStartCol, LStartPos));
  end
  else if LCh = '[' then
  begin
    Advance();
    EmitToken(tkLBracket, '[', MakeRange(LStartLine, LStartCol, LStartPos));
  end
  else if LCh = ']' then
  begin
    Advance();
    EmitToken(tkRBracket, ']', MakeRange(LStartLine, LStartCol, LStartPos));
  end
  else if LCh = ',' then
  begin
    Advance();
    EmitToken(tkComma, ',', MakeRange(LStartLine, LStartCol, LStartPos));
  end
  else if LCh = ':' then
  begin
    Advance();
    EmitToken(tkColon, ':', MakeRange(LStartLine, LStartCol, LStartPos));
  end
  else if LCh = ';' then
  begin
    Advance();
    EmitToken(tkSemicolon, ';', MakeRange(LStartLine, LStartCol, LStartPos));
  end
  else if LCh = '.' then
  begin
    Advance();
    EmitToken(tkDot, '.', MakeRange(LStartLine, LStartCol, LStartPos));
  end
  else
    Result := False;
end;

//------------------------------------------------------------------------------
// Main tokenizer
//------------------------------------------------------------------------------

function TGnyScriptLexer.Tokenize(const ASource: string;
  const AFilename: string): Boolean;
var
  LCh: Char;
  LStartLine: Integer;
  LStartCol: Integer;
  LStartPos: Integer;
begin
  // Reset state
  FSource := ASource;
  FSourceLen := Length(FSource);
  FPos := 1;
  FLine := 1;
  FCol := 1;
  FFilename := AFilename;
  FTokens.Clear();

  Status(RSScriptLexerStatusStart, [FSourceLen]);

  // Main scan loop
  while not IsAtEnd() do
  begin
    // Skip whitespace
    SkipWhitespace();
    if IsAtEnd() then
      Break;

    // Skip comments
    if SkipLineComment() then
      Continue;
    if SkipBlockComment() then
      Continue;

    // Wide string: w" (must check before identifier since 'w' is a valid ident)
    if (Peek() = 'w') and (PeekAt(1) = '"') then
    begin
      if ScanWideString() then
        Continue;
      // Error already reported inside ScanWideString
      Break;
    end;

    // Identifiers and keywords
    if ScanIdentOrKeyword() then
      Continue;

    // Number literals
    if ScanNumber() then
      Continue;

    // String literals
    if Peek() = '"' then
    begin
      if ScanString() then
        Continue;
      // Error already reported inside ScanString
      Break;
    end;

    // Directives
    if Peek() = '@' then
    begin
      if ScanDirective() then
        Continue;
      // Error already reported inside ScanDirective
      Break;
    end;

    // Operators and delimiters
    if ScanOperatorOrDelimiter() then
      Continue;

    // Unexpected character
    LStartLine := FLine;
    LStartCol := FCol;
    LStartPos := FPos;
    LCh := Advance();
    FErrors.Add(MakeRange(LStartLine, LStartCol, LStartPos), esError,
      GNY_ERROR_SCRIPT_UNEXPECTED_CHAR, RSScriptUnexpectedChar, [LCh]);
  end;

  // Emit EOF token
  EmitToken(tkEOF, '', MakeRange(FLine, FCol, FPos));

  Status(RSScriptLexerStatusComplete, [FTokens.Count, FErrors.ErrorCount()]);

  Result := FErrors.ErrorCount() = 0;
end;

//------------------------------------------------------------------------------
// Token access
//------------------------------------------------------------------------------

function TGnyScriptLexer.GetTokenCount(): Integer;
begin
  Result := FTokens.Count;
end;

function TGnyScriptLexer.GetToken(const AIndex: Integer): TGnyScriptToken;
begin
  Result := FTokens[AIndex];
end;

end.
