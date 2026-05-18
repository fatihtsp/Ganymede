{===============================================================================
  Ganymede™ - Embeddable Native Scripting Engine

  Copyright © 2026-present tinyBigGAMES™ LLC
  All Rights Reserved.

  See LICENSE for license information
===============================================================================}

unit UTest.VariadicArgs;

{$I Ganymede.Defines.inc}

interface

uses
  Ganymede.TestCase;

type
  TScriptVariadicArgsTest = class(TGnyTestCase)
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
{ TScriptVariadicArgsTest }

constructor TScriptVariadicArgsTest.Create();
begin
  inherited;
  Title := 'GanymedeScript — Variadic Arguments';
  Pause := True;
end;

procedure TScriptVariadicArgsTest.Run();
var
  LEngine: TGnyEngine;
  LI64: Int64;
  LI32: Int32;
  LF64: Double;
  LOptLevel: Integer;
  LFile: string;
begin
  if not gny_load(PAnsiChar(UTF8Encode(CDllPath))) then
  begin
    Check(False, 'Failed to load Ganymede DLL');
    Exit;
  end;

  LFile := TPath.Combine(CTestDir, 'test_mem_variadic_args.gny');

  for LOptLevel := GNY_OPT_NONE to GNY_OPT_FULL do
  begin
    Section('Variadic Arguments — opt level %d', [LOptLevel]);
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

      // 1: sum_ints(3, 10, 20, 30) = 60
      gny_arg_push_int32(LEngine, 3);
      gny_arg_push_int64(LEngine, 10);
      gny_arg_push_int64(LEngine, 20);
      gny_arg_push_int64(LEngine, 30);
      LI64 := gny_invoke(LEngine, PAnsiChar(UTF8Encode('sum_ints')), GNY_VT_INT64).AsInt64;
      Check(LI64 = 60, 'sum_ints(3, 10,20,30) = %d (exp 60, opt %d)', [LI64, LOptLevel]);

      // 2: va_count_test(1,2,3,4,5) = 5
      gny_arg_push_int64(LEngine, 1);
      gny_arg_push_int64(LEngine, 2);
      gny_arg_push_int64(LEngine, 3);
      gny_arg_push_int64(LEngine, 4);
      gny_arg_push_int64(LEngine, 5);
      LI32 := gny_invoke(LEngine, PAnsiChar(UTF8Encode('va_count_test')), GNY_VT_INT32).AsInt32;
      Check(LI32 = 5, 'va_count_test(1..5) = %d (exp 5, opt %d)', [LI32, LOptLevel]);

      // 3: sum_i32(2, 100, 200) = 300
      gny_arg_push_int32(LEngine, 2);
      gny_arg_push_int32(LEngine, 100);
      gny_arg_push_int32(LEngine, 200);
      LI32 := gny_invoke(LEngine, PAnsiChar(UTF8Encode('sum_i32')), GNY_VT_INT32).AsInt32;
      Check(LI32 = 300, 'sum_i32(2, 100,200) = %d (exp 300, opt %d)', [LI32, LOptLevel]);
      // 4: sum_f64(3, 1.5, 2.5, 3.0) = 7.0
      gny_arg_push_int32(LEngine, 3);
      gny_arg_push_float64(LEngine, 1.5);
      gny_arg_push_float64(LEngine, 2.5);
      gny_arg_push_float64(LEngine, 3.0);
      LF64 := gny_invoke(LEngine, PAnsiChar(UTF8Encode('sum_f64')), GNY_VT_FLOAT64).AsFloat64;
      Check(Abs(LF64 - 7.0) < 0.001, 'sum_f64(3, 1.5,2.5,3.0) = %.2f (exp 7.0, opt %d)', [LF64, LOptLevel]);

      // 5: count_after_fixed(10, 20, 1, 2, 3) = 3
      gny_arg_push_int32(LEngine, 10);
      gny_arg_push_int32(LEngine, 20);
      gny_arg_push_int64(LEngine, 1);
      gny_arg_push_int64(LEngine, 2);
      gny_arg_push_int64(LEngine, 3);
      LI32 := gny_invoke(LEngine, PAnsiChar(UTF8Encode('count_after_fixed')), GNY_VT_INT32).AsInt32;
      Check(LI32 = 3, 'count_after_fixed(10,20, 1,2,3) = %d (exp 3, opt %d)', [LI32, LOptLevel]);

      // 6: single_va(42) = 42
      gny_arg_push_int64(LEngine, 42);
      LI64 := gny_invoke(LEngine, PAnsiChar(UTF8Encode('single_va')), GNY_VT_INT64).AsInt64;
      Check(LI64 = 42, 'single_va(42) = %d (exp 42, opt %d)', [LI64, LOptLevel]);

      // 7: seq_next(10, 20, 30) = 60
      gny_arg_push_int64(LEngine, 10);
      gny_arg_push_int64(LEngine, 20);
      gny_arg_push_int64(LEngine, 30);
      LI64 := gny_invoke(LEngine, PAnsiChar(UTF8Encode('seq_next')), GNY_VT_INT64).AsInt64;
      Check(LI64 = 60, 'seq_next(10,20,30) = %d (exp 60, opt %d)', [LI64, LOptLevel]);
      // 8: sum_pairs(2, 3, 4, 5, 6) = 42
      gny_arg_push_int32(LEngine, 2);
      gny_arg_push_int64(LEngine, 3);
      gny_arg_push_int64(LEngine, 4);
      gny_arg_push_int64(LEngine, 5);
      gny_arg_push_int64(LEngine, 6);
      LI64 := gny_invoke(LEngine, PAnsiChar(UTF8Encode('sum_pairs')), GNY_VT_INT64).AsInt64;
      Check(LI64 = 42, 'sum_pairs(2, 3,4,5,6) = %d (exp 42, opt %d)', [LI64, LOptLevel]);

      // 9: sum_many(1..6) = 21
      gny_arg_push_int64(LEngine, 1);
      gny_arg_push_int64(LEngine, 2);
      gny_arg_push_int64(LEngine, 3);
      gny_arg_push_int64(LEngine, 4);
      gny_arg_push_int64(LEngine, 5);
      gny_arg_push_int64(LEngine, 6);
      LI64 := gny_invoke(LEngine, PAnsiChar(UTF8Encode('sum_many')), GNY_VT_INT64).AsInt64;
      Check(LI64 = 21, 'sum_many(1..6) = %d (exp 21, opt %d)', [LI64, LOptLevel]);

      // 10: zero_va(42) = 42
      gny_arg_push_int32(LEngine, 42);
      LI32 := gny_invoke(LEngine, PAnsiChar(UTF8Encode('zero_va')), GNY_VT_INT32).AsInt32;
      Check(LI32 = 42, 'zero_va(42) = %d (exp 42, opt %d)', [LI32, LOptLevel]);

      // 11: nested_va(10, 20) = 30
      gny_arg_push_int64(LEngine, 10);
      gny_arg_push_int64(LEngine, 20);
      LI64 := gny_invoke(LEngine, PAnsiChar(UTF8Encode('nested_va')), GNY_VT_INT64).AsInt64;
      Check(LI64 = 30, 'nested_va(10,20) = %d (exp 30, opt %d)', [LI64, LOptLevel]);

      // 12: script_calls_va() = 600
      LI64 := gny_invoke(LEngine, PAnsiChar(UTF8Encode('script_calls_va')), GNY_VT_INT64).AsInt64;
      Check(LI64 = 600, 'script_calls_va() = %d (exp 600, opt %d)', [LI64, LOptLevel]);

      gny_print_errors(LEngine);
    finally
      gny_destroy(LEngine);
    end;
  end;

  gny_unload();
end;

end.