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
  System.SysUtils,
  Ganymede.Native,
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
  LScript: TGanymede;
  LResult: Int64;
  LOptLevel: TGnyOptLevel;
  LOrd: Integer;
begin
  for LOptLevel := Low(TGnyOptLevel) to High(TGnyOptLevel) do
  begin
    LOrd := Ord(LOptLevel);
    Section('Control Flow — opt level %d', [LOrd]);
    LScript := TGanymede.Create();
    try
      LScript.SetOptimizationLevel(LOptLevel);
      LScript.LoadFromString(CControlFlowSource, 'ctrlflow.pxs');

      if not LScript.Compile() then
      begin
        FlushErrors(LScript.GetErrors());
        Check(False, 'Compile failed (opt %d)', [LOrd]);
        Continue;
      end;

      Check(True, 'Compiled successfully (opt %d)', [LOrd]);

      // whilesum(10): 1+2+...+10 = 55
      LResult := LScript.Invoke('whilesum', [10], gvtInt64).AsInt64;
      Check(LResult = 55,
        'whilesum(10) = %d (expected 55, opt %d)', [LResult, LOrd]);

      // forsum(10): 1+2+...+10 = 55
      LResult := LScript.Invoke('forsum', [10], gvtInt64).AsInt64;
      Check(LResult = 55,
        'forsum(10) = %d (expected 55, opt %d)', [LResult, LOrd]);

      // countdown(10): 10+9+...+1 = 55
      LResult := LScript.Invoke('countdown', [10], gvtInt64).AsInt64;
      Check(LResult = 55,
        'countdown(10) = %d (expected 55, opt %d)', [LResult, LOrd]);

      // repeatsum(10): 1+2+...+10 = 55
      LResult := LScript.Invoke('repeatsum', [10], gvtInt64).AsInt64;
      Check(LResult = 55,
        'repeatsum(10) = %d (expected 55, opt %d)', [LResult, LOrd]);

      // earlyexit(100): 1+2+3+4+5 = 15 (s>10 triggers leave before adding 6)
      LResult := LScript.Invoke('earlyexit', [100], gvtInt64).AsInt64;
      Check(LResult = 15,
        'earlyexit(100) = %d (expected 15, opt %d)', [LResult, LOrd]);

      // skipodd(10): 1+3+5+7+9 = 25 (skip evens)
      LResult := LScript.Invoke('skipodd', [10], gvtInt64).AsInt64;
      Check(LResult = 25,
        'skipodd(10) = %d (expected 25, opt %d)', [LResult, LOrd]);

      // nested(3): sum of i*j for i,j in 1..3
      // = 1*1+1*2+1*3+2*1+2*2+2*3+3*1+3*2+3*3
      // = (1+2+3)*(1+2+3) = 6*6 = 36
      LResult := LScript.Invoke('nested', [3], gvtInt64).AsInt64;
      Check(LResult = 36,
        'nested(3) = %d (expected 36, opt %d)', [LResult, LOrd]);
    finally
      LScript.Free();
    end;
  end;
end;

end.
