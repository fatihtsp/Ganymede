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
  System.SysUtils,
  System.IOUtils,
  Ganymede.Utils,
  Ganymede.TestCase,
  Ganymede.Core,
  Ganymede.Native,
  UCommon;

type
  TScriptRecordsTest = class(TGnyTestCase)
  public
    constructor Create(); override;
  protected
    procedure Run(); override;
  end;

implementation

{ TScriptRecordsTest }

constructor TScriptRecordsTest.Create();
begin
  inherited;
  Title := 'GanymedeScript — Record Types';
  Pause := True;
end;

procedure TScriptRecordsTest.Run();
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
  LFile := TPath.Combine(CTestDir, 'test_mem_records.gny');

  for LOptLevel := Low(TGnyOptLevel) to High(TGnyOptLevel) do
  begin
    LOrd := Ord(LOptLevel);
    Section('Record Types — opt level %d', [LOrd]);
    LScript := TGanymede.Create();
    try
      LScript.SetOptimizationLevel(LOptLevel);
      //LScript.SetDumpIR(True);
      LScript.LoadFromFile(LFile);

      if not LScript.Compile() then
      begin
        FlushErrors(LScript.GetErrors());
        Check(False, 'Compile failed (opt %d)', [LOrd]);
        Continue;
      end;

      //WriteLn(LScript.GetSSADump());

      //WriteLn(LScript.GetSSADump());
      Check(True, 'Compiled successfully (opt %d)', [LOrd]);

      // --- int32 fields, int32 return ---

      LI32 := LScript.Invoke('pointsum', [], gvtInt32).AsInt32;
      Check(LI32 = 30,
        'pointsum():int32 = %d (expected 30, opt %d)', [LI32, LOrd]);

      LI32 := LScript.Invoke('pointlit', [], gvtInt32).AsInt32;
      Check(LI32 = 300,
        'pointlit():int32 = %d (expected 300, opt %d)', [LI32, LOrd]);

      // --- int8 fields, int8 return ---

      LI8 := LScript.Invoke('byterec', [], gvtInt8).AsInt8;
      Check(LI8 = 60,
        'byterec():int8 = %d (expected 60, opt %d)', [LI8, LOrd]);

      // --- int16 fields, int16 return ---

      LI16 := LScript.Invoke('shortrec', [], gvtInt16).AsInt16;
      Check(LI16 = 3000,
        'shortrec():int16 = %d (expected 3000, opt %d)', [LI16, LOrd]);

      // --- int64 fields, int64 return ---

      LI64 := LScript.Invoke('bigrec', [], gvtInt64).AsInt64;
      Check(LI64 = 3000000000,
        'bigrec():int64 = %d (expected 3000000000, opt %d)', [LI64, LOrd]);

      // --- uint8 fields, uint8 return ---

      LU8 := LScript.Invoke('u8rec', [], gvtUInt8).AsUInt8;
      Check(LU8 = 250,
        'u8rec():uint8 = %d (expected 250, opt %d)', [LU8, LOrd]);

      // --- uint16 fields, uint16 return ---

      LU16 := LScript.Invoke('u16rec', [], gvtUInt16).AsUInt16;
      Check(LU16 = 50000,
        'u16rec():uint16 = %d (expected 50000, opt %d)', [LU16, LOrd]);

      // --- uint32 fields, uint32 return ---

      LU32 := LScript.Invoke('u32rec', [], gvtUInt32).AsUInt32;
      Check(LU32 = 300000,
        'u32rec():uint32 = %d (expected 300000, opt %d)', [LU32, LOrd]);

      // --- float32 fields, float32 return ---

      LF32 := LScript.Invoke('colorsum', [], gvtFloat32).AsFloat32;
      Check(Abs(LF32 - 2.5) < 0.01,
        'colorsum():float32 = %.4f (expected 2.5, opt %d)', [LF32, LOrd]);

      // --- float64 fields, float64 return ---

      LF64 := LScript.Invoke('vec2dot', [], gvtFloat64).AsFloat64;
      Check(Abs(LF64 - 25.0) < 0.001,
        'vec2dot():float64 = %.4f (expected 25.0, opt %d)', [LF64, LOrd]);

      // --- boolean fields, boolean return ---

      LBool := LScript.Invoke('flagand', [], gvtInt8).AsInt8;
      Check(LBool = 1,
        'flagand():bool = %d (expected 1/true, opt %d)', [LBool, LOrd]);

      LBool := LScript.Invoke('flagor', [], gvtInt8).AsInt8;
      Check(LBool = 1,
        'flagor():bool = %d (expected 1/true, opt %d)', [LBool, LOrd]);

      LBool := LScript.Invoke('flagfalse', [], gvtInt8).AsInt8;
      Check(LBool = 0,
        'flagfalse():bool = %d (expected 0/false, opt %d)', [LBool, LOrd]);

      // --- char field, char return ---

      LI8 := LScript.Invoke('charfield', [], gvtInt8).AsInt8;
      Check(LI8 = 65,
        'charfield():char = %d (expected 65/A, opt %d)', [LI8, LOrd]);

      // --- wchar field, wchar return ---

      LI16 := LScript.Invoke('wcharfield', [], gvtInt16).AsInt16;
      Check(LI16 = 89,
        'wcharfield():wchar = %d (expected 89/Y, opt %d)', [LI16, LOrd]);

      // --- packed record (int8/int32/int8), int32 return ---

      LI32 := LScript.Invoke('packedrec', [], gvtInt32).AsInt32;
      Check(LI32 = 1003,
        'packedrec():int32 = %d (expected 1003, opt %d)', [LI32, LOrd]);

      // --- packed unsigned, uint32 return ---

      LU32 := LScript.Invoke('packedunsigned', [], gvtUInt32).AsUInt32;
      Check(LU32 = 120200,
        'packedunsigned():uint32 = %d (expected 120200, opt %d)', [LU32, LOrd]);

      // --- aligned record, float64 return ---

      LF64 := LScript.Invoke('alignedrec', [], gvtFloat64).AsFloat64;
      Check(Abs(LF64 - 111.0) < 0.001,
        'alignedrec():float64 = %.4f (expected 111.0, opt %d)', [LF64, LOrd]);

      // --- packed + aligned, int16 return ---

      LI16 := LScript.Invoke('packedaligned', [], gvtInt16).AsInt16;
      Check(LI16 = 3210,
        'packedaligned():int16 = %d (expected 3210, opt %d)', [LI16, LOrd]);

      // --- nested records, int32 return ---

      LI32 := LScript.Invoke('nestedrec', [], gvtInt32).AsInt32;
      Check(LI32 = 33,
        'nestedrec():int32 = %d (expected 33, opt %d)', [LI32, LOrd]);

      LI32 := LScript.Invoke('nestedlit', [], gvtInt32).AsInt32;
      Check(LI32 = 65,
        'nestedlit():int32 = %d (expected 65, opt %d)', [LI32, LOrd]);

      // --- inheritance, int64 return ---

      LI64 := LScript.Invoke('inheritance', [], gvtInt64).AsInt64;
      Check(LI64 = 300,
        'inheritance():int64 = %d (expected 300, opt %d)', [LI64, LOrd]);

      // --- string field compare, boolean return ---

      LBool := LScript.Invoke('stringfieldcmp', [], gvtInt8).AsInt8;
      Check(LBool = 1,
        'stringfieldcmp():bool = %d (expected 1/true, opt %d)', [LBool, LOrd]);

      // --- string field with int32 field, int32 return ---

      LI32 := LScript.Invoke('stringfieldint', [], gvtInt32).AsInt32;
      Check(LI32 = 77,
        'stringfieldint():int32 = %d (expected 77, opt %d)', [LI32, LOrd]);

      // --- two string fields, boolean return ---

      LBool := LScript.Invoke('twostringfields', [], gvtInt8).AsInt8;
      Check(LBool = 1,
        'twostringfields():bool = %d (expected 1/true, opt %d)', [LBool, LOrd]);

      // --- string field concat, boolean return ---

      LBool := LScript.Invoke('stringfieldconcat', [], gvtInt8).AsInt8;
      Check(LBool = 1,
        'stringfieldconcat():bool = %d (expected 1/true, opt %d)', [LBool, LOrd]);

      // --- wstring field, int32 return ---

      LI32 := LScript.Invoke('wstringfield', [], gvtInt32).AsInt32;
      Check(LI32 = 99,
        'wstringfield():int32 = %d (expected 99, opt %d)', [LI32, LOrd]);

      // --- field passing: int32 args, int32 return ---

      LI32 := LScript.Invoke('fieldpassint', [], gvtInt32).AsInt32;
      Check(LI32 = 100,
        'fieldpassint():int32 = %d (expected 100, opt %d)', [LI32, LOrd]);

      // --- field passing: float64 args, float64 return ---

      LF64 := LScript.Invoke('fieldpassfloat', [], gvtFloat64).AsFloat64;
      Check(Abs(LF64 - 4.0) < 0.001,
        'fieldpassfloat():float64 = %.4f (expected 4.0, opt %d)', [LF64, LOrd]);

      // --- field passing: int64 args, int64 return ---

      LI64 := LScript.Invoke('fieldpassi64', [], gvtInt64).AsInt64;
      Check(LI64 = 333333333,
        'fieldpassi64():int64 = %d (expected 333333333, opt %d)', [LI64, LOrd]);

      // --- record literal: float64 fields, float64 return ---

      LF64 := LScript.Invoke('veclit', [], gvtFloat64).AsFloat64;
      Check(Abs(LF64 - 15.0) < 0.001,
        'veclit():float64 = %.4f (expected 15.0, opt %d)', [LF64, LOrd]);

      // --- record literal: int8 fields, int8 return ---

      LI8 := LScript.Invoke('bytelit', [], gvtInt8).AsInt8;
      Check(LI8 = 30,
        'bytelit():int8 = %d (expected 30, opt %d)', [LI8, LOrd]);

      // --- record literal: int64 fields, int64 return ---

      LI64 := LScript.Invoke('biglit', [], gvtInt64).AsInt64;
      Check(LI64 = 1000000000,
        'biglit():int64 = %d (expected 1000000000, opt %d)', [LI64, LOrd]);

      // --- field overwrite: float64 return ---

      LF64 := LScript.Invoke('floatoverwrite', [], gvtFloat64).AsFloat64;
      Check(Abs(LF64 - 99.5) < 0.001,
        'floatoverwrite():float64 = %.4f (expected 99.5, opt %d)', [LF64, LOrd]);

      // --- literal then overwrite: int32 return ---

      LI32 := LScript.Invoke('litoverwrite', [], gvtInt32).AsInt32;
      Check(LI32 = 75,
        'litoverwrite():int32 = %d (expected 75, opt %d)', [LI32, LOrd]);

      // --- multiple record vars: int64 return ---

      LI64 := LScript.Invoke('multivar', [], gvtInt64).AsInt64;
      Check(LI64 = 3103,
        'multivar():int64 = %d (expected 3103, opt %d)', [LI64, LOrd]);

      // --- kitchen sink: all types, int64 return ---

      LI64 := LScript.Invoke('kitchensink', [], gvtInt64).AsInt64;
      Check(LI64 = 62,
        'kitchensink():int64 = %d (expected 62, opt %d)', [LI64, LOrd]);

    finally
      LScript.Free();
    end;
  end;
end;

end.
