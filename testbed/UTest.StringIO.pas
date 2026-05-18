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
  UCommon,
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
    Section('Compile & JIT (opt level %d)', [LOptLevel]);
    LEngine := gny_create();
    try
      gny_set_optimization_level(LEngine, LOptLevel);
      gny_set_dump_ir(LEngine, True);
      gny_load_from_string(LEngine,
        PAnsiChar(UTF8Encode(CStringIOSource)),
        PAnsiChar(UTF8Encode('stringio.pxs')));

      if not gny_compile(LEngine) then
      begin
        gny_print_errors(LEngine);
        Check(False, 'Compile failed (opt %d)', [LOptLevel]);
        Continue;
      end;

      Check(True, 'Compiled successfully (opt %d)', [LOptLevel]);

      // Run print test (outputs to console)
      WriteLn('--- Script output (opt ', LOptLevel, ') ---');
      gny_invoke(LEngine,
        PAnsiChar(UTF8Encode('testPrint')), GNY_VT_VOID);
      WriteLn('--- End script output ---');
      Check(True, 'testPrint ran without crash (opt %d)', [LOptLevel]);

      // Test boolean logic (returns boolean — 1=true, 0=false as int8)
      gny_arg_push_int32(LEngine, 10);
      gny_arg_push_int32(LEngine, 5);
      LResult := gny_invoke(LEngine,
        PAnsiChar(UTF8Encode('testBool')), GNY_VT_INT64).AsInt64;
      Check(LResult = 1, 'testBool(10,5) = %d (expected true, opt %d)',
        [LResult, LOptLevel]);

      gny_arg_push_int32(LEngine, 3);
      gny_arg_push_int32(LEngine, 7);
      LResult := gny_invoke(LEngine,
        PAnsiChar(UTF8Encode('testBool')), GNY_VT_INT64).AsInt64;
      Check(LResult = 0, 'testBool(3,7) = %d (expected false, opt %d)',
        [LResult, LOptLevel]);

      gny_arg_push_int32(LEngine, 5);
      gny_arg_push_int32(LEngine, 5);
      LResult := gny_invoke(LEngine,
        PAnsiChar(UTF8Encode('testBool')), GNY_VT_INT64).AsInt64;
      Check(LResult = 0, 'testBool(5,5) = %d (expected false, opt %d)',
        [LResult, LOptLevel]);

      // Test managed strings: concat, sharing, reassignment, comparison, +=
      WriteLn('--- String output (opt ', LOptLevel, ') ---');
      LResult := gny_invoke(LEngine,
        PAnsiChar(UTF8Encode('testStrings')), GNY_VT_INT64).AsInt64;
      WriteLn('--- End string output ---');

      // Report heap leaks while backend is still alive
      gny_report_leaks(LEngine);

      Check(LResult = 6, 'testStrings passed %d/6 (opt %d)',
        [LResult, LOptLevel]);
    finally
      gny_destroy(LEngine);
    end;
  end;

  gny_unload();
end;

end.