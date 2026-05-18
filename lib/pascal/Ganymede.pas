{===============================================================================
  Ganymede™ - Embeddable Native Scripting Engine

  Copyright © 2026-present tinyBigGAMES™ LLC
  All Rights Reserved.

  See LICENSE for license information
===============================================================================}

/// <summary>
///   Delphi and Free Pascal dynamic import unit for Ganymede.dll.
///   All functions are loaded at runtime via gny_load / gny_unload.
///   No compile-time dependency on Ganymede source units.
/// </summary>
/// <remarks>
///   <b>String contract:</b> All strings crossing the DLL boundary are
///   null-terminated UTF-8 (PAnsiChar). Strings returned by the DLL are
///   heap-allocated and must be freed with gny_free. Strings passed to
///   callbacks are stack-local — copy with UTF8ToString if needed.
///   <para>
///   <b>Thread safety:</b> Each engine handle is independent. Multiple
///   handles may be used from different threads. A single handle must
///   not be accessed from multiple threads simultaneously.
///   </para>
/// </remarks>
unit Ganymede;

{$Z4}
{$A8}

{$WARN SYMBOL_DEPRECATED OFF}
{$WARN SYMBOL_PLATFORM OFF}
{$WARN UNIT_PLATFORM OFF}
{$WARN UNIT_DEPRECATED OFF}

{$INLINE AUTO}

{$IFNDEF WIN64}
  {$MESSAGE Error 'Unsupported platform'}
{$ENDIF}

{$IFDEF FPC}
  {$MODE DELPHIUNICODE}
{$ENDIF}

interface

uses
  WinAPI.Windows;

const
  // Value type ordinals
  GNY_VT_VOID    = 0;
  GNY_VT_INT8    = 1;
  GNY_VT_INT16   = 2;
  GNY_VT_INT32   = 3;
  GNY_VT_INT64   = 4;
  GNY_VT_UINT8   = 5;
  GNY_VT_UINT16  = 6;
  GNY_VT_UINT32  = 7;
  GNY_VT_UINT64  = 8;
  GNY_VT_FLOAT32 = 9;
  GNY_VT_FLOAT64 = 10;
  GNY_VT_POINTER = 11;

  // Optimization level ordinals
  GNY_OPT_NONE   = 0;
  GNY_OPT_BASIC  = 1;
  GNY_OPT_FULL   = 2;

  // Linkage ordinals
  GNY_LINK_DEFAULT = 0;
  GNY_LINK_C       = 1;

type
  /// <summary>Opaque handle to a Ganymede engine instance.</summary>
  TGnyEngine = type Pointer;

  /// <summary>
  ///   Tagged value for crossing the DLL boundary.
  /// </summary>
  TGnyValue = record
    ValueType: Integer;
    case Byte of
      0: (AsInt8: Int8);
      1: (AsInt16: Int16);
      2: (AsInt32: Int32);
      3: (AsInt64: Int64);
      4: (AsUInt8: UInt8);
      5: (AsUInt16: UInt16);
      6: (AsUInt32: UInt32);
      7: (AsUInt64: UInt64);
      8: (AsFloat32: Single);
      9: (AsFloat64: Double);
      10: (AsPointer: Pointer);
  end;
  PGnyValue = ^TGnyValue;

  /// <summary>Status callback. AText is stack-local UTF-8.</summary>
  TGnyApiStatusHandler = procedure(const AText: PAnsiChar;
    const AUserData: Pointer); cdecl;

// ---------------------------------------------------------------------------
// Loader API
// ---------------------------------------------------------------------------
function  gny_load(const ADllPath: PAnsiChar): Boolean;
procedure gny_unload();
function  gny_is_loaded(): Boolean;

