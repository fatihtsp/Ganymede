{===============================================================================
  Ganymede™ - Embeddable Native Scripting Engine

  Copyright © 2026-present tinyBigGAMES™ LLC
  All Rights Reserved.

  See LICENSE for license information
===============================================================================}

unit UTest.NumericOps;

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
  System.Math,
  UCommon,
  Ganymede;

const
  CNumericSource =
  '''
  module mem numops;

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
  LEngine: TGnyEngine;
  LIntResult: Int64;
  LFloatResult: Double;
  LOptLevel: Integer;
begin
  if not gny_load(PAnsiChar(UTF8Encode(CDllPath))) then
  begin
    Check(False, 'Failed to load Ganymede DLL');
    Exit;
  end;

  for LOptLevel := GNY_OPT_NONE to GNY_OPT_FULL do
  begin
    Section('Numeric Ops — opt level %d', [LOptLevel]);
    LEngine := gny_create();
    try
      gny_set_optimization_level(LEngine, LOptLevel);
      gny_load_from_string(LEngine,
        PAnsiChar(UTF8Encode(CNumericSource)),
        PAnsiChar(UTF8Encode('numops.pxs')));

      if not gny_compile(LEngine) then
      begin
        gny_print_errors(LEngine);
        Check(False, 'Compile failed (opt %d)', [LOptLevel]);
        Continue;
      end;

      Check(True, 'Compiled successfully (opt %d)', [LOptLevel]);

      // intops(10): div=3, mod=1, xor=15, shl=20, shr=2 → 41
      gny_arg_push_int32(LEngine, 10);
      LIntResult := gny_invoke(LEngine,
        PAnsiChar(UTF8Encode('intops')), GNY_VT_INT64).AsInt64;
      Check(LIntResult = 41,
        'intops(10) = %d (expected 41, opt %d)', [LIntResult, LOptLevel]);

      // floatconst(): 10.5 + 3.0*2.0 - 1.5 = 15.0
      LFloatResult := gny_invoke(LEngine,
        PAnsiChar(UTF8Encode('floatconst')), GNY_VT_FLOAT64).AsFloat64;
      Check(SameValue(LFloatResult, 15.0, 0.001),
        'floatconst() = %.4f (expected 15.0, opt %d)', [LFloatResult, LOptLevel]);

      // mixed(5): 5 * 2.5 + 1.0 = 13.5
      gny_arg_push_int32(LEngine, 5);
      LFloatResult := gny_invoke(LEngine,
        PAnsiChar(UTF8Encode('mixed')), GNY_VT_FLOAT64).AsFloat64;
      Check(SameValue(LFloatResult, 13.5, 0.001),
        'mixed(5) = %.4f (expected 13.5, opt %d)', [LFloatResult, LOptLevel]);

      // slashdiv(7, 2): 7 / 2 = 3.5
      gny_arg_push_int32(LEngine, 7);
      gny_arg_push_int32(LEngine, 2);
      LFloatResult := gny_invoke(LEngine,
        PAnsiChar(UTF8Encode('slashdiv')), GNY_VT_FLOAT64).AsFloat64;
      Check(SameValue(LFloatResult, 3.5, 0.001),
        'slashdiv(7,2) = %.4f (expected 3.5, opt %d)', [LFloatResult, LOptLevel]);
    finally
      gny_destroy(LEngine);
    end;
  end;

  gny_unload();
end;

end.