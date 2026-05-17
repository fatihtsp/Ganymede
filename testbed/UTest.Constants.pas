{===============================================================================
  Ganymede™ - Embeddable Native Scripting Engine

  Copyright © 2026-present tinyBigGAMES™ LLC
  All Rights Reserved.

  See LICENSE for license information
===============================================================================}

unit UTest.Constants;

{$I Ganymede.Defines.inc}

interface

uses
  Ganymede.TestCase;

type
  TScriptConstantsTest = class(TGnyTestCase)
  public
    constructor Create(); override;
  protected
    procedure Run(); override;
  end;

implementation

uses
  System.SysUtils,
  Ganymede.Utils,
  Ganymede.Native,
  Ganymede;

const
  CConstSource =
  '''
  module mem consttest;

  public routine compute(x: int32): int32;
  const
    BASE: int32 = 100;
    MULT: int32 = 3;
  var
    result: int32;
  begin
    result := BASE + x * MULT;
    return result;
  end;

  end.
  ''';

  CConstAssignSource =
  '''
  module mem constassign;

  public routine bad(): int32;
  const
    LIMIT: int32 = 50;
  begin
    LIMIT := 99;
    return LIMIT;
  end;

  end.
  ''';

type
  TComputeFunc = function(x: Int32): Int32;

{ TScriptConstantsTest }

constructor TScriptConstantsTest.Create();
begin
  inherited;
  Title := 'PxlScript — Constants';
  Pause := True;
end;

procedure TScriptConstantsTest.Run();
var
  LScript: TGanymede;
  LResult: Int64;
  LCompute: TComputeFunc;
  LOptLevel: TGnyOptLevel;
  LOrd: Integer;
begin
  // --- Test 1: Constants used in arithmetic ---
  for LOptLevel := Low(TGnyOptLevel) to High(TGnyOptLevel) do
  begin
    LOrd := Ord(LOptLevel);
    Section('Constants — Compile & JIT (opt level %d)', [LOrd]);
    LScript := TGanymede.Create();
    try
      LScript.SetOptimizationLevel(LOptLevel);
      LScript.LoadFromString(CConstSource, 'consttest.pxs');

      if not LScript.Compile() then
      begin
        FlushErrors(LScript.GetErrors());
        Check(False, 'Compile failed (opt %d)', [LOrd]);
        Continue;
      end;

      Check(True, 'Compiled successfully (opt %d)', [LOrd]);

      // compute(5) = 100 + 5*3 = 115
      LResult := LScript.Invoke('compute', [5], gvtInt64).AsInt64;
      Check(LResult = 115, 'compute(5) = %d (expected 115, opt %d)', [LResult, LOrd]);

      LCompute := LScript.GetSymbol('compute');
      LResult := LCompute(5);
      Check(LResult = 115, 'direct compute(5) = %d (expected 115, opt %d)', [LResult, LOrd]);

      // compute(0) = 100 + 0*3 = 100
      LResult := LScript.Invoke('compute', [0], gvtInt64).AsInt64;
      Check(LResult = 100, 'compute(0) = %d (expected 100, opt %d)', [LResult, LOrd]);

      // compute(-10) = 100 + (-10)*3 = 70
      LResult := LScript.Invoke('compute', [-10], gvtInt64).AsInt64;
      Check(LResult = 70, 'compute(-10) = %d (expected 70, opt %d)', [LResult, LOrd]);
    finally
      LScript.Free();
    end;
  end;

  // --- Test 2: Assignment to const must fail ---
  Section('Constants — Immutability check');
  LScript := TGanymede.Create();
  try
    LScript.LoadFromString(CConstAssignSource, 'constassign.pxs');

    if LScript.Compile() then
      Check(False, 'Compile should have failed (assignment to const)')
    else
      Check(True, 'Correctly rejected assignment to constant');
  finally
    LScript.Free();
  end;
end;

end.