var
  // Lifecycle
  gny_create: function(): TGnyEngine; cdecl;
  gny_destroy: procedure(const AEngine: TGnyEngine); cdecl;
  gny_version: function(): PAnsiChar; cdecl;
  gny_free: procedure(const APtr: PAnsiChar); cdecl;

  // Source Loading
  gny_load_from_string: procedure(const AEngine: TGnyEngine;
    const ASource: PAnsiChar; const AFilename: PAnsiChar); cdecl;
  gny_load_from_file: procedure(const AEngine: TGnyEngine;
    const AFilename: PAnsiChar); cdecl;

  // Compilation
  gny_compile: function(const AEngine: TGnyEngine): Boolean; cdecl;

  // Host Interop
  gny_import_host: procedure(const AEngine: TGnyEngine;
    const AName: PAnsiChar; const AAddr: Pointer;
    const AParamTypes: PInteger; const AParamCount: Integer;
    const AReturn: Integer; const ALinkage: Integer); cdecl;

  // Invocation — consumes pushed args, auto-clears after call
  gny_invoke: function(const AEngine: TGnyEngine;
    const AName: PAnsiChar;
    const AReturnType: Integer): TGnyValue; cdecl;

  // Argument Building
  gny_arg_clear: procedure(const AEngine: TGnyEngine); cdecl;
  gny_arg_push_int8: procedure(const AEngine: TGnyEngine;
    const AValue: Int8); cdecl;
  gny_arg_push_int16: procedure(const AEngine: TGnyEngine;
    const AValue: Int16); cdecl;
  gny_arg_push_int32: procedure(const AEngine: TGnyEngine;
    const AValue: Int32); cdecl;
  gny_arg_push_int64: procedure(const AEngine: TGnyEngine;
    const AValue: Int64); cdecl;
  gny_arg_push_uint8: procedure(const AEngine: TGnyEngine;
    const AValue: UInt8); cdecl;
  gny_arg_push_uint16: procedure(const AEngine: TGnyEngine;
    const AValue: UInt16); cdecl;
  gny_arg_push_uint32: procedure(const AEngine: TGnyEngine;
    const AValue: UInt32); cdecl;
  gny_arg_push_uint64: procedure(const AEngine: TGnyEngine;
    const AValue: UInt64); cdecl;
  gny_arg_push_float32: procedure(const AEngine: TGnyEngine;
    const AValue: Single); cdecl;
  gny_arg_push_float64: procedure(const AEngine: TGnyEngine;
    const AValue: Double); cdecl;
  gny_arg_push_pointer: procedure(const AEngine: TGnyEngine;
    const AValue: Pointer); cdecl;

  // Symbols
  gny_get_symbol: function(const AEngine: TGnyEngine;
    const AName: PAnsiChar): Pointer; cdecl;
  gny_has_symbol: function(const AEngine: TGnyEngine;
    const AName: PAnsiChar): Boolean; cdecl;
  gny_get_symbol_names: function(
    const AEngine: TGnyEngine): PAnsiChar; cdecl;

  // Configuration
  gny_set_output_path: procedure(const AEngine: TGnyEngine;
    const APath: PAnsiChar); cdecl;
  gny_add_lib_path: procedure(const AEngine: TGnyEngine;
    const APath: PAnsiChar); cdecl;
  gny_set_optimization_level: procedure(const AEngine: TGnyEngine;
    const ALevel: Integer); cdecl;
  gny_get_optimization_level: function(
    const AEngine: TGnyEngine): Integer; cdecl;
  gny_set_dump_ir: procedure(const AEngine: TGnyEngine;
    const AValue: Boolean); cdecl;
  gny_get_ssa_dump: function(
    const AEngine: TGnyEngine): PAnsiChar; cdecl;

  // Conditional Compilation
  gny_set_define: procedure(const AEngine: TGnyEngine;
    const AName: PAnsiChar; const AValue: PAnsiChar); cdecl;
  gny_undefine: procedure(const AEngine: TGnyEngine;
    const AName: PAnsiChar); cdecl;
  gny_is_defined: function(const AEngine: TGnyEngine;
    const AName: PAnsiChar): Boolean; cdecl;

  // Error Reporting
  gny_print_errors: procedure(const AEngine: TGnyEngine); cdecl;
  gny_get_errors: function(
    const AEngine: TGnyEngine): PAnsiChar; cdecl;
  gny_has_errors: function(
    const AEngine: TGnyEngine): Boolean; cdecl;

  // Status Callback
  gny_set_status_callback: procedure(const AEngine: TGnyEngine;
    const ACallback: TGnyApiStatusHandler;
    const AUserData: Pointer); cdecl;

  // Debug
  gny_report_leaks: procedure(const AEngine: TGnyEngine); cdecl;

