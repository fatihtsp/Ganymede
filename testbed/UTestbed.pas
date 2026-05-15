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
  UTest.Script.ImportLib;

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
      .Add('Script: Vars & Assignment',
        procedure begin TGnyTestCase.Run(TScriptVarAssignTest) end)
      .Add('Script: Constants',
        procedure begin TGnyTestCase.Run(TScriptConstantsTest) end)
      .Add('Script: Numeric Ops',
        procedure begin TGnyTestCase.Run(TScriptNumericOpsTest) end)
      .Add('Script: Control Flow',
        procedure begin TGnyTestCase.Run(TScriptControlFlowTest) end)
      .Add('Script: Strings & I/O',
        procedure begin TGnyTestCase.Run(TScriptStringIOTest) end)
      .Add('Script: Import Host',
        procedure begin TGnyTestCase.Run(TScriptImportHostTest) end)
      .Add('Script: Import Lib',
        procedure begin TGnyTestCase.Run(TScriptImportLibTest) end);
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
    end;
  end;

  if TGnyUtils.RunFromIDE() then
    TGnyUtils.Pause();
end;

end.
