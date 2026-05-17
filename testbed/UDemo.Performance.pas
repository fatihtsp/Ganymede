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
  Ganymede.Utils,
  Ganymede.Native,
  Ganymede.Core,
  UCommon;

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
{  Native JIT fib — x64 codegen via TGnyNativeBackend fluent API              }
{ -------------------------------------------------------------------------- }

function BenchNativeJIT(): Double;
var
  LNative: TGnyNativeBackend;
  LJIT: TGnyJIT;
  LSW: TStopwatch;
  LResult: Int64;
begin
  LNative := TGnyNativeBackend.Create();
  try
    LNative.SetOptimizationLevel(2);

    // Define fib as a recursive function
    LNative.Func('fib', gvtInt64, False, plDefault, True)
      .Arg('n', gvtInt64)
      .When(LNative.Lt(LNative.Get('n'), LNative.Int64(2)))
        .Ret(LNative.Get('n'))
      .EndWhen()
      .Ret(LNative.Add(
        LNative.Invoke('fib', [LNative.Sub(LNative.Get('n'), LNative.Int64(1))]),
        LNative.Invoke('fib', [LNative.Sub(LNative.Get('n'), LNative.Int64(2))])))
    .EndFunc();

    // JIT compile
    LJIT := LNative.BuildJIT();
    try
      // Benchmark the JIT execution
      LSW := TStopwatch.StartNew();
      LResult := LJIT.Invoke('fib', [FIB_N]);
      LSW.Stop();
      Result := LSW.Elapsed.TotalMilliseconds;
      Assert(LResult = 832040);
    finally
      LJIT.Free();
    end;
  finally
    LNative.Free();
  end;
end;

{ -------------------------------------------------------------------------- }
{  PxlScript Frontend JIT fib — source → lex → parse → emit → JIT           }
{ -------------------------------------------------------------------------- }

type
  TFibFunc = function(n: Int64): Int64;

function BenchScriptJIT(var ADirectMs: Double): Double;
var
  LScript: TGanymede;
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
  ''';
begin
  ADirectMs := -1;
  LScript := TGanymede.Create();
  try
    LScript.SetOptimizationLevel(olFull);
    LScript.LoadFromString(CFibSource, 'fibonacci.pxl');
    if not LScript.Compile() then
    begin
      TGnyUtils.PrintLn(COLOR_RED + '  Script compilation failed!');
      TGnyUtils.PrintLn(COLOR_RED + '  %s', [LScript.GetErrors().ToString()]);
      Result := -1;
      Exit;
    end;

    // Benchmark via Invoke (string lookup + arg boxing)
    LSW := TStopwatch.StartNew();
    LResult := LScript.Invoke('fib', [FIB_N], gvtInt64).AsInt64;
    LSW.Stop();
    Result := LSW.Elapsed.TotalMilliseconds;
    Assert(LResult = 832040);

    // Benchmark via direct function pointer (zero overhead)
    LFib := LScript.GetSymbol('fib');
    LSW := TStopwatch.StartNew();
    LDirectResult := LFib(FIB_N);
    LSW.Stop();
    ADirectMs := LSW.Elapsed.TotalMilliseconds;
    Assert(LDirectResult = 832040);
  finally
    LScript.Free();
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
  TGnyUtils.PrintLn(COLOR_CYAN + '  Ganymede™ Native JIT — fib(%d) Benchmark', [FIB_N]);
  TGnyUtils.PrintLn(COLOR_CYAN + '  =========================================================');
  TGnyUtils.PrintLn('');

  TGnyUtils.PrintLn(COLOR_WHITE + '  Running native Delphi...');
  LNativeMs := BenchNative();

  //TGnyUtils.PrintLn(COLOR_WHITE + '  Running native JIT...');
  //LJITMs := BenchNativeJIT();

  TGnyUtils.PrintLn(COLOR_WHITE + '  Running Native Script...');
  LScriptMs := BenchScriptJIT(LDirectMs);

  TGnyUtils.PrintLn('');
  TGnyUtils.PrintLn(COLOR_CYAN + '  Results (fib(%d) = 832040)', [FIB_N]);
  TGnyUtils.PrintLn(COLOR_CYAN + '  ---------------------------------------------------------');
  TGnyUtils.PrintLn(COLOR_WHITE + '  %-24s %10s %8s', ['Implementation', 'Time (ms)', 'Ratio']);
  TGnyUtils.PrintLn(COLOR_WHITE + '  %-24s %10s %8s', ['------------------------', '----------', '--------']);
  TGnyUtils.PrintLn(COLOR_GREEN + '  %-24s %10.1f %7.1fx', ['Native Delphi', LNativeMs, 1.0]);
  //TGnyUtils.PrintLn(COLOR_GREEN + '  %-24s %10.1f %7.1fx', ['Native JIT', LJITMs, LJITMs / LNativeMs]);
  if LScriptMs >= 0 then
  begin
    TGnyUtils.PrintLn(COLOR_GREEN + '  %-24s %10.1f %7.1fx', ['Native Script (Invoke)', LScriptMs, LScriptMs / LNativeMs]);
    TGnyUtils.PrintLn(COLOR_GREEN + '  %-24s %10.1f %7.1fx', ['Native Sript (Direct)', LDirectMs, LDirectMs / LNativeMs]);
  end
  else
    TGnyUtils.PrintLn(COLOR_RED + '  %-24s %10s %8s', ['PxlScript JIT', 'FAILED', 'N/A']);
  TGnyUtils.PrintLn(COLOR_WHITE + '  %-24s %10s %8s', ['------------------------', '----------', '--------']);
  TGnyUtils.PrintLn('');

  PrintBenchmarkReference();
end;

end.
