{===============================================================================
  Ganymede™ - Embeddable Native Scripting Engine

  Copyright © 2026-present tinyBigGAMES™ LLC
  All Rights Reserved.

  See LICENSE for license information
===============================================================================}

unit Ganymede.ABI;

{$I Ganymede.Defines.inc}

interface

uses
  System.SysUtils,
  System.Generics.Collections,
  Ganymede.Types;

type
  //============================================================================
  // TABIMangler - Itanium C++ ABI name mangling
  //============================================================================
  TABIMangler = class
  private
    class function EncodeName(const AName: string): string;
    class function EncodeNestedName(const AComponents: array of string): string;
  public
    class function ManglePrimitiveType(const AType: TGnyValueType): string;
    class function ManglePointerType(const APointeeType: TGnyValueType;
      const AIsConst: Boolean = False): string;
    class function MangleFunction(
      const AName: string;
      const AParams: TArray<TGnyValueType>): string;
    class function MangleNestedFunction(
      const AComponents: array of string;
      const AParams: TArray<TGnyValueType>): string;
    class function MangleFunctionWithLinkage(
      const AName: string;
      const AParams: TArray<TGnyValueType>;
      const ALinkage: TLinkage): string;
    class function MangleNestedFunctionWithLinkage(
      const AComponents: array of string;
      const AParams: TArray<TGnyValueType>;
      const ALinkage: TLinkage): string;
    class function Demangle(const AMangled: string): string;
    class function IsMangled(const AName: string): Boolean;
  end;

implementation

//==============================================================================
// TABIMangler - Private Helpers
//==============================================================================

class function TABIMangler.EncodeName(const AName: string): string;
begin
  Result := IntToStr(Length(AName)) + AName;
end;

class function TABIMangler.EncodeNestedName(const AComponents: array of string): string;
var
  LI: Integer;
begin
  Result := 'N';
  for LI := Low(AComponents) to High(AComponents) do
    Result := Result + EncodeName(AComponents[LI]);
  Result := Result + 'E';
end;

//==============================================================================
// TABIMangler - Type Mangling
//==============================================================================

class function TABIMangler.ManglePrimitiveType(const AType: TGnyValueType): string;
begin
  case AType of
    gvtVoid:    Result := 'v';
    gvtInt8:    Result := 'a';
    gvtInt16:   Result := 's';
    gvtInt32:   Result := 'i';
    gvtInt64:   Result := 'x';
    gvtUInt8:   Result := 'h';
    gvtUInt16:  Result := 't';
    gvtUInt32:  Result := 'j';
    gvtUInt64:  Result := 'y';
    gvtFloat32: Result := 'f';
    gvtFloat64: Result := 'd';
    gvtPointer: Result := 'Pv';
  else
    Result := 'v';
  end;
end;

class function TABIMangler.ManglePointerType(const APointeeType: TGnyValueType;
  const AIsConst: Boolean): string;
begin
  if AIsConst then
    Result := 'PK' + ManglePrimitiveType(APointeeType)
  else
    Result := 'P' + ManglePrimitiveType(APointeeType);
end;

//==============================================================================
// TABIMangler - Function Mangling
//==============================================================================

class function TABIMangler.MangleFunction(
  const AName: string;
  const AParams: TArray<TGnyValueType>): string;
var
  LI: Integer;
begin
  Result := '_Z' + EncodeName(AName);

  if Length(AParams) = 0 then
    Result := Result + 'v'
  else
  begin
    for LI := 0 to High(AParams) do
      Result := Result + ManglePrimitiveType(AParams[LI]);
  end;
end;

class function TABIMangler.MangleNestedFunction(
  const AComponents: array of string;
  const AParams: TArray<TGnyValueType>): string;
var
  LI: Integer;
begin
  Result := '_Z' + EncodeNestedName(AComponents);

  if Length(AParams) = 0 then
    Result := Result + 'v'
  else
  begin
    for LI := 0 to High(AParams) do
      Result := Result + ManglePrimitiveType(AParams[LI]);
  end;
end;

class function TABIMangler.MangleFunctionWithLinkage(
  const AName: string;
  const AParams: TArray<TGnyValueType>;
  const ALinkage: TLinkage): string;
begin
  if ALinkage = plC then
    Result := AName
  else
    Result := MangleFunction(AName, AParams);
