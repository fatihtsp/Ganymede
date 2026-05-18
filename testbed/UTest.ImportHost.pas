{===============================================================================
  Ganymede™ - Embeddable Native Scripting Engine

  Copyright © 2026-present tinyBigGAMES™ LLC
  All Rights Reserved.

  See LICENSE for license information
===============================================================================}

unit UTest.ImportHost;

{$I Ganymede.Defines.inc}

interface

uses
  Ganymede.TestCase;

type
  { TScriptImportHostTest }
  TScriptImportHostTest = class(TGnyTestCase)
  protected
    procedure Run(); override;
  public
    constructor Create(); override;
  end;

implementation

uses
  UCommon,
  Ganymede;

// Host functions for testing — called from JIT'd script code

function host_add(const A, B: Int64): Int64;
begin
  Result := A + B;
end;

function host_mul(const A, B: Int64): Int64;
begin
  Result := A * B;
end;

function host_negate(const A: Int64): Int64;
begin
  Result := -A;
end;

var
  GHostCallCount: Int64;

procedure host_increment_counter();
begin
  Inc(GHostCallCount);
end;

function host_get_counter(): Int64;
begin
  Result := GHostCallCount;
end;

const
  // Param type arrays for gny_import_host
  CParamsInt64x2: array[0..1] of Integer = (GNY_VT_INT64, GNY_VT_INT64);
  CParamsInt64x1: array[0..0] of Integer = (GNY_VT_INT64);

{ TScriptImportHostTest }

constructor TScriptImportHostTest.Create();
begin
  inherited;
  Title := 'PxlScript — ImportHost (Host Function Calls)';
  Pause := True;
end;

procedure TScriptImportHostTest.Run();
var
  LEngine: TGnyEngine;
  LResult: Int64;
const

  // Test 1: Host function with two args and return value
  CAddSource =
  '''
  module mem test_add;

  public routine main(): int64;
  begin
    return host_add(10, 20);
  end;

  end.
  ''';
  // Test 2: Nested host calls
  CNestedSource =
  '''
  module mem test_nested;

  public routine main(): int64;
  begin
    return host_add(host_mul(3, 4), host_negate(5));
  end;

  end.
  ''';

  // Test 3: Host function with no args/return (side effect)
  CCounterSource =
  '''
  module mem test_counter;

  public routine main(): int64;
  begin
    host_increment_counter();
    host_increment_counter();
    host_increment_counter();
    return host_get_counter();
  end;

  end.
  ''';
