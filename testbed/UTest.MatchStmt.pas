{===============================================================================
  Ganymede™ - Embeddable Native Scripting Engine

  Copyright © 2026-present tinyBigGAMES™ LLC
  All Rights Reserved.

  See LICENSE for license information
===============================================================================}

unit UTest.MatchStmt;

{$I Ganymede.Defines.inc}

interface

uses
  Ganymede.TestCase;

type
  TScriptMatchStmtTest = class(TGnyTestCase)
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

{ TScriptMatchStmtTest }

constructor TScriptMatchStmtTest.Create();
begin
  inherited;
  Title := 'GanymedeScript — Match Statement';
  Pause := True;
end;

procedure TScriptMatchStmtTest.Run();
var
  LEngine: TGnyEngine;
  LResult: Int64;
  LOptLevel: Integer;
  LFile: string;
begin
  if not gny_load(PAnsiChar(UTF8Encode(CDllPath))) then
  begin
    Check(False, 'Failed to load Ganymede DLL');
    Exit;
  end;

  LFile := TPath.Combine(CTestDir, 'test_mem_match.gny');

  for LOptLevel := GNY_OPT_NONE to GNY_OPT_FULL do
  begin
    Section('Match Statement — opt level %d', [LOptLevel]);
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
      // matchval: discrete values
      gny_arg_push_int32(LEngine, 1);
      LResult := gny_invoke(LEngine, PAnsiChar(UTF8Encode('matchval')), GNY_VT_INT64).AsInt64;
      Check(LResult = 10, 'matchval(1) = %d (expected 10, opt %d)', [LResult, LOptLevel]);

      gny_arg_push_int32(LEngine, 2);
      LResult := gny_invoke(LEngine, PAnsiChar(UTF8Encode('matchval')), GNY_VT_INT64).AsInt64;
      Check(LResult = 20, 'matchval(2) = %d (expected 20, opt %d)', [LResult, LOptLevel]);

      gny_arg_push_int32(LEngine, 3);
      LResult := gny_invoke(LEngine, PAnsiChar(UTF8Encode('matchval')), GNY_VT_INT64).AsInt64;
      Check(LResult = 30, 'matchval(3) = %d (expected 30, opt %d)', [LResult, LOptLevel]);

      gny_arg_push_int32(LEngine, 99);
      LResult := gny_invoke(LEngine, PAnsiChar(UTF8Encode('matchval')), GNY_VT_INT64).AsInt64;
      Check(LResult = -1, 'matchval(99) = %d (expected -1/else, opt %d)', [LResult, LOptLevel]);

      // matchmulti: comma-separated labels
      gny_arg_push_int32(LEngine, 2);
      LResult := gny_invoke(LEngine, PAnsiChar(UTF8Encode('matchmulti')), GNY_VT_INT64).AsInt64;
      Check(LResult = 100, 'matchmulti(2) = %d (expected 100, opt %d)', [LResult, LOptLevel]);

      gny_arg_push_int32(LEngine, 5);
      LResult := gny_invoke(LEngine, PAnsiChar(UTF8Encode('matchmulti')), GNY_VT_INT64).AsInt64;
      Check(LResult = 200, 'matchmulti(5) = %d (expected 200, opt %d)', [LResult, LOptLevel]);

      gny_arg_push_int32(LEngine, 7);
      LResult := gny_invoke(LEngine, PAnsiChar(UTF8Encode('matchmulti')), GNY_VT_INT64).AsInt64;
      Check(LResult = 0, 'matchmulti(7) = %d (expected 0/else, opt %d)', [LResult, LOptLevel]);
      // matchrange: range labels
      gny_arg_push_int32(LEngine, 3);
      LResult := gny_invoke(LEngine, PAnsiChar(UTF8Encode('matchrange')), GNY_VT_INT64).AsInt64;
      Check(LResult = 1, 'matchrange(3) = %d (expected 1, opt %d)', [LResult, LOptLevel]);

      gny_arg_push_int32(LEngine, 8);
      LResult := gny_invoke(LEngine, PAnsiChar(UTF8Encode('matchrange')), GNY_VT_INT64).AsInt64;
      Check(LResult = 2, 'matchrange(8) = %d (expected 2, opt %d)', [LResult, LOptLevel]);

      gny_arg_push_int32(LEngine, 15);
      LResult := gny_invoke(LEngine, PAnsiChar(UTF8Encode('matchrange')), GNY_VT_INT64).AsInt64;
      Check(LResult = 3, 'matchrange(15) = %d (expected 3, opt %d)', [LResult, LOptLevel]);

      gny_arg_push_int32(LEngine, 25);
      LResult := gny_invoke(LEngine, PAnsiChar(UTF8Encode('matchrange')), GNY_VT_INT64).AsInt64;
      Check(LResult = 0, 'matchrange(25) = %d (expected 0/else, opt %d)', [LResult, LOptLevel]);

      // matchmixed: values + ranges combined
      gny_arg_push_int32(LEngine, 0);
      LResult := gny_invoke(LEngine, PAnsiChar(UTF8Encode('matchmixed')), GNY_VT_INT64).AsInt64;
      Check(LResult = 100, 'matchmixed(0) = %d (expected 100, opt %d)', [LResult, LOptLevel]);

      gny_arg_push_int32(LEngine, 2);
      LResult := gny_invoke(LEngine, PAnsiChar(UTF8Encode('matchmixed')), GNY_VT_INT64).AsInt64;
      Check(LResult = 200, 'matchmixed(2) = %d (expected 200, opt %d)', [LResult, LOptLevel]);

      gny_arg_push_int32(LEngine, 7);
      LResult := gny_invoke(LEngine, PAnsiChar(UTF8Encode('matchmixed')), GNY_VT_INT64).AsInt64;
      Check(LResult = 300, 'matchmixed(7) = %d (expected 300, opt %d)', [LResult, LOptLevel]);

      gny_arg_push_int32(LEngine, 12);
      LResult := gny_invoke(LEngine, PAnsiChar(UTF8Encode('matchmixed')), GNY_VT_INT64).AsInt64;
      Check(LResult = 400, 'matchmixed(12) = %d (expected 400, opt %d)', [LResult, LOptLevel]);

      gny_arg_push_int32(LEngine, 50);
      LResult := gny_invoke(LEngine, PAnsiChar(UTF8Encode('matchmixed')), GNY_VT_INT64).AsInt64;
      Check(LResult = -1, 'matchmixed(50) = %d (expected -1/else, opt %d)', [LResult, LOptLevel]);
      // matchnoelse: no else, unmatched returns 0 from after match
      gny_arg_push_int32(LEngine, 1);
      LResult := gny_invoke(LEngine, PAnsiChar(UTF8Encode('matchnoelse')), GNY_VT_INT64).AsInt64;
      Check(LResult = 10, 'matchnoelse(1) = %d (expected 10, opt %d)', [LResult, LOptLevel]);

      gny_arg_push_int32(LEngine, 99);
      LResult := gny_invoke(LEngine, PAnsiChar(UTF8Encode('matchnoelse')), GNY_VT_INT64).AsInt64;
      Check(LResult = 0, 'matchnoelse(99) = %d (expected 0/fallthrough, opt %d)', [LResult, LOptLevel]);

    finally
      gny_destroy(LEngine);
    end;
  end;

  // Negative test: non-constant match label must produce a compile error
  Section('Match — non-constant label rejection');
  LEngine := gny_create();
  try
    gny_load_from_file(LEngine,
      PAnsiChar(UTF8Encode(TPath.Combine(CTestDir, 'test_mem_match_bad.gny'))));
    Check(not gny_compile(LEngine),
      'Non-constant match label correctly rejected');
  finally
    gny_destroy(LEngine);
  end;

  gny_unload();
end;

end.