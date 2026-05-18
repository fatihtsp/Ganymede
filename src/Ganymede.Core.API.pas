{===============================================================================
  Ganymede™ - Embeddable Native Scripting Engine

  Copyright © 2026-present tinyBigGAMES™ LLC
  All Rights Reserved.

  See LICENSE for license information
===============================================================================}

unit Ganymede.Core.API;

{$I Ganymede.Defines.inc}

interface

uses
  System.SysUtils,
  System.Classes,
  System.Generics.Collections,
  Ganymede.Utils,
  Ganymede.Core;

type
  { TGnyApiStatusHandler — cdecl callback for status messages }
  TGnyApiStatusHandler = procedure(const AText: PAnsiChar;
    const AUserData: Pointer); cdecl;

  { TGnyAPI — wrapper around TGanymede with API-specific state }
  TGnyAPI = class(TGnyBaseObject)
  public
    FCore: TGanymede;
    FArgs: TList<TGnyValue>;
    constructor Create(); override;
    destructor Destroy(); override;
    procedure PushArg(const AValue: TGnyValue);
  end;

//------------------------------------------------------------------------------
// Lifecycle
//------------------------------------------------------------------------------
function  gny_create(): Pointer; cdecl;
  exports gny_create;
procedure gny_destroy(const AEngine: Pointer); cdecl;
  exports gny_destroy;
function  gny_version(): PAnsiChar; cdecl;
  exports gny_version;
procedure gny_free(const APtr: PAnsiChar); cdecl;
  exports gny_free;

//------------------------------------------------------------------------------
// Source Loading
//------------------------------------------------------------------------------
procedure gny_load_from_string(const AEngine: Pointer;
  const ASource: PAnsiChar; const AFilename: PAnsiChar); cdecl;
  exports gny_load_from_string;
procedure gny_load_from_file(const AEngine: Pointer;
  const AFilename: PAnsiChar); cdecl;
  exports gny_load_from_file;

//------------------------------------------------------------------------------
// Compilation
//------------------------------------------------------------------------------
function gny_compile(const AEngine: Pointer): Boolean; cdecl;
  exports gny_compile;

//------------------------------------------------------------------------------
// Host Interop
//------------------------------------------------------------------------------
procedure gny_import_host(const AEngine: Pointer;
  const AName: PAnsiChar; const AAddr: Pointer;
  const AParamTypes: PInteger; const AParamCount: Integer;
  const AReturn: Integer; const ALinkage: Integer); cdecl;
  exports gny_import_host;

//------------------------------------------------------------------------------
// Argument Building
//------------------------------------------------------------------------------
procedure gny_arg_clear(const AEngine: Pointer); cdecl;
  exports gny_arg_clear;
procedure gny_arg_push_int8(const AEngine: Pointer; const AValue: Int8); cdecl;
  exports gny_arg_push_int8;
procedure gny_arg_push_int16(const AEngine: Pointer; const AValue: Int16); cdecl;
  exports gny_arg_push_int16;
procedure gny_arg_push_int32(const AEngine: Pointer; const AValue: Int32); cdecl;
  exports gny_arg_push_int32;
procedure gny_arg_push_int64(const AEngine: Pointer; const AValue: Int64); cdecl;
  exports gny_arg_push_int64;
procedure gny_arg_push_uint8(const AEngine: Pointer; const AValue: UInt8); cdecl;
  exports gny_arg_push_uint8;
procedure gny_arg_push_uint16(const AEngine: Pointer; const AValue: UInt16); cdecl;
  exports gny_arg_push_uint16;
procedure gny_arg_push_uint32(const AEngine: Pointer; const AValue: UInt32); cdecl;
  exports gny_arg_push_uint32;
procedure gny_arg_push_uint64(const AEngine: Pointer; const AValue: UInt64); cdecl;
  exports gny_arg_push_uint64;
procedure gny_arg_push_float32(const AEngine: Pointer; const AValue: Single); cdecl;
  exports gny_arg_push_float32;