implementation

var
  FDllHandle: HMODULE = 0;

{ Helper: resolve one symbol or fail }

function LoadProc(const AName: PAnsiChar; out AProc: Pointer): Boolean;
begin
  AProc := GetProcAddress(FDllHandle, AName);
  Result := AProc <> nil;
  if not Result then
    MessageBoxA(0, AName, 'Ganymede: failed to load symbol',
      MB_OK or MB_ICONERROR);
end;

{ Clear all function pointers to nil }

procedure ClearPointers();
begin
  gny_create := nil;
  gny_destroy := nil;
  gny_version := nil;
  gny_free := nil;
  gny_load_from_string := nil;
  gny_load_from_file := nil;
  gny_compile := nil;
  gny_import_host := nil;
  gny_invoke := nil;
  gny_arg_clear := nil;
  gny_arg_push_int8 := nil;
  gny_arg_push_int16 := nil;
  gny_arg_push_int32 := nil;
  gny_arg_push_int64 := nil;
  gny_arg_push_uint8 := nil;
  gny_arg_push_uint16 := nil;
  gny_arg_push_uint32 := nil;
  gny_arg_push_uint64 := nil;
  gny_arg_push_float32 := nil;
  gny_arg_push_float64 := nil;
  gny_arg_push_pointer := nil;
  gny_get_symbol := nil;
  gny_has_symbol := nil;
  gny_get_symbol_names := nil;
  gny_set_output_path := nil;
  gny_add_lib_path := nil;
  gny_set_optimization_level := nil;
  gny_get_optimization_level := nil;
  gny_set_dump_ir := nil;
  gny_get_ssa_dump := nil;
  gny_set_define := nil;
  gny_undefine := nil;
  gny_is_defined := nil;
  gny_print_errors := nil;
  gny_get_errors := nil;
  gny_has_errors := nil;
  gny_set_status_callback := nil;
  gny_report_leaks := nil;
end;

{ gny_load }

