{===============================================================================
  Ganymede™ - Embeddable Native Scripting Engine

  Copyright © 2026-present tinyBigGAMES™ LLC
  All Rights Reserved.

  See LICENSE for license information
===============================================================================}

program Testbed;

{$APPTYPE CONSOLE}

{$R *.res}

uses
  System.SysUtils,
  UTestbed in 'UTestbed.pas',
  Ganymede.ABI in '..\src\Ganymede.ABI.pas',
  Ganymede.API in '..\src\Ganymede.API.pas',
  Ganymede.Builders in '..\src\Ganymede.Builders.pas',
  Ganymede.Codegen in '..\src\Ganymede.Codegen.pas',
  Ganymede.Config in '..\src\Ganymede.Config.pas',
  Ganymede.Debug.Client in '..\src\Ganymede.Debug.Client.pas',
  Ganymede.Debug.DAP in '..\src\Ganymede.Debug.DAP.pas',
  Ganymede.Debug.REPL in '..\src\Ganymede.Debug.REPL.pas',
  Ganymede.Debug.Runtime in '..\src\Ganymede.Debug.Runtime.pas',
  Ganymede.Debug.Server in '..\src\Ganymede.Debug.Server.pas',
  Ganymede.Debug.SourceMap in '..\src\Ganymede.Debug.SourceMap.pas',
  Ganymede.Debug.Target in '..\src\Ganymede.Debug.Target.pas',
  Ganymede.Emitter in '..\src\Ganymede.Emitter.pas',
  Ganymede.IR in '..\src\Ganymede.IR.pas',
  Ganymede.JIT in '..\src\Ganymede.JIT.pas',
  Ganymede.Lexer in '..\src\Ganymede.Lexer.pas',
  Ganymede.Linker in '..\src\Ganymede.Linker.pas',
  Ganymede.Native in '..\src\Ganymede.Native.pas',
  Ganymede.Parser in '..\src\Ganymede.Parser.pas',
  Ganymede in '..\src\Ganymede.pas',
  Ganymede.Resources in '..\src\Ganymede.Resources.pas',
  Ganymede.Runtime in '..\src\Ganymede.Runtime.pas',
  Ganymede.Semantics in '..\src\Ganymede.Semantics.pas',
  Ganymede.SSA in '..\src\Ganymede.SSA.pas',
  Ganymede.TestCase in '..\src\Ganymede.TestCase.pas',
  Ganymede.TestDemo in '..\src\Ganymede.TestDemo.pas',
  Ganymede.TOML in '..\src\Ganymede.TOML.pas',
  Ganymede.Types in '..\src\Ganymede.Types.pas',
  Ganymede.Utils in '..\src\Ganymede.Utils.pas',
  UCommon in 'UCommon.pas',
  UTest.Script.ImportClause in 'UTest.Script.ImportClause.pas';

begin
  RunTestbed();
end.
