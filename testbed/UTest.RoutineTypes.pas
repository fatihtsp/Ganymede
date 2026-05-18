{===============================================================================
  Ganymede™ - Embeddable Native Scripting Engine

  Copyright © 2026-present tinyBigGAMES™ LLC
  All Rights Reserved.

  See LICENSE for license information
===============================================================================}

unit UTest.RoutineTypes;

{$I Ganymede.Defines.inc}

interface

uses
  Ganymede.TestCase;

type
  TScriptRoutineTypesTest = class(TGnyTestCase)
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
{ TScriptRoutineTypesTest }

constructor TScriptRoutineTypesTest.Create();
begin
  inherited;
  Title := 'GanymedeScript — Routine Types & Function Pointers';
  Pause := True;
end;

procedure TScriptRoutineTypesTest.Run();
var
  LEngine: TGnyEngine;
  LVal: Int32;
  LOptLevel: Integer;
  LFile: string;
begin
  if not gny_load(PAnsiChar(UTF8Encode(CDllPath))) then
  begin
    Check(False, 'Failed to load Ganymede DLL');
    Exit;
  end;

  LFile := TPath.Combine(CTestDir, 'test_mem_routine_types.gny');

  for LOptLevel := GNY_OPT_NONE to GNY_OPT_FULL do
  begin
    Section('Routine Types — opt level %d', [LOptLevel]);
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

      LVal := gny_invoke(LEngine, PAnsiChar(UTF8Encode('test_basic')), GNY_VT_INT32).AsInt32;
      Check(LVal = 7, 'test_basic = %d (exp 7, opt %d)', [LVal, LOptLevel]);

      LVal := gny_invoke(LEngine, PAnsiChar(UTF8Encode('test_reassign')), GNY_VT_INT32).AsInt32;
      Check(LVal = 20, 'test_reassign = %d (exp 20, opt %d)', [LVal, LOptLevel]);

      LVal := gny_invoke(LEngine, PAnsiChar(UTF8Encode('test_callback')), GNY_VT_INT32).AsInt32;
      Check(LVal = 13, 'test_callback = %d (exp 13, opt %d)', [LVal, LOptLevel]);

      LVal := gny_invoke(LEngine, PAnsiChar(UTF8Encode('test_void_indirect')), GNY_VT_INT32).AsInt32;
      Check(LVal = 123, 'test_void_indirect = %d (exp 123, opt %d)', [LVal, LOptLevel]);

      LVal := gny_invoke(LEngine, PAnsiChar(UTF8Encode('test_nullary')), GNY_VT_INT32).AsInt32;
      Check(LVal = 7, 'test_nullary = %d (exp 7, opt %d)', [LVal, LOptLevel]);

      LVal := gny_invoke(LEngine, PAnsiChar(UTF8Encode('test_nullary_reassign')), GNY_VT_INT32).AsInt32;
      Check(LVal = 49, 'test_nullary_reassign = %d (exp 49, opt %d)', [LVal, LOptLevel]);
      LVal := gny_invoke(LEngine, PAnsiChar(UTF8Encode('test_array')), GNY_VT_INT32).AsInt32;
      Check(LVal = 50, 'test_array = %d (exp 50, opt %d)', [LVal, LOptLevel]);

      LVal := gny_invoke(LEngine, PAnsiChar(UTF8Encode('test_global')), GNY_VT_INT32).AsInt32;
      Check(LVal = 42, 'test_global = %d (exp 42, opt %d)', [LVal, LOptLevel]);

      LVal := gny_invoke(LEngine, PAnsiChar(UTF8Encode('test_chain')), GNY_VT_INT32).AsInt32;
      Check(LVal = 10, 'test_chain = %d (exp 10, opt %d)', [LVal, LOptLevel]);

      LVal := gny_invoke(LEngine, PAnsiChar(UTF8Encode('test_multi_callback')), GNY_VT_INT32).AsInt32;
      Check(LVal = 19, 'test_multi_callback = %d (exp 19, opt %d)', [LVal, LOptLevel]);

      LVal := gny_invoke(LEngine, PAnsiChar(UTF8Encode('test_loop')), GNY_VT_INT32).AsInt32;
      Check(LVal = 15, 'test_loop = %d (exp 15, opt %d)', [LVal, LOptLevel]);

      LVal := gny_invoke(LEngine, PAnsiChar(UTF8Encode('test_swap_callback')), GNY_VT_INT32).AsInt32;
      Check(LVal = 20, 'test_swap_callback = %d (exp 20, opt %d)', [LVal, LOptLevel]);

      gny_print_errors(LEngine);
    finally
      gny_destroy(LEngine);
    end;
  end;

  gny_unload();
end;

end.