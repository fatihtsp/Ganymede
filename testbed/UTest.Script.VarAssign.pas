{===============================================================================
  Ganymede™ - Embeddable Native Scripting Engine

  Copyright © 2026-present tinyBigGAMES™ LLC
  All Rights Reserved.

  See LICENSE for license information
===============================================================================}

unit UTest.Script.VarAssign;

{$I Ganymede.Defines.inc}

interface

uses
  Ganymede.TestCase;

type
  TScriptVarAssignTest = class(TGnyTestCase)
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
  CVarAssignSource =
  '''
  module jit vartest;

  public routine compute(x: int32): int32;
  var
    a: int32;
    b: int32 = 10;
    c: int32;
  begin
    a := x;
    b += a;
    c := b * 2;
    c -= 1;
    return c;
  end;

  end.
  ''';

type
  TComputeFunc = function(x: Int32): Int32;

{ TScriptVarAssignTest }

constructor TScriptVarAssignTest.Create();
begin
  inherited;
  Title := 'PxlScript — Variables & Assignment';
  Pause := True;
end;

procedure TScriptVarAssignTest.Run();
var
  LScript: TGanymede;
  LResult: Int64;
  LCompute: TComputeFunc;
  LOptLevel: TGnyOptLevel;
  LOrd: Integer;
begin
  for LOptLevel := Low(TGnyOptLevel) to High(TGnyOptLevel) do
  begin
    LOrd := Ord(LOptLevel);
    Section('Compile & JIT (opt level %d)', [LOrd]);
    LScript := TGanymede.Create();
    try
      LScript.SetOptimizationLevel(LOptLevel);
      LScript.LoadFromString(CVarAssignSource, 'vartest.pxs');

      if not LScript.Compile() then
      begin
        FlushErrors(LScript.GetErrors());
        Check(False, 'Compile failed (opt %d)', [LOrd]);
        Continue;
      end;

      Check(True, 'Compiled successfully (opt %d)', [LOrd]);

      LResult := LScript.Invoke('compute', [5], vtInt64).AsInt64;
      Check(LResult = 29, 'compute(5) = %d (expected 29, opt %d)', [LResult, LOrd]);

      LCompute := LScript.GetSymbol('compute');
      LResult := LCompute(5);
      Check(LResult = 29, 'direct compute(5) = %d (expected 29, opt %d)', [LResult, LOrd]);

      LResult := LScript.Invoke('compute', [0], vtInt64).AsInt64;
      Check(LResult = 19, 'compute(0) = %d (expected 19, opt %d)', [LResult, LOrd]);

      LResult := LScript.Invoke('compute', [-3], vtInt64).AsInt64;
      Check(LResult = 13, 'compute(-3) = %d (expected 13, opt %d)', [LResult, LOrd]);
    finally
      LScript.Free();
    end;
  end;
end;

end.
