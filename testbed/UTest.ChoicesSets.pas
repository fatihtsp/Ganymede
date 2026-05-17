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
  System.SysUtils,
  System.IOUtils,
  Ganymede.Utils,
  Ganymede.TestCase,
  Ganymede,
  Ganymede.Native,
  UCommon;

type
  TScriptChoicesSetsTest = class(TGnyTestCase)
  public
    constructor Create(); override;
  protected
    procedure Run(); override;
  end;

implementation

{ TScriptChoicesSetsTest }

constructor TScriptChoicesSetsTest.Create();
begin
  inherited;
  Title := 'GanymedeScript — Choices & Sets';
  Pause := True;
end;

procedure TScriptChoicesSetsTest.Run();
var
  LScript: TGanymede;
  LResult: Int32;
  LOptLevel: TGnyOptLevel;
  LOrd: Integer;
  LFile: string;
begin
  LFile := TPath.Combine(CTestDir, 'test_mem_choices_sets.gny');

  for LOptLevel := Low(TGnyOptLevel) to High(TGnyOptLevel) do
  begin
    LOrd := Ord(LOptLevel);
    Section('Choices & Sets — opt level %d', [LOrd]);
    LScript := TGanymede.Create();
    try
      //LScript.SetDumpIR(True);
      LScript.SetOptimizationLevel(LOptLevel);
      LScript.LoadFromFile(LFile);

      if not LScript.Compile() then
      begin
        FlushErrors(LScript.GetErrors());
        Check(False, 'Compile failed (opt %d)', [LOrd]);
        Continue;
      end;

      //WriteLn(LScript.GetSSADump());

      Check(True, 'Compiled successfully (opt %d)', [LOrd]);

      // Enum — auto ordinal: green = 1
      LResult := LScript.Invoke('enumval', [], gvtInt32).AsInt32;
      Check(LResult = 1,
        'enumval() = %d (expected 1, opt %d)', [LResult, LOrd]);

      // Enum — explicit ordinal: fail = 10
      LResult := LScript.Invoke('explicitval', [], gvtInt32).AsInt32;
      Check(LResult = 10,
        'explicitval() = %d (expected 10, opt %d)', [LResult, LOrd]);

      // Enum — first: red = 0
      LResult := LScript.Invoke('enumfirst', [], gvtInt32).AsInt32;
      Check(LResult = 0,
        'enumfirst() = %d (expected 0, opt %d)', [LResult, LOrd]);

      // Enum — last: blue = 2
      LResult := LScript.Invoke('enumlast', [], gvtInt32).AsInt32;
      Check(LResult = 2,
        'enumlast() = %d (expected 2, opt %d)', [LResult, LOrd]);

      // Set — member present (7 in [1,3,5..10])
      LResult := LScript.Invoke('setmember', [], gvtInt32).AsInt32;
      Check(LResult = 1,
        'setmember() = %d (expected 1, opt %d)', [LResult, LOrd]);

      // Set — member absent (2 not in [1,3,5..10])
      LResult := LScript.Invoke('setnomember', [], gvtInt32).AsInt32;
      Check(LResult = 0,
        'setnomember() = %d (expected 0, opt %d)', [LResult, LOrd]);

      // Set — empty set (1 not in [])
      LResult := LScript.Invoke('setempty', [], gvtInt32).AsInt32;
      Check(LResult = 0,
        'setempty() = %d (expected 0, opt %d)', [LResult, LOrd]);

      // Set — boundary check (5 and 10 in [5..10], 4 not in)
      LResult := LScript.Invoke('setboundary', [], gvtInt32).AsInt32;
      Check(LResult = 1,
        'setboundary() = %d (expected 1, opt %d)', [LResult, LOrd]);

    finally
      LScript.Free();
    end;
  end;
end;

end.
