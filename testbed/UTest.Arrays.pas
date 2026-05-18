{===============================================================================
  Ganymede™ - Embeddable Native Scripting Engine

  Copyright © 2026-present tinyBigGAMES™ LLC
  All Rights Reserved.

  See LICENSE for license information
===============================================================================}

unit UTest.Arrays;

{$I Ganymede.Defines.inc}

interface

uses
  Ganymede.TestCase;

type
  TArraysTest = class(TGnyTestCase)
  public
    constructor Create(); override;
  protected
    procedure Run(); override;
  end;

implementation

uses
  System.IOUtils,
  UCommon,
  Ganymede;
{ TArraysTest }

constructor TArraysTest.Create();
begin
  inherited;
  Title := 'GanymedeScript — Array Types';
  Pause := True;
end;

procedure TArraysTest.Run();
var
  LEngine: TGnyEngine;
  LI8: Int8;
  LI16: Int16;
  LI32: Int32;
  LI64: Int64;
  LU8: UInt8;
  LU16: UInt16;
  LU32: UInt32;
  LF32: Single;
  LF64: Double;
  LBool: Int8;
  LOptLevel: Integer;
  LFile: string;
begin
  if not gny_load(PAnsiChar(UTF8Encode(CDllPath))) then
  begin
    Check(False, 'Failed to load Ganymede DLL');
    Exit;
  end;

  LFile := TPath.Combine(CTestDir, 'test_mem_arrays.gny');
  for LOptLevel := GNY_OPT_NONE to GNY_OPT_FULL do
  begin
    Section('Array Types — opt level %d', [LOptLevel]);
    LEngine := gny_create();
    try
      gny_set_optimization_level(LEngine, LOptLevel);
      gny_load_from_file(LEngine, PAnsiChar(UTF8Encode(LFile)));

      if not gny_compile(LEngine) then
      begin
        gny_print_errors(LEngine);
        Check(False, 'Compile failed (opt %d)', [LOptLevel]);
        Continue;
      end;

      Check(True, 'Compiled successfully (opt %d)', [LOptLevel]);

      // --- int32 array, basic read/write ---
      LI32 := gny_invoke(LEngine, PAnsiChar(UTF8Encode('intarr')), GNY_VT_INT32).AsInt32;
      Check(LI32 = 60, 'intarr():int32 = %d (expected 60, opt %d)', [LI32, LOptLevel]);

      LI32 := gny_invoke(LEngine, PAnsiChar(UTF8Encode('inlinearr')), GNY_VT_INT32).AsInt32;
      Check(LI32 = 600, 'inlinearr():int32 = %d (expected 600, opt %d)', [LI32, LOptLevel]);

      LI8 := gny_invoke(LEngine, PAnsiChar(UTF8Encode('i8arr')), GNY_VT_INT8).AsInt8;
      Check(LI8 = 50, 'i8arr():int8 = %d (expected 50, opt %d)', [LI8, LOptLevel]);

      LI16 := gny_invoke(LEngine, PAnsiChar(UTF8Encode('i16arr')), GNY_VT_INT16).AsInt16;
      Check(LI16 = 5000, 'i16arr():int16 = %d (expected 5000, opt %d)', [LI16, LOptLevel]);
      LI64 := gny_invoke(LEngine, PAnsiChar(UTF8Encode('i64arr')), GNY_VT_INT64).AsInt64;
      Check(LI64 = 4000000000, 'i64arr():int64 = %d (expected 4000000000, opt %d)', [LI64, LOptLevel]);

      LU8 := gny_invoke(LEngine, PAnsiChar(UTF8Encode('u8arr')), GNY_VT_UINT8).AsUInt8;
      Check(LU8 = 250, 'u8arr():uint8 = %d (expected 250, opt %d)', [LU8, LOptLevel]);

      LU16 := gny_invoke(LEngine, PAnsiChar(UTF8Encode('u16arr')), GNY_VT_UINT16).AsUInt16;
      Check(LU16 = 50000, 'u16arr():uint16 = %d (expected 50000, opt %d)', [LU16, LOptLevel]);

      LU32 := gny_invoke(LEngine, PAnsiChar(UTF8Encode('u32arr')), GNY_VT_UINT32).AsUInt32;
      Check(LU32 = 400000, 'u32arr():uint32 = %d (expected 400000, opt %d)', [LU32, LOptLevel]);

      LF32 := gny_invoke(LEngine, PAnsiChar(UTF8Encode('f32arr')), GNY_VT_FLOAT32).AsFloat32;
      Check(Abs(LF32 - 5.0) < 0.01, 'f32arr():float32 = %.4f (expected 5.0, opt %d)', [LF32, LOptLevel]);

      LF64 := gny_invoke(LEngine, PAnsiChar(UTF8Encode('f64arr')), GNY_VT_FLOAT64).AsFloat64;
      Check(Abs(LF64 - 30.75) < 0.001, 'f64arr():float64 = %.4f (expected 30.75, opt %d)', [LF64, LOptLevel]);

      LBool := gny_invoke(LEngine, PAnsiChar(UTF8Encode('boolarr')), GNY_VT_INT8).AsInt8;
      Check(LBool = 1, 'boolarr():bool = %d (expected 1/true, opt %d)', [LBool, LOptLevel]);

      LBool := gny_invoke(LEngine, PAnsiChar(UTF8Encode('boolarrfalse')), GNY_VT_INT8).AsInt8;
      Check(LBool = 0, 'boolarrfalse():bool = %d (expected 0/false, opt %d)', [LBool, LOptLevel]);

      LI32 := gny_invoke(LEngine, PAnsiChar(UTF8Encode('elemmath')), GNY_VT_INT32).AsInt32;
      Check(LI32 = 590, 'elemmath():int32 = %d (expected 590, opt %d)', [LI32, LOptLevel]);

      LI32 := gny_invoke(LEngine, PAnsiChar(UTF8Encode('loopsum')), GNY_VT_INT32).AsInt32;
      Check(LI32 = 550, 'loopsum():int32 = %d (expected 550, opt %d)', [LI32, LOptLevel]);

      LI32 := gny_invoke(LEngine, PAnsiChar(UTF8Encode('overwrite')), GNY_VT_INT32).AsInt32;
      Check(LI32 = 1999, 'overwrite():int32 = %d (expected 1999, opt %d)', [LI32, LOptLevel]);

      LI32 := gny_invoke(LEngine, PAnsiChar(UTF8Encode('boundary')), GNY_VT_INT32).AsInt32;
      Check(LI32 = 100, 'boundary():int32 = %d (expected 100, opt %d)', [LI32, LOptLevel]);
      LI64 := gny_invoke(LEngine, PAnsiChar(UTF8Encode('multiarray')), GNY_VT_INT64).AsInt64;
      Check(LI64 = 300, 'multiarray():int64 = %d (expected 300, opt %d)', [LI64, LOptLevel]);

      LI32 := gny_invoke(LEngine, PAnsiChar(UTF8Encode('elemarg')), GNY_VT_INT32).AsInt32;
      Check(LI32 = 100, 'elemarg():int32 = %d (expected 100, opt %d)', [LI32, LOptLevel]);

      LI32 := gny_invoke(LEngine, PAnsiChar(UTF8Encode('recarr')), GNY_VT_INT32).AsInt32;
      Check(LI32 = 121, 'recarr():int32 = %d (expected 121, opt %d)', [LI32, LOptLevel]);

      LI32 := gny_invoke(LEngine, PAnsiChar(UTF8Encode('condelem')), GNY_VT_INT32).AsInt32;
      Check(LI32 = 10, 'condelem():int32 = %d (expected 10, opt %d)', [LI32, LOptLevel]);

      LI32 := gny_invoke(LEngine, PAnsiChar(UTF8Encode('arrcopy')), GNY_VT_INT32).AsInt32;
      Check(LI32 = 99, 'arrcopy():int32 = %d (expected 99, opt %d)', [LI32, LOptLevel]);

      LI64 := gny_invoke(LEngine, PAnsiChar(UTF8Encode('kitchensink')), GNY_VT_INT64).AsInt64;
      Check(LI64 = 28, 'kitchensink():int64 = %d (expected 28, opt %d)', [LI64, LOptLevel]);
      // --- dynamic arrays ---
      LI32 := gny_invoke(LEngine, PAnsiChar(UTF8Encode('dynarr_basic')), GNY_VT_INT32).AsInt32;
      Check(LI32 = 150, 'dynarr_basic():int32 = %d (expected 150, opt %d)', [LI32, LOptLevel]);

      LI64 := gny_invoke(LEngine, PAnsiChar(UTF8Encode('dynarr_len')), GNY_VT_INT64).AsInt64;
      Check(LI64 = 10, 'dynarr_len():int64 = %d (expected 10, opt %d)', [LI64, LOptLevel]);

      LI64 := gny_invoke(LEngine, PAnsiChar(UTF8Encode('dynarr_len_nil')), GNY_VT_INT64).AsInt64;
      Check(LI64 = 0, 'dynarr_len_nil():int64 = %d (expected 0, opt %d)', [LI64, LOptLevel]);

      LI32 := gny_invoke(LEngine, PAnsiChar(UTF8Encode('dynarr_loopsum')), GNY_VT_INT32).AsInt32;
      Check(LI32 = 550, 'dynarr_loopsum():int32 = %d (expected 550, opt %d)', [LI32, LOptLevel]);

      LI64 := gny_invoke(LEngine, PAnsiChar(UTF8Encode('dynarr_i64')), GNY_VT_INT64).AsInt64;
      Check(LI64 = 4000000000, 'dynarr_i64():int64 = %d (expected 4000000000, opt %d)', [LI64, LOptLevel]);

      LI32 := gny_invoke(LEngine, PAnsiChar(UTF8Encode('dynarr_overwrite')), GNY_VT_INT32).AsInt32;
      Check(LI32 = 1999, 'dynarr_overwrite():int32 = %d (expected 1999, opt %d)', [LI32, LOptLevel]);

      LI64 := gny_invoke(LEngine, PAnsiChar(UTF8Encode('dynarr_expr_len')), GNY_VT_INT64).AsInt64;
      Check(LI64 = 5, 'dynarr_expr_len():int64 = %d (expected 5, opt %d)', [LI64, LOptLevel]);

      LI32 := gny_invoke(LEngine, PAnsiChar(UTF8Encode('dynarr_i8')), GNY_VT_INT32).AsInt32;
      Check(LI32 = 40, 'dynarr_i8():int32 = %d (expected 40, opt %d)', [LI32, LOptLevel]);
      LF64 := gny_invoke(LEngine, PAnsiChar(UTF8Encode('dynarr_f64')), GNY_VT_FLOAT64).AsFloat64;
      Check(Abs(LF64 - 41.0) < 0.001, 'dynarr_f64():float64 = %.4f (expected 41.0, opt %d)', [LF64, LOptLevel]);

      LI64 := gny_invoke(LEngine, PAnsiChar(UTF8Encode('dynarr_multi')), GNY_VT_INT64).AsInt64;
      Check(LI64 = 3300, 'dynarr_multi():int64 = %d (expected 3300, opt %d)', [LI64, LOptLevel]);

      LI32 := gny_invoke(LEngine, PAnsiChar(UTF8Encode('dynarr_elemmath')), GNY_VT_INT32).AsInt32;
      Check(LI32 = 590, 'dynarr_elemmath():int32 = %d (expected 590, opt %d)', [LI32, LOptLevel]);

      LI32 := gny_invoke(LEngine, PAnsiChar(UTF8Encode('dynarr_elemarg')), GNY_VT_INT32).AsInt32;
      Check(LI32 = 100, 'dynarr_elemarg():int32 = %d (expected 100, opt %d)', [LI32, LOptLevel]);

      LI32 := gny_invoke(LEngine, PAnsiChar(UTF8Encode('dynarr_condelem')), GNY_VT_INT32).AsInt32;
      Check(LI32 = 10, 'dynarr_condelem():int32 = %d (expected 10, opt %d)', [LI32, LOptLevel]);

      // --- len() on managed string ---
      LI64 := gny_invoke(LEngine, PAnsiChar(UTF8Encode('len_string')), GNY_VT_INT64).AsInt64;
      Check(LI64 = 5, 'len_string():int64 = %d (expected 5, opt %d)', [LI64, LOptLevel]);

    finally
      gny_destroy(LEngine);
    end;
  end;

  gny_unload();
end;

end.