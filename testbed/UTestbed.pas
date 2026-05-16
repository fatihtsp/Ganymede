{===============================================================================
  Ganymede™ - Embeddable Native Scripting Engine

  Copyright © 2026-present tinyBigGAMES™ LLC
  All Rights Reserved.

  See LICENSE for license information
===============================================================================}

unit UTestbed;

interface

procedure RunTestbed();

implementation

uses
  System.SysUtils,
  Ganymede.Utils,
  Ganymede.ConsoleMenu,
  Ganymede.TestCase,
  UDemo.Script.Performance,
  UTest.Script.VarAssign,
  UTest.Script.Constants,
  UTest.Script.NumericOps,
  UTest.Script.ControlFlow,
  UTest.Script.StringIO,
  UTest.Script.ImportHost,
  UTest.Script.ImportClause,
  UTest.Script.MatchStmt,
  UTest.Script.Records;

procedure Menu();
var
  LMenu: TGnyConsoleMenu;
begin
  LMenu := TGnyConsoleMenu.Create();
  try
    LMenu
      .Title('Ganymede Testbed')
      .ExitLabel('Quit')
      .Add('Script Performance',
        procedure
        begin
          RunScriptPerformanceDemo();
          TGnyUtils.Pause();
        end)
      .Add('Vars & Assignment',
        procedure begin TGnyTestCase.Run(TScriptVarAssignTest) end)
      .Add('Constants',
        procedure begin TGnyTestCase.Run(TScriptConstantsTest) end)
      .Add('Numeric Ops',
        procedure begin TGnyTestCase.Run(TScriptNumericOpsTest) end)
      .Add('Control Flow',
        procedure begin TGnyTestCase.Run(TScriptControlFlowTest) end)
      .Add('Strings & I/O',
        procedure begin TGnyTestCase.Run(TScriptStringIOTest) end)
      .Add('Import Host',
        procedure begin TGnyTestCase.Run(TScriptImportHostTest) end)
      .Add('Import Clause',
        procedure begin TGnyTestCase.Run(TScriptImportClauseTest) end)
      .Add('Match Statement',
        procedure begin TGnyTestCase.Run(TScriptMatchStmtTest) end)
      .Add('Record Types',
        procedure begin TGnyTestCase.Run(TScriptRecordsTest) end);
    LMenu.Run();
  finally
    LMenu.Free();
  end;
end;

procedure RunTestbed();
begin
  try
    Menu();
  except
    on E: Exception do
    begin
      TGnyUtils.PrintLn('');
      TGnyUtils.PrintLn(COLOR_RED + 'EXCEPTION: %s', [E.Message]);

      if TGnyUtils.RunFromIDE() then
        TGnyUtils.Pause();
    end;
  end;

end;

end.
