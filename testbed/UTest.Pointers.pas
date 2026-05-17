{===============================================================================
  Ganymede™ - Embeddable Native Scripting Engine

  Copyright © 2026-present tinyBigGAMES™ LLC
  All Rights Reserved.

  See LICENSE for license information
===============================================================================}

unit UTest.Pointers;

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
  TScriptPointersTest = class(TGnyTestCase)
  public
    constructor Create(); override;
  protected
    procedure Run(); override;
  end;

implementation

const
  CTestDir = 'C:\Dev\Delphi\Projects\Ganymede\repo\bin\tests';

{ TScriptPointersTest }

constructor TScriptPointersTest.Create();
begin
  inherited;
  Title := 'GanymedeScript — Pointer Types';
  Pause := True;
end;

procedure TScriptPointersTest.Run();
var
  LScript: TGanymede;
  LI8: Int8;
  LI16: Int16;
  LI32: Int32;
  LI64: Int64;
  LU8: UInt8;
  LU16: UInt16;
  LU32: UInt32;
  LF32: Single;
  LF64: Double;
  LBool: Int8;
  LOptLevel: TGnyOptLevel;
  LOrd: Integer;
  LFile: string;
begin
  LFile := TPath.Combine(CTestDir, 'test_mem_pointers.gny');

  for LOptLevel := Low(TGnyOptLevel) to High(TGnyOptLevel) do
  begin
    LOrd := Ord(LOptLevel);
    Section('Pointer Types — opt level %d', [LOrd]);
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

      // --- int8 pointer ---
      LI8 := LScript.Invoke('ptr_i8', [], gvtInt8).AsInt8;
      Check(LI8 = 127,
        'ptr_i8():int8 = %d (expected 127, opt %d)', [LI8, LOrd]);

      // --- int16 pointer ---
      LI16 := LScript.Invoke('ptr_i16', [], gvtInt16).AsInt16;
      Check(LI16 = 30000,
        'ptr_i16():int16 = %d (expected 30000, opt %d)', [LI16, LOrd]);

      // --- int32 pointer ---
      LI32 := LScript.Invoke('ptr_i32', [], gvtInt32).AsInt32;
      Check(LI32 = 42,
        'ptr_i32():int32 = %d (expected 42, opt %d)', [LI32, LOrd]);

      // --- int64 pointer ---
      LI64 := LScript.Invoke('ptr_i64', [], gvtInt64).AsInt64;
      Check(LI64 = 4000000000,
        'ptr_i64():int64 = %d (expected 4000000000, opt %d)', [LI64, LOrd]);

      // --- uint8 pointer ---
      LU8 := LScript.Invoke('ptr_u8', [], gvtUInt8).AsUInt8;
      Check(LU8 = 250,
        'ptr_u8():uint8 = %d (expected 250, opt %d)', [LU8, LOrd]);

      // --- uint16 pointer ---
      LU16 := LScript.Invoke('ptr_u16', [], gvtUInt16).AsUInt16;
      Check(LU16 = 50000,
        'ptr_u16():uint16 = %d (expected 50000, opt %d)', [LU16, LOrd]);

      // --- uint32 pointer ---
      LU32 := LScript.Invoke('ptr_u32', [], gvtUInt32).AsUInt32;
      Check(LU32 = 300000,
        'ptr_u32():uint32 = %d (expected 300000, opt %d)', [LU32, LOrd]);

      // --- float32 pointer ---
      LF32 := LScript.Invoke('ptr_f32', [], gvtFloat32).AsFloat32;
      Check(Abs(LF32 - 2.5) < 0.01,
        'ptr_f32():float32 = %.4f (expected 2.5, opt %d)', [LF32, LOrd]);

      // --- float64 pointer ---
      LF64 := LScript.Invoke('ptr_f64', [], gvtFloat64).AsFloat64;
      Check(Abs(LF64 - 3.14159) < 0.0001,
        'ptr_f64():float64 = %.5f (expected 3.14159, opt %d)', [LF64, LOrd]);

      // --- boolean pointer true ---
      LBool := LScript.Invoke('ptr_bool_true', [], gvtInt8).AsInt8;
      Check(LBool = 1,
        'ptr_bool_true():bool = %d (expected 1, opt %d)', [LBool, LOrd]);

      // --- boolean pointer false ---
      LBool := LScript.Invoke('ptr_bool_false', [], gvtInt8).AsInt8;
      Check(LBool = 0,
        'ptr_bool_false():bool = %d (expected 0, opt %d)', [LBool, LOrd]);

      // --- write through int32 ---
      LI32 := LScript.Invoke('ptr_write_i32', [], gvtInt32).AsInt32;
      Check(LI32 = 99,
        'ptr_write_i32():int32 = %d (expected 99, opt %d)', [LI32, LOrd]);

      // --- write through int64 ---
      LI64 := LScript.Invoke('ptr_write_i64', [], gvtInt64).AsInt64;
      Check(LI64 = 9999999999,
        'ptr_write_i64():int64 = %d (expected 9999999999, opt %d)', [LI64, LOrd]);

      // --- write through float64 ---
      LF64 := LScript.Invoke('ptr_write_f64', [], gvtFloat64).AsFloat64;
      Check(Abs(LF64 - 77.25) < 0.001,
        'ptr_write_f64():float64 = %.4f (expected 77.25, opt %d)', [LF64, LOrd]);

      // --- nil pointer ---
      LI32 := LScript.Invoke('ptr_nil', [], gvtInt32).AsInt32;
      Check(LI32 = 1,
        'ptr_nil():int32 = %d (expected 1, opt %d)', [LI32, LOrd]);

      // --- not-nil comparison ---
      LI32 := LScript.Invoke('ptr_not_nil', [], gvtInt32).AsInt32;
      Check(LI32 = 1,
        'ptr_not_nil():int32 = %d (expected 1, opt %d)', [LI32, LOrd]);

      // --- untyped pointer ---
      LI32 := LScript.Invoke('ptr_untyped', [], gvtInt32).AsInt32;
      Check(LI32 = 1,
        'ptr_untyped():int32 = %d (expected 1, opt %d)', [LI32, LOrd]);

      // --- ampersand syntax ---
      LI32 := LScript.Invoke('ptr_ampersand', [], gvtInt32).AsInt32;
      Check(LI32 = 77,
        'ptr_ampersand():int32 = %d (expected 77, opt %d)', [LI32, LOrd]);

      // --- named pointer type int32 ---
      LI32 := LScript.Invoke('ptr_named_type', [], gvtInt32).AsInt32;
      Check(LI32 = 55,
        'ptr_named_type():int32 = %d (expected 55, opt %d)', [LI32, LOrd]);

      // --- named pointer type float64 ---
      LF64 := LScript.Invoke('ptr_named_f64', [], gvtFloat64).AsFloat64;
      Check(Abs(LF64 - 12.75) < 0.001,
        'ptr_named_f64():float64 = %.4f (expected 12.75, opt %d)', [LF64, LOrd]);

      // --- pass-by-ref int32 ---
      LI32 := LScript.Invoke('ptr_passref_i32', [], gvtInt32).AsInt32;
      Check(LI32 = 123,
        'ptr_passref_i32():int32 = %d (expected 123, opt %d)', [LI32, LOrd]);

      // --- pass-by-ref int64 ---
      LI64 := LScript.Invoke('ptr_passref_i64', [], gvtInt64).AsInt64;
      Check(LI64 = 5000000000,
        'ptr_passref_i64():int64 = %d (expected 5000000000, opt %d)', [LI64, LOrd]);

      // --- pass-by-ref float64 ---
      LF64 := LScript.Invoke('ptr_passref_f64', [], gvtFloat64).AsFloat64;
      Check(Abs(LF64 - 99.5) < 0.001,
        'ptr_passref_f64():float64 = %.4f (expected 99.5, opt %d)', [LF64, LOrd]);

      // --- swap via pointers ---
      LI32 := LScript.Invoke('ptr_swap', [], gvtInt32).AsInt32;
      Check(LI32 = 2010,
        'ptr_swap():int32 = %d (expected 2010, opt %d)', [LI32, LOrd]);

      // --- pointer to record field read ---
      LI32 := LScript.Invoke('ptr_rec_field', [], gvtInt32).AsInt32;
      Check(LI32 = 300,
        'ptr_rec_field():int32 = %d (expected 300, opt %d)', [LI32, LOrd]);

      // --- pointer to record field write ---
      LI32 := LScript.Invoke('ptr_rec_write', [], gvtInt32).AsInt32;
      Check(LI32 = 127,
        'ptr_rec_write():int32 = %d (expected 127, opt %d)', [LI32, LOrd]);

      // --- pointer reassignment ---
      LI32 := LScript.Invoke('ptr_reassign', [], gvtInt32).AsInt32;
      Check(LI32 = 20,
        'ptr_reassign():int32 = %d (expected 20, opt %d)', [LI32, LOrd]);

      // --- multiple pointer vars ---
      LI64 := LScript.Invoke('ptr_multi', [], gvtInt64).AsInt64;
      Check(LI64 = 30,
        'ptr_multi():int64 = %d (expected 30, opt %d)', [LI64, LOrd]);

      // --- kitchen sink: all integer types via pointers ---
      LI64 := LScript.Invoke('ptr_kitchensink', [], gvtInt64).AsInt64;
      Check(LI64 = 29,
        'ptr_kitchensink():int64 = %d (expected 29, opt %d)', [LI64, LOrd]);

    finally
      LScript.Free();
    end;
  end;
end;

end.
