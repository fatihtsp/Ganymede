{===============================================================================
  Ganymede™ - Embeddable Native Scripting Engine

  Copyright © 2026-present tinyBigGAMES™ LLC
  All Rights Reserved.

  See LICENSE for license information
===============================================================================}

unit UTest.VarAssign;

{$I Ganymede.Defines.inc}

interface

uses
  Ganymede.TestCase;

type
  TScriptVarAssignTest = class(TGnyTestCase)
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
  CVarAssignSource =
  '''
  module mem vartest;

  public routine compute(x: int32): int32;
  var
    a: int32;
    b: int32 = 10;
    c: int32;
  begin
    a := x;
    b += a;
    c := b * 2;
    c -= 1;
    return c;
  end;

  end.
  ''';

type
  TComputeFunc = function(x: Int32): Int32;

{ TScriptVarAssignTest }

constructor TScriptVarAssignTest.Create();
begin
  inherited;
  Title := 'PxlScript — Variables & Assignment';
  Pause := True;
end;

procedure TScriptVarAssignTest.Run();
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

  for LOptLevel := GNY_OPT_NONE to GNY_OPT_FULL do
  begin
    Section('Compile & JIT (opt level %d)', [LOptLevel]);
    LEngine := gny_create();
    try
      gny_set_optimization_level(LEngine, LOptLevel);
      gny_load_from_string(LEngine,
        PAnsiChar(UTF8Encode(CVarAssignSource)),
        PAnsiChar(UTF8Encode('vartest.pxs')));

      if not gny_compile(LEngine) then
      begin
        gny_print_errors(LEngine);
        Check(False, 'Compile failed (opt %d)', [LOptLevel]);
        Continue;
      end;

      Check(True, 'Compiled successfully (opt %d)', [LOptLevel]);

      gny_arg_push_int32(LEngine, 5);
      LResult := gny_invoke(LEngine,
        PAnsiChar(UTF8Encode('compute')), GNY_VT_INT64).AsInt64;
      Check(LResult = 29, 'compute(5) = %d (expected 29, opt %d)',
        [LResult, LOptLevel]);

      LCompute := gny_get_symbol(LEngine,
        PAnsiChar(UTF8Encode('compute')));
      LResult := LCompute(5);
      Check(LResult = 29, 'direct compute(5) = %d (expected 29, opt %d)',
        [LResult, LOptLevel]);

      gny_arg_push_int32(LEngine, 0);
      LResult := gny_invoke(LEngine,
        PAnsiChar(UTF8Encode('compute')), GNY_VT_INT64).AsInt64;
      Check(LResult = 19, 'compute(0) = %d (expected 19, opt %d)',
        [LResult, LOptLevel]);

      gny_arg_push_int32(LEngine, -3);
      LResult := gny_invoke(LEngine,
        PAnsiChar(UTF8Encode('compute')), GNY_VT_INT64).AsInt64;
      Check(LResult = 13, 'compute(-3) = %d (expected 13, opt %d)',
        [LResult, LOptLevel]);
    finally
      gny_destroy(LEngine);
    end;
  end;

  gny_unload();
end;

end.