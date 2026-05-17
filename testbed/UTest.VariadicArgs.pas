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
  System.SysUtils,
  System.IOUtils,
  Ganymede.Utils,
  Ganymede.TestCase,
  Ganymede.Core,
  Ganymede.Native,
  UCommon;

type
  TScriptVariadicArgsTest = class(TGnyTestCase)
  public
    constructor Create(); override;
  protected
    procedure Run(); override;
  end;

implementation

{ TScriptVariadicArgsTest }

constructor TScriptVariadicArgsTest.Create();
begin
  inherited;
  Title := 'GanymedeScript — Variadic Arguments';
  Pause := True;
end;

procedure TScriptVariadicArgsTest.Run();
var
  LScript: TGanymede;
  LI64: Int64;
  LI32: Int32;
  LF64: Double;
  LOptLevel: TGnyOptLevel;
  LOrd: Integer;
  LFile: string;
begin
  LFile := TPath.Combine(CTestDir, 'test_mem_variadic_args.gny');

  for LOptLevel := Low(TGnyOptLevel) to High(TGnyOptLevel) do
  begin
    LOrd := Ord(LOptLevel);
    Section('Variadic Arguments — opt level %d', [LOrd]);
    LScript := TGanymede.Create();
    try
      LScript.SetOptimizationLevel(LOptLevel);
      LScript.LoadFromFile(LFile);

      if not LScript.Compile() then
      begin
        FlushErrors(LScript.GetErrors());
        Check(False, 'Compile failed (opt %d)', [LOrd]);
        Continue;
      end;

      Check(True, 'Compiled successfully (opt %d)', [LOrd]);

      // 1: sum_ints — basic loop with next()
      LI64 := LScript.Invoke('sum_ints', [3, Int64(10), Int64(20), Int64(30)], gvtInt64).AsInt64;
      Check(LI64 = 60, 'sum_ints(3, 10,20,30) = %d (exp 60, opt %d)', [LI64, LOrd]);

      // 2: va_count_test — standalone varargs count
      LI32 := LScript.Invoke('va_count_test', [Int64(1), Int64(2), Int64(3), Int64(4), Int64(5)], gvtInt32).AsInt32;
      Check(LI32 = 5, 'va_count_test(1..5) = %d (exp 5, opt %d)', [LI32, LOrd]);

      // 3: sum_i32 — int32 varargs
      LI32 := LScript.Invoke('sum_i32', [2, 100, 200], gvtInt32).AsInt32;
      Check(LI32 = 300, 'sum_i32(2, 100,200) = %d (exp 300, opt %d)', [LI32, LOrd]);

      // 4: sum_f64 — float64 varargs
      LF64 := LScript.Invoke('sum_f64', [3, 1.5, 2.5, 3.0], gvtFloat64).AsFloat64;
      Check(Abs(LF64 - 7.0) < 0.001, 'sum_f64(3, 1.5,2.5,3.0) = %.2f (exp 7.0, opt %d)', [LF64, LOrd]);

      // 5: count_after_fixed — varargs.count with fixed params
      LI32 := LScript.Invoke('count_after_fixed', [10, 20, Int64(1), Int64(2), Int64(3)], gvtInt32).AsInt32;
      Check(LI32 = 3, 'count_after_fixed(10,20, 1,2,3) = %d (exp 3, opt %d)', [LI32, LOrd]);

      // 6: single_va — single variadic arg
      LI64 := LScript.Invoke('single_va', [Int64(42)], gvtInt64).AsInt64;
      Check(LI64 = 42, 'single_va(42) = %d (exp 42, opt %d)', [LI64, LOrd]);

      // 7: seq_next — sequential next() without loop
      LI64 := LScript.Invoke('seq_next', [Int64(10), Int64(20), Int64(30)], gvtInt64).AsInt64;
      Check(LI64 = 60, 'seq_next(10,20,30) = %d (exp 60, opt %d)', [LI64, LOrd]);

      // 8: sum_pairs — multiple next() per loop iteration: 3*4 + 5*6 = 42
      LI64 := LScript.Invoke('sum_pairs', [2, Int64(3), Int64(4), Int64(5), Int64(6)], gvtInt64).AsInt64;
      Check(LI64 = 42, 'sum_pairs(2, 3,4,5,6) = %d (exp 42, opt %d)', [LI64, LOrd]);

      // 9: sum_many — 6 varargs (stack spill past R8/R9): 1+2+3+4+5+6 = 21
      LI64 := LScript.Invoke('sum_many', [Int64(1), Int64(2), Int64(3), Int64(4), Int64(5), Int64(6)], gvtInt64).AsInt64;
      Check(LI64 = 21, 'sum_many(1..6) = %d (exp 21, opt %d)', [LI64, LOrd]);

      // 10: zero_va — no variadic args, only fixed param
      LI32 := LScript.Invoke('zero_va', [42], gvtInt32).AsInt32;
      Check(LI32 = 42, 'zero_va(42) = %d (exp 42, opt %d)', [LI32, LOrd]);

      // 11: nested_va — varargs.next() passed to another function
      LI64 := LScript.Invoke('nested_va', [Int64(10), Int64(20)], gvtInt64).AsInt64;
      Check(LI64 = 30, 'nested_va(10,20) = %d (exp 30, opt %d)', [LI64, LOrd]);

      // 12: script_calls_va — script-to-script variadic call
      LI64 := LScript.Invoke('script_calls_va', [], gvtInt64).AsInt64;
      Check(LI64 = 600, 'script_calls_va() = %d (exp 600, opt %d)', [LI64, LOrd]);

      FlushErrors(LScript.GetErrors());
    finally
      LScript.Free();
    end;
  end;
end;

end.