end;

class function TABIMangler.MangleNestedFunctionWithLinkage(
  const AComponents: array of string;
  const AParams: TArray<TGnyValueType>;
  const ALinkage: TLinkage): string;
begin
  if ALinkage = plC then
  begin
    if Length(AComponents) > 0 then
      Result := AComponents[High(AComponents)]
    else
      Result := '';
  end
  else
    Result := MangleNestedFunction(AComponents, AParams);
end;

//==============================================================================
// TABIMangler - Demangling
//==============================================================================

class function TABIMangler.IsMangled(const AName: string): Boolean;
begin
  Result := (Length(AName) >= 2) and (AName[1] = '_') and (AName[2] = 'Z');
end;

class function TABIMangler.Demangle(const AMangled: string): string;
var
  LPos: Integer;
  LName: string;
  LParams: string;
  LComponents: TList<string>;
  LI: Integer;

  function ParseLength(var APos: Integer): Integer;
  var
    LStart: Integer;
  begin
    LStart := APos;
    while (APos <= Length(AMangled)) and (AMangled[APos] >= '0') and (AMangled[APos] <= '9') do
      Inc(APos);
    if APos = LStart then
      Result := 0
    else
      Result := StrToIntDef(Copy(AMangled, LStart, APos - LStart), 0);
  end;

  function ParseName(var APos: Integer): string;
  var
    LNameLen: Integer;
  begin
    LNameLen := ParseLength(APos);
    if LNameLen > 0 then
    begin
      Result := Copy(AMangled, APos, LNameLen);
      Inc(APos, LNameLen);
    end
    else
      Result := '';
  end;

  function DemangleType(var APos: Integer): string;
  var
    LIsPointer: Boolean;
    LIsConst: Boolean;
  begin
    Result := '';
    if APos > Length(AMangled) then
      Exit;

    LIsPointer := False;
    LIsConst := False;

    if AMangled[APos] = 'P' then
    begin
      LIsPointer := True;
      Inc(APos);
      if (APos <= Length(AMangled)) and (AMangled[APos] = 'K') then
      begin
        LIsConst := True;
        Inc(APos);
      end;
    end;

    if APos > Length(AMangled) then
      Exit;

    case AMangled[APos] of
      'v': Result := 'void';
      'a': Result := 'int8';
      'h': Result := 'uint8';
      's': Result := 'int16';
      't': Result := 'uint16';
      'i': Result := 'int32';
      'j': Result := 'uint32';
      'x': Result := 'int64';
      'y': Result := 'uint64';
      'f': Result := 'float32';
      'd': Result := 'float64';
      'b': Result := 'boolean';
    else
      Result := '?';
    end;
    Inc(APos);

    if LIsPointer then
    begin
      if LIsConst then
        Result := 'pointer to const ' + Result
      else
        Result := 'pointer to ' + Result;
    end;
  end;

begin
  if not IsMangled(AMangled) then
  begin
    Result := AMangled;
    Exit;
  end;

  LComponents := TList<string>.Create();
  try
    LPos := 3;

    if (LPos <= Length(AMangled)) and (AMangled[LPos] = 'N') then
    begin
      Inc(LPos);
      while (LPos <= Length(AMangled)) and (AMangled[LPos] <> 'E') do
      begin
        LName := ParseName(LPos);
        if LName <> '' then
          LComponents.Add(LName);
      end;
      if (LPos <= Length(AMangled)) and (AMangled[LPos] = 'E') then
        Inc(LPos);
    end
    else
    begin
      LName := ParseName(LPos);
      if LName <> '' then
        LComponents.Add(LName);
    end;

    if LComponents.Count > 0 then
    begin
      Result := LComponents[0];
      for LI := 1 to LComponents.Count - 1 do
        Result := Result + '.' + LComponents[LI];
    end
    else
      Result := '?';

    LParams := '';
    while LPos <= Length(AMangled) do
    begin
      LName := DemangleType(LPos);
      if LName = 'void' then
      begin
        if LParams = '' then
          Break;
      end;
      if LParams <> '' then
        LParams := LParams + ', ';
      LParams := LParams + LName;
    end;

    Result := Result + '(' + LParams + ')';
  finally
    LComponents.Free();
  end;
end;

end.
