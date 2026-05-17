{===============================================================================
  Ganymede™ - Embeddable Native Scripting Engine

  Copyright © 2026-present tinyBigGAMES™ LLC
  All Rights Reserved.

  See LICENSE for license information
===============================================================================}

unit UTest.Arrays;

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
  TArraysTest = class(TGnyTestCase)
  public
    constructor Create(); override;
  protected
    procedure Run(); override;
  end;

implementation

{ TArraysTest }

constructor TArraysTest.Create();
begin
  inherited;
  Title := 'GanymedeScript — Array Types';
  Pause := True;
end;

procedure TArraysTest.Run();
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
  LFile := TPath.Combine(CTestDir, 'test_mem_arrays.gny');

  for LOptLevel := Low(TGnyOptLevel) to High(TGnyOptLevel) do
  begin
    LOrd := Ord(LOptLevel);
    Section('Array Types — opt level %d', [LOrd]);
    LScript := TGanymede.Create();
    try
      LScript.SetOptimizationLevel(LOptLevel);
      LScript.LoadFromFile(LFile);

      if not LScript.Compile() then
      begin
        FlushErrors(LScript.GetErrors());
        //WriteLn(LScript.GetSSADump());
        Check(False, 'Compile failed (opt %d)', [LOrd]);
        Continue;
      end;

      Check(True, 'Compiled successfully (opt %d)', [LOrd]);

      // --- int32 array, basic read/write ---
      LI32 := LScript.Invoke('intarr', [], gvtInt32).AsInt32;
      Check(LI32 = 60,
        'intarr():int32 = %d (expected 60, opt %d)', [LI32, LOrd]);

      // --- inline array type ---
      LI32 := LScript.Invoke('inlinearr', [], gvtInt32).AsInt32;
      Check(LI32 = 600,
        'inlinearr():int32 = %d (expected 600, opt %d)', [LI32, LOrd]);

      // --- int8 array ---
      LI8 := LScript.Invoke('i8arr', [], gvtInt8).AsInt8;
      Check(LI8 = 50,
        'i8arr():int8 = %d (expected 50, opt %d)', [LI8, LOrd]);

      // --- int16 array ---
      LI16 := LScript.Invoke('i16arr', [], gvtInt16).AsInt16;
      Check(LI16 = 5000,
        'i16arr():int16 = %d (expected 5000, opt %d)', [LI16, LOrd]);

      // --- int64 array ---
      LI64 := LScript.Invoke('i64arr', [], gvtInt64).AsInt64;
      Check(LI64 = 4000000000,
        'i64arr():int64 = %d (expected 4000000000, opt %d)', [LI64, LOrd]);

      // --- uint8 array ---
      LU8 := LScript.Invoke('u8arr', [], gvtUInt8).AsUInt8;
      Check(LU8 = 250,
        'u8arr():uint8 = %d (expected 250, opt %d)', [LU8, LOrd]);

      // --- uint16 array ---
      LU16 := LScript.Invoke('u16arr', [], gvtUInt16).AsUInt16;
      Check(LU16 = 50000,
        'u16arr():uint16 = %d (expected 50000, opt %d)', [LU16, LOrd]);

      // --- uint32 array ---
      LU32 := LScript.Invoke('u32arr', [], gvtUInt32).AsUInt32;
      Check(LU32 = 400000,
        'u32arr():uint32 = %d (expected 400000, opt %d)', [LU32, LOrd]);

      // --- float32 array ---
      LF32 := LScript.Invoke('f32arr', [], gvtFloat32).AsFloat32;
      Check(Abs(LF32 - 5.0) < 0.01,
        'f32arr():float32 = %.4f (expected 5.0, opt %d)', [LF32, LOrd]);

      // --- float64 array ---
      LF64 := LScript.Invoke('f64arr', [], gvtFloat64).AsFloat64;
      Check(Abs(LF64 - 30.75) < 0.001,
        'f64arr():float64 = %.4f (expected 30.75, opt %d)', [LF64, LOrd]);

      // --- boolean array ---
      LBool := LScript.Invoke('boolarr', [], gvtInt8).AsInt8;
      Check(LBool = 1,
        'boolarr():bool = %d (expected 1/true, opt %d)', [LBool, LOrd]);

      LBool := LScript.Invoke('boolarrfalse', [], gvtInt8).AsInt8;
      Check(LBool = 0,
        'boolarrfalse():bool = %d (expected 0/false, opt %d)', [LBool, LOrd]);

      // --- element arithmetic ---
      LI32 := LScript.Invoke('elemmath', [], gvtInt32).AsInt32;
      Check(LI32 = 590,
        'elemmath():int32 = %d (expected 590, opt %d)', [LI32, LOrd]);

      // --- loop fill + sum ---
      LI32 := LScript.Invoke('loopsum', [], gvtInt32).AsInt32;
      Check(LI32 = 550,
        'loopsum():int32 = %d (expected 550, opt %d)', [LI32, LOrd]);

      // --- element overwrite ---
      LI32 := LScript.Invoke('overwrite', [], gvtInt32).AsInt32;
      Check(LI32 = 1999,
        'overwrite():int32 = %d (expected 1999, opt %d)', [LI32, LOrd]);

      // --- boundary access ---
      LI32 := LScript.Invoke('boundary', [], gvtInt32).AsInt32;
      Check(LI32 = 100,
        'boundary():int32 = %d (expected 100, opt %d)', [LI32, LOrd]);

      // --- multiple array vars ---
      LI64 := LScript.Invoke('multiarray', [], gvtInt64).AsInt64;
      Check(LI64 = 300,
        'multiarray():int64 = %d (expected 300, opt %d)', [LI64, LOrd]);

      // --- element as function arg ---
      LI32 := LScript.Invoke('elemarg', [], gvtInt32).AsInt32;
      Check(LI32 = 100,
        'elemarg():int32 = %d (expected 100, opt %d)', [LI32, LOrd]);

      // --- array of records ---
      LI32 := LScript.Invoke('recarr', [], gvtInt32).AsInt32;
      Check(LI32 = 121,
        'recarr():int32 = %d (expected 121, opt %d)', [LI32, LOrd]);

      // --- conditional on array element ---
      LI32 := LScript.Invoke('condelem', [], gvtInt32).AsInt32;
      Check(LI32 = 10,
        'condelem():int32 = %d (expected 10, opt %d)', [LI32, LOrd]);

      // --- array copy via loop ---
      LI32 := LScript.Invoke('arrcopy', [], gvtInt32).AsInt32;
      Check(LI32 = 99,
        'arrcopy():int32 = %d (expected 99, opt %d)', [LI32, LOrd]);

      // --- kitchen sink: all integer types ---
      LI64 := LScript.Invoke('kitchensink', [], gvtInt64).AsInt64;
      Check(LI64 = 28,
        'kitchensink():int64 = %d (expected 28, opt %d)', [LI64, LOrd]);

      // --- dynamic array: basic setlength + read/write ---
      LI32 := LScript.Invoke('dynarr_basic', [], gvtInt32).AsInt32;
      Check(LI32 = 150,
        'dynarr_basic():int32 = %d (expected 150, opt %d)', [LI32, LOrd]);

      // --- dynamic array: len() intrinsic ---
      LI64 := LScript.Invoke('dynarr_len', [], gvtInt64).AsInt64;
      Check(LI64 = 10,
        'dynarr_len():int64 = %d (expected 10, opt %d)', [LI64, LOrd]);

      // --- dynamic array: len() on nil (before setlength) ---
      LI64 := LScript.Invoke('dynarr_len_nil', [], gvtInt64).AsInt64;
      Check(LI64 = 0,
        'dynarr_len_nil():int64 = %d (expected 0, opt %d)', [LI64, LOrd]);

      // --- dynamic array: loop fill + sum ---
      LI32 := LScript.Invoke('dynarr_loopsum', [], gvtInt32).AsInt32;
      Check(LI32 = 550,
        'dynarr_loopsum():int32 = %d (expected 550, opt %d)', [LI32, LOrd]);

      // --- dynamic array: int64 elements ---
      LI64 := LScript.Invoke('dynarr_i64', [], gvtInt64).AsInt64;
      Check(LI64 = 4000000000,
        'dynarr_i64():int64 = %d (expected 4000000000, opt %d)', [LI64, LOrd]);

      // --- dynamic array: element overwrite ---
      LI32 := LScript.Invoke('dynarr_overwrite', [], gvtInt32).AsInt32;
      Check(LI32 = 1999,
        'dynarr_overwrite():int32 = %d (expected 1999, opt %d)', [LI32, LOrd]);

      // --- dynamic array: setlength with expression ---
      LI64 := LScript.Invoke('dynarr_expr_len', [], gvtInt64).AsInt64;
      Check(LI64 = 5,
        'dynarr_expr_len():int64 = %d (expected 5, opt %d)', [LI64, LOrd]);

      // --- dynamic array: int8 elements ---
      LI32 := LScript.Invoke('dynarr_i8', [], gvtInt32).AsInt32;
      Check(LI32 = 40,
        'dynarr_i8():int32 = %d (expected 40, opt %d)', [LI32, LOrd]);

      // --- dynamic array: float64 elements ---
      LF64 := LScript.Invoke('dynarr_f64', [], gvtFloat64).AsFloat64;
      Check(Abs(LF64 - 41.0) < 0.001,
        'dynarr_f64():float64 = %.4f (expected 41.0, opt %d)', [LF64, LOrd]);

      // --- dynamic array: multiple arrays ---
      LI64 := LScript.Invoke('dynarr_multi', [], gvtInt64).AsInt64;
      Check(LI64 = 3300,
        'dynarr_multi():int64 = %d (expected 3300, opt %d)', [LI64, LOrd]);

      // --- dynamic array: element arithmetic ---
      LI32 := LScript.Invoke('dynarr_elemmath', [], gvtInt32).AsInt32;
      Check(LI32 = 590,
        'dynarr_elemmath():int32 = %d (expected 590, opt %d)', [LI32, LOrd]);

      // --- dynamic array: element as function arg ---
      LI32 := LScript.Invoke('dynarr_elemarg', [], gvtInt32).AsInt32;
      Check(LI32 = 100,
        'dynarr_elemarg():int32 = %d (expected 100, opt %d)', [LI32, LOrd]);

      // --- dynamic array: conditional on element ---
      LI32 := LScript.Invoke('dynarr_condelem', [], gvtInt32).AsInt32;
      Check(LI32 = 10,
        'dynarr_condelem():int32 = %d (expected 10, opt %d)', [LI32, LOrd]);

      // --- len() on managed string ---
      LI64 := LScript.Invoke('len_string', [], gvtInt64).AsInt64;
      Check(LI64 = 5,
        'len_string():int64 = %d (expected 5, opt %d)', [LI64, LOrd]);

    finally
      LScript.Free();
    end;
  end;
end;

end.
