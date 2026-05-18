{===============================================================================
  Ganymede™ - Embeddable Native Scripting Engine

  Copyright © 2026-present tinyBigGAMES™ LLC
  All Rights Reserved.

  See LICENSE for license information
===============================================================================}

unit UTest.GetMem;

{$I Ganymede.Defines.inc}

interface

uses
  Ganymede.TestCase;

type
  TScriptGetMemTest = class(TGnyTestCase)
  public
    constructor Create(); override;
  protected
    procedure Run(); override;
  end;

implementation

uses
  System.IOUtils,
  UCommon,
  Ganymede;
{ TScriptGetMemTest }

constructor TScriptGetMemTest.Create();
begin
  inherited;
  Title := 'GanymedeScript — GetMem/FreeMem/ResizeMem';
  Pause := True;
end;

procedure TScriptGetMemTest.Run();
var
  LEngine: TGnyEngine;
  LI32: Int32;
  LI64: Int64;
  LF64: Double;
  LU8: UInt8;
  LOptLevel: Integer;
  LFile: string;
begin
  if not gny_load(PAnsiChar(UTF8Encode(CDllPath))) then
  begin
    Check(False, 'Failed to load Ganymede DLL');
    Exit;
  end;

  LFile := TPath.Combine(CTestDir, 'test_mem_getmem.gny');

  for LOptLevel := GNY_OPT_NONE to GNY_OPT_FULL do
  begin
    Section('GetMem/FreeMem/ResizeMem — opt level %d', [LOptLevel]);
    LEngine := gny_create();
    try
      gny_set_optimization_level(LEngine, LOptLevel);
      gny_load_from_file(LEngine, PAnsiChar(UTF8Encode(LFile)));

      if not gny_compile(LEngine) then
      begin
        gny_print_errors(LEngine);
        Check(False, 'Compile failed (opt %d)', [LOptLevel]);
        Continue;
      end;

      Check(True, 'Compiled successfully (opt %d)', [LOptLevel]);
      LI32 := gny_invoke(LEngine, PAnsiChar(UTF8Encode('test_getmem_i32')), GNY_VT_INT32).AsInt32;
      Check(LI32 = 42, 'test_getmem_i32 = %d (expected 42, opt %d)', [LI32, LOptLevel]);

      LI64 := gny_invoke(LEngine, PAnsiChar(UTF8Encode('test_getmem_i64')), GNY_VT_INT64).AsInt64;
      Check(LI64 = 1000000000, 'test_getmem_i64 = %d (expected 1000000000, opt %d)', [LI64, LOptLevel]);

      LF64 := gny_invoke(LEngine, PAnsiChar(UTF8Encode('test_getmem_f64')), GNY_VT_FLOAT64).AsFloat64;
      Check(Abs(LF64 - 3.14) < 0.001, 'test_getmem_f64 = %.4f (expected 3.14, opt %d)', [LF64, LOptLevel]);

      LI32 := gny_invoke(LEngine, PAnsiChar(UTF8Encode('test_resizemem')), GNY_VT_INT32).AsInt32;
      Check(LI32 = 99, 'test_resizemem = %d (expected 99, opt %d)', [LI32, LOptLevel]);

      LU8 := gny_invoke(LEngine, PAnsiChar(UTF8Encode('test_getmem_u8')), GNY_VT_UINT8).AsUInt8;
      Check(LU8 = 255, 'test_getmem_u8 = %d (expected 255, opt %d)', [LU8, LOptLevel]);

    finally
      gny_destroy(LEngine);
    end;
  end;

  gny_unload();
end;

end.