{===============================================================================
  PIXELS™ - 2D Game Engine

  Copyright © 2026-present tinyBigGAMES™ LLC
  All Rights Reserved.

  See LICENSE for license information
===============================================================================}

unit UCommon;

{$I Ganymede.Defines.inc}

interface

procedure PrintBenchmarkReference();

const
  CTestDir = 'tests';
  CDllPath = '..\lib\bin\Ganymede.dll';

implementation

uses
  Ganymede.Utils;


procedure PrintBenchmarkReference();
begin
  TGnyUtils.PrintLn('');
  TGnyUtils.PrintLn(COLOR_CYAN + '  Reference: Published Benchmark Results');
  TGnyUtils.PrintLn(COLOR_CYAN + '  =========================================================');
  TGnyUtils.PrintLn('');
  TGnyUtils.PrintLn(COLOR_YELLOW + '  Note: Numbers below are from published benchmarks on');
  TGnyUtils.PrintLn(COLOR_YELLOW + '  DIFFERENT hardware. For a fair comparison, run the');
  TGnyUtils.PrintLn(COLOR_YELLOW + '  equivalent Lua/Python/Wren/Cyber scripts on YOUR machine.');
  TGnyUtils.PrintLn('');

  // Source: cyberscript.dev performance page
  TGnyUtils.PrintLn(COLOR_BLUE + '  Source: cyberscript.dev performance page');
  TGnyUtils.PrintLn(COLOR_WHITE + '  Hardware: MacBook Pro M2');
  TGnyUtils.PrintLn(COLOR_WHITE + '  Method: script body timing, load time excluded');
  TGnyUtils.PrintLn(COLOR_WHITE + '  Versions: Cyber, LuaJIT 2.1.17, Lua 5.4.6, Wren 0.4, Python 3.12.0');
  TGnyUtils.PrintLn('');
  TGnyUtils.PrintLn(COLOR_WHITE + '  %-20s %8s %8s %8s %8s %8s',
    ['Test', 'Cyber', 'LuaJIT', 'Lua5.4', 'Wren', 'Python3']);
  TGnyUtils.PrintLn(COLOR_WHITE + '  %-20s %8s %8s %8s %8s %8s',
    ['--------------------', '--------', '--------', '--------', '--------', '--------']);
  TGnyUtils.PrintLn(COLOR_WHITE + '  %-20s %7s %7s %7s %7s %7s',
    ['Recursive Fib', '19ms', '21ms', '39ms', '71ms', '70ms']);  TGnyUtils.PrintLn(COLOR_WHITE + '  %-20s %7s %7s %7s %7s %7s',
    ['For Range/Iterator', '12ms', '11ms', '27ms', '44ms', '87ms']);
  TGnyUtils.PrintLn(COLOR_WHITE + '  %-20s %7s %7s %7s %7s %7s',
    ['Max-Heap Insert/Pop', '40ms', '52ms', '82ms', '123ms', '69ms']);
  TGnyUtils.PrintLn(COLOR_WHITE + '  %-20s %7s %7s %7s %7s %7s',
    ['Fibers/Coroutines', '8ms', '20ms', '48ms', '15ms', '34ms']);
  TGnyUtils.PrintLn('');

  // Source: muxup.com, "Updating Wren's benchmarks"
  TGnyUtils.PrintLn(COLOR_BLUE + '  Source: muxup.com, "Updating Wren''s benchmarks"');
  TGnyUtils.PrintLn(COLOR_WHITE + '  Hardware: AMD Ryzen 9 5950X');
  TGnyUtils.PrintLn(COLOR_WHITE + '  Method: median of 10 runs, interpreter startup not measured');
  TGnyUtils.PrintLn(COLOR_WHITE + '  Versions: LuaJIT 2.1 -joff, Lua 5.4.4, Wren 0.4, Ruby 3.0.5, Python 3.11.3');
  TGnyUtils.PrintLn('');
  TGnyUtils.PrintLn(COLOR_WHITE + '  %-20s %10s %8s %8s %8s %10s',
    ['Test', 'LuaJIT-joff', 'Lua5.4', 'Wren', 'Ruby3', 'Python3.11']);
  TGnyUtils.PrintLn(COLOR_WHITE + '  %-20s %10s %8s %8s %8s %10s',
    ['--------------------', '----------', '--------', '--------', '--------', '----------']);
  TGnyUtils.PrintLn(COLOR_WHITE + '  %-20s %10s %8s %8s %8s %10s',
    ['Recursive Fib', '55ms', '90ms', '148ms', '117ms', '157ms']);
  TGnyUtils.PrintLn(COLOR_WHITE + '  %-20s %10s %8s %8s %8s %10s',
    ['Binary Trees', '73ms', '138ms', '144ms', '115ms', '137ms']);
  TGnyUtils.PrintLn(COLOR_WHITE + '  %-20s %10s %8s %8s %8s %10s',
    ['Method Call', '90ms', '123ms', '79ms', '104ms', '170ms']);
  TGnyUtils.PrintLn('');

  // Fib N values
  TGnyUtils.PrintLn(COLOR_YELLOW + '  Recursive Fib N values:');
  TGnyUtils.PrintLn(COLOR_WHITE + '    Cyber source:      fib(30) once');
  TGnyUtils.PrintLn(COLOR_WHITE + '    Muxup/Wren source: fib(28) x 5 runs inside the script');
  TGnyUtils.PrintLn('');
end;


end.