procedure gny_arg_push_float64(const AEngine: Pointer; const AValue: Double); cdecl;
  exports gny_arg_push_float64;
procedure gny_arg_push_pointer(const AEngine: Pointer; const AValue: Pointer); cdecl;
  exports gny_arg_push_pointer;

//------------------------------------------------------------------------------
// Invocation — consumes pushed args, auto-clears after call
//------------------------------------------------------------------------------
function gny_invoke(const AEngine: Pointer; const AName: PAnsiChar;
  const AReturnType: Integer): TGnyValue; cdecl;
  exports gny_invoke;

//------------------------------------------------------------------------------
// Symbols
//------------------------------------------------------------------------------
function  gny_get_symbol(const AEngine: Pointer;
  const AName: PAnsiChar): Pointer; cdecl;
  exports gny_get_symbol;
function  gny_has_symbol(const AEngine: Pointer;
  const AName: PAnsiChar): Boolean; cdecl;
  exports gny_has_symbol;
function  gny_get_symbol_names(const AEngine: Pointer): PAnsiChar; cdecl;
  exports gny_get_symbol_names;

//------------------------------------------------------------------------------
// Configuration
//------------------------------------------------------------------------------
procedure gny_set_output_path(const AEngine: Pointer;
  const APath: PAnsiChar); cdecl;
  exports gny_set_output_path;
procedure gny_add_lib_path(const AEngine: Pointer;
  const APath: PAnsiChar); cdecl;
  exports gny_add_lib_path;
procedure gny_set_optimization_level(const AEngine: Pointer;
  const ALevel: Integer); cdecl;
  exports gny_set_optimization_level;
function  gny_get_optimization_level(const AEngine: Pointer): Integer; cdecl;
  exports gny_get_optimization_level;
procedure gny_set_dump_ir(const AEngine: Pointer;
  const AValue: Boolean); cdecl;
  exports gny_set_dump_ir;
function  gny_get_ssa_dump(const AEngine: Pointer): PAnsiChar; cdecl;
  exports gny_get_ssa_dump;

//------------------------------------------------------------------------------
// Conditional Compilation
//------------------------------------------------------------------------------
procedure gny_set_define(const AEngine: Pointer;
  const AName: PAnsiChar; const AValue: PAnsiChar); cdecl;
  exports gny_set_define;
procedure gny_undefine(const AEngine: Pointer;
  const AName: PAnsiChar); cdecl;
  exports gny_undefine;
function  gny_is_defined(const AEngine: Pointer;
  const AName: PAnsiChar): Boolean; cdecl;
  exports gny_is_defined;

//------------------------------------------------------------------------------
// Error Reporting
//------------------------------------------------------------------------------
procedure gny_print_errors(const AEngine: Pointer); cdecl;
  exports gny_print_errors;
function  gny_get_errors(const AEngine: Pointer): PAnsiChar; cdecl;
  exports gny_get_errors;
function  gny_has_errors(const AEngine: Pointer): Boolean; cdecl;
  exports gny_has_errors;

//------------------------------------------------------------------------------
// Status Callback
//------------------------------------------------------------------------------
procedure gny_set_status_callback(const AEngine: Pointer;
  const ACallback: TGnyApiStatusHandler;
  const AUserData: Pointer); cdecl;
  exports gny_set_status_callback;

//------------------------------------------------------------------------------
// Debug
//------------------------------------------------------------------------------
procedure gny_report_leaks(const AEngine: Pointer); cdecl;
  exports gny_report_leaks;

implementation

var
  FVersionStr: UTF8String;

{ UTF-8 helpers }

function AllocUtf8(const AStr: string): PAnsiChar;
var
  LUtf8: UTF8String;
  LLen: Integer;
begin
  LUtf8 := UTF8String(AStr);
  LLen := Length(LUtf8);
  GetMem(Result, LLen + 1);
  if LLen > 0 then
    Move(LUtf8[1], Result^, LLen);
  Result[LLen] := #0;
end;

