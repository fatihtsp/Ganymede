{===============================================================================
  Ganymede™ - Embeddable Native Scripting Engine

  Copyright © 2026-present tinyBigGAMES™ LLC
  All Rights Reserved.

  See LICENSE for license information
===============================================================================}

unit UTest.Script.NumericOps;

{$I Ganymede.Defines.inc}

interface

uses
  Ganymede.TestCase;

type
  TScriptNumericOpsTest = class(TGnyTestCase)
  public
    constructor Create(); override;
  protected
    procedure Run(); override;
  end;

implementation

uses
  System.SysUtils,
  System.Math,
  Ganymede.Utils,
  Ganymede.Native,
  Ganymede;

const
  CNumericSource =
  '''
  module jit numops;

  // Test integer div, mod, xor, shl, shr
  public routine intops(x: int32): int32;
  var
    a: int32;
  begin
    a := x div 3;
    a := a + (x mod 3);
    a := a + (x xor 5);
    a := a + (x shl 1);
    a := a + (x shr 2);
    return a;
  end;

  // Test float constant arithmetic
  public routine floatconst(): float64;
  const
    A: float64 = 10.5;
    B: float64 = 3.0;
  var
    r: float64;
  begin
    r := A + B * 2.0 - 1.5;
    return r;
  end;

  // Test mixed int/float promotion
  public routine mixed(x: int32): float64;
  const
    FACTOR: float64 = 2.5;
  begin
    return x * FACTOR + 1.0;
  end;

  // Test / always returns float
  public routine slashdiv(a: int32; b: int32): float64;
  begin
    return a / b;
  end;

  end.
  ''';

{ TScriptNumericOpsTest }

constructor TScriptNumericOpsTest.Create();
begin
  inherited;
  Title := 'PxlScript — Numeric Types & Operators';
  Pause := True;
end;

procedure TScriptNumericOpsTest.Run();
var
  LScript: TGanymede;
  LIntResult: Int64;
  LFloatResult: Double;
  LOptLevel: TGnyOptLevel;
  LOrd: Integer;
begin
  for LOptLevel := Low(TGnyOptLevel) to High(TGnyOptLevel) do
  begin
    LOrd := Ord(LOptLevel);
    Section('Numeric Ops — opt level %d', [LOrd]);
    LScript := TGanymede.Create();
    try
      LScript.SetOptimizationLevel(LOptLevel);
      LScript.LoadFromString(CNumericSource, 'numops.pxs');

      if not LScript.Compile() then
      begin
        FlushErrors(LScript.GetErrors());
        Check(False, 'Compile failed (opt %d)', [LOrd]);
        Continue;
      end;

      Check(True, 'Compiled successfully (opt %d)', [LOrd]);

      // intops(10): div=3, mod=1, xor=15, shl=20, shr=2 → 41
      LIntResult := LScript.Invoke('intops', [10], vtInt64).AsInt64;
      Check(LIntResult = 41,
        'intops(10) = %d (expected 41, opt %d)', [LIntResult, LOrd]);

      // floatconst(): 10.5 + 3.0*2.0 - 1.5 = 15.0
      LFloatResult := LScript.Invoke('floatconst', [], vtFloat64).AsFloat64;
      Check(SameValue(LFloatResult, 15.0, 0.001),
        'floatconst() = %.4f (expected 15.0, opt %d)', [LFloatResult, LOrd]);

      // mixed(5): 5 * 2.5 + 1.0 = 13.5
      LFloatResult := LScript.Invoke('mixed', [5], vtFloat64).AsFloat64;
      Check(SameValue(LFloatResult, 13.5, 0.001),
        'mixed(5) = %.4f (expected 13.5, opt %d)', [LFloatResult, LOrd]);

      // slashdiv(7, 2): 7 / 2 = 3.5
      LFloatResult := LScript.Invoke('slashdiv', [7, 2], vtFloat64).AsFloat64;
      Check(SameValue(LFloatResult, 3.5, 0.001),
        'slashdiv(7,2) = %.4f (expected 3.5, opt %d)', [LFloatResult, LOrd]);
    finally
      LScript.Free();
    end;
  end;
end;

end.
