{===============================================================================
  Ganymede™ - Embeddable Native Scripting Engine

  Copyright © 2026-present tinyBigGAMES™ LLC
  All Rights Reserved.

  See LICENSE for license information
===============================================================================}

unit UDemo.Performance;

{$I Ganymede.Defines.inc}

interface

procedure RunScriptPerformanceDemo();

implementation

uses
  System.SysUtils,
  System.Diagnostics,
  UCommon,
  Ganymede;

const
  FIB_N = 30;

{ -------------------------------------------------------------------------- }
{  Native Delphi fib                                                         }
{ -------------------------------------------------------------------------- }

function NativeFib(const AN: Int64): Int64;
begin
  if AN < 2 then
    Result := AN
  else
    Result := NativeFib(AN - 1) + NativeFib(AN - 2);
end;
function BenchNative(): Double;
var
  LSW: TStopwatch;
  LResult: Int64;
begin
  LSW := TStopwatch.StartNew();
  LResult := NativeFib(FIB_N);
  LSW.Stop();
  Result := LSW.Elapsed.TotalMilliseconds;
  Assert(LResult = 832040);
end;

{ -------------------------------------------------------------------------- }
{  Script JIT fib — source → compile → JIT via DLL API                      }
{ -------------------------------------------------------------------------- }

type
  TFibFunc = function(n: Int64): Int64;

function BenchScriptJIT(var ADirectMs: Double): Double;
var
  LEngine: TGnyEngine;
  LSW: TStopwatch;
  LResult: Int64;
  LFib: TFibFunc;
  LDirectResult: Int64;
const
  CFibSource =
  '''
  module mem fibonacci;

  public routine fib(n: int64): int64;
  begin
    if n <= 1 then
      return n;
    end;
    return fib(n - 1) + fib(n - 2);
  end;

  end.
  ''';begin
  ADirectMs := -1;
  LEngine := gny_create();
  try
    gny_set_optimization_level(LEngine, GNY_OPT_FULL);
    gny_load_from_string(LEngine,
      PAnsiChar(UTF8Encode(CFibSource)),
      PAnsiChar(UTF8Encode('fibonacci.pxl')));
    if not gny_compile(LEngine) then
    begin
      WriteLn('  Script compilation failed!');
      gny_print_errors(LEngine);
      Result := -1;
      Exit;
    end;

    // Benchmark via Invoke (string lookup + arg boxing)
    LSW := TStopwatch.StartNew();
    gny_arg_push_int64(LEngine, FIB_N);
    LResult := gny_invoke(LEngine,
      PAnsiChar(UTF8Encode('fib')), GNY_VT_INT64).AsInt64;
    LSW.Stop();
    Result := LSW.Elapsed.TotalMilliseconds;
    Assert(LResult = 832040);

    // Benchmark via direct function pointer (zero overhead)
    LFib := gny_get_symbol(LEngine, PAnsiChar(UTF8Encode('fib')));
    LSW := TStopwatch.StartNew();
    LDirectResult := LFib(FIB_N);
    LSW.Stop();
    ADirectMs := LSW.Elapsed.TotalMilliseconds;
    Assert(LDirectResult = 832040);
  finally
    gny_destroy(LEngine);
  end;
end;
{ -------------------------------------------------------------------------- }
{  Main                                                                      }
{ -------------------------------------------------------------------------- }

procedure RunScriptPerformanceDemo();
var
  LNativeMs: Double;
  LScriptMs: Double;
  LDirectMs: Double;
begin
  if not gny_load(PAnsiChar(UTF8Encode(CDllPath))) then
  begin
    WriteLn('  Failed to load Ganymede DLL');
    Exit;
  end;

  WriteLn('  Ganymede Native JIT — fib(', FIB_N, ') Benchmark');
  WriteLn('  =========================================================');
  WriteLn('');

  WriteLn('  Running native Delphi...');
  LNativeMs := BenchNative();

  WriteLn('  Running Native Script...');
  LScriptMs := BenchScriptJIT(LDirectMs);

  WriteLn('');
  WriteLn(Format('  Results (fib(%d) = 832040)', [FIB_N]));
  WriteLn('  ---------------------------------------------------------');
  WriteLn(Format('  %-24s %10s %8s', ['Implementation', 'Time (ms)', 'Ratio']));
  WriteLn(Format('  %-24s %10s %8s', ['------------------------', '----------', '--------']));
  WriteLn(Format('  %-24s %10.1f %7.1fx', ['Native Delphi', LNativeMs, 1.0]));
  if LScriptMs >= 0 then
  begin
    WriteLn(Format('  %-24s %10.1f %7.1fx', ['Native Script (Invoke)', LScriptMs, LScriptMs / LNativeMs]));
    WriteLn(Format('  %-24s %10.1f %7.1fx', ['Native Script (Direct)', LDirectMs, LDirectMs / LNativeMs]));
  end
  else
    WriteLn(Format('  %-24s %10s %8s', ['Script JIT', 'FAILED', 'N/A']));
  WriteLn(Format('  %-24s %10s %8s', ['------------------------', '----------', '--------']));
  WriteLn('');

  PrintBenchmarkReference();

  gny_unload();
end;

end.