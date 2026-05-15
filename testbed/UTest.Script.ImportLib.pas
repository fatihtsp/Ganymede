{===============================================================================
  Ganymede™ - Embeddable Native Scripting Engine

  Copyright © 2026-present tinyBigGAMES™ LLC
  All Rights Reserved.

  See LICENSE for license information
===============================================================================}

unit UTest.Script.ImportLib;

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
  { TScriptImportLibTest }
  TScriptImportLibTest = class(TGnyTestCase)
  protected
    procedure Run(); override;
  public
    constructor Create(); override;
  end;

implementation

procedure StatusCallback(const AText: string; const AUserData: Pointer);
begin
  //TGnyUtils.PrintLn(AText);
end;

{ TScriptImportLibTest }

constructor TScriptImportLibTest.Create();
begin
  inherited;
  Title := 'PxlScript — ImportLib (JIT Static Library Linking)';
  Pause := True;
end;

procedure TScriptImportLibTest.Run();
var
  LScript: TGanymede;
  LResult: Int64;
  LTempDir: string;
  LLibPath: string;
const

  // Library source — exports a simple add function
  CLibSource =
  '''
  module lib mathlib;

  public routine lib_add(a: int64; b: int64): int64;
  begin
    return a + b;
  end;

  end.
  ''';

  // Library source — exports multiply and subtract
  CLib2Source =
  '''
  module lib mathlib2;

  public routine lib_mul(a: int64; b: int64): int64;
  begin
    return a * b;
  end;

  public routine lib_sub(a: int64; b: int64): int64;
  begin
    return a - b;
  end;

  end.
  ''';

  // JIT source — calls lib_add from the .lib
  CJITAddSource =
  '''
  module mem test_add;

  public routine main(): int64;
  begin
    return lib_add(10, 20);
  end;

  end.
  ''';

  // JIT source — calls both lib_mul and lib_sub
  CJITMultiSource =
  '''
  module mem test_multi;

  public routine main(): int64;
  begin
    return lib_mul(6, 7) - lib_sub(10, 2);
  end;

  end.
  ''';

  // JIT source — calls abs from msvcrt.dll
  CJITDllSource =
  '''
  module mem test_dll;

  public routine main(): int64;
  begin
    return abs(-42);
  end;

  end.
  ''';

begin
  // Create a temp directory for .lib files
  LTempDir := 'output';
  TGnyUtils.CreateDirInPath(LTempDir);

  //--- Test 1: Compile library, then JIT-link and invoke ----------------------
  Section('Compile mathlib.lib + JIT link lib_add(10, 20)');

  LLibPath := TPath.Combine(LTempDir, 'mathlib.lib');
  LScript := TGanymede.Create();
  try
    LScript.SetStatusCallback(StatusCallback, nil);
    LScript.LoadFromString(CLibSource, 'mathlib.pxs');
    if not LScript.CompileToLib(LLibPath) then
    begin
      FlushErrors(LScript.GetErrors());
      Check(False, 'Library compilation failed');
    end
    else
    begin
      Check(True, 'mathlib.lib compiled successfully');
      Check(FileExists(LLibPath), 'mathlib.lib exists on disk');
    end;
  finally
    LScript.Free();
  end;

  // Now JIT-compile a module that imports from the .lib
  LScript := TGanymede.Create();
  try
    LScript.SetStatusCallback(StatusCallback, nil);
    LScript.ImportLib('mathlib', 'lib_add', [gvtInt64, gvtInt64], gvtInt64, False, plDefault);
    LScript.AddLibPath(LTempDir);
    LScript.LoadFromString(CJITAddSource, 'test_add.pxs');
    if not LScript.Compile() then
    begin
      FlushErrors(LScript.GetErrors());
      Check(False, 'JIT compile failed');
    end
    else
    begin
      Check(True, 'JIT compiled successfully');

      LResult := LScript.Invoke('main', [], gvtInt64).AsInt64;
      Check(LResult = 30, 'lib_add(10, 20) = %d (expected 30)', [LResult]);
    end;
  finally
    LScript.Free();
  end;

  //--- Test 2: Multiple functions from one lib --------------------------------
  Section('Compile mathlib2.lib + JIT link lib_mul and lib_sub');

  LLibPath := TPath.Combine(LTempDir, 'mathlib2.lib');
  LScript := TGanymede.Create();
  try
    LScript.SetStatusCallback(StatusCallback, nil);
    LScript.LoadFromString(CLib2Source, 'mathlib2.pxs');
    if not LScript.CompileToLib(LLibPath) then
    begin
      FlushErrors(LScript.GetErrors());
      Check(False, 'Library compilation failed');
    end
    else
      Check(True, 'mathlib2.lib compiled successfully');
  finally
    LScript.Free();
  end;

  LScript := TGanymede.Create();
  try
    LScript.SetStatusCallback(StatusCallback, nil);
    LScript.ImportLib('mathlib2', 'lib_mul', [gvtInt64, gvtInt64], gvtInt64, False, plDefault);
    LScript.ImportLib('mathlib2', 'lib_sub', [gvtInt64, gvtInt64], gvtInt64, False, plDefault);
    LScript.AddLibPath(LTempDir);
    LScript.LoadFromString(CJITMultiSource, 'test_multi.pxs');

    if not LScript.Compile() then
    begin
      FlushErrors(LScript.GetErrors());
      Check(False, 'JIT compile failed');
    end
    else
    begin
      Check(True, 'JIT compiled successfully');
      LResult := LScript.Invoke('main', [], gvtInt64).AsInt64;
      Check(LResult = 34, 'lib_mul(6,7) - lib_sub(10,2) = %d (expected 34)',
        [LResult]);
    end;
  finally
    LScript.Free();
  end;

  //--- Test 3: DLL import -----------------------------------------------------
  Section('ImportDll — msvcrt.dll!abs(-42)');

  LScript := TGanymede.Create();
  try
    LScript.SetStatusCallback(StatusCallback);
    LScript.ImportDll('msvcrt.dll', 'abs', [gvtInt64], gvtInt64);
    LScript.LoadFromString(CJITDllSource, 'test_dll.pxs');

    if not LScript.Compile() then
    begin
      FlushErrors(LScript.GetErrors());
      Check(False, 'JIT compile failed');
    end
    else
    begin
      Check(True, 'JIT compiled successfully');
      LResult := LScript.Invoke('main', [], gvtInt64).AsInt64;
      Check(LResult = 42, 'abs(-42) = %d (expected 42)', [LResult]);
    end;
  finally
    LScript.Free();
  end;

end;

end.
