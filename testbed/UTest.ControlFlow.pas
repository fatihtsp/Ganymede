{===============================================================================
  Ganymede™ - Embeddable Native Scripting Engine

  Copyright © 2026-present tinyBigGAMES™ LLC
  All Rights Reserved.

  See LICENSE for license information
===============================================================================}

unit UTest.ControlFlow;

{$I Ganymede.Defines.inc}

interface

uses
  Ganymede.TestCase;

type
  TScriptControlFlowTest = class(TGnyTestCase)
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
  CControlFlowSource =
  '''
  module mem ctrlflow;

  // While loop: sum 1..n
  public routine whilesum(n: int32): int32;
  var
    i: int32;
    s: int32;
  begin
    i := 1;
    s := 0;
    while i <= n do
      s := s + i;
      i := i + 1;
    end;
    return s;
  end;

  // For/to loop: sum 1..n
  public routine forsum(n: int32): int32;
  var
    s: int32;
  begin
    s := 0;
    for i := 1 to n do
      s := s + i;
    end;
    return s;
  end;

  // For/downto loop: count down from n to 1, return final counter
  public routine countdown(n: int32): int32;
  var
    s: int32;
  begin
    s := 0;
    for i := n downto 1 do
      s := s + i;
    end;
    return s;
  end;

  // Repeat/until loop: sum 1..n
  public routine repeatsum(n: int32): int32;
  var
    i: int32;
    s: int32;
  begin
    i := 1;
    s := 0;
    repeat
      s := s + i;
      i := i + 1;
    until i > n;
    return s;
  end;

  // Leave (break): sum until threshold
  public routine earlyexit(n: int32): int32;
  var
    i: int32;
    s: int32;
  begin
    i := 1;
    s := 0;
    while i <= n do
      if s > 10 then
        leave;
      end;
      s := s + i;
      i := i + 1;
    end;
    return s;
  end;

  // Skip (continue): sum odd numbers only
  public routine skipodd(n: int32): int32;
  var
    s: int32;
    rem: int32;
  begin
    s := 0;
    for i := 1 to n do
      rem := i mod 2;
      if rem = 0 then
        skip;
      end;
      s := s + i;
    end;
    return s;
  end;

  // Nested loops: sum of products
  public routine nested(n: int32): int32;
  var
    s: int32;
  begin
    s := 0;
    for i := 1 to n do
      for j := 1 to n do
        s := s + i * j;
      end;
    end;
    return s;
  end;

  end.
  ''';

{ TScriptControlFlowTest }

constructor TScriptControlFlowTest.Create();
begin
  inherited;
  Title := 'PxlScript — Control Flow';
  Pause := True;
end;

procedure TScriptControlFlowTest.Run();
var
  LEngine: TGnyEngine;
  LResult: Int64;
  LOptLevel: Integer;
begin
  if not gny_load(PAnsiChar(UTF8Encode(CDllPath))) then
  begin
    Check(False, 'Failed to load Ganymede DLL');
    Exit;
  end;

  for LOptLevel := GNY_OPT_NONE to GNY_OPT_FULL do
  begin
    Section('Control Flow — opt level %d', [LOptLevel]);
    LEngine := gny_create();
    try
      gny_set_optimization_level(LEngine, LOptLevel);
      gny_load_from_string(LEngine,
        PAnsiChar(UTF8Encode(CControlFlowSource)),
        PAnsiChar(UTF8Encode('ctrlflow.pxs')));

      if not gny_compile(LEngine) then
      begin
        gny_print_errors(LEngine);
        Check(False, 'Compile failed (opt %d)', [LOptLevel]);
        Continue;
      end;

      Check(True, 'Compiled successfully (opt %d)', [LOptLevel]);

      // whilesum(10): 1+2+...+10 = 55
      gny_arg_push_int32(LEngine, 10);
      LResult := gny_invoke(LEngine,
        PAnsiChar(UTF8Encode('whilesum')), GNY_VT_INT64).AsInt64;
      Check(LResult = 55,
        'whilesum(10) = %d (expected 55, opt %d)', [LResult, LOptLevel]);

      // forsum(10): 1+2+...+10 = 55
      gny_arg_push_int32(LEngine, 10);
      LResult := gny_invoke(LEngine,
        PAnsiChar(UTF8Encode('forsum')), GNY_VT_INT64).AsInt64;
      Check(LResult = 55,
        'forsum(10) = %d (expected 55, opt %d)', [LResult, LOptLevel]);

      // countdown(10): 10+9+...+1 = 55
      gny_arg_push_int32(LEngine, 10);
      LResult := gny_invoke(LEngine,
        PAnsiChar(UTF8Encode('countdown')), GNY_VT_INT64).AsInt64;
      Check(LResult = 55,
        'countdown(10) = %d (expected 55, opt %d)', [LResult, LOptLevel]);

      // repeatsum(10): 1+2+...+10 = 55
      gny_arg_push_int32(LEngine, 10);
      LResult := gny_invoke(LEngine,
        PAnsiChar(UTF8Encode('repeatsum')), GNY_VT_INT64).AsInt64;
      Check(LResult = 55,
        'repeatsum(10) = %d (expected 55, opt %d)', [LResult, LOptLevel]);

      // earlyexit(100): 1+2+3+4+5 = 15 (s>10 triggers leave before adding 6)
      gny_arg_push_int32(LEngine, 100);
      LResult := gny_invoke(LEngine,
        PAnsiChar(UTF8Encode('earlyexit')), GNY_VT_INT64).AsInt64;
      Check(LResult = 15,
        'earlyexit(100) = %d (expected 15, opt %d)', [LResult, LOptLevel]);

      // skipodd(10): 1+3+5+7+9 = 25 (skip evens)
      gny_arg_push_int32(LEngine, 10);
      LResult := gny_invoke(LEngine,
        PAnsiChar(UTF8Encode('skipodd')), GNY_VT_INT64).AsInt64;
      Check(LResult = 25,
        'skipodd(10) = %d (expected 25, opt %d)', [LResult, LOptLevel]);

      // nested(3): sum of i*j for i,j in 1..3 = 36
      gny_arg_push_int32(LEngine, 3);
      LResult := gny_invoke(LEngine,
        PAnsiChar(UTF8Encode('nested')), GNY_VT_INT64).AsInt64;
      Check(LResult = 36,
        'nested(3) = %d (expected 36, opt %d)', [LResult, LOptLevel]);
    finally
      gny_destroy(LEngine);
    end;
  end;

  gny_unload();
end;

end.