begin
  if not gny_load(PAnsiChar(UTF8Encode(CDllPath))) then
  begin
    Check(False, 'Failed to load Ganymede DLL');
    Exit;
  end;

  //--- Test 1: Simple host call with args and return --------------------------
  Section('Simple host call — host_add(10, 20)');
  LEngine := gny_create();
  try
    gny_import_host(LEngine, PAnsiChar(UTF8Encode('host_add')),
      @host_add, @CParamsInt64x2[0], 2, GNY_VT_INT64, GNY_LINK_DEFAULT);
    gny_load_from_string(LEngine,
      PAnsiChar(UTF8Encode(CAddSource)),
      PAnsiChar(UTF8Encode('test_add.pxs')));

    if not gny_compile(LEngine) then
    begin
      gny_print_errors(LEngine);
      Check(False, 'Compile failed');
    end
    else
    begin
      Check(True, 'Compiled successfully');
      LResult := gny_invoke(LEngine,
        PAnsiChar(UTF8Encode('main')), GNY_VT_INT64).AsInt64;
      Check(LResult = 30, 'host_add(10, 20) = %d (expected 30)', [LResult]);
    end;
  finally
    gny_destroy(LEngine);
  end;
  //--- Test 2: Nested host calls ----------------------------------------------
  Section('Nested host calls — host_add(host_mul(3, 4), host_negate(5))');
  LEngine := gny_create();
  try
    gny_import_host(LEngine, PAnsiChar(UTF8Encode('host_add')),
      @host_add, @CParamsInt64x2[0], 2, GNY_VT_INT64, GNY_LINK_DEFAULT);
    gny_import_host(LEngine, PAnsiChar(UTF8Encode('host_mul')),
      @host_mul, @CParamsInt64x2[0], 2, GNY_VT_INT64, GNY_LINK_DEFAULT);
    gny_import_host(LEngine, PAnsiChar(UTF8Encode('host_negate')),
      @host_negate, @CParamsInt64x1[0], 1, GNY_VT_INT64, GNY_LINK_DEFAULT);
    gny_load_from_string(LEngine,
      PAnsiChar(UTF8Encode(CNestedSource)),
      PAnsiChar(UTF8Encode('test_nested.pxs')));

    if not gny_compile(LEngine) then
    begin
      gny_print_errors(LEngine);
      Check(False, 'Compile failed');
    end
    else
    begin
      Check(True, 'Compiled successfully');
      LResult := gny_invoke(LEngine,
        PAnsiChar(UTF8Encode('main')), GNY_VT_INT64).AsInt64;
      Check(LResult = 7,
        'host_add(host_mul(3,4), host_negate(5)) = %d (expected 7)', [LResult]);
    end;
  finally
    gny_destroy(LEngine);
  end;
  //--- Test 3: Void host calls (side effects) ---------------------------------
  Section('Void host calls — counter increment');
  GHostCallCount := 0;
  LEngine := gny_create();
  try
    gny_import_host(LEngine, PAnsiChar(UTF8Encode('host_increment_counter')),
      @host_increment_counter, nil, 0, GNY_VT_VOID, GNY_LINK_DEFAULT);
    gny_import_host(LEngine, PAnsiChar(UTF8Encode('host_get_counter')),
      @host_get_counter, nil, 0, GNY_VT_INT64, GNY_LINK_DEFAULT);
    gny_load_from_string(LEngine,
      PAnsiChar(UTF8Encode(CCounterSource)),
      PAnsiChar(UTF8Encode('test_counter.pxs')));

    if not gny_compile(LEngine) then
    begin
      gny_print_errors(LEngine);
      Check(False, 'Compile failed');
    end
    else
    begin
      Check(True, 'Compiled successfully');
      LResult := gny_invoke(LEngine,
        PAnsiChar(UTF8Encode('main')), GNY_VT_INT64).AsInt64;
      Check(LResult = 3, 'Counter after 3 increments = %d (expected 3)', [LResult]);
    end;
  finally
    gny_destroy(LEngine);
  end;
  //--- Test 4: Recompilation on same instance ---------------------------------
  Section('Recompile — same instance, different source');
  LEngine := gny_create();
  try
    gny_import_host(LEngine, PAnsiChar(UTF8Encode('host_add')),
      @host_add, @CParamsInt64x2[0], 2, GNY_VT_INT64, GNY_LINK_DEFAULT);

    // First compile: 10 + 20 = 30
    gny_load_from_string(LEngine,
      PAnsiChar(UTF8Encode(
      '''
      module mem test_recomp1;
      public routine main(): int64;
      begin
        return host_add(10, 20);
      end;
      end.
      ''')),
      PAnsiChar(UTF8Encode('recomp1.pxs')));

    if not gny_compile(LEngine) then
    begin
      gny_print_errors(LEngine);
      Check(False, 'First compile failed');
    end
    else
    begin
      Check(True, 'First compile OK');
      LResult := gny_invoke(LEngine,
        PAnsiChar(UTF8Encode('main')), GNY_VT_INT64).AsInt64;
      Check(LResult = 30, 'First: host_add(10, 20) = %d (expected 30)', [LResult]);
    end;
    // Second compile: 100 + 200 = 300
    gny_load_from_string(LEngine,
      PAnsiChar(UTF8Encode(
      '''
      module mem test_recomp2;
      public routine main(): int64;
      begin
        return host_add(100, 200);
      end;
      end.
      ''')),
      PAnsiChar(UTF8Encode('recomp2.pxs')));

    if not gny_compile(LEngine) then
    begin
      gny_print_errors(LEngine);
      Check(False, 'Recompile failed');
    end
    else
    begin
      Check(True, 'Recompile OK');
      LResult := gny_invoke(LEngine,
        PAnsiChar(UTF8Encode('main')), GNY_VT_INT64).AsInt64;
      Check(LResult = 300, 'Recompile: host_add(100, 200) = %d (expected 300)',
        [LResult]);
    end;
  finally
    gny_destroy(LEngine);
  end;

  gny_unload();
end;

end.