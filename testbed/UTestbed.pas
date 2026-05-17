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
  UDemo.Performance,
  UTest.VarAssign,
  UTest.Constants,
  UTest.NumericOps,
  UTest.ControlFlow,
  UTest.StringIO,
  UTest.ImportHost,
  UTest.ImportClause,
  UTest.MatchStmt,
  UTest.Records,
  UTest.Pointers,
  UTest.Arrays,
  UTest.ChoicesSets,
  UTest.Overlays,
  UTest.RoutineTypes,
  UTest.VariadicArgs;

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
        procedure begin TGnyTestCase.Run(TScriptRecordsTest) end)
      .Add('Array Types',
        procedure begin TGnyTestCase.Run(TArraysTest) end)
      .Add('Pointer Types',
        procedure begin TGnyTestCase.Run(TScriptPointersTest) end)
      .Add('Choices & Sets',
        procedure begin TGnyTestCase.Run(TScriptChoicesSetsTest) end)
      .Add('Overlay Types',
        procedure begin TGnyTestCase.Run(TScriptOverlaysTest) end)
      .Add('Routine Types',
        procedure begin TGnyTestCase.Run(TScriptRoutineTypesTest) end)
      .Add('Variadic Arguments',
        procedure begin TGnyTestCase.Run(TScriptVariadicArgsTest) end);
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
