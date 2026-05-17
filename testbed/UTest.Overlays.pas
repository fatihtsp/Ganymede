{===============================================================================
  Ganymede™ - Embeddable Native Scripting Engine
  Test: Overlay (Union) Types
===============================================================================}

unit UTest.Overlays;

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
  TScriptOverlaysTest = class(TGnyTestCase)
  public
    constructor Create(); override;
  protected
    procedure Run(); override;
  end;
implementation

const
  CTestDir = 'C:\Dev\Delphi\Projects\Ganymede\repo\bin\tests';

{ TScriptOverlaysTest }

constructor TScriptOverlaysTest.Create();
begin
  inherited;
  Title := 'GanymedeScript — Overlay (Union) Types';
  Pause := True;
end;

procedure TScriptOverlaysTest.Run();
var
  LScript: TGanymede;
  LI32: Int32;
  LI64: Int64;
  LI8: Int8;
  LF32: Single;
  LOptLevel: TGnyOptLevel;
  LOrd: Integer;
  LFile: string;
begin  LFile := TPath.Combine(CTestDir, 'test_mem_overlays.gny');

  for LOptLevel := Low(TGnyOptLevel) to High(TGnyOptLevel) do
  begin
    LOrd := Ord(LOptLevel);
    Section('Overlay Types — opt level %d', [LOrd]);
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

      // --- Basic overlay: write int, read int ---
      LI32 := LScript.Invoke('overlay_int', [], gvtInt32).AsInt32;
      Check(LI32 = 42,
        'overlay_int():int32 = %d (expected 42, opt %d)', [LI32, LOrd]);
      // --- Basic overlay: write float, read float ---
      LF32 := LScript.Invoke('overlay_float', [], gvtFloat32).AsFloat32;
      Check(Abs(LF32 - 3.14) < 0.01,
        'overlay_float():f32 = %.4f (expected 3.14, opt %d)', [LF32, LOrd]);

      // --- Reinterpret: write int, read as float ---
      // 0x42280000 = 42.0f in IEEE 754
      LF32 := LScript.Invoke('overlay_reinterpret', [], gvtFloat32).AsFloat32;
      Check(Abs(LF32 - 42.0) < 0.001,
        'overlay_reinterpret():f32 = %.4f (expected 42.0, opt %d)', [LF32, LOrd]);

      // --- Mixed sizes: int64 ---
      LI64 := LScript.Invoke('overlay_i64', [], gvtInt64).AsInt64;
      Check(LI64 = 1234567890123,
        'overlay_i64():int64 = %d (expected 1234567890123, opt %d)', [LI64, LOrd]);

      // --- Mixed sizes: int8 ---
      LI8 := LScript.Invoke('overlay_i8', [], gvtInt8).AsInt8;
      Check(LI8 = 99,
        'overlay_i8():int8 = %d (expected 99, opt %d)', [LI8, LOrd]);

      // --- Pointer/int overlay ---
      LI64 := LScript.Invoke('overlay_ptr', [], gvtInt64).AsInt64;
      Check(LI64 = 0,
        'overlay_ptr():int64 = %d (expected 0, opt %d)', [LI64, LOrd]);
      // --- Record with anonymous overlay (tagged union) ---
      LI32 := LScript.Invoke('tagged_int', [], gvtInt32).AsInt32;
      Check(LI32 = 999,
        'tagged_int():int32 = %d (expected 999, opt %d)', [LI32, LOrd]);

      LI32 := LScript.Invoke('tagged_tag', [], gvtInt32).AsInt32;
      Check(LI32 = 2,
        'tagged_tag():int32 = %d (expected 2, opt %d)', [LI32, LOrd]);

      // --- Overlay with anonymous records ---
      LI32 := LScript.Invoke('event_xy', [], gvtInt32).AsInt32;
      Check(LI32 = 300,
        'event_xy():int32 = %d (expected 300, opt %d)', [LI32, LOrd]);

      LI32 := LScript.Invoke('event_key', [], gvtInt32).AsInt32;
      Check(LI32 = 65,
        'event_key():int32 = %d (expected 65, opt %d)', [LI32, LOrd]);

    finally
      LScript.Free();
    end;
  end;
end;

end.