{===============================================================================
  Ganymede™ - Embeddable Native Scripting Engine

  Copyright © 2026-present tinyBigGAMES™ LLC
  All Rights Reserved.

  See LICENSE for license information
===============================================================================}

unit UTest.Script.MatchStmt;

{$I Ganymede.Defines.inc}

interface

uses
  System.SysUtils,
  System.IOUtils,
  Ganymede.Utils,
  Ganymede.TestCase,
  Ganymede,
  Ganymede.Native;

type
  TScriptMatchStmtTest = class(TGnyTestCase)
  public
    constructor Create(); override;
  protected
    procedure Run(); override;
  end;

implementation

const
  CTestDir = 'C:\Dev\Delphi\Projects\Ganymede\repo\bin\tests';

{ TScriptMatchStmtTest }

constructor TScriptMatchStmtTest.Create();
begin
  inherited;
  Title := 'GanymedeScript — Match Statement';
  Pause := True;
end;

procedure TScriptMatchStmtTest.Run();
var
  LScript: TGanymede;
  LResult: Int64;
  LOptLevel: TGnyOptLevel;
  LOrd: Integer;
  LFile: string;
begin
  LFile := TPath.Combine(CTestDir, 'test_mem_match.gny');

  for LOptLevel := Low(TGnyOptLevel) to High(TGnyOptLevel) do
  begin
    LOrd := Ord(LOptLevel);
    Section('Match Statement — opt level %d', [LOrd]);
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

      // matchval: discrete values
      LResult := LScript.Invoke('matchval', [1], gvtInt64).AsInt64;
      Check(LResult = 10,
        'matchval(1) = %d (expected 10, opt %d)', [LResult, LOrd]);

      LResult := LScript.Invoke('matchval', [2], gvtInt64).AsInt64;
      Check(LResult = 20,
        'matchval(2) = %d (expected 20, opt %d)', [LResult, LOrd]);

      LResult := LScript.Invoke('matchval', [3], gvtInt64).AsInt64;
      Check(LResult = 30,
        'matchval(3) = %d (expected 30, opt %d)', [LResult, LOrd]);

      LResult := LScript.Invoke('matchval', [99], gvtInt64).AsInt64;
      Check(LResult = -1,
        'matchval(99) = %d (expected -1/else, opt %d)', [LResult, LOrd]);

      // matchmulti: comma-separated labels
      LResult := LScript.Invoke('matchmulti', [2], gvtInt64).AsInt64;
      Check(LResult = 100,
        'matchmulti(2) = %d (expected 100, opt %d)', [LResult, LOrd]);

      LResult := LScript.Invoke('matchmulti', [5], gvtInt64).AsInt64;
      Check(LResult = 200,
        'matchmulti(5) = %d (expected 200, opt %d)', [LResult, LOrd]);

      LResult := LScript.Invoke('matchmulti', [7], gvtInt64).AsInt64;
      Check(LResult = 0,
        'matchmulti(7) = %d (expected 0/else, opt %d)', [LResult, LOrd]);

      // matchrange: range labels
      LResult := LScript.Invoke('matchrange', [3], gvtInt64).AsInt64;
      Check(LResult = 1,
        'matchrange(3) = %d (expected 1, opt %d)', [LResult, LOrd]);

      LResult := LScript.Invoke('matchrange', [8], gvtInt64).AsInt64;
      Check(LResult = 2,
        'matchrange(8) = %d (expected 2, opt %d)', [LResult, LOrd]);

      LResult := LScript.Invoke('matchrange', [15], gvtInt64).AsInt64;
      Check(LResult = 3,
        'matchrange(15) = %d (expected 3, opt %d)', [LResult, LOrd]);

      LResult := LScript.Invoke('matchrange', [25], gvtInt64).AsInt64;
      Check(LResult = 0,
        'matchrange(25) = %d (expected 0/else, opt %d)', [LResult, LOrd]);

      // matchmixed: values + ranges combined
      LResult := LScript.Invoke('matchmixed', [0], gvtInt64).AsInt64;
      Check(LResult = 100,
        'matchmixed(0) = %d (expected 100, opt %d)', [LResult, LOrd]);

      LResult := LScript.Invoke('matchmixed', [2], gvtInt64).AsInt64;
      Check(LResult = 200,
        'matchmixed(2) = %d (expected 200, opt %d)', [LResult, LOrd]);

      LResult := LScript.Invoke('matchmixed', [7], gvtInt64).AsInt64;
      Check(LResult = 300,
        'matchmixed(7) = %d (expected 300, opt %d)', [LResult, LOrd]);

      LResult := LScript.Invoke('matchmixed', [12], gvtInt64).AsInt64;
      Check(LResult = 400,
        'matchmixed(12) = %d (expected 400, opt %d)', [LResult, LOrd]);

      LResult := LScript.Invoke('matchmixed', [50], gvtInt64).AsInt64;
      Check(LResult = -1,
        'matchmixed(50) = %d (expected -1/else, opt %d)', [LResult, LOrd]);

      // matchnoelse: no else, unmatched returns 0 from after match
      LResult := LScript.Invoke('matchnoelse', [1], gvtInt64).AsInt64;
      Check(LResult = 10,
        'matchnoelse(1) = %d (expected 10, opt %d)', [LResult, LOrd]);

      LResult := LScript.Invoke('matchnoelse', [99], gvtInt64).AsInt64;
      Check(LResult = 0,
        'matchnoelse(99) = %d (expected 0/fallthrough, opt %d)', [LResult, LOrd]);

    finally
      LScript.Free();
    end;
  end;

  // Negative test: non-constant match label must produce a compile error
  Section('Match — non-constant label rejection');
  LScript := TGanymede.Create();
  try
    LScript.LoadFromFile(TPath.Combine(CTestDir, 'test_mem_match_bad.gny'));
    Check(not LScript.Compile(),
      'Non-constant match label correctly rejected');
  finally
    LScript.Free();
  end;
end;

end.
