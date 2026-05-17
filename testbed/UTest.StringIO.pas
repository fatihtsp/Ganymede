{===============================================================================
  Ganymede™ - Embeddable Native Scripting Engine

  Copyright © 2026-present tinyBigGAMES™ LLC
  All Rights Reserved.

  See LICENSE for license information
===============================================================================}

unit UTest.StringIO;

{$I Ganymede.Defines.inc}

interface

uses
  Ganymede.TestCase;

type
  TScriptStringIOTest = class(TGnyTestCase)
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
  CStringIOSource =
  '''
  module mem stringio;

  // Test write/writeln with printf-style format strings
  public routine testPrint();
  var
    x: int32 = 42;
    pi: float64 = 3.14159;
    flag: boolean = true;
  begin
    writeln("=== PxlScript String & I/O Test ===");
    writeln("Integer: %d", x);
    writeln("Float: %f", pi);
    writeln("Boolean: %d", flag);
    writeln("Multi-arg: %d / %f", x, pi);
    writeln();
    writeln("Done.");
  end;

  // Test boolean type in conditions and variables
  public routine testBool(a: int32; b: int32): boolean;
  var
    isGreater: boolean;
  begin
    isGreater := a > b;
    return isGreater;
  end;

  // Test managed string variables, concat, comparison, assignment
  public routine testStrings(): int32;
  var
    s1: string = "Hello";
    s2: string = " World";
    s3: string;
    s4: string;
    passed: int32 = 0;
  begin
    // Concat
    s3 := s1 + s2;

    // Sharing (init from var)
    s4 := s1;

    // Print managed strings via %s format
    writeln("s1 = %s", s1);
    writeln("s2 = %s", s2);
    writeln("s3 = %s", s3);
    writeln("s4 = %s", s4);

    // Comparison: s3 should equal "Hello World"
    if s3 = "Hello World" then
      passed := passed + 1;
    end;

    // Comparison: s4 should equal s1
    if s4 = "Hello" then
      passed := passed + 1;
    end;

    // Reassignment
    s1 := "Changed";
    writeln("s1 after reassign = %s", s1);

    if s1 = "Changed" then
      passed := passed + 1;
    end;

    // s4 should still be "Hello" (sharing doesn't alias)
    if s4 = "Hello" then
      passed := passed + 1;
    end;

    // Inequality
    if s1 <> s2 then
      passed := passed + 1;
    end;

    // Concat-assign
    s1 += "!";
    if s1 = "Changed!" then
      passed := passed + 1;
    end;

    writeln("s1 after += = %s", s1);
    return passed;
  end;

  end.
  ''';

{ TScriptStringIOTest }

constructor TScriptStringIOTest.Create();
begin
  inherited;
  Title := 'PxlScript — Strings & I/O';
  Pause := True;
end;

procedure TScriptStringIOTest.Run();
var
  LScript: TGanymede;
  LResult: Int64;
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
      LScript.SetDumpIR(True);
      LScript.LoadFromString(CStringIOSource, 'stringio.pxs');

      if not LScript.Compile() then
      begin
        FlushErrors(LScript.GetErrors());
        Check(False, 'Compile failed (opt %d)', [LOrd]);
        Continue;
      end;

      // Print SSA IR dump for debugging managed string cleanup
//      TGnyUtils.PrintLn('--- SSA IR Dump (opt %d) ---', [LOrd]);
//      TGnyUtils.PrintLn('%s', [LScript.GetSSADump()]);
//      TGnyUtils.PrintLn('--- End SSA IR Dump ---', []);

      Check(True, 'Compiled successfully (opt %d)', [LOrd]);

      // Run print test (outputs to console)
      TGnyUtils.PrintLn('--- Script output (opt %d) ---', [LOrd]);
      LScript.Invoke('testPrint', []);
      TGnyUtils.PrintLn('--- End script output ---', []);
      Check(True, 'testPrint ran without crash (opt %d)', [LOrd]);

      // Test boolean logic (returns boolean — 1=true, 0=false as int8)
      LResult := LScript.Invoke('testBool', [10, 5], gvtInt64).AsInt64;
      Check(LResult = 1, 'testBool(10,5) = %d (expected true, opt %d)', [LResult, LOrd]);

      LResult := LScript.Invoke('testBool', [3, 7], gvtInt64).AsInt64;
      Check(LResult = 0, 'testBool(3,7) = %d (expected false, opt %d)', [LResult, LOrd]);

      LResult := LScript.Invoke('testBool', [5, 5], gvtInt64).AsInt64;
      Check(LResult = 0, 'testBool(5,5) = %d (expected false, opt %d)', [LResult, LOrd]);

      // Test managed strings: concat, sharing, reassignment, comparison, +=
      TGnyUtils.PrintLn('--- String output (opt %d) ---', [LOrd]);
      LResult := LScript.Invoke('testStrings', [], gvtInt64).AsInt64;
      TGnyUtils.PrintLn('--- End string output ---', []);

      // Report heap leaks while backend is still alive
      LScript.ReportLeaks();

      Check(LResult = 6, 'testStrings passed %d/6 (opt %d)', [LResult, LOrd]);
    finally
      LScript.Free();
    end;
  end;
end;

end.
