{===============================================================================
  Ganymede™ - Embeddable Native Scripting Engine

  Copyright © 2026-present tinyBigGAMES™ LLC
  All Rights Reserved.

  See LICENSE for license information
===============================================================================}

unit UTest.Pointers;

{$I Ganymede.Defines.inc}

interface

uses
  Ganymede.TestCase;

type
  TScriptPointersTest = class(TGnyTestCase)
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
{ TScriptPointersTest }

constructor TScriptPointersTest.Create();
begin
  inherited;
  Title := 'GanymedeScript — Pointer Types';
  Pause := True;
end;

procedure TScriptPointersTest.Run();
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

  LFile := TPath.Combine(CTestDir, 'test_mem_pointers.gny');
  for LOptLevel := GNY_OPT_NONE to GNY_OPT_FULL do
  begin
    Section('Pointer Types — opt level %d', [LOptLevel]);
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

      LI8 := gny_invoke(LEngine, PAnsiChar(UTF8Encode('ptr_i8')), GNY_VT_INT8).AsInt8;
      Check(LI8 = 127, 'ptr_i8():int8 = %d (expected 127, opt %d)', [LI8, LOptLevel]);

      LI16 := gny_invoke(LEngine, PAnsiChar(UTF8Encode('ptr_i16')), GNY_VT_INT16).AsInt16;
      Check(LI16 = 30000, 'ptr_i16():int16 = %d (expected 30000, opt %d)', [LI16, LOptLevel]);

      LI32 := gny_invoke(LEngine, PAnsiChar(UTF8Encode('ptr_i32')), GNY_VT_INT32).AsInt32;
      Check(LI32 = 42, 'ptr_i32():int32 = %d (expected 42, opt %d)', [LI32, LOptLevel]);

      LI64 := gny_invoke(LEngine, PAnsiChar(UTF8Encode('ptr_i64')), GNY_VT_INT64).AsInt64;
      Check(LI64 = 4000000000, 'ptr_i64():int64 = %d (expected 4000000000, opt %d)', [LI64, LOptLevel]);

      LU8 := gny_invoke(LEngine, PAnsiChar(UTF8Encode('ptr_u8')), GNY_VT_UINT8).AsUInt8;
      Check(LU8 = 250, 'ptr_u8():uint8 = %d (expected 250, opt %d)', [LU8, LOptLevel]);
      LU16 := gny_invoke(LEngine, PAnsiChar(UTF8Encode('ptr_u16')), GNY_VT_UINT16).AsUInt16;
      Check(LU16 = 50000, 'ptr_u16():uint16 = %d (expected 50000, opt %d)', [LU16, LOptLevel]);

      LU32 := gny_invoke(LEngine, PAnsiChar(UTF8Encode('ptr_u32')), GNY_VT_UINT32).AsUInt32;
      Check(LU32 = 300000, 'ptr_u32():uint32 = %d (expected 300000, opt %d)', [LU32, LOptLevel]);

      LF32 := gny_invoke(LEngine, PAnsiChar(UTF8Encode('ptr_f32')), GNY_VT_FLOAT32).AsFloat32;
      Check(Abs(LF32 - 2.5) < 0.01, 'ptr_f32():float32 = %.4f (expected 2.5, opt %d)', [LF32, LOptLevel]);

      LF64 := gny_invoke(LEngine, PAnsiChar(UTF8Encode('ptr_f64')), GNY_VT_FLOAT64).AsFloat64;
      Check(Abs(LF64 - 3.14159) < 0.0001, 'ptr_f64():float64 = %.5f (expected 3.14159, opt %d)', [LF64, LOptLevel]);

      LBool := gny_invoke(LEngine, PAnsiChar(UTF8Encode('ptr_bool_true')), GNY_VT_INT8).AsInt8;
      Check(LBool = 1, 'ptr_bool_true():bool = %d (expected 1, opt %d)', [LBool, LOptLevel]);

      LBool := gny_invoke(LEngine, PAnsiChar(UTF8Encode('ptr_bool_false')), GNY_VT_INT8).AsInt8;
      Check(LBool = 0, 'ptr_bool_false():bool = %d (expected 0, opt %d)', [LBool, LOptLevel]);

      LI32 := gny_invoke(LEngine, PAnsiChar(UTF8Encode('ptr_write_i32')), GNY_VT_INT32).AsInt32;
      Check(LI32 = 99, 'ptr_write_i32():int32 = %d (expected 99, opt %d)', [LI32, LOptLevel]);

      LI64 := gny_invoke(LEngine, PAnsiChar(UTF8Encode('ptr_write_i64')), GNY_VT_INT64).AsInt64;
      Check(LI64 = 9999999999, 'ptr_write_i64():int64 = %d (expected 9999999999, opt %d)', [LI64, LOptLevel]);

      LF64 := gny_invoke(LEngine, PAnsiChar(UTF8Encode('ptr_write_f64')), GNY_VT_FLOAT64).AsFloat64;
      Check(Abs(LF64 - 77.25) < 0.001, 'ptr_write_f64():float64 = %.4f (expected 77.25, opt %d)', [LF64, LOptLevel]);

      LI32 := gny_invoke(LEngine, PAnsiChar(UTF8Encode('ptr_nil')), GNY_VT_INT32).AsInt32;
      Check(LI32 = 1, 'ptr_nil():int32 = %d (expected 1, opt %d)', [LI32, LOptLevel]);

      LI32 := gny_invoke(LEngine, PAnsiChar(UTF8Encode('ptr_not_nil')), GNY_VT_INT32).AsInt32;
      Check(LI32 = 1, 'ptr_not_nil():int32 = %d (expected 1, opt %d)', [LI32, LOptLevel]);
      LI32 := gny_invoke(LEngine, PAnsiChar(UTF8Encode('ptr_untyped')), GNY_VT_INT32).AsInt32;
      Check(LI32 = 1, 'ptr_untyped():int32 = %d (expected 1, opt %d)', [LI32, LOptLevel]);

      LI32 := gny_invoke(LEngine, PAnsiChar(UTF8Encode('ptr_ampersand')), GNY_VT_INT32).AsInt32;
      Check(LI32 = 77, 'ptr_ampersand():int32 = %d (expected 77, opt %d)', [LI32, LOptLevel]);

      LI32 := gny_invoke(LEngine, PAnsiChar(UTF8Encode('ptr_named_type')), GNY_VT_INT32).AsInt32;
      Check(LI32 = 55, 'ptr_named_type():int32 = %d (expected 55, opt %d)', [LI32, LOptLevel]);

      LF64 := gny_invoke(LEngine, PAnsiChar(UTF8Encode('ptr_named_f64')), GNY_VT_FLOAT64).AsFloat64;
      Check(Abs(LF64 - 12.75) < 0.001, 'ptr_named_f64():float64 = %.4f (expected 12.75, opt %d)', [LF64, LOptLevel]);

      LI32 := gny_invoke(LEngine, PAnsiChar(UTF8Encode('ptr_passref_i32')), GNY_VT_INT32).AsInt32;
      Check(LI32 = 123, 'ptr_passref_i32():int32 = %d (expected 123, opt %d)', [LI32, LOptLevel]);

      LI64 := gny_invoke(LEngine, PAnsiChar(UTF8Encode('ptr_passref_i64')), GNY_VT_INT64).AsInt64;
      Check(LI64 = 5000000000, 'ptr_passref_i64():int64 = %d (expected 5000000000, opt %d)', [LI64, LOptLevel]);

      LF64 := gny_invoke(LEngine, PAnsiChar(UTF8Encode('ptr_passref_f64')), GNY_VT_FLOAT64).AsFloat64;
      Check(Abs(LF64 - 99.5) < 0.001, 'ptr_passref_f64():float64 = %.4f (expected 99.5, opt %d)', [LF64, LOptLevel]);

      LI32 := gny_invoke(LEngine, PAnsiChar(UTF8Encode('ptr_swap')), GNY_VT_INT32).AsInt32;
      Check(LI32 = 2010, 'ptr_swap():int32 = %d (expected 2010, opt %d)', [LI32, LOptLevel]);

      LI32 := gny_invoke(LEngine, PAnsiChar(UTF8Encode('ptr_rec_field')), GNY_VT_INT32).AsInt32;
      Check(LI32 = 300, 'ptr_rec_field():int32 = %d (expected 300, opt %d)', [LI32, LOptLevel]);

      LI32 := gny_invoke(LEngine, PAnsiChar(UTF8Encode('ptr_rec_write')), GNY_VT_INT32).AsInt32;
      Check(LI32 = 127, 'ptr_rec_write():int32 = %d (expected 127, opt %d)', [LI32, LOptLevel]);

      LI32 := gny_invoke(LEngine, PAnsiChar(UTF8Encode('ptr_reassign')), GNY_VT_INT32).AsInt32;
      Check(LI32 = 20, 'ptr_reassign():int32 = %d (expected 20, opt %d)', [LI32, LOptLevel]);

      LI64 := gny_invoke(LEngine, PAnsiChar(UTF8Encode('ptr_multi')), GNY_VT_INT64).AsInt64;
      Check(LI64 = 30, 'ptr_multi():int64 = %d (expected 30, opt %d)', [LI64, LOptLevel]);

      LI64 := gny_invoke(LEngine, PAnsiChar(UTF8Encode('ptr_kitchensink')), GNY_VT_INT64).AsInt64;
      Check(LI64 = 29, 'ptr_kitchensink():int64 = %d (expected 29, opt %d)', [LI64, LOptLevel]);

    finally
      gny_destroy(LEngine);
    end;
  end;

  gny_unload();
end;

end.