function Utf8ToStr(const APtr: PAnsiChar): string;
begin
  if APtr = nil then
    Result := ''
  else
    Result := string(UTF8String(APtr));
end;

{ Error serialization }

function ErrorsToJson(const AEngine: TGanymede): string;
var
  LErrors: TGnyErrors;
  LItems: TList<TGnyError>;
  LSB: TStringBuilder;
  LI: Integer;
  LErr: TGnyError;
  LSev: string;
begin
  LErrors := AEngine.GetErrors();
  LItems := LErrors.GetItems();
  LSB := TStringBuilder.Create();
  try
    LSB.Append('[');
    for LI := 0 to LItems.Count - 1 do
    begin
      LErr := LItems[LI];
      if LI > 0 then
        LSB.Append(',');
      if LErr.Severity = esHint then
        LSev := 'hint'
      else if LErr.Severity = esWarning then
        LSev := 'warning'
      else if LErr.Severity = esError then
        LSev := 'error'
      else if LErr.Severity = esFatal then
        LSev := 'fatal'
      else
        LSev := 'unknown';
      LSB.Append('{"severity":"');
      LSB.Append(LSev);
      LSB.Append('","code":"');
      LSB.Append(LErr.Code);
      LSB.Append('","message":"');
      LSB.Append(StringReplace(
        StringReplace(LErr.Message, '\', '\\', [rfReplaceAll]),
        '"', '\"', [rfReplaceAll]));
      if not LErr.Range.IsEmpty() then
      begin
        LSB.Append('","location":"');
        LSB.Append(StringReplace(LErr.Range.ToPointString(),
          '"', '\"', [rfReplaceAll]));
      end;
      LSB.Append('"}');
    end;
    LSB.Append(']');
    Result := LSB.ToString();
  finally
    FreeAndNil(LSB);
  end;
end;

{ TGnyAPI }

constructor TGnyAPI.Create();
begin
  inherited;
  FCore := TGanymede.Create();
  FArgs := TList<TGnyValue>.Create();
end;

destructor TGnyAPI.Destroy();
begin
  FreeAndNil(FArgs);
  FreeAndNil(FCore);
  inherited;
end;

procedure TGnyAPI.PushArg(const AValue: TGnyValue);
begin
  FArgs.Add(AValue);
end;

{ Lifecycle }

function gny_create(): Pointer;
begin
  Result := TGnyAPI.Create();
end;

procedure gny_destroy(const AEngine: Pointer);
begin
  if AEngine <> nil then
    TGnyAPI(AEngine).Free();
end;

function gny_version(): PAnsiChar;
begin
  Result := PAnsiChar(FVersionStr);
end;

procedure gny_free(const APtr: PAnsiChar);
begin
  if APtr <> nil then
    FreeMem(Pointer(APtr));
end;

{ Source Loading }

procedure gny_load_from_string(const AEngine: Pointer;
  const ASource: PAnsiChar; const AFilename: PAnsiChar);
begin
  TGnyAPI(AEngine).FCore.LoadFromString(
    Utf8ToStr(ASource), Utf8ToStr(AFilename));
end;

procedure gny_load_from_file(const AEngine: Pointer;
  const AFilename: PAnsiChar);
begin
  TGnyAPI(AEngine).FCore.LoadFromFile(Utf8ToStr(AFilename));
end;

{ Compilation }

function gny_compile(const AEngine: Pointer): Boolean;
begin
  Result := TGnyAPI(AEngine).FCore.Compile();
end;

{ Host Interop }

procedure gny_import_host(const AEngine: Pointer;
  const AName: PAnsiChar; const AAddr: Pointer;
  const AParamTypes: PInteger; const AParamCount: Integer;
  const AReturn: Integer; const ALinkage: Integer);
var
  LParams: array of TGnyValueType;
  LI: Integer;
  LPtr: PInteger;
begin
  SetLength(LParams, AParamCount);
  LPtr := AParamTypes;
  for LI := 0 to AParamCount - 1 do
  begin
    LParams[LI] := TGnyValueType(LPtr^);
    Inc(LPtr);
  end;
  TGnyAPI(AEngine).FCore.ImportHost(
    Utf8ToStr(AName), AAddr, LParams,
    TGnyValueType(AReturn), TGnyLinkage(ALinkage));
end;

{ Argument Building }

procedure gny_arg_clear(const AEngine: Pointer);
begin
  TGnyAPI(AEngine).FArgs.Clear();
end;

procedure gny_arg_push_int8(const AEngine: Pointer; const AValue: Int8);
var LArg: TGnyValue;
begin
  LArg := Default(TGnyValue);
  LArg.ValueType := gvtInt8;
  LArg.AsInt8 := AValue;
  TGnyAPI(AEngine).PushArg(LArg);
end;

procedure gny_arg_push_int16(const AEngine: Pointer; const AValue: Int16);
var LArg: TGnyValue;
begin
  LArg := Default(TGnyValue);
  LArg.ValueType := gvtInt16;
  LArg.AsInt16 := AValue;
  TGnyAPI(AEngine).PushArg(LArg);
end;

procedure gny_arg_push_int32(const AEngine: Pointer; const AValue: Int32);
var LArg: TGnyValue;
begin
  LArg := Default(TGnyValue);
  LArg.ValueType := gvtInt32;
  LArg.AsInt32 := AValue;
  TGnyAPI(AEngine).PushArg(LArg);
end;

procedure gny_arg_push_int64(const AEngine: Pointer; const AValue: Int64);
var LArg: TGnyValue;
begin
  LArg := Default(TGnyValue);
  LArg.ValueType := gvtInt64;
  LArg.AsInt64 := AValue;
  TGnyAPI(AEngine).PushArg(LArg);
end;

procedure gny_arg_push_uint8(const AEngine: Pointer; const AValue: UInt8);
var LArg: TGnyValue;
begin
  LArg := Default(TGnyValue);
  LArg.ValueType := gvtUInt8;
  LArg.AsUInt8 := AValue;
  TGnyAPI(AEngine).PushArg(LArg);
end;

procedure gny_arg_push_uint16(const AEngine: Pointer; const AValue: UInt16);
var LArg: TGnyValue;
begin
  LArg := Default(TGnyValue);
  LArg.ValueType := gvtUInt16;
  LArg.AsUInt16 := AValue;
  TGnyAPI(AEngine).PushArg(LArg);
end;

procedure gny_arg_push_uint32(const AEngine: Pointer; const AValue: UInt32);
var LArg: TGnyValue;
begin
  LArg := Default(TGnyValue);
  LArg.ValueType := gvtUInt32;
  LArg.AsUInt32 := AValue;
  TGnyAPI(AEngine).PushArg(LArg);
end;

procedure gny_arg_push_uint64(const AEngine: Pointer; const AValue: UInt64);
var LArg: TGnyValue;
begin
  LArg := Default(TGnyValue);
  LArg.ValueType := gvtUInt64;
  LArg.AsUInt64 := AValue;
  TGnyAPI(AEngine).PushArg(LArg);
end;

procedure gny_arg_push_float32(const AEngine: Pointer; const AValue: Single);
var LArg: TGnyValue;
begin
  LArg := Default(TGnyValue);
  LArg.ValueType := gvtFloat32;
  LArg.AsFloat32 := AValue;
  TGnyAPI(AEngine).PushArg(LArg);
end;

procedure gny_arg_push_float64(const AEngine: Pointer; const AValue: Double);
var LArg: TGnyValue;
begin
  LArg := Default(TGnyValue);
  LArg.ValueType := gvtFloat64;
  LArg.AsFloat64 := AValue;
  TGnyAPI(AEngine).PushArg(LArg);
end;

procedure gny_arg_push_pointer(const AEngine: Pointer; const AValue: Pointer);
var LArg: TGnyValue;
begin
  LArg := Default(TGnyValue);
  LArg.ValueType := gvtPointer;
  LArg.AsPointer := AValue;
  TGnyAPI(AEngine).PushArg(LArg);
end;

{ Invocation — consumes pushed args, auto-clears after call }

function gny_invoke(const AEngine: Pointer; const AName: PAnsiChar;
  const AReturnType: Integer): TGnyValue;
var
  LAPI: TGnyAPI;
  LName: string;
  LVarRecs: array of TVarRec;
  LInt64Buf: array of Int64;
  LExtBuf: array of Extended;
  LArg: TGnyValue;
  LI: Integer;
  LInt64Idx: Integer;
  LExtIdx: Integer;
  LCount: Integer;
begin
  LAPI := TGnyAPI(AEngine);
  LName := Utf8ToStr(AName);
  LCount := LAPI.FArgs.Count;

  if LCount = 0 then
  begin
    Result := LAPI.FCore.Invoke(LName, [], TGnyValueType(AReturnType));
    Exit;
  end;

  // Convert pushed GnyValues to TVarRec array
  SetLength(LVarRecs, LCount);
  SetLength(LInt64Buf, LCount);
  SetLength(LExtBuf, LCount);
  LInt64Idx := 0;
  LExtIdx := 0;

  for LI := 0 to LCount - 1 do
  begin
    LArg := LAPI.FArgs[LI];
    case TGnyValueType(LArg.ValueType) of
      gvtInt8, gvtUInt8, gvtInt16, gvtUInt16, gvtInt32:
      begin
        LVarRecs[LI].VType := vtInteger;
        LVarRecs[LI].VInteger := LArg.AsInt32;
      end;
      gvtUInt32:
      begin
        LInt64Buf[LInt64Idx] := LArg.AsUInt32;
        LVarRecs[LI].VType := vtInt64;
        LVarRecs[LI].VInt64 := @LInt64Buf[LInt64Idx];
        Inc(LInt64Idx);
      end;
      gvtInt64:
      begin
        LInt64Buf[LInt64Idx] := LArg.AsInt64;
        LVarRecs[LI].VType := vtInt64;
        LVarRecs[LI].VInt64 := @LInt64Buf[LInt64Idx];
        Inc(LInt64Idx);
      end;
      gvtUInt64:
      begin
        LInt64Buf[LInt64Idx] := Int64(LArg.AsUInt64);
        LVarRecs[LI].VType := vtInt64;
        LVarRecs[LI].VInt64 := @LInt64Buf[LInt64Idx];
        Inc(LInt64Idx);
      end;
      gvtFloat32:
      begin
        LExtBuf[LExtIdx] := Extended(LArg.AsFloat32);
        LVarRecs[LI].VType := vtExtended;
        LVarRecs[LI].VExtended := @LExtBuf[LExtIdx];
        Inc(LExtIdx);
      end;
      gvtFloat64:
      begin
        LExtBuf[LExtIdx] := Extended(LArg.AsFloat64);
        LVarRecs[LI].VType := vtExtended;
        LVarRecs[LI].VExtended := @LExtBuf[LExtIdx];
        Inc(LExtIdx);
      end;
      gvtPointer:
      begin
        LVarRecs[LI].VType := vtPointer;
        LVarRecs[LI].VPointer := LArg.AsPointer;
      end;
    else
      LVarRecs[LI].VType := vtInteger;
      LVarRecs[LI].VInteger := 0;
    end;
  end;

  Result := LAPI.FCore.Invoke(LName, LVarRecs, TGnyValueType(AReturnType));

  // Auto-clear after invocation
  LAPI.FArgs.Clear();
end;

{ Symbols }

function gny_get_symbol(const AEngine: Pointer;
  const AName: PAnsiChar): Pointer;
begin
  Result := TGnyAPI(AEngine).FCore.GetSymbol(Utf8ToStr(AName));
end;

function gny_has_symbol(const AEngine: Pointer;
  const AName: PAnsiChar): Boolean;
begin
  Result := TGnyAPI(AEngine).FCore.HasSymbol(Utf8ToStr(AName));
end;

function gny_get_symbol_names(const AEngine: Pointer): PAnsiChar;
var
  LNames: TArray<string>;
  LSB: TStringBuilder;
  LI: Integer;
begin
  LNames := TGnyAPI(AEngine).FCore.GetSymbolNames();
  LSB := TStringBuilder.Create();
  try
    LSB.Append('[');
    for LI := 0 to Length(LNames) - 1 do
    begin
      if LI > 0 then
        LSB.Append(',');
      LSB.Append('"');
      LSB.Append(StringReplace(LNames[LI], '"', '\"', [rfReplaceAll]));
      LSB.Append('"');
    end;
    LSB.Append(']');
    Result := AllocUtf8(LSB.ToString());
  finally
    FreeAndNil(LSB);
  end;
end;

{ Configuration }

procedure gny_set_output_path(const AEngine: Pointer;
  const APath: PAnsiChar);
begin
  TGnyAPI(AEngine).FCore.SetOutputPath(Utf8ToStr(APath));
end;

procedure gny_add_lib_path(const AEngine: Pointer;
  const APath: PAnsiChar);
begin
  TGnyAPI(AEngine).FCore.AddLibPath(Utf8ToStr(APath));
end;

procedure gny_set_optimization_level(const AEngine: Pointer;
  const ALevel: Integer);
begin
  TGnyAPI(AEngine).FCore.SetOptimizationLevel(TGnyOptLevel(ALevel));
end;

function gny_get_optimization_level(const AEngine: Pointer): Integer;
begin
  Result := Ord(TGnyAPI(AEngine).FCore.GetOptimizationLevel());
end;

procedure gny_set_dump_ir(const AEngine: Pointer; const AValue: Boolean);
begin
  TGnyAPI(AEngine).FCore.SetDumpIR(AValue);
end;

function gny_get_ssa_dump(const AEngine: Pointer): PAnsiChar;
begin
  Result := AllocUtf8(TGnyAPI(AEngine).FCore.GetSSADump());
end;

{ Conditional Compilation }

procedure gny_set_define(const AEngine: Pointer;
  const AName: PAnsiChar; const AValue: PAnsiChar);
begin
  TGnyAPI(AEngine).FCore.SetDefine(Utf8ToStr(AName), Utf8ToStr(AValue));
end;

procedure gny_undefine(const AEngine: Pointer; const AName: PAnsiChar);
begin
  TGnyAPI(AEngine).FCore.Undefine(Utf8ToStr(AName));
end;

function gny_is_defined(const AEngine: Pointer;
  const AName: PAnsiChar): Boolean;
begin
  Result := TGnyAPI(AEngine).FCore.IsDefined(Utf8ToStr(AName));
end;

{ Error Reporting }

procedure gny_print_errors(const AEngine: Pointer);
begin
  TGnyAPI(AEngine).FCore.PrintErrors();
end;

function gny_get_errors(const AEngine: Pointer): PAnsiChar;
begin
  Result := AllocUtf8(ErrorsToJson(TGnyAPI(AEngine).FCore));
end;

function gny_has_errors(const AEngine: Pointer): Boolean;
begin
  Result := TGnyAPI(AEngine).FCore.GetErrors().HasErrors();
end;

{ Status Callback }

procedure gny_set_status_callback(const AEngine: Pointer;
  const ACallback: TGnyApiStatusHandler; const AUserData: Pointer);
begin
  if not Assigned(ACallback) then
  begin
    TGnyAPI(AEngine).FCore.SetStatusCallback(nil);
    Exit;
  end;

  TGnyAPI(AEngine).FCore.SetStatusCallback(
    procedure(const AText: string; const AInternalUserData: Pointer)
    var
      LUtf8: UTF8String;
    begin
      LUtf8 := UTF8String(AText);
      ACallback(PAnsiChar(LUtf8), AUserData);
    end,
    AUserData);
end;

{ Debug }

procedure gny_report_leaks(const AEngine: Pointer);
begin
  TGnyAPI(AEngine).FCore.ReportLeaks();
end;

initialization
  FVersionStr := UTF8String(TGnyUtils.GetModuleVersionString(HInstance));

end.
