{===============================================================================
  Ganymede™ - Embeddable Native Scripting Engine

  Copyright © 2026-present tinyBigGAMES™ LLC
  All Rights Reserved.

  See LICENSE for license information
===============================================================================}

unit UTest.Records;

{$I Ganymede.Defines.inc}

interface

uses
  Ganymede.TestCase;

type
  TScriptRecordsTest = class(TGnyTestCase)
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
{ TScriptRecordsTest }

constructor TScriptRecordsTest.Create();
begin
  inherited;
  Title := 'GanymedeScript — Record Types';
  Pause := True;
end;

procedure TScriptRecordsTest.Run();
var
  LEngine: TGnyEngine;
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
  LOptLevel: Integer;
  LFile: string;
begin
  if not gny_load(PAnsiChar(UTF8Encode(CDllPath))) then
  begin
    Check(False, 'Failed to load Ganymede DLL');
    Exit;
  end;

  LFile := TPath.Combine(CTestDir, 'test_mem_records.gny');
  for LOptLevel := GNY_OPT_NONE to GNY_OPT_FULL do
  begin
    Section('Record Types — opt level %d', [LOptLevel]);
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

      // --- int32 fields, int32 return ---
      LI32 := gny_invoke(LEngine, PAnsiChar(UTF8Encode('pointsum')), GNY_VT_INT32).AsInt32;
      Check(LI32 = 30, 'pointsum():int32 = %d (expected 30, opt %d)', [LI32, LOptLevel]);

      LI32 := gny_invoke(LEngine, PAnsiChar(UTF8Encode('pointlit')), GNY_VT_INT32).AsInt32;
      Check(LI32 = 300, 'pointlit():int32 = %d (expected 300, opt %d)', [LI32, LOptLevel]);

      // --- int8 fields, int8 return ---
      LI8 := gny_invoke(LEngine, PAnsiChar(UTF8Encode('byterec')), GNY_VT_INT8).AsInt8;
      Check(LI8 = 60, 'byterec():int8 = %d (expected 60, opt %d)', [LI8, LOptLevel]);

      // --- int16 fields, int16 return ---
      LI16 := gny_invoke(LEngine, PAnsiChar(UTF8Encode('shortrec')), GNY_VT_INT16).AsInt16;
      Check(LI16 = 3000, 'shortrec():int16 = %d (expected 3000, opt %d)', [LI16, LOptLevel]);
      // --- int64 fields, int64 return ---
      LI64 := gny_invoke(LEngine, PAnsiChar(UTF8Encode('bigrec')), GNY_VT_INT64).AsInt64;
      Check(LI64 = 3000000000, 'bigrec():int64 = %d (expected 3000000000, opt %d)', [LI64, LOptLevel]);

      // --- uint8/uint16/uint32 ---
      LU8 := gny_invoke(LEngine, PAnsiChar(UTF8Encode('u8rec')), GNY_VT_UINT8).AsUInt8;
      Check(LU8 = 250, 'u8rec():uint8 = %d (expected 250, opt %d)', [LU8, LOptLevel]);

      LU16 := gny_invoke(LEngine, PAnsiChar(UTF8Encode('u16rec')), GNY_VT_UINT16).AsUInt16;
      Check(LU16 = 50000, 'u16rec():uint16 = %d (expected 50000, opt %d)', [LU16, LOptLevel]);

      LU32 := gny_invoke(LEngine, PAnsiChar(UTF8Encode('u32rec')), GNY_VT_UINT32).AsUInt32;
      Check(LU32 = 300000, 'u32rec():uint32 = %d (expected 300000, opt %d)', [LU32, LOptLevel]);

      // --- float32/float64 ---
      LF32 := gny_invoke(LEngine, PAnsiChar(UTF8Encode('colorsum')), GNY_VT_FLOAT32).AsFloat32;
      Check(Abs(LF32 - 2.5) < 0.01, 'colorsum():float32 = %.4f (expected 2.5, opt %d)', [LF32, LOptLevel]);

      LF64 := gny_invoke(LEngine, PAnsiChar(UTF8Encode('vec2dot')), GNY_VT_FLOAT64).AsFloat64;
      Check(Abs(LF64 - 25.0) < 0.001, 'vec2dot():float64 = %.4f (expected 25.0, opt %d)', [LF64, LOptLevel]);

      // --- boolean fields ---
      LBool := gny_invoke(LEngine, PAnsiChar(UTF8Encode('flagand')), GNY_VT_INT8).AsInt8;
      Check(LBool = 1, 'flagand():bool = %d (expected 1/true, opt %d)', [LBool, LOptLevel]);

      LBool := gny_invoke(LEngine, PAnsiChar(UTF8Encode('flagor')), GNY_VT_INT8).AsInt8;
      Check(LBool = 1, 'flagor():bool = %d (expected 1/true, opt %d)', [LBool, LOptLevel]);

      LBool := gny_invoke(LEngine, PAnsiChar(UTF8Encode('flagfalse')), GNY_VT_INT8).AsInt8;
      Check(LBool = 0, 'flagfalse():bool = %d (expected 0/false, opt %d)', [LBool, LOptLevel]);
      // --- char/wchar fields ---
      LI8 := gny_invoke(LEngine, PAnsiChar(UTF8Encode('charfield')), GNY_VT_INT8).AsInt8;
      Check(LI8 = 65, 'charfield():char = %d (expected 65/A, opt %d)', [LI8, LOptLevel]);

      LI16 := gny_invoke(LEngine, PAnsiChar(UTF8Encode('wcharfield')), GNY_VT_INT16).AsInt16;
      Check(LI16 = 89, 'wcharfield():wchar = %d (expected 89/Y, opt %d)', [LI16, LOptLevel]);

      // --- packed/aligned records ---
      LI32 := gny_invoke(LEngine, PAnsiChar(UTF8Encode('packedrec')), GNY_VT_INT32).AsInt32;
      Check(LI32 = 1003, 'packedrec():int32 = %d (expected 1003, opt %d)', [LI32, LOptLevel]);

      LU32 := gny_invoke(LEngine, PAnsiChar(UTF8Encode('packedunsigned')), GNY_VT_UINT32).AsUInt32;
      Check(LU32 = 120200, 'packedunsigned():uint32 = %d (expected 120200, opt %d)', [LU32, LOptLevel]);

      LF64 := gny_invoke(LEngine, PAnsiChar(UTF8Encode('alignedrec')), GNY_VT_FLOAT64).AsFloat64;
      Check(Abs(LF64 - 111.0) < 0.001, 'alignedrec():float64 = %.4f (expected 111.0, opt %d)', [LF64, LOptLevel]);

      LI16 := gny_invoke(LEngine, PAnsiChar(UTF8Encode('packedaligned')), GNY_VT_INT16).AsInt16;
      Check(LI16 = 3210, 'packedaligned():int16 = %d (expected 3210, opt %d)', [LI16, LOptLevel]);

      // --- nested records ---
      LI32 := gny_invoke(LEngine, PAnsiChar(UTF8Encode('nestedrec')), GNY_VT_INT32).AsInt32;
      Check(LI32 = 33, 'nestedrec():int32 = %d (expected 33, opt %d)', [LI32, LOptLevel]);

      LI32 := gny_invoke(LEngine, PAnsiChar(UTF8Encode('nestedlit')), GNY_VT_INT32).AsInt32;
      Check(LI32 = 65, 'nestedlit():int32 = %d (expected 65, opt %d)', [LI32, LOptLevel]);

      // --- inheritance ---
      LI64 := gny_invoke(LEngine, PAnsiChar(UTF8Encode('inheritance')), GNY_VT_INT64).AsInt64;
      Check(LI64 = 300, 'inheritance():int64 = %d (expected 300, opt %d)', [LI64, LOptLevel]);
      // --- string fields ---
      LBool := gny_invoke(LEngine, PAnsiChar(UTF8Encode('stringfieldcmp')), GNY_VT_INT8).AsInt8;
      Check(LBool = 1, 'stringfieldcmp():bool = %d (expected 1/true, opt %d)', [LBool, LOptLevel]);

      LI32 := gny_invoke(LEngine, PAnsiChar(UTF8Encode('stringfieldint')), GNY_VT_INT32).AsInt32;
      Check(LI32 = 77, 'stringfieldint():int32 = %d (expected 77, opt %d)', [LI32, LOptLevel]);

      LBool := gny_invoke(LEngine, PAnsiChar(UTF8Encode('twostringfields')), GNY_VT_INT8).AsInt8;
      Check(LBool = 1, 'twostringfields():bool = %d (expected 1/true, opt %d)', [LBool, LOptLevel]);

      LBool := gny_invoke(LEngine, PAnsiChar(UTF8Encode('stringfieldconcat')), GNY_VT_INT8).AsInt8;
      Check(LBool = 1, 'stringfieldconcat():bool = %d (expected 1/true, opt %d)', [LBool, LOptLevel]);

      LI32 := gny_invoke(LEngine, PAnsiChar(UTF8Encode('wstringfield')), GNY_VT_INT32).AsInt32;
      Check(LI32 = 99, 'wstringfield():int32 = %d (expected 99, opt %d)', [LI32, LOptLevel]);

      // --- field passing ---
      LI32 := gny_invoke(LEngine, PAnsiChar(UTF8Encode('fieldpassint')), GNY_VT_INT32).AsInt32;
      Check(LI32 = 100, 'fieldpassint():int32 = %d (expected 100, opt %d)', [LI32, LOptLevel]);

      LF64 := gny_invoke(LEngine, PAnsiChar(UTF8Encode('fieldpassfloat')), GNY_VT_FLOAT64).AsFloat64;
      Check(Abs(LF64 - 4.0) < 0.001, 'fieldpassfloat():float64 = %.4f (expected 4.0, opt %d)', [LF64, LOptLevel]);

      LI64 := gny_invoke(LEngine, PAnsiChar(UTF8Encode('fieldpassi64')), GNY_VT_INT64).AsInt64;
      Check(LI64 = 333333333, 'fieldpassi64():int64 = %d (expected 333333333, opt %d)', [LI64, LOptLevel]);
      // --- record literals ---
      LF64 := gny_invoke(LEngine, PAnsiChar(UTF8Encode('veclit')), GNY_VT_FLOAT64).AsFloat64;
      Check(Abs(LF64 - 15.0) < 0.001, 'veclit():float64 = %.4f (expected 15.0, opt %d)', [LF64, LOptLevel]);

      LI8 := gny_invoke(LEngine, PAnsiChar(UTF8Encode('bytelit')), GNY_VT_INT8).AsInt8;
      Check(LI8 = 30, 'bytelit():int8 = %d (expected 30, opt %d)', [LI8, LOptLevel]);

      LI64 := gny_invoke(LEngine, PAnsiChar(UTF8Encode('biglit')), GNY_VT_INT64).AsInt64;
      Check(LI64 = 1000000000, 'biglit():int64 = %d (expected 1000000000, opt %d)', [LI64, LOptLevel]);

      // --- field overwrite ---
      LF64 := gny_invoke(LEngine, PAnsiChar(UTF8Encode('floatoverwrite')), GNY_VT_FLOAT64).AsFloat64;
      Check(Abs(LF64 - 99.5) < 0.001, 'floatoverwrite():float64 = %.4f (expected 99.5, opt %d)', [LF64, LOptLevel]);

      LI32 := gny_invoke(LEngine, PAnsiChar(UTF8Encode('litoverwrite')), GNY_VT_INT32).AsInt32;
      Check(LI32 = 75, 'litoverwrite():int32 = %d (expected 75, opt %d)', [LI32, LOptLevel]);

      // --- multiple record vars ---
      LI64 := gny_invoke(LEngine, PAnsiChar(UTF8Encode('multivar')), GNY_VT_INT64).AsInt64;
      Check(LI64 = 3103, 'multivar():int64 = %d (expected 3103, opt %d)', [LI64, LOptLevel]);

      // --- kitchen sink ---
      LI64 := gny_invoke(LEngine, PAnsiChar(UTF8Encode('kitchensink')), GNY_VT_INT64).AsInt64;
      Check(LI64 = 62, 'kitchensink():int64 = %d (expected 62, opt %d)', [LI64, LOptLevel]);

    finally
      gny_destroy(LEngine);
    end;
  end;

  gny_unload();
end;

end.