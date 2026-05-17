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
  System.SysUtils,
  System.IOUtils,
  Ganymede.Utils,
  Ganymede.TestCase,
  Ganymede,
  Ganymede.Native,
  UCommon;

type
  TScriptConditionalCompTest = class(TGnyTestCase)
  public
    constructor Create(); override;
  protected
    procedure Run(); override;
  end;

implementation

{ TScriptConditionalCompTest }

constructor TScriptConditionalCompTest.Create();
begin
  inherited;
  Title := 'GanymedeScript — Conditional Compilation';
  Pause := True;
end;

procedure TScriptConditionalCompTest.Run();
var
  LScript: TGanymede;
  LResult: Int64;
  LExpected: Int64;
  LOptLevel: TGnyOptLevel;
  LOrd: Integer;
  LFile: string;
begin
  LFile := TPath.Combine(CTestDir, 'test_mem_conditional_comp.gny');

  for LOptLevel := Low(TGnyOptLevel) to High(TGnyOptLevel) do
  begin
    LOrd := Ord(LOptLevel);
    Section('Conditional Compilation — opt level %d', [LOrd]);
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

      // 1: @ifdef WINDOWS — platform symbol, true branch
      LResult := LScript.Invoke('platform_check', [], gvtInt64).AsInt64;
      Check(LResult = 1,
        'platform_check() = %d (exp 1, opt %d)', [LResult, LOrd]);

      // 2: @ifndef LINUX — undefined symbol, true branch
      LResult := LScript.Invoke('ifndef_check', [], gvtInt64).AsInt64;
      Check(LResult = 1,
        'ifndef_check() = %d (exp 1, opt %d)', [LResult, LOrd]);

      // 3: @ifdef LINUX + @else — false branch, else taken
      LResult := LScript.Invoke('else_check', [], gvtInt64).AsInt64;
      Check(LResult = 2,
        'else_check() = %d (exp 2, opt %d)', [LResult, LOrd]);

      // 4: @define + @ifdef — user-defined symbol
      LResult := LScript.Invoke('define_check', [], gvtInt64).AsInt64;
      Check(LResult = 42,
        'define_check() = %d (exp 42, opt %d)', [LResult, LOrd]);

      // 5: @define + @undef + @ifdef — symbol removed
      LResult := LScript.Invoke('undef_check', [], gvtInt64).AsInt64;
      Check(LResult = 99,
        'undef_check() = %d (exp 99, opt %d)', [LResult, LOrd]);

      // 6: Nested @ifdef WINDOWS + @ifdef BUILD_MEM — both true
      LResult := LScript.Invoke('nested_check', [], gvtInt64).AsInt64;
      Check(LResult = 77,
        'nested_check() = %d (exp 77, opt %d)', [LResult, LOrd]);

      // 7: @elseif chain — LINUX false, WINDOWS true
      LResult := LScript.Invoke('elseif_check', [], gvtInt64).AsInt64;
      Check(LResult = 55,
        'elseif_check() = %d (exp 55, opt %d)', [LResult, LOrd]);

      // 8: BUILD_MEM predefined
      LResult := LScript.Invoke('buildmem_check', [], gvtInt64).AsInt64;
      Check(LResult = 1,
        'buildmem_check() = %d (exp 1, opt %d)', [LResult, LOrd]);

      // 9: GANYMEDE engine symbol
      LResult := LScript.Invoke('ganymede_check', [], gvtInt64).AsInt64;
      Check(LResult = 1,
        'ganymede_check() = %d (exp 1, opt %d)', [LResult, LOrd]);

      // 10: DEBUG vs RELEASE — varies per opt level
      // olNone → DEBUG → 1, olBasic/olFull → RELEASE → 2
      if LOptLevel = olNone then
        LExpected := 1
      else
        LExpected := 2;
      LResult := LScript.Invoke('optlevel_check', [], gvtInt64).AsInt64;
      Check(LResult = LExpected,
        'optlevel_check() = %d (exp %d, opt %d)', [LResult, LExpected, LOrd]);

      // 11: @ifndef with DEFINED symbol — @else taken
      LResult := LScript.Invoke('ifndef_defined_check', [], gvtInt64).AsInt64;
      Check(LResult = 3,
        'ifndef_defined_check() = %d (exp 3, opt %d)', [LResult, LOrd]);

      // 12: @elseif first branch true — second must NOT activate
      LResult := LScript.Invoke('elseif_first_wins', [], gvtInt64).AsInt64;
      Check(LResult = 10,
        'elseif_first_wins() = %d (exp 10, opt %d)', [LResult, LOrd]);

      // 13: Nested with outer false + @define in false block ignored
      LResult := LScript.Invoke('outer_false_check', [], gvtInt64).AsInt64;
      Check(LResult = 88,
        'outer_false_check() = %d (exp 88, opt %d)', [LResult, LOrd]);

      // 14: Multiple platform symbols — WIN64+CPUX64+TARGET_WIN64+MSWINDOWS = 1+2+4+8 = 15
      LResult := LScript.Invoke('platform_multi', [], gvtInt64).AsInt64;
      Check(LResult = 15,
        'platform_multi() = %d (exp 15, opt %d)', [LResult, LOrd]);

      // 15: @elseif chain where NO branch matches — @else taken
      LResult := LScript.Invoke('elseif_none_match', [], gvtInt64).AsInt64;
      Check(LResult = 66,
        'elseif_none_match() = %d (exp 66, opt %d)', [LResult, LOrd]);

      // 16: @ifdef without @else — only emits when true
      LResult := LScript.Invoke('ifdef_no_else', [], gvtInt64).AsInt64;
      Check(LResult = 7,
        'ifdef_no_else() = %d (exp 7, opt %d)', [LResult, LOrd]);

      // 17: APPTYPE_CONSOLE — testbed is a console app
      LResult := LScript.Invoke('apptype_check', [], gvtInt64).AsInt64;
      Check(LResult = 1,
        'apptype_check() = %d (exp 1, opt %d)', [LResult, LOrd]);

      // 18: Print detected defines (visual confirmation)
      LScript.Invoke('print_defines', []);

      FlushErrors(LScript.GetErrors());
    finally
      LScript.Free();
    end;
  end;
end;

end.
