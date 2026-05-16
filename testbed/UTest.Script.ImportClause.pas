{===============================================================================
  Ganymede™ - Embeddable Native Scripting Engine

  Copyright © 2026-present tinyBigGAMES™ LLC
  All Rights Reserved.

  See LICENSE for license information
===============================================================================}

unit UTest.Script.ImportClause;

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
  { TScriptImportClauseTest }
  TScriptImportClauseTest = class(TGnyTestCase)
  protected
    procedure Run(); override;
  public
    constructor Create(); override;
  end;

implementation

const
  CTestDir = 'C:\Dev\Delphi\Projects\Ganymede\repo\bin\tests';

{ TScriptImportClauseTest }

constructor TScriptImportClauseTest.Create();
begin
  inherited;
  Title := 'PxlScript — Import Clause + Externals';
  Pause := True;
end;

procedure TScriptImportClauseTest.Run();
var
  LScript: TGanymede;
  LResult: Int64;
  LLibPath: string;
begin
  //--- Test 1: Basic scoped import — source compiled inline -------------------
  Section('import test_lib_mathlib — source compiled inline');
  LScript := TGanymede.Create();
  try
    LScript
      .AddLibPath(CTestDir)
      .LoadFromFile(TPath.Combine(CTestDir, 'test_mem_import_basic.gny'));
    if not LScript.Compile() then
    begin
      FlushErrors(LScript.GetErrors());
      Check(False, 'Compile failed');
    end
    else
    begin
      Check(True, 'Compiled with scoped import');
      LResult := LScript.Invoke('main', [], gvtInt64).AsInt64;
      Check(LResult = 30, 'lib_add(10, 20) = %d (expected 30)', [LResult]);
    end;
  finally
    LScript.PrintErrors();
    LScript.Free();
  end;

  //--- Test 2: Multi-import ---------------------------------------------------
  Section('import test_lib_mathlib, test_lib_mathlib2 — multi-import');
  LScript := TGanymede.Create();
  try
    LScript
      .AddLibPath(CTestDir)
      .LoadFromFile(TPath.Combine(CTestDir, 'test_mem_import_multi.gny'));
    if not LScript.Compile() then
    begin
      FlushErrors(LScript.GetErrors());
      Check(False, 'Compile failed');
    end
    else
    begin
      Check(True, 'Compiled with multi-import');
      LResult := LScript.Invoke('main', [], gvtInt64).AsInt64;
      Check(LResult = 37, 'lib_add(3,4)+lib_mul(5,6) = %d (expected 37)', [LResult]);
    end;
  finally
    LScript.PrintErrors();
    LScript.Free();
  end;

  //--- Test 3: Import module with external DLL declaration --------------------
  Section('import test_dll_crtlib — external "msvcrt" via import');
  LScript := TGanymede.Create();
  try
    LScript
      .AddLibPath(CTestDir)
      .LoadFromFile(TPath.Combine(CTestDir, 'test_mem_import_dll.gny'));
    if not LScript.Compile() then
    begin
      FlushErrors(LScript.GetErrors());
      Check(False, 'Compile failed');
    end
    else
    begin
      Check(True, 'Compiled with DLL import via import clause');
      LResult := LScript.Invoke('main', [], gvtInt64).AsInt64;
      Check(LResult = 42, 'abs(-42) = %d (expected 42)', [LResult]);
    end;
  finally
    LScript.PrintErrors();
    LScript.Free();
  end;

  //--- Test 4: Lib creation — compile module lib to .lib ----------------------
  Section('module lib — compile to .lib via Compile()');
  LLibPath := TPath.Combine('output', 'test_lib_mathlib.lib');
  if TFile.Exists(LLibPath) then
    TFile.Delete(LLibPath);
  LScript := TGanymede.Create();
  try
    LScript
      .LoadFromFile(TPath.Combine(CTestDir, 'test_lib_mathlib.gny'));
    if not LScript.Compile() then
    begin
      FlushErrors(LScript.GetErrors());
      Check(False, 'Lib compile failed');
    end
    else
    begin
      Check(True, 'Compile() succeeded for module lib');
      Check(TFile.Exists(LLibPath), 'test_lib_mathlib.lib exists at %s', [LLibPath]);
    end;
  finally
    LScript.PrintErrors();
    LScript.Free();
  end;

  //--- Test 5: External .lib declaration in module mem -------------------------
  Section('module mem — source-level external .lib');
  LScript := TGanymede.Create();
  try
    LScript
      .AddLibPath('output')
      .LoadFromFile(TPath.Combine(CTestDir, 'test_mem_external_lib.gny'));
    if not LScript.Compile() then
    begin
      FlushErrors(LScript.GetErrors());
      Check(False, 'Compile failed');
    end
    else
    begin
      Check(True, 'Compiled with source-level .lib external');
      LResult := LScript.Invoke('main', [], gvtInt64).AsInt64;
      Check(LResult = 30, 'lib_add(10, 20) = %d (expected 30)', [LResult]);
    end;
  finally
    LScript.PrintErrors();
    LScript.Free();
  end;

  //--- Test 6: External DLL declaration in module mem -------------------------
  Section('module mem — source-level external "msvcrt"');
  LScript := TGanymede.Create();
  try
    LScript
      .LoadFromFile(TPath.Combine(CTestDir, 'test_mem_external_dll.gny'));
    if not LScript.Compile() then
    begin
      FlushErrors(LScript.GetErrors());
      Check(False, 'Compile failed');
    end
    else
    begin
      Check(True, 'Compiled with source-level external');
      LResult := LScript.Invoke('main', [], gvtInt64).AsInt64;
      Check(LResult = 42, 'abs(-42) = %d (expected 42)', [LResult]);
    end;
  finally
    LScript.PrintErrors();
    LScript.Free();
  end;

  //--- Test 6: External declaration in module lib -----------------------------
  Section('module lib — source-level external + own routine');
  LLibPath := TPath.Combine('output', 'test_lib_external_dll.lib');
  if TFile.Exists(LLibPath) then
    TFile.Delete(LLibPath);
  LScript := TGanymede.Create();
  try
    LScript
      .LoadFromFile(TPath.Combine(CTestDir, 'test_lib_external_dll.gny'));
    if not LScript.Compile() then
    begin
      FlushErrors(LScript.GetErrors());
      Check(False, 'Lib compile failed');
    end
    else
    begin
      Check(True, 'Compile() succeeded for lib with external');
      Check(TFile.Exists(LLibPath), 'test_lib_external_dll.lib exists');
    end;
  finally
    LScript.PrintErrors();
    LScript.Free();
  end;

  //--- Test 7: mem imports .gny with external .lib ----------------------------
  Section('module mem — import ext wrapper for .lib');
  LScript := TGanymede.Create();
  try
    LScript
      .AddLibPath(CTestDir)
      .AddLibPath('output')
      .LoadFromFile(TPath.Combine(CTestDir, 'test_mem_import_lib_ext.gny'));
    if not LScript.Compile() then
    begin
      FlushErrors(LScript.GetErrors());
      Check(False, 'Compile failed');
    end
    else
    begin
      Check(True, 'Compiled mem with imported .lib external');
      LResult := LScript.Invoke('main', [], gvtInt64).AsInt64;
      Check(LResult = 30, 'lib_add(10, 20) = %d (expected 30)', [LResult]);
    end;
  finally
    LScript.PrintErrors();
    LScript.Free();
  end;

  //--- Test 8: lib imports .gny with external .lib ----------------------------
  Section('module lib — import ext wrapper for .lib');
  LLibPath := TPath.Combine('output', 'test_lib_import_lib_ext.lib');
  if TFile.Exists(LLibPath) then
    TFile.Delete(LLibPath);
  LScript := TGanymede.Create();
  try
    LScript
      .AddLibPath(CTestDir)
      .AddLibPath('output')
      .LoadFromFile(TPath.Combine(CTestDir, 'test_lib_import_lib_ext.gny'));
    if not LScript.Compile() then
    begin
      FlushErrors(LScript.GetErrors());
      Check(False, 'Lib compile failed');
    end
    else
    begin
      Check(True, 'Compiled lib with imported .lib external');
      Check(TFile.Exists(LLibPath), 'test_lib_import_lib_ext.lib exists');
    end;
  finally
    LScript.PrintErrors();
    LScript.Free();
  end;

  //--- Test 9: Import not found -----------------------------------------------
  Section('import nonexistent — expect compile error');
  LScript := TGanymede.Create();
  try
    LScript
      .AddLibPath(CTestDir)
      .LoadFromFile(TPath.Combine(CTestDir, 'test_mem_import_bad.gny'));
    if not LScript.Compile() then
      Check(True, 'Compile correctly failed for missing import')
    else
      Check(False, 'Compile should have failed but succeeded');
  finally
    LScript.PrintErrors();
    LScript.Free();
  end;

  //--- Test 10: Overloaded cpplink exports via import -------------------------
  Section('import test_lib_overload — cpplink overloads');
  LScript := TGanymede.Create();
  try
    LScript
      .AddLibPath(CTestDir)
      .LoadFromFile(TPath.Combine(CTestDir, 'test_mem_import_overload.gny'));
    if not LScript.Compile() then
    begin
      FlushErrors(LScript.GetErrors());
      Check(False, 'Compile failed');
    end
    else
    begin
      Check(True, 'Compiled with overloaded cpplink imports');
      LResult := LScript.Invoke('main', [], gvtInt64).AsInt64;
      Check(LResult = 94, 'compute(5)+compute(3,4)+add(10,20) = %d (expected 94)', [LResult]);
    end;
  finally
    LScript.PrintErrors();
    LScript.Free();
  end;

  //--- Test 11: Compile overload lib to .lib ----------------------------------
  Section('module lib — compile overload lib to .lib');
  LLibPath := TPath.Combine('output', 'test_lib_overload.lib');
  if TFile.Exists(LLibPath) then
    TFile.Delete(LLibPath);
  LScript := TGanymede.Create();
  try
    LScript
      .LoadFromFile(TPath.Combine(CTestDir, 'test_lib_overload.gny'));
    if not LScript.Compile() then
    begin
      FlushErrors(LScript.GetErrors());
      Check(False, 'Lib compile failed');
    end
    else
    begin
      Check(True, 'Compile() succeeded for overload lib');
      Check(TFile.Exists(LLibPath), 'test_lib_overload.lib exists at %s', [LLibPath]);
    end;
  finally
    LScript.PrintErrors();
    LScript.Free();
  end;

  //--- Test 12: External cpplink overloads from .lib --------------------------
  Section('module mem — external cpplink overloads from .lib');
  LScript := TGanymede.Create();
  try
    LScript
      .AddLibPath('output')
      .LoadFromFile(TPath.Combine(CTestDir, 'test_mem_external_overload_lib.gny'));
    if not LScript.Compile() then
    begin
      FlushErrors(LScript.GetErrors());
      Check(False, 'Compile failed');
    end
    else
    begin
      Check(True, 'Compiled with external cpplink overloads from .lib');
      LResult := LScript.Invoke('main', [], gvtInt64).AsInt64;
      Check(LResult = 94, 'compute(5)+compute(3,4)+add(10,20) = %d (expected 94)', [LResult]);
    end;
  finally
    LScript.PrintErrors();
    LScript.Free();
  end;

  //--- Test 13: Compile module dll — C linkage --------------------------------
  Section('module dll — compile to .dll via Compile()');
  LLibPath := TPath.Combine(ExtractFilePath(ParamStr(0)), 'test_dll_mathlib.dll');
  if TFile.Exists(LLibPath) then
    TFile.Delete(LLibPath);
  LScript := TGanymede.Create();
  try
    LScript
      .SetOutputPath(ExtractFilePath(ParamStr(0)))
      .LoadFromFile(TPath.Combine(CTestDir, 'test_dll_mathlib.gny'));
    if not LScript.Compile() then
    begin
      FlushErrors(LScript.GetErrors());
      Check(False, 'DLL compile failed');
    end
    else
    begin
      Check(True, 'Compile() succeeded for module dll');
      Check(TFile.Exists(LLibPath), 'test_dll_mathlib.dll exists at %s', [LLibPath]);
    end;
  finally
    LScript.PrintErrors();
    LScript.Free();
  end;

  //--- Test 14: External .dll declaration in module mem (C linkage) ------------
  Section('module mem — external .dll C linkage');
  LScript := TGanymede.Create();
  try
    LScript
      .LoadFromFile(TPath.Combine(CTestDir, 'test_mem_external_dll_custom.gny'));
    if not LScript.Compile() then
    begin
      FlushErrors(LScript.GetErrors());
      Check(False, 'Compile failed');
    end
    else
    begin
      Check(True, 'Compiled with external .dll C linkage');
      LResult := LScript.Invoke('main', [], gvtInt64).AsInt64;
      Check(LResult = 30, 'lib_add(10, 20) = %d (expected 30)', [LResult]);
    end;
  finally
    LScript.PrintErrors();
    LScript.Free();
  end;

  //--- Test 15: mem imports wrapper with external .dll (C linkage) -------------
  Section('module mem — import wrapper with external .dll');
  LScript := TGanymede.Create();
  try
    LScript
      .AddLibPath(CTestDir)
      .LoadFromFile(TPath.Combine(CTestDir, 'test_mem_import_dll_custom_ext.gny'));
    if not LScript.Compile() then
    begin
      FlushErrors(LScript.GetErrors());
      Check(False, 'Compile failed');
    end
    else
    begin
      Check(True, 'Compiled mem with imported .dll external');
      LResult := LScript.Invoke('main', [], gvtInt64).AsInt64;
      Check(LResult = 30, 'lib_add(10, 20) = %d (expected 30)', [LResult]);
    end;
  finally
    LScript.PrintErrors();
    LScript.Free();
  end;

  //--- Test 16: Compile overload dll to .dll (cpplink) ------------------------
  Section('module dll — compile overload dll to .dll');
  LLibPath := TPath.Combine(ExtractFilePath(ParamStr(0)), 'test_dll_overload.dll');
  if TFile.Exists(LLibPath) then
    TFile.Delete(LLibPath);
  LScript := TGanymede.Create();
  try
    LScript
      .SetOutputPath(ExtractFilePath(ParamStr(0)))
      .LoadFromFile(TPath.Combine(CTestDir, 'test_dll_overload.gny'));
    if not LScript.Compile() then
    begin
      FlushErrors(LScript.GetErrors());
      Check(False, 'DLL compile failed');
    end
    else
    begin
      Check(True, 'Compile() succeeded for overload dll');
      Check(TFile.Exists(LLibPath), 'test_dll_overload.dll exists at %s', [LLibPath]);
    end;
  finally
    LScript.PrintErrors();
    LScript.Free();
  end;

  //--- Test 17: External cpplink overloads from .dll --------------------------
  Section('module mem — external cpplink overloads from .dll');
  LScript := TGanymede.Create();
  try
    LScript
      .LoadFromFile(TPath.Combine(CTestDir, 'test_mem_external_overload_dll.gny'));
    if not LScript.Compile() then
    begin
      FlushErrors(LScript.GetErrors());
      Check(False, 'Compile failed');
    end
    else
    begin
      Check(True, 'Compiled with external cpplink overloads from .dll');
      LResult := LScript.Invoke('main', [], gvtInt64).AsInt64;
      Check(LResult = 94, 'compute(5)+compute(3,4)+add(10,20) = %d (expected 94)', [LResult]);
    end;
  finally
    LScript.PrintErrors();
    LScript.Free();
  end;
end;

end.
