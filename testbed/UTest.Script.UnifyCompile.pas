{===============================================================================
  Ganymede™ - Embeddable Native Scripting Engine

  Copyright © 2026-present tinyBigGAMES™ LLC
  All Rights Reserved.

  See LICENSE for license information
===============================================================================}

unit UTest.Script.UnifyCompile;

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
  { TScriptUnifyCompileTest }
  TScriptUnifyCompileTest = class(TGnyTestCase)
  protected
    procedure Run(); override;
  public
    constructor Create(); override;
  end;

implementation

{ TScriptUnifyCompileTest }

constructor TScriptUnifyCompileTest.Create();
begin
  inherited;
  Title := 'PxlScript — Unified Compile (module kind routing)';
  Pause := True;
end;

procedure TScriptUnifyCompileTest.Run();
var
  LScript: TGanymede;
  LResult: Int64;
  LTempDir: string;
  LLibPath: string;
  LDump: string;
const
  // Test 1: module mem routes to BuildJIT
  CMemSource =
  '''
  module mem unify_test;

  public routine compute(x: int64): int64;
  begin
    return x * 2 + 1;
  end;

  end.
  ''';

  // Test 2: module lib via unified Compile (no CompileToLib)
  CLibSource =
  '''
  module lib unifylib;

  public routine ulib_add(a: int64; b: int64): int64;
  begin
    return a + b;
  end;

  end.
  ''';

  // Test 3: module mem that calls the lib we just compiled
  CMemCallLibSource =
  '''
  module mem unify_caller;

  public routine main(): int64;
  begin
    return ulib_add(100, 23);
  end;

  end.
  ''';
begin
  LTempDir := 'output';
  TGnyUtils.CreateDirInPath(LTempDir);

  //--- Test 1: module mem routes to BuildJIT ----------------------------------
  Section('module mem — routes to BuildJIT');
  LScript := TGanymede.Create();
  try
    LScript.LoadFromString(CMemSource, 'unify_test.pxs');
    if not LScript.Compile() then
      Check(False, 'Compile failed')
    else
    begin
      Check(LScript.Compiled, 'Compiled flag is True');
      LResult := LScript.Invoke('compute', [Int64(10)], gvtInt64).AsInt64;
      Check(LResult = 21, 'compute(10) = %d (expected 21)', [LResult]);
    end;
  finally
    LScript.PrintErrors();
    LScript.Free();
  end;

  //--- Test 2: module lib via plain Compile() + SetOutputPath -----------------
  Section('module lib — routes to TargetLib+Build via Compile()');
  LLibPath := TPath.Combine(LTempDir, 'unifylib.lib');

  // Clean up any previous run
  if TFile.Exists(LLibPath) then
    TFile.Delete(LLibPath);

  LScript := TGanymede.Create();
  try
    LScript
      .SetOutputPath(LTempDir)
      .LoadFromString(CLibSource, 'unifylib.pxs');

    if not LScript.Compile() then
      Check(False, 'Lib compile failed')
    else
    begin
      Check(True, 'Compile() succeeded for module lib');
      Check(TFile.Exists(LLibPath),
        'unifylib.lib exists at %s', [LLibPath]);
      Check(not LScript.Compiled,
        'Compiled (JIT) flag is False for lib target');
    end;
  finally
    LScript.PrintErrors();
    LScript.Free();
  end;

  //--- Test 3: Link the lib we just compiled and call it ----------------------
  Section('module mem — link unifylib.lib and invoke');
  LScript := TGanymede.Create();
  try
    LScript
      .ImportLib('unifylib', 'ulib_add',
        [gvtInt64, gvtInt64], gvtInt64, False, plDefault)
      .AddLibPath(LTempDir)
      .LoadFromString(CMemCallLibSource, 'unify_caller.pxs');

    if not LScript.Compile() then
      Check(False, 'JIT compile with lib link failed')
    else
    begin
      Check(True, 'Compiled mem module linking unifylib');
      LResult := LScript.Invoke('main', [], gvtInt64).AsInt64;
      Check(LResult = 123,
        'ulib_add(100, 23) = %d (expected 123)', [LResult]);
    end;
  finally
    LScript.PrintErrors();
    LScript.Free();
  end;

  //--- Test 4: SetDumpIR survives recompile -----------------------------------
  Section('SetDumpIR survives ResetBackend on recompile');
  LScript := TGanymede.Create();
  try
    LScript.SetDumpIR(True);
    LScript.LoadFromString(CMemSource, 'dump_test.pxs');

    // First compile
    if not LScript.Compile() then
      Check(False, 'First compile failed')
    else
    begin
      LDump := LScript.GetSSADump();
      Check(LDump.Length > 0,
        'First compile: SSA dump populated (%d chars)', [LDump.Length]);
    end;
    LScript.PrintErrors();

    // Second compile (triggers ResetBackend — DumpIR must survive)
    LScript.LoadFromString(CMemSource, 'dump_test2.pxs');
    if not LScript.Compile() then
      Check(False, 'Recompile failed')
    else
    begin
      LDump := LScript.GetSSADump();
      Check(LDump.Length > 0,
        'Recompile: SSA dump still populated (%d chars)', [LDump.Length]);
    end;
  finally
    LScript.PrintErrors();
    LScript.Free();
  end;
end;

end.
