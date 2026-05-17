{===============================================================================
  Ganymede™ - Embeddable Native Scripting Engine

  Copyright © 2026-present tinyBigGAMES™ LLC
  All Rights Reserved.

  See LICENSE for license information
===============================================================================}

unit UTest.Intrinsics;

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
  TScriptIntrinsicsTest = class(TGnyTestCase)
  public
    constructor Create(); override;
  protected
    procedure Run(); override;
  end;

implementation


{ TScriptIntrinsicsTest }

constructor TScriptIntrinsicsTest.Create();
begin
  inherited;
  Title := 'GanymedeScript — Built-in Intrinsics (size, utf8)';
  Pause := True;
end;

procedure TScriptIntrinsicsTest.Run();
var
  LScript: TGanymede;
  LI64: Int64;
  LI32: Int32;
  LOptLevel: TGnyOptLevel;
  LOrd: Integer;
  LFile: string;
begin
  LFile := TPath.Combine(CTestDir, 'test_mem_intrinsics.gny');

  for LOptLevel := Low(TGnyOptLevel) to High(TGnyOptLevel) do
  begin
    LOrd := Ord(LOptLevel);
    Section('Intrinsics (size, utf8) — opt level %d', [LOrd]);
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

      // --- size() primitives ---
      LI64 := LScript.Invoke('test_size_i8', [], gvtInt64).AsInt64;
      Check(LI64 = 1, 'size(int8) = %d (expected 1, opt %d)', [LI64, LOrd]);

      LI64 := LScript.Invoke('test_size_i16', [], gvtInt64).AsInt64;
      Check(LI64 = 2, 'size(int16) = %d (expected 2, opt %d)', [LI64, LOrd]);

      LI64 := LScript.Invoke('test_size_i32', [], gvtInt64).AsInt64;
      Check(LI64 = 4, 'size(int32) = %d (expected 4, opt %d)', [LI64, LOrd]);

      LI64 := LScript.Invoke('test_size_i64', [], gvtInt64).AsInt64;
      Check(LI64 = 8, 'size(int64) = %d (expected 8, opt %d)', [LI64, LOrd]);

      LI64 := LScript.Invoke('test_size_f32', [], gvtInt64).AsInt64;
      Check(LI64 = 4, 'size(float32) = %d (expected 4, opt %d)', [LI64, LOrd]);

      LI64 := LScript.Invoke('test_size_f64', [], gvtInt64).AsInt64;
      Check(LI64 = 8, 'size(float64) = %d (expected 8, opt %d)', [LI64, LOrd]);

      LI64 := LScript.Invoke('test_size_ptr', [], gvtInt64).AsInt64;
      Check(LI64 = 8, 'size(pointer) = %d (expected 8, opt %d)', [LI64, LOrd]);

      LI64 := LScript.Invoke('test_size_bool', [], gvtInt64).AsInt64;
      Check(LI64 = 1, 'size(boolean) = %d (expected 1, opt %d)', [LI64, LOrd]);

      // --- size() record ---
      LI64 := LScript.Invoke('test_size_record', [], gvtInt64).AsInt64;
      Check(LI64 = 8, 'size(TPoint) = %d (expected 8, opt %d)', [LI64, LOrd]);

      // --- size() in expression ---
      LI32 := LScript.Invoke('test_size_in_expr', [], gvtInt32).AsInt32;
      Check(LI32 = 12, 'size(int32)+size(int64) = %d (expected 12, opt %d)', [LI32, LOrd]);

      // --- utf8() non-null ---
      LI32 := LScript.Invoke('test_utf8_nonnull', [], gvtInt32).AsInt32;
      Check(LI32 = 1, 'utf8() returns non-nil = %d (expected 1, opt %d)', [LI32, LOrd]);

    finally
      LScript.Free();
    end;
  end;
end;

end.
