{===============================================================================
  Ganymede™ - Embeddable Native Scripting Engine

  Copyright © 2026-present tinyBigGAMES™ LLC
  All Rights Reserved.

  See LICENSE for license information
===============================================================================}

unit UTest.ImportClause;

{$I Ganymede.Defines.inc}

interface

uses
  Ganymede.TestCase;

type
  { TScriptImportClauseTest }
  TScriptImportClauseTest = class(TGnyTestCase)
  protected
    procedure Run(); override;
  public
    constructor Create(); override;
  end;

implementation

uses
  System.SysUtils,
  System.IOUtils,
  UCommon,
  Ganymede;

{ TScriptImportClauseTest }

constructor TScriptImportClauseTest.Create();
begin
  inherited;
  Title := 'PxlScript — Import Clause + Externals';
  Pause := True;
end;

procedure TScriptImportClauseTest.Run();
var
  LEngine: TGnyEngine;
  LResult: Int64;
  LLibPath: string;
begin
  if not gny_load(PAnsiChar(UTF8Encode(CDllPath))) then
  begin
    Check(False, 'Failed to load Ganymede DLL');
    Exit;
  end;
  //--- Test 1: Basic scoped import — source compiled inline -------------------
  Section('import test_lib_mathlib — source compiled inline');
  LEngine := gny_create();
  try
    gny_add_lib_path(LEngine, PAnsiChar(UTF8Encode(CTestDir)));
    gny_load_from_file(LEngine,
      PAnsiChar(UTF8Encode(TPath.Combine(CTestDir, 'test_mem_import_basic.gny'))));
    if not gny_compile(LEngine) then
    begin
      gny_print_errors(LEngine);
      Check(False, 'Compile failed');
    end
    else
    begin
      Check(True, 'Compiled with scoped import');
      LResult := gny_invoke(LEngine,
        PAnsiChar(UTF8Encode('main')), GNY_VT_INT64).AsInt64;
      Check(LResult = 30, 'lib_add(10, 20) = %d (expected 30)', [LResult]);
    end;
  finally
    gny_print_errors(LEngine);
    gny_destroy(LEngine);
  end;

  //--- Test 2: Multi-import ---------------------------------------------------
  Section('import test_lib_mathlib, test_lib_mathlib2 — multi-import');
  LEngine := gny_create();
  try
    gny_add_lib_path(LEngine, PAnsiChar(UTF8Encode(CTestDir)));
    gny_load_from_file(LEngine,
      PAnsiChar(UTF8Encode(TPath.Combine(CTestDir, 'test_mem_import_multi.gny'))));
    if not gny_compile(LEngine) then
    begin
      gny_print_errors(LEngine);
      Check(False, 'Compile failed');
    end
    else
    begin
      Check(True, 'Compiled with multi-import');
      LResult := gny_invoke(LEngine,
        PAnsiChar(UTF8Encode('main')), GNY_VT_INT64).AsInt64;
      Check(LResult = 37, 'lib_add(3,4)+lib_mul(5,6) = %d (expected 37)', [LResult]);
    end;
  finally
    gny_print_errors(LEngine);
    gny_destroy(LEngine);
  end;
  //--- Test 3: Import module with external DLL declaration --------------------
  Section('import test_dll_crtlib — external "msvcrt" via import');
  LEngine := gny_create();
  try
    gny_add_lib_path(LEngine, PAnsiChar(UTF8Encode(CTestDir)));
    gny_load_from_file(LEngine,
      PAnsiChar(UTF8Encode(TPath.Combine(CTestDir, 'test_mem_import_dll.gny'))));
    if not gny_compile(LEngine) then
    begin
      gny_print_errors(LEngine);
      Check(False, 'Compile failed');
    end
    else
    begin
      Check(True, 'Compiled with DLL import via import clause');
      LResult := gny_invoke(LEngine,
        PAnsiChar(UTF8Encode('main')), GNY_VT_INT64).AsInt64;
      Check(LResult = 42, 'abs(-42) = %d (expected 42)', [LResult]);
    end;
  finally
    gny_print_errors(LEngine);
    gny_destroy(LEngine);
  end;

  //--- Test 4: Lib creation — compile module lib to .lib ----------------------
  Section('module lib — compile to .lib via Compile()');
  LLibPath := TPath.Combine('output', 'test_lib_mathlib.lib');
  if TFile.Exists(LLibPath) then
    TFile.Delete(LLibPath);
  LEngine := gny_create();
  try
    gny_load_from_file(LEngine,
      PAnsiChar(UTF8Encode(TPath.Combine(CTestDir, 'test_lib_mathlib.gny'))));
    if not gny_compile(LEngine) then
    begin
      gny_print_errors(LEngine);
      Check(False, 'Lib compile failed');
    end
    else
    begin
      Check(True, 'Compile() succeeded for module lib');
      Check(TFile.Exists(LLibPath), 'test_lib_mathlib.lib exists at %s', [LLibPath]);
    end;
  finally
    gny_print_errors(LEngine);
    gny_destroy(LEngine);
  end;
  //--- Test 5: External .lib declaration in module mem -------------------------
  Section('module mem — source-level external .lib');
  LEngine := gny_create();
  try
    gny_add_lib_path(LEngine, PAnsiChar(UTF8Encode('output')));
    gny_load_from_file(LEngine,
      PAnsiChar(UTF8Encode(TPath.Combine(CTestDir, 'test_mem_external_lib.gny'))));
    if not gny_compile(LEngine) then
    begin
      gny_print_errors(LEngine);
      Check(False, 'Compile failed');
    end
    else
    begin
      Check(True, 'Compiled with source-level .lib external');
      LResult := gny_invoke(LEngine,
        PAnsiChar(UTF8Encode('main')), GNY_VT_INT64).AsInt64;
      Check(LResult = 30, 'lib_add(10, 20) = %d (expected 30)', [LResult]);
    end;
  finally
    gny_print_errors(LEngine);
    gny_destroy(LEngine);
  end;

  //--- Test 6: External DLL declaration in module mem -------------------------
  Section('module mem — source-level external "msvcrt"');
  LEngine := gny_create();
  try
    gny_load_from_file(LEngine,
      PAnsiChar(UTF8Encode(TPath.Combine(CTestDir, 'test_mem_external_dll.gny'))));
    if not gny_compile(LEngine) then
    begin
      gny_print_errors(LEngine);
      Check(False, 'Compile failed');
    end
    else
    begin
      Check(True, 'Compiled with source-level external');
      LResult := gny_invoke(LEngine,
        PAnsiChar(UTF8Encode('main')), GNY_VT_INT64).AsInt64;
      Check(LResult = 42, 'abs(-42) = %d (expected 42)', [LResult]);
    end;
  finally
    gny_print_errors(LEngine);
    gny_destroy(LEngine);
  end;
  //--- Test 6: External declaration in module lib -----------------------------
  Section('module lib — source-level external + own routine');
  LLibPath := TPath.Combine('output', 'test_lib_external_dll.lib');
  if TFile.Exists(LLibPath) then
    TFile.Delete(LLibPath);
  LEngine := gny_create();
  try
    gny_load_from_file(LEngine,
      PAnsiChar(UTF8Encode(TPath.Combine(CTestDir, 'test_lib_external_dll.gny'))));
    if not gny_compile(LEngine) then
    begin
      gny_print_errors(LEngine);
      Check(False, 'Lib compile failed');
    end
    else
    begin
      Check(True, 'Compile() succeeded for lib with external');
      Check(TFile.Exists(LLibPath), 'test_lib_external_dll.lib exists');
    end;
  finally
    gny_print_errors(LEngine);
    gny_destroy(LEngine);
  end;

  //--- Test 7: mem imports .gny with external .lib ----------------------------
  Section('module mem — import ext wrapper for .lib');
  LEngine := gny_create();
  try
    gny_add_lib_path(LEngine, PAnsiChar(UTF8Encode(CTestDir)));
    gny_add_lib_path(LEngine, PAnsiChar(UTF8Encode('output')));
    gny_load_from_file(LEngine,
      PAnsiChar(UTF8Encode(TPath.Combine(CTestDir, 'test_mem_import_lib_ext.gny'))));
    if not gny_compile(LEngine) then
    begin
      gny_print_errors(LEngine);
      Check(False, 'Compile failed');
    end
    else
    begin
      Check(True, 'Compiled mem with imported .lib external');
      LResult := gny_invoke(LEngine,
        PAnsiChar(UTF8Encode('main')), GNY_VT_INT64).AsInt64;
      Check(LResult = 30, 'lib_add(10, 20) = %d (expected 30)', [LResult]);
    end;
  finally
    gny_print_errors(LEngine);
    gny_destroy(LEngine);
  end;
  //--- Test 8: lib imports .gny with external .lib ----------------------------
  Section('module lib — import ext wrapper for .lib');
  LLibPath := TPath.Combine('output', 'test_lib_import_lib_ext.lib');
  if TFile.Exists(LLibPath) then
    TFile.Delete(LLibPath);
  LEngine := gny_create();
  try
    gny_add_lib_path(LEngine, PAnsiChar(UTF8Encode(CTestDir)));
    gny_add_lib_path(LEngine, PAnsiChar(UTF8Encode('output')));
    gny_load_from_file(LEngine,
      PAnsiChar(UTF8Encode(TPath.Combine(CTestDir, 'test_lib_import_lib_ext.gny'))));
    if not gny_compile(LEngine) then
    begin
      gny_print_errors(LEngine);
      Check(False, 'Lib compile failed');
    end
    else
    begin
      Check(True, 'Compiled lib with imported .lib external');
      Check(TFile.Exists(LLibPath), 'test_lib_import_lib_ext.lib exists');
    end;
  finally
    gny_print_errors(LEngine);
    gny_destroy(LEngine);
  end;

  //--- Test 9: Import not found -----------------------------------------------
  Section('import nonexistent — expect compile error');
  LEngine := gny_create();
  try
    gny_add_lib_path(LEngine, PAnsiChar(UTF8Encode(CTestDir)));
    gny_load_from_file(LEngine,
      PAnsiChar(UTF8Encode(TPath.Combine(CTestDir, 'test_mem_import_bad.gny'))));
    if not gny_compile(LEngine) then
      Check(True, 'Compile correctly failed for missing import')
    else
      Check(False, 'Compile should have failed but succeeded');
  finally
    gny_print_errors(LEngine);
    gny_destroy(LEngine);
  end;
  //--- Test 10: Overloaded cpplink exports via import -------------------------
  Section('import test_lib_overload — cpplink overloads');
  LEngine := gny_create();
  try
    gny_add_lib_path(LEngine, PAnsiChar(UTF8Encode(CTestDir)));
    gny_load_from_file(LEngine,
      PAnsiChar(UTF8Encode(TPath.Combine(CTestDir, 'test_mem_import_overload.gny'))));
    if not gny_compile(LEngine) then
    begin
      gny_print_errors(LEngine);
      Check(False, 'Compile failed');
    end
    else
    begin
      Check(True, 'Compiled with overloaded cpplink imports');
      LResult := gny_invoke(LEngine,
        PAnsiChar(UTF8Encode('main')), GNY_VT_INT64).AsInt64;
      Check(LResult = 94, 'compute(5)+compute(3,4)+add(10,20) = %d (expected 94)', [LResult]);
    end;
  finally
    gny_print_errors(LEngine);
    gny_destroy(LEngine);
  end;

  //--- Test 11: Compile overload lib to .lib ----------------------------------
  Section('module lib — compile overload lib to .lib');
  LLibPath := TPath.Combine('output', 'test_lib_overload.lib');
  if TFile.Exists(LLibPath) then
    TFile.Delete(LLibPath);
  LEngine := gny_create();
  try
    gny_load_from_file(LEngine,
      PAnsiChar(UTF8Encode(TPath.Combine(CTestDir, 'test_lib_overload.gny'))));
    if not gny_compile(LEngine) then
    begin
      gny_print_errors(LEngine);
      Check(False, 'Lib compile failed');
    end
    else
    begin
      Check(True, 'Compile() succeeded for overload lib');
      Check(TFile.Exists(LLibPath), 'test_lib_overload.lib exists at %s', [LLibPath]);
    end;
  finally
    gny_print_errors(LEngine);
    gny_destroy(LEngine);
  end;
  //--- Test 12: External cpplink overloads from .lib --------------------------
  Section('module mem — external cpplink overloads from .lib');
  LEngine := gny_create();
  try
    gny_add_lib_path(LEngine, PAnsiChar(UTF8Encode('output')));
    gny_load_from_file(LEngine,
      PAnsiChar(UTF8Encode(TPath.Combine(CTestDir, 'test_mem_external_overload_lib.gny'))));
    if not gny_compile(LEngine) then
    begin
      gny_print_errors(LEngine);
      Check(False, 'Compile failed');
    end
    else
    begin
      Check(True, 'Compiled with external cpplink overloads from .lib');
      LResult := gny_invoke(LEngine,
        PAnsiChar(UTF8Encode('main')), GNY_VT_INT64).AsInt64;
      Check(LResult = 94, 'compute(5)+compute(3,4)+add(10,20) = %d (expected 94)', [LResult]);
    end;
  finally
    gny_print_errors(LEngine);
    gny_destroy(LEngine);
  end;

  //--- Test 13: Compile module dll — C linkage --------------------------------
  Section('module dll — compile to .dll via Compile()');
  LLibPath := TPath.Combine(ExtractFilePath(ParamStr(0)), 'test_dll_mathlib.dll');
  if TFile.Exists(LLibPath) then
    TFile.Delete(LLibPath);
  LEngine := gny_create();
  try
    gny_set_output_path(LEngine,
      PAnsiChar(UTF8Encode(ExtractFilePath(ParamStr(0)))));
    gny_load_from_file(LEngine,
      PAnsiChar(UTF8Encode(TPath.Combine(CTestDir, 'test_dll_mathlib.gny'))));
    if not gny_compile(LEngine) then
    begin
      gny_print_errors(LEngine);
      Check(False, 'DLL compile failed');
    end
    else
    begin
      Check(True, 'Compile() succeeded for module dll');
      Check(TFile.Exists(LLibPath), 'test_dll_mathlib.dll exists at %s', [LLibPath]);
    end;
  finally
    gny_print_errors(LEngine);
    gny_destroy(LEngine);
  end;
  //--- Test 14: External .dll declaration in module mem (C linkage) ------------
  Section('module mem — external .dll C linkage');
  LEngine := gny_create();
  try
    gny_load_from_file(LEngine,
      PAnsiChar(UTF8Encode(TPath.Combine(CTestDir, 'test_mem_external_dll_custom.gny'))));
    if not gny_compile(LEngine) then
    begin
      gny_print_errors(LEngine);
      Check(False, 'Compile failed');
    end
    else
    begin
      Check(True, 'Compiled with external .dll C linkage');
      LResult := gny_invoke(LEngine,
        PAnsiChar(UTF8Encode('main')), GNY_VT_INT64).AsInt64;
      Check(LResult = 30, 'lib_add(10, 20) = %d (expected 30)', [LResult]);
    end;
  finally
    gny_print_errors(LEngine);
    gny_destroy(LEngine);
  end;

  //--- Test 15: mem imports wrapper with external .dll (C linkage) -------------
  Section('module mem — import wrapper with external .dll');
  LEngine := gny_create();
  try
    gny_add_lib_path(LEngine, PAnsiChar(UTF8Encode(CTestDir)));
    gny_load_from_file(LEngine,
      PAnsiChar(UTF8Encode(TPath.Combine(CTestDir, 'test_mem_import_dll_custom_ext.gny'))));
    if not gny_compile(LEngine) then
    begin
      gny_print_errors(LEngine);
      Check(False, 'Compile failed');
    end
    else
    begin
      Check(True, 'Compiled mem with imported .dll external');
      LResult := gny_invoke(LEngine,
        PAnsiChar(UTF8Encode('main')), GNY_VT_INT64).AsInt64;
      Check(LResult = 30, 'lib_add(10, 20) = %d (expected 30)', [LResult]);
    end;
  finally
    gny_print_errors(LEngine);
    gny_destroy(LEngine);
  end;
  //--- Test 16: Compile overload dll to .dll (cpplink) ------------------------
  Section('module dll — compile overload dll to .dll');
  LLibPath := TPath.Combine(ExtractFilePath(ParamStr(0)), 'test_dll_overload.dll');
  if TFile.Exists(LLibPath) then
    TFile.Delete(LLibPath);
  LEngine := gny_create();
  try
    gny_set_output_path(LEngine,
      PAnsiChar(UTF8Encode(ExtractFilePath(ParamStr(0)))));
    gny_load_from_file(LEngine,
      PAnsiChar(UTF8Encode(TPath.Combine(CTestDir, 'test_dll_overload.gny'))));
    if not gny_compile(LEngine) then
    begin
      gny_print_errors(LEngine);
      Check(False, 'DLL compile failed');
    end
    else
    begin
      Check(True, 'Compile() succeeded for overload dll');
      Check(TFile.Exists(LLibPath), 'test_dll_overload.dll exists at %s', [LLibPath]);
    end;
  finally
    gny_print_errors(LEngine);
    gny_destroy(LEngine);
  end;

  //--- Test 17: External cpplink overloads from .dll --------------------------
  Section('module mem — external cpplink overloads from .dll');
  LEngine := gny_create();
  try
    gny_load_from_file(LEngine,
      PAnsiChar(UTF8Encode(TPath.Combine(CTestDir, 'test_mem_external_overload_dll.gny'))));
    if not gny_compile(LEngine) then
    begin
      gny_print_errors(LEngine);
      Check(False, 'Compile failed');
    end
    else
    begin
      Check(True, 'Compiled with external cpplink overloads from .dll');
      LResult := gny_invoke(LEngine,
        PAnsiChar(UTF8Encode('main')), GNY_VT_INT64).AsInt64;
      Check(LResult = 94, 'compute(5)+compute(3,4)+add(10,20) = %d (expected 94)', [LResult]);
    end;
  finally
    gny_print_errors(LEngine);
    gny_destroy(LEngine);
  end;

  gny_unload();
end;

end.