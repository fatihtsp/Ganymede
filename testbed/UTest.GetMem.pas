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
  System.SysUtils,
  System.IOUtils,
  Ganymede.Utils,
  Ganymede.TestCase,
  Ganymede.Core,
  Ganymede.Native,
  UCommon;

type
  TScriptGetMemTest = class(TGnyTestCase)
  public
    constructor Create(); override;
  protected
    procedure Run(); override;
  end;

implementation


{ TScriptGetMemTest }

constructor TScriptGetMemTest.Create();
begin
  inherited;
  Title := 'GanymedeScript — GetMem/FreeMem/ResizeMem';
  Pause := True;
end;

procedure TScriptGetMemTest.Run();
var
  LScript: TGanymede;
  LI32: Int32;
  LI64: Int64;
  LF64: Double;
  LU8: UInt8;
  LOptLevel: TGnyOptLevel;
  LOrd: Integer;
  LFile: string;
begin
  LFile := TPath.Combine(CTestDir, 'test_mem_getmem.gny');

  for LOptLevel := Low(TGnyOptLevel) to High(TGnyOptLevel) do
  begin
    LOrd := Ord(LOptLevel);
    Section('GetMem/FreeMem/ResizeMem — opt level %d', [LOrd]);
    LScript := TGanymede.Create();
    try
      LScript.SetOptimizationLevel(LOptLevel);
      LScript.LoadFromFile(LFile);

      if not LScript.Compile() then
      begin
        FlushErrors(LScript.GetErrors());
        Check(False, 'Compile failed (opt %d)', [LOrd]);
        Continue;
      end;

      Check(True, 'Compiled successfully (opt %d)', [LOrd]);

      // --- getmem int32 ---
      LI32 := LScript.Invoke('test_getmem_i32', [], gvtInt32).AsInt32;
      Check(LI32 = 42,
        'test_getmem_i32 = %d (expected 42, opt %d)', [LI32, LOrd]);

      // --- getmem int64 ---
      LI64 := LScript.Invoke('test_getmem_i64', [], gvtInt64).AsInt64;
      Check(LI64 = 1000000000,
        'test_getmem_i64 = %d (expected 1000000000, opt %d)', [LI64, LOrd]);

      // --- getmem float64 ---
      LF64 := LScript.Invoke('test_getmem_f64', [], gvtFloat64).AsFloat64;
      Check(Abs(LF64 - 3.14) < 0.001,
        'test_getmem_f64 = %.4f (expected 3.14, opt %d)', [LF64, LOrd]);

      // --- resizemem ---
      LI32 := LScript.Invoke('test_resizemem', [], gvtInt32).AsInt32;
      Check(LI32 = 99,
        'test_resizemem = %d (expected 99, opt %d)', [LI32, LOrd]);

      // --- getmem uint8 ---
      LU8 := LScript.Invoke('test_getmem_u8', [], gvtUInt8).AsUInt8;
      Check(LU8 = 255,
        'test_getmem_u8 = %d (expected 255, opt %d)', [LU8, LOrd]);

    finally
      LScript.Free();
    end;
  end;
end;

end.
