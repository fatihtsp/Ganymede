{===============================================================================
  Ganymede™ - Embeddable Native Scripting Engine
  Test: Overlay (Union) Types
===============================================================================}

unit UTest.Overlays;

{$I Ganymede.Defines.inc}

interface

uses
  Ganymede.TestCase;

type
  TScriptOverlaysTest = class(TGnyTestCase)
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

{ TScriptOverlaysTest }

constructor TScriptOverlaysTest.Create();
begin
  inherited;
  Title := 'GanymedeScript — Overlay (Union) Types';
  Pause := True;
end;
procedure TScriptOverlaysTest.Run();
var
  LEngine: TGnyEngine;
  LI32: Int32;
  LI64: Int64;
  LI8: Int8;
  LF32: Single;
  LOptLevel: Integer;
  LFile: string;
begin
  if not gny_load(PAnsiChar(UTF8Encode(CDllPath))) then
  begin
    Check(False, 'Failed to load Ganymede DLL');
    Exit;
  end;

  LFile := TPath.Combine(CTestDir, 'test_mem_overlays.gny');

  for LOptLevel := GNY_OPT_NONE to GNY_OPT_FULL do
  begin
    Section('Overlay Types — opt level %d', [LOptLevel]);
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
      LI32 := gny_invoke(LEngine, PAnsiChar(UTF8Encode('overlay_int')), GNY_VT_INT32).AsInt32;
      Check(LI32 = 42, 'overlay_int():int32 = %d (expected 42, opt %d)', [LI32, LOptLevel]);

      LF32 := gny_invoke(LEngine, PAnsiChar(UTF8Encode('overlay_float')), GNY_VT_FLOAT32).AsFloat32;
      Check(Abs(LF32 - 3.14) < 0.01, 'overlay_float():f32 = %.4f (expected 3.14, opt %d)', [LF32, LOptLevel]);

      LF32 := gny_invoke(LEngine, PAnsiChar(UTF8Encode('overlay_reinterpret')), GNY_VT_FLOAT32).AsFloat32;
      Check(Abs(LF32 - 42.0) < 0.001, 'overlay_reinterpret():f32 = %.4f (expected 42.0, opt %d)', [LF32, LOptLevel]);

      LI64 := gny_invoke(LEngine, PAnsiChar(UTF8Encode('overlay_i64')), GNY_VT_INT64).AsInt64;
      Check(LI64 = 1234567890123, 'overlay_i64():int64 = %d (expected 1234567890123, opt %d)', [LI64, LOptLevel]);

      LI8 := gny_invoke(LEngine, PAnsiChar(UTF8Encode('overlay_i8')), GNY_VT_INT8).AsInt8;
      Check(LI8 = 99, 'overlay_i8():int8 = %d (expected 99, opt %d)', [LI8, LOptLevel]);

      LI64 := gny_invoke(LEngine, PAnsiChar(UTF8Encode('overlay_ptr')), GNY_VT_INT64).AsInt64;
      Check(LI64 = 0, 'overlay_ptr():int64 = %d (expected 0, opt %d)', [LI64, LOptLevel]);

      LI32 := gny_invoke(LEngine, PAnsiChar(UTF8Encode('tagged_int')), GNY_VT_INT32).AsInt32;
      Check(LI32 = 999, 'tagged_int():int32 = %d (expected 999, opt %d)', [LI32, LOptLevel]);

      LI32 := gny_invoke(LEngine, PAnsiChar(UTF8Encode('tagged_tag')), GNY_VT_INT32).AsInt32;
      Check(LI32 = 2, 'tagged_tag():int32 = %d (expected 2, opt %d)', [LI32, LOptLevel]);

      LI32 := gny_invoke(LEngine, PAnsiChar(UTF8Encode('event_xy')), GNY_VT_INT32).AsInt32;
      Check(LI32 = 300, 'event_xy():int32 = %d (expected 300, opt %d)', [LI32, LOptLevel]);

      LI32 := gny_invoke(LEngine, PAnsiChar(UTF8Encode('event_key')), GNY_VT_INT32).AsInt32;
      Check(LI32 = 65, 'event_key():int32 = %d (expected 65, opt %d)', [LI32, LOptLevel]);

    finally
      gny_destroy(LEngine);
    end;
  end;

  gny_unload();
end;

end.