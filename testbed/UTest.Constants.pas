{===============================================================================
  Ganymede™ - Embeddable Native Scripting Engine

  Copyright © 2026-present tinyBigGAMES™ LLC
  All Rights Reserved.

  See LICENSE for license information
===============================================================================}

unit UTest.Constants;

{$I Ganymede.Defines.inc}

interface

uses
  Ganymede.TestCase;

type
  TScriptConstantsTest = class(TGnyTestCase)
  public
    constructor Create(); override;
  protected
    procedure Run(); override;
  end;

implementation

uses
  UCommon,
  Ganymede;

const
  CConstSource =
  '''
  module mem consttest;

  public routine compute(x: int32): int32;
  const
    BASE: int32 = 100;
    MULT: int32 = 3;
  var
    result: int32;
  begin
    result := BASE + x * MULT;
    return result;
  end;

  end.
  ''';

  CConstAssignSource =
  '''
  module mem constassign;

  public routine bad(): int32;
  const
    LIMIT: int32 = 50;
  begin
    LIMIT := 99;
    return LIMIT;
  end;

  end.
  ''';

type
  TComputeFunc = function(x: Int32): Int32;

{ TScriptConstantsTest }

constructor TScriptConstantsTest.Create();
begin
  inherited;
  Title := 'PxlScript — Constants';
  Pause := True;
end;

procedure TScriptConstantsTest.Run();
var
  LEngine: TGnyEngine;
  LResult: Int64;
  LCompute: TComputeFunc;
  LOptLevel: Integer;
begin
  if not gny_load(PAnsiChar(UTF8Encode(CDllPath))) then
  begin
    Check(False, 'Failed to load Ganymede DLL');
    Exit;
  end;

  // --- Test 1: Constants used in arithmetic ---
  for LOptLevel := GNY_OPT_NONE to GNY_OPT_FULL do
  begin
    Section('Constants — Compile & JIT (opt level %d)', [LOptLevel]);
    LEngine := gny_create();
    try
      gny_set_optimization_level(LEngine, LOptLevel);
      gny_load_from_string(LEngine,
        PAnsiChar(UTF8Encode(CConstSource)),
        PAnsiChar(UTF8Encode('consttest.pxs')));

      if not gny_compile(LEngine) then
      begin
        gny_print_errors(LEngine);
        Check(False, 'Compile failed (opt %d)', [LOptLevel]);
        Continue;
      end;

      Check(True, 'Compiled successfully (opt %d)', [LOptLevel]);

      // compute(5) = 100 + 5*3 = 115
      gny_arg_push_int32(LEngine, 5);
      LResult := gny_invoke(LEngine,
        PAnsiChar(UTF8Encode('compute')), GNY_VT_INT64).AsInt64;
      Check(LResult = 115, 'compute(5) = %d (expected 115, opt %d)',
        [LResult, LOptLevel]);

      LCompute := gny_get_symbol(LEngine,
        PAnsiChar(UTF8Encode('compute')));
      LResult := LCompute(5);
      Check(LResult = 115, 'direct compute(5) = %d (expected 115, opt %d)',
        [LResult, LOptLevel]);

      // compute(0) = 100 + 0*3 = 100
      gny_arg_push_int32(LEngine, 0);
      LResult := gny_invoke(LEngine,
        PAnsiChar(UTF8Encode('compute')), GNY_VT_INT64).AsInt64;
      Check(LResult = 100, 'compute(0) = %d (expected 100, opt %d)',
        [LResult, LOptLevel]);

      // compute(-10) = 100 + (-10)*3 = 70
      gny_arg_push_int32(LEngine, -10);
      LResult := gny_invoke(LEngine,
        PAnsiChar(UTF8Encode('compute')), GNY_VT_INT64).AsInt64;
      Check(LResult = 70, 'compute(-10) = %d (expected 70, opt %d)',
        [LResult, LOptLevel]);
    finally
      gny_destroy(LEngine);
    end;
  end;

  // --- Test 2: Assignment to const must fail ---
  Section('Constants — Immutability check');
  LEngine := gny_create();
  try
    gny_load_from_string(LEngine,
      PAnsiChar(UTF8Encode(CConstAssignSource)),
      PAnsiChar(UTF8Encode('constassign.pxs')));

    if gny_compile(LEngine) then
      Check(False, 'Compile should have failed (assignment to const)')
    else
      Check(True, 'Correctly rejected assignment to constant');
  finally
    gny_destroy(LEngine);
  end;

  gny_unload();
end;

end.