function gny_load(const ADllPath: PAnsiChar): Boolean;
begin
  Result := False;

  // Already loaded
  if FDllHandle <> 0 then
  begin
    Result := True;
    Exit;
  end;

  FDllHandle := LoadLibraryA(ADllPath);
  if FDllHandle = 0 then
  begin
    MessageBoxA(0, ADllPath, 'Ganymede: failed to load DLL',
      MB_OK or MB_ICONERROR);
    Exit;
  end;

  // Resolve every export — bail on first failure
  if not LoadProc('gny_create', @gny_create) then begin gny_unload(); Exit; end;
  if not LoadProc('gny_destroy', @gny_destroy) then begin gny_unload(); Exit; end;
  if not LoadProc('gny_version', @gny_version) then begin gny_unload(); Exit; end;
  if not LoadProc('gny_free', @gny_free) then begin gny_unload(); Exit; end;
  if not LoadProc('gny_load_from_string', @gny_load_from_string) then begin gny_unload(); Exit; end;
  if not LoadProc('gny_load_from_file', @gny_load_from_file) then begin gny_unload(); Exit; end;
  if not LoadProc('gny_compile', @gny_compile) then begin gny_unload(); Exit; end;
  if not LoadProc('gny_import_host', @gny_import_host) then begin gny_unload(); Exit; end;
  if not LoadProc('gny_invoke', @gny_invoke) then begin gny_unload(); Exit; end;
  if not LoadProc('gny_arg_clear', @gny_arg_clear) then begin gny_unload(); Exit; end;
  if not LoadProc('gny_arg_push_int8', @gny_arg_push_int8) then begin gny_unload(); Exit; end;
  if not LoadProc('gny_arg_push_int16', @gny_arg_push_int16) then begin gny_unload(); Exit; end;
  if not LoadProc('gny_arg_push_int32', @gny_arg_push_int32) then begin gny_unload(); Exit; end;
  if not LoadProc('gny_arg_push_int64', @gny_arg_push_int64) then begin gny_unload(); Exit; end;
  if not LoadProc('gny_arg_push_uint8', @gny_arg_push_uint8) then begin gny_unload(); Exit; end;
  if not LoadProc('gny_arg_push_uint16', @gny_arg_push_uint16) then begin gny_unload(); Exit; end;
  if not LoadProc('gny_arg_push_uint32', @gny_arg_push_uint32) then begin gny_unload(); Exit; end;
  if not LoadProc('gny_arg_push_uint64', @gny_arg_push_uint64) then begin gny_unload(); Exit; end;
  if not LoadProc('gny_arg_push_float32', @gny_arg_push_float32) then begin gny_unload(); Exit; end;
  if not LoadProc('gny_arg_push_float64', @gny_arg_push_float64) then begin gny_unload(); Exit; end;
  if not LoadProc('gny_arg_push_pointer', @gny_arg_push_pointer) then begin gny_unload(); Exit; end;
  if not LoadProc('gny_get_symbol', @gny_get_symbol) then begin gny_unload(); Exit; end;
  if not LoadProc('gny_has_symbol', @gny_has_symbol) then begin gny_unload(); Exit; end;
  if not LoadProc('gny_get_symbol_names', @gny_get_symbol_names) then begin gny_unload(); Exit; end;
  if not LoadProc('gny_set_output_path', @gny_set_output_path) then begin gny_unload(); Exit; end;
  if not LoadProc('gny_add_lib_path', @gny_add_lib_path) then begin gny_unload(); Exit; end;
  if not LoadProc('gny_set_optimization_level', @gny_set_optimization_level) then begin gny_unload(); Exit; end;
  if not LoadProc('gny_get_optimization_level', @gny_get_optimization_level) then begin gny_unload(); Exit; end;
  if not LoadProc('gny_set_dump_ir', @gny_set_dump_ir) then begin gny_unload(); Exit; end;
  if not LoadProc('gny_get_ssa_dump', @gny_get_ssa_dump) then begin gny_unload(); Exit; end;
  if not LoadProc('gny_set_define', @gny_set_define) then begin gny_unload(); Exit; end;
  if not LoadProc('gny_undefine', @gny_undefine) then begin gny_unload(); Exit; end;
  if not LoadProc('gny_is_defined', @gny_is_defined) then begin gny_unload(); Exit; end;
  if not LoadProc('gny_print_errors', @gny_print_errors) then begin gny_unload(); Exit; end;
  if not LoadProc('gny_get_errors', @gny_get_errors) then begin gny_unload(); Exit; end;
  if not LoadProc('gny_has_errors', @gny_has_errors) then begin gny_unload(); Exit; end;
  if not LoadProc('gny_set_status_callback', @gny_set_status_callback) then begin gny_unload(); Exit; end;
  if not LoadProc('gny_report_leaks', @gny_report_leaks) then begin gny_unload(); Exit; end;

  Result := True;
end;

{ gny_unload }

procedure gny_unload();
begin
  if FDllHandle <> 0 then
  begin
    FreeLibrary(FDllHandle);
    FDllHandle := 0;
  end;
  ClearPointers();
end;

{ gny_is_loaded }

function gny_is_loaded(): Boolean;
begin
  Result := FDllHandle <> 0;
end;

end.
