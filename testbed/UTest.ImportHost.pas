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
  System.SysUtils,
  Ganymede.Utils,
  Ganymede.TestCase,
  Ganymede,
  Ganymede.Native;

type
  { TScriptImportHostTest }
  TScriptImportHostTest = class(TGnyTestCase)
  protected
    procedure Run(); override;
  public
    constructor Create(); override;
  end;

implementation

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

{ TScriptImportHostTest }

constructor TScriptImportHostTest.Create();
begin
  inherited;
  Title := 'PxlScript — ImportHost (Host Function Calls)';
  Pause := True;
end;

procedure TScriptImportHostTest.Run();
var
  LScript: TGanymede;
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
  //--- Test 1: Simple host call with args and return --------------------------
  Section('Simple host call — host_add(10, 20)');
  LScript := TGanymede.Create();
  try
    LScript.ImportHost('host_add', @host_add,
      [gvtInt64, gvtInt64], gvtInt64);
    LScript.LoadFromString(CAddSource, 'test_add.pxs');

    if not LScript.Compile() then
    begin
      FlushErrors(LScript.GetErrors());
      Check(False, 'Compile failed');
    end
    else
    begin
      Check(True, 'Compiled successfully');
      LResult := LScript.Invoke('main', [], gvtInt64).AsInt64;
      Check(LResult = 30, 'host_add(10, 20) = %d (expected 30)', [LResult]);
    end;
  finally
    LScript.Free();
  end;

  //--- Test 2: Nested host calls ----------------------------------------------
  Section('Nested host calls — host_add(host_mul(3, 4), host_negate(5))');
  LScript := TGanymede.Create();
  try
    LScript.ImportHost('host_add', @host_add,
      [gvtInt64, gvtInt64], gvtInt64);
    LScript.ImportHost('host_mul', @host_mul,
      [gvtInt64, gvtInt64], gvtInt64);
    LScript.ImportHost('host_negate', @host_negate,
      [gvtInt64], gvtInt64);
    LScript.LoadFromString(CNestedSource, 'test_nested.pxs');

    if not LScript.Compile() then
    begin
      FlushErrors(LScript.GetErrors());
      Check(False, 'Compile failed');
    end
    else
    begin
      Check(True, 'Compiled successfully');
      LResult := LScript.Invoke('main', [], gvtInt64).AsInt64;
      Check(LResult = 7, 'host_add(host_mul(3,4), host_negate(5)) = %d (expected 7)',
        [LResult]);
    end;
  finally
    LScript.Free();
  end;

  //--- Test 3: Void host calls (side effects) ---------------------------------
  Section('Void host calls — counter increment');
  GHostCallCount := 0;
  LScript := TGanymede.Create();
  try
    LScript.ImportHost('host_increment_counter',
      @host_increment_counter, []);
    LScript.ImportHost('host_get_counter',
      @host_get_counter, [], gvtInt64);
    LScript.LoadFromString(CCounterSource, 'test_counter.pxs');

    if not LScript.Compile() then
    begin
      FlushErrors(LScript.GetErrors());
      Check(False, 'Compile failed');
    end
    else
    begin
      Check(True, 'Compiled successfully');
      LResult := LScript.Invoke('main', [], gvtInt64).AsInt64;
      Check(LResult = 3, 'Counter after 3 increments = %d (expected 3)', [LResult]);
    end;
  finally
    LScript.Free();
  end;

  //--- Test 4: Recompilation on same instance ---------------------------------
  Section('Recompile — same instance, different source');
  LScript := TGanymede.Create();
  try
    LScript.ImportHost('host_add', @host_add,
      [gvtInt64, gvtInt64], gvtInt64);

    // First compile: 10 + 20 = 30
    LScript.LoadFromString(
      '''
      module mem test_recomp1;
      public routine main(): int64;
      begin
        return host_add(10, 20);
      end;
      end.
      ''', 'recomp1.pxs');

    if not LScript.Compile() then
    begin
      FlushErrors(LScript.GetErrors());
      Check(False, 'First compile failed');
    end
    else
    begin
      Check(True, 'First compile OK');
      LResult := LScript.Invoke('main', [], gvtInt64).AsInt64;
      Check(LResult = 30, 'First: host_add(10, 20) = %d (expected 30)', [LResult]);
    end;

    // Second compile: 100 + 200 = 300
    LScript.LoadFromString(
      '''
      module mem test_recomp2;
      public routine main(): int64;
      begin
        return host_add(100, 200);
      end;
      end.
      ''', 'recomp2.pxs');

    if not LScript.Compile() then
    begin
      FlushErrors(LScript.GetErrors());
      Check(False, 'Recompile failed');
    end
    else
    begin
      Check(True, 'Recompile OK');
      LResult := LScript.Invoke('main', [], gvtInt64).AsInt64;
      Check(LResult = 300, 'Recompile: host_add(100, 200) = %d (expected 300)', [LResult]);
    end;
  finally
    LScript.Free();
  end;
end;

end.
