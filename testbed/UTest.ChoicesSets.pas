{===============================================================================
  Ganymede™ - Embeddable Native Scripting Engine

  Copyright © 2026-present tinyBigGAMES™ LLC
  All Rights Reserved.

  See LICENSE for license information
===============================================================================}

unit UTest.ChoicesSets;

{$I Ganymede.Defines.inc}

interface

uses
  Ganymede.TestCase;

type
  TScriptChoicesSetsTest = class(TGnyTestCase)
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
{ TScriptChoicesSetsTest }

constructor TScriptChoicesSetsTest.Create();
begin
  inherited;
  Title := 'GanymedeScript — Choices & Sets';
  Pause := True;
end;

procedure TScriptChoicesSetsTest.Run();
var
  LEngine: TGnyEngine;
  LResult: Int32;
  LOptLevel: Integer;
  LFile: string;
begin
  if not gny_load(PAnsiChar(UTF8Encode(CDllPath))) then
  begin
    Check(False, 'Failed to load Ganymede DLL');
    Exit;
  end;

  LFile := TPath.Combine(CTestDir, 'test_mem_choices_sets.gny');

  for LOptLevel := GNY_OPT_NONE to GNY_OPT_FULL do
  begin
    Section('Choices & Sets — opt level %d', [LOptLevel]);
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

      LResult := gny_invoke(LEngine, PAnsiChar(UTF8Encode('enumval')), GNY_VT_INT32).AsInt32;
      Check(LResult = 1, 'enumval() = %d (expected 1, opt %d)', [LResult, LOptLevel]);

      LResult := gny_invoke(LEngine, PAnsiChar(UTF8Encode('explicitval')), GNY_VT_INT32).AsInt32;
      Check(LResult = 10, 'explicitval() = %d (expected 10, opt %d)', [LResult, LOptLevel]);

      LResult := gny_invoke(LEngine, PAnsiChar(UTF8Encode('enumfirst')), GNY_VT_INT32).AsInt32;
      Check(LResult = 0, 'enumfirst() = %d (expected 0, opt %d)', [LResult, LOptLevel]);

      LResult := gny_invoke(LEngine, PAnsiChar(UTF8Encode('enumlast')), GNY_VT_INT32).AsInt32;
      Check(LResult = 2, 'enumlast() = %d (expected 2, opt %d)', [LResult, LOptLevel]);

      LResult := gny_invoke(LEngine, PAnsiChar(UTF8Encode('setmember')), GNY_VT_INT32).AsInt32;
      Check(LResult = 1, 'setmember() = %d (expected 1, opt %d)', [LResult, LOptLevel]);

      LResult := gny_invoke(LEngine, PAnsiChar(UTF8Encode('setnomember')), GNY_VT_INT32).AsInt32;
      Check(LResult = 0, 'setnomember() = %d (expected 0, opt %d)', [LResult, LOptLevel]);

      LResult := gny_invoke(LEngine, PAnsiChar(UTF8Encode('setempty')), GNY_VT_INT32).AsInt32;
      Check(LResult = 0, 'setempty() = %d (expected 0, opt %d)', [LResult, LOptLevel]);

      LResult := gny_invoke(LEngine, PAnsiChar(UTF8Encode('setboundary')), GNY_VT_INT32).AsInt32;
      Check(LResult = 1, 'setboundary() = %d (expected 1, opt %d)', [LResult, LOptLevel]);

    finally
      gny_destroy(LEngine);
    end;
  end;

  gny_unload();
end;

end.