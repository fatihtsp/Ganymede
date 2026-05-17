{===============================================================================
  Ganymede™ - Embeddable Native Scripting Engine

  Copyright © 2026-present tinyBigGAMES™ LLC
  All Rights Reserved.

  See LICENSE for license information
===============================================================================}

unit UTest.RoutineTypes;

{$I Ganymede.Defines.inc}

interface

uses
  System.SysUtils,
  System.IOUtils,
  Ganymede.Utils,
  Ganymede.TestCase,
  Ganymede.Core,
  Ganymede.Native,
  UCommon;

type
  TScriptRoutineTypesTest = class(TGnyTestCase)
  public
    constructor Create(); override;
  protected
    procedure Run(); override;
  end;

implementation

{ TScriptRoutineTypesTest }

constructor TScriptRoutineTypesTest.Create();
begin
  inherited;
  Title := 'GanymedeScript — Routine Types & Function Pointers';
  Pause := True;
end;

procedure TScriptRoutineTypesTest.Run();
var
  LScript: TGanymede;
  LVal: Int32;
  LOptLevel: TGnyOptLevel;
  LOrd: Integer;
  LFile: string;
begin
  LFile := TPath.Combine(CTestDir, 'test_mem_routine_types.gny');

  for LOptLevel := Low(TGnyOptLevel) to High(TGnyOptLevel) do
  begin
    LOrd := Ord(LOptLevel);
    Section('Routine Types — opt level %d', [LOrd]);
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

      //writeln(LScript.GetSSADump());

      Check(True, 'Compiled successfully (opt %d)', [LOrd]);

      // 1: basic assign + call
      LVal := LScript.Invoke('test_basic', [], gvtInt32).AsInt32;
      Check(LVal = 7, 'test_basic = %d (exp 7, opt %d)', [LVal, LOrd]);

      // 2: reassign to different function
      LVal := LScript.Invoke('test_reassign', [], gvtInt32).AsInt32;
      Check(LVal = 20, 'test_reassign = %d (exp 20, opt %d)', [LVal, LOrd]);

      // 3: callback — funcptr as parameter
      LVal := LScript.Invoke('test_callback', [], gvtInt32).AsInt32;
      Check(LVal = 13, 'test_callback = %d (exp 13, opt %d)', [LVal, LOrd]);

      // 4: void indirect call — side effect
      LVal := LScript.Invoke('test_void_indirect', [], gvtInt32).AsInt32;
      Check(LVal = 123, 'test_void_indirect = %d (exp 123, opt %d)', [LVal, LOrd]);

      // 5: nullary routine type (no params)
      LVal := LScript.Invoke('test_nullary', [], gvtInt32).AsInt32;
      Check(LVal = 7, 'test_nullary = %d (exp 7, opt %d)', [LVal, LOrd]);

      // 6: reassign nullary
      LVal := LScript.Invoke('test_nullary_reassign', [], gvtInt32).AsInt32;
      Check(LVal = 49, 'test_nullary_reassign = %d (exp 49, opt %d)', [LVal, LOrd]);

      // 7: funcptr in static array — add(10,3)+sub(10,3)+mul(10,3) = 13+7+30 = 50
      LVal := LScript.Invoke('test_array', [], gvtInt32).AsInt32;
      Check(LVal = 50, 'test_array = %d (exp 50, opt %d)', [LVal, LOrd]);

      // 8: global funcptr variable — mul(6,7) = 42
      LVal := LScript.Invoke('test_global', [], gvtInt32).AsInt32;
      Check(LVal = 42, 'test_global = %d (exp 42, opt %d)', [LVal, LOrd]);

      // 9: chain — add(add(1,2), add(3,4)) = add(3,7) = 10
      LVal := LScript.Invoke('test_chain', [], gvtInt32).AsInt32;
      Check(LVal = 10, 'test_chain = %d (exp 10, opt %d)', [LVal, LOrd]);

      // 10: multiple callback params — add(3,4)+mul(3,4) = 7+12 = 19
      LVal := LScript.Invoke('test_multi_callback', [], gvtInt32).AsInt32;
      Check(LVal = 19, 'test_multi_callback = %d (exp 19, opt %d)', [LVal, LOrd]);

      // 11: indirect call in loop — sum 1..5 = 15
      LVal := LScript.Invoke('test_loop', [], gvtInt32).AsInt32;
      Check(LVal = 15, 'test_loop = %d (exp 15, opt %d)', [LVal, LOrd]);

      // 12: different funcptrs to same callback — apply(add,10,5)+apply(sub,10,5) = 15+5 = 20
      LVal := LScript.Invoke('test_swap_callback', [], gvtInt32).AsInt32;
      Check(LVal = 20, 'test_swap_callback = %d (exp 20, opt %d)', [LVal, LOrd]);

      FlushErrors(LScript.GetErrors());
    finally
      LScript.Free();
    end;
  end;
end;

end.
