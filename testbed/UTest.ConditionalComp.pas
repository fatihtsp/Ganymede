{===============================================================================
  Ganymede™ - Embeddable Native Scripting Engine

  Copyright © 2026-present tinyBigGAMES™ LLC
  All Rights Reserved.

  See LICENSE for license information
===============================================================================}

unit UTest.ConditionalComp;

{$I Ganymede.Defines.inc}

interface

uses
  Ganymede.TestCase;

type
  TScriptConditionalCompTest = class(TGnyTestCase)
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
{ TScriptConditionalCompTest }

constructor TScriptConditionalCompTest.Create();
begin
  inherited;
  Title := 'GanymedeScript — Conditional Compilation';
  Pause := True;
end;

procedure TScriptConditionalCompTest.Run();
var
  LEngine: TGnyEngine;
  LResult: Int64;
  LExpected: Int64;
  LOptLevel: Integer;
  LFile: string;
begin
  if not gny_load(PAnsiChar(UTF8Encode(CDllPath))) then
  begin
    Check(False, 'Failed to load Ganymede DLL');
    Exit;
  end;

  LFile := TPath.Combine(CTestDir, 'test_mem_conditional_comp.gny');

  for LOptLevel := GNY_OPT_NONE to GNY_OPT_FULL do
  begin
    Section('Conditional Compilation — opt level %d', [LOptLevel]);
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

      LResult := gny_invoke(LEngine, PAnsiChar(UTF8Encode('platform_check')), GNY_VT_INT64).AsInt64;
      Check(LResult = 1, 'platform_check() = %d (exp 1, opt %d)', [LResult, LOptLevel]);

      LResult := gny_invoke(LEngine, PAnsiChar(UTF8Encode('ifndef_check')), GNY_VT_INT64).AsInt64;
      Check(LResult = 1, 'ifndef_check() = %d (exp 1, opt %d)', [LResult, LOptLevel]);

      LResult := gny_invoke(LEngine, PAnsiChar(UTF8Encode('else_check')), GNY_VT_INT64).AsInt64;
      Check(LResult = 2, 'else_check() = %d (exp 2, opt %d)', [LResult, LOptLevel]);

      LResult := gny_invoke(LEngine, PAnsiChar(UTF8Encode('define_check')), GNY_VT_INT64).AsInt64;
      Check(LResult = 42, 'define_check() = %d (exp 42, opt %d)', [LResult, LOptLevel]);

      LResult := gny_invoke(LEngine, PAnsiChar(UTF8Encode('undef_check')), GNY_VT_INT64).AsInt64;
      Check(LResult = 99, 'undef_check() = %d (exp 99, opt %d)', [LResult, LOptLevel]);

      LResult := gny_invoke(LEngine, PAnsiChar(UTF8Encode('nested_check')), GNY_VT_INT64).AsInt64;
      Check(LResult = 77, 'nested_check() = %d (exp 77, opt %d)', [LResult, LOptLevel]);

      LResult := gny_invoke(LEngine, PAnsiChar(UTF8Encode('elseif_check')), GNY_VT_INT64).AsInt64;
      Check(LResult = 55, 'elseif_check() = %d (exp 55, opt %d)', [LResult, LOptLevel]);

      LResult := gny_invoke(LEngine, PAnsiChar(UTF8Encode('buildmem_check')), GNY_VT_INT64).AsInt64;
      Check(LResult = 1, 'buildmem_check() = %d (exp 1, opt %d)', [LResult, LOptLevel]);

      LResult := gny_invoke(LEngine, PAnsiChar(UTF8Encode('ganymede_check')), GNY_VT_INT64).AsInt64;
      Check(LResult = 1, 'ganymede_check() = %d (exp 1, opt %d)', [LResult, LOptLevel]);
      // 10: DEBUG vs RELEASE — varies per opt level
      if LOptLevel = GNY_OPT_NONE then
        LExpected := 1
      else
        LExpected := 2;
      LResult := gny_invoke(LEngine, PAnsiChar(UTF8Encode('optlevel_check')), GNY_VT_INT64).AsInt64;
      Check(LResult = LExpected, 'optlevel_check() = %d (exp %d, opt %d)', [LResult, LExpected, LOptLevel]);

      LResult := gny_invoke(LEngine, PAnsiChar(UTF8Encode('ifndef_defined_check')), GNY_VT_INT64).AsInt64;
      Check(LResult = 3, 'ifndef_defined_check() = %d (exp 3, opt %d)', [LResult, LOptLevel]);

      LResult := gny_invoke(LEngine, PAnsiChar(UTF8Encode('elseif_first_wins')), GNY_VT_INT64).AsInt64;
      Check(LResult = 10, 'elseif_first_wins() = %d (exp 10, opt %d)', [LResult, LOptLevel]);

      LResult := gny_invoke(LEngine, PAnsiChar(UTF8Encode('outer_false_check')), GNY_VT_INT64).AsInt64;
      Check(LResult = 88, 'outer_false_check() = %d (exp 88, opt %d)', [LResult, LOptLevel]);

      LResult := gny_invoke(LEngine, PAnsiChar(UTF8Encode('platform_multi')), GNY_VT_INT64).AsInt64;
      Check(LResult = 15, 'platform_multi() = %d (exp 15, opt %d)', [LResult, LOptLevel]);

      LResult := gny_invoke(LEngine, PAnsiChar(UTF8Encode('elseif_none_match')), GNY_VT_INT64).AsInt64;
      Check(LResult = 66, 'elseif_none_match() = %d (exp 66, opt %d)', [LResult, LOptLevel]);

      LResult := gny_invoke(LEngine, PAnsiChar(UTF8Encode('ifdef_no_else')), GNY_VT_INT64).AsInt64;
      Check(LResult = 7, 'ifdef_no_else() = %d (exp 7, opt %d)', [LResult, LOptLevel]);

      LResult := gny_invoke(LEngine, PAnsiChar(UTF8Encode('apptype_check')), GNY_VT_INT64).AsInt64;
      Check(LResult = 1, 'apptype_check() = %d (exp 1, opt %d)', [LResult, LOptLevel]);

      // 18: Print detected defines (visual confirmation)
      gny_invoke(LEngine, PAnsiChar(UTF8Encode('print_defines')), GNY_VT_VOID);

      gny_print_errors(LEngine);
    finally
      gny_destroy(LEngine);
    end;
  end;

  gny_unload();
end;

end.