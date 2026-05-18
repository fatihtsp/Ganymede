{===============================================================================
  Ganymede™ - Embeddable Native Scripting Engine

  Copyright © 2026-present tinyBigGAMES™ LLC
  All Rights Reserved.

  See LICENSE for license information
===============================================================================}

unit UTest.Intrinsics;

{$I Ganymede.Defines.inc}

interface

uses
  Ganymede.TestCase;

type
  TScriptIntrinsicsTest = class(TGnyTestCase)
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
{ TScriptIntrinsicsTest }

constructor TScriptIntrinsicsTest.Create();
begin
  inherited;
  Title := 'GanymedeScript — Built-in Intrinsics (size, utf8)';
  Pause := True;
end;

procedure TScriptIntrinsicsTest.Run();
var
  LEngine: TGnyEngine;
  LI64: Int64;
  LI32: Int32;
  LOptLevel: Integer;
  LFile: string;
begin
  if not gny_load(PAnsiChar(UTF8Encode(CDllPath))) then
  begin
    Check(False, 'Failed to load Ganymede DLL');
    Exit;
  end;

  LFile := TPath.Combine(CTestDir, 'test_mem_intrinsics.gny');

  for LOptLevel := GNY_OPT_NONE to GNY_OPT_FULL do
  begin
    Section('Intrinsics (size, utf8) — opt level %d', [LOptLevel]);
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
      LI64 := gny_invoke(LEngine, PAnsiChar(UTF8Encode('test_size_i8')), GNY_VT_INT64).AsInt64;
      Check(LI64 = 1, 'size(int8) = %d (expected 1, opt %d)', [LI64, LOptLevel]);

      LI64 := gny_invoke(LEngine, PAnsiChar(UTF8Encode('test_size_i16')), GNY_VT_INT64).AsInt64;
      Check(LI64 = 2, 'size(int16) = %d (expected 2, opt %d)', [LI64, LOptLevel]);

      LI64 := gny_invoke(LEngine, PAnsiChar(UTF8Encode('test_size_i32')), GNY_VT_INT64).AsInt64;
      Check(LI64 = 4, 'size(int32) = %d (expected 4, opt %d)', [LI64, LOptLevel]);

      LI64 := gny_invoke(LEngine, PAnsiChar(UTF8Encode('test_size_i64')), GNY_VT_INT64).AsInt64;
      Check(LI64 = 8, 'size(int64) = %d (expected 8, opt %d)', [LI64, LOptLevel]);

      LI64 := gny_invoke(LEngine, PAnsiChar(UTF8Encode('test_size_f32')), GNY_VT_INT64).AsInt64;
      Check(LI64 = 4, 'size(float32) = %d (expected 4, opt %d)', [LI64, LOptLevel]);

      LI64 := gny_invoke(LEngine, PAnsiChar(UTF8Encode('test_size_f64')), GNY_VT_INT64).AsInt64;
      Check(LI64 = 8, 'size(float64) = %d (expected 8, opt %d)', [LI64, LOptLevel]);

      LI64 := gny_invoke(LEngine, PAnsiChar(UTF8Encode('test_size_ptr')), GNY_VT_INT64).AsInt64;
      Check(LI64 = 8, 'size(pointer) = %d (expected 8, opt %d)', [LI64, LOptLevel]);

      LI64 := gny_invoke(LEngine, PAnsiChar(UTF8Encode('test_size_bool')), GNY_VT_INT64).AsInt64;
      Check(LI64 = 1, 'size(boolean) = %d (expected 1, opt %d)', [LI64, LOptLevel]);

      LI64 := gny_invoke(LEngine, PAnsiChar(UTF8Encode('test_size_record')), GNY_VT_INT64).AsInt64;
      Check(LI64 = 8, 'size(TPoint) = %d (expected 8, opt %d)', [LI64, LOptLevel]);

      LI32 := gny_invoke(LEngine, PAnsiChar(UTF8Encode('test_size_in_expr')), GNY_VT_INT32).AsInt32;
      Check(LI32 = 12, 'size(int32)+size(int64) = %d (expected 12, opt %d)', [LI32, LOptLevel]);

      LI32 := gny_invoke(LEngine, PAnsiChar(UTF8Encode('test_utf8_nonnull')), GNY_VT_INT32).AsInt32;
      Check(LI32 = 1, 'utf8() returns non-nil = %d (expected 1, opt %d)', [LI32, LOptLevel]);

    finally
      gny_destroy(LEngine);
    end;
  end;

  gny_unload();
end;

end.