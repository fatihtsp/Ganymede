{===============================================================================
  Ganymede™ - Embeddable Native Scripting Engine

  Copyright (c) 2026-present tinyBigGAMES LLC
  All Rights Reserved.

  See LICENSE for license information
===============================================================================}

unit Ganymede.ConsoleMenu;

{$I Ganymede.Defines.inc}

interface

uses
  System.SysUtils,
  System.Generics.Collections,
  Ganymede.Utils;

type

  { TGnyMenuCallback }
  TGnyMenuCallback = reference to procedure;

  { TGnyMenuItemKind }
  TGnyMenuItemKind = (
    pxlMenuAction,
    pxlMenuSeparator
  );

  { TGnyMenuItem }
  TGnyMenuItem = record
    ItemName: string;
    Callback: TGnyMenuCallback;
    Kind: TGnyMenuItemKind;
  end;

  { TGnyConsoleMenu }
  TGnyConsoleMenu = class(TGnyBaseObject)
  private
    FTitle: string;
    FExitLabel: string;
    FItems: TList<TGnyMenuItem>;
    FTitleColor: string;
    FItemColor: string;
    FItemNumberColor: string;
    FExitColor: string;
    FErrorColor: string;
    FPromptColor: string;
    FSeparatorColor: string;
    FPromptText: string;
  public
    constructor Create(); override;
    destructor Destroy(); override;

    // Configuration (fluent - returns Self)
    function Title(const ATitle: string): TGnyConsoleMenu;
    function ExitLabel(const ALabel: string): TGnyConsoleMenu;
    function PromptText(const AText: string): TGnyConsoleMenu;
    function TitleColor(const AColor: string): TGnyConsoleMenu;
    function ItemColor(const AColor: string): TGnyConsoleMenu;
    function ItemNumberColor(const AColor: string): TGnyConsoleMenu;
    function ExitColor(const AColor: string): TGnyConsoleMenu;
    function ErrorColor(const AColor: string): TGnyConsoleMenu;
    function PromptColor(const AColor: string): TGnyConsoleMenu;
    function SeparatorColor(const AColor: string): TGnyConsoleMenu;

    // Add items
    function Add(const AItemName: string;
      const ACallback: TGnyMenuCallback): TGnyConsoleMenu;
    function AddSeparator(): TGnyConsoleMenu;

    // Run the menu loop (blocks until user selects exit)
    procedure Run();

    // Clear all items
    procedure Clear();

    // Item count (excluding separators)
    function ActionCount(): Integer;
  end;

implementation

{ TGnyConsoleMenu }

constructor TGnyConsoleMenu.Create();
begin
  inherited;
  FItems := TList<TGnyMenuItem>.Create();
  FTitle := 'Menu';
  FExitLabel := 'Quit';
  FPromptText := ':: ';
  FTitleColor := COLOR_CYAN + COLOR_BOLD;
  FItemColor := COLOR_WHITE;
  FItemNumberColor := COLOR_YELLOW;
  FExitColor := COLOR_WHITE;
  FErrorColor := COLOR_RED;
  FPromptColor := COLOR_GREEN;
  FSeparatorColor := COLOR_WHITE;
end;

destructor TGnyConsoleMenu.Destroy();
begin
  FItems.Free();
  inherited;
end;

function TGnyConsoleMenu.Title(const ATitle: string): TGnyConsoleMenu;
begin
  FTitle := ATitle;
  Result := Self;
end;

function TGnyConsoleMenu.ExitLabel(const ALabel: string): TGnyConsoleMenu;
begin
  FExitLabel := ALabel;
  Result := Self;
end;

function TGnyConsoleMenu.PromptText(const AText: string): TGnyConsoleMenu;
begin
  FPromptText := AText;
  Result := Self;
end;

function TGnyConsoleMenu.TitleColor(const AColor: string): TGnyConsoleMenu;
begin
  FTitleColor := AColor;
  Result := Self;
end;

function TGnyConsoleMenu.ItemColor(const AColor: string): TGnyConsoleMenu;
begin
  FItemColor := AColor;
  Result := Self;
end;

function TGnyConsoleMenu.ItemNumberColor(const AColor: string): TGnyConsoleMenu;
begin
  FItemNumberColor := AColor;
  Result := Self;
end;

function TGnyConsoleMenu.ExitColor(const AColor: string): TGnyConsoleMenu;
begin
  FExitColor := AColor;
  Result := Self;
end;

function TGnyConsoleMenu.ErrorColor(const AColor: string): TGnyConsoleMenu;
begin
  FErrorColor := AColor;
  Result := Self;
end;

function TGnyConsoleMenu.PromptColor(const AColor: string): TGnyConsoleMenu;
begin
  FPromptColor := AColor;
  Result := Self;
end;

function TGnyConsoleMenu.SeparatorColor(const AColor: string): TGnyConsoleMenu;
begin
  FSeparatorColor := AColor;
  Result := Self;
end;

function TGnyConsoleMenu.Add(const AItemName: string;
  const ACallback: TGnyMenuCallback): TGnyConsoleMenu;
var
  LItem: TGnyMenuItem;
begin
  LItem.ItemName := AItemName;
  LItem.Callback := ACallback;
  LItem.Kind := pxlMenuAction;
  FItems.Add(LItem);
  Result := Self;
end;

function TGnyConsoleMenu.AddSeparator(): TGnyConsoleMenu;
var
  LItem: TGnyMenuItem;
begin
  LItem.ItemName := '';
  LItem.Callback := nil;
  LItem.Kind := pxlMenuSeparator;
  FItems.Add(LItem);
  Result := Self;
end;

procedure TGnyConsoleMenu.Clear();
begin
  FItems.Clear();
end;

function TGnyConsoleMenu.ActionCount(): Integer;
var
  LI: Integer;
begin
  Result := 0;
  for LI := 0 to FItems.Count - 1 do
  begin
    if FItems[LI].Kind = pxlMenuAction then
      Inc(Result);
  end;
end;

procedure TGnyConsoleMenu.Run();
var
  LInput: string;
  LChoice: Integer;
  LI: Integer;
  LNumber: Integer;
  LActionMap: TList<Integer>;  // maps menu number -> FItems index
begin
  LActionMap := TList<Integer>.Create();
  try
    while True do
    begin
      // Build action map (skip separators)
      LActionMap.Clear();
      for LI := 0 to FItems.Count - 1 do
      begin
        if FItems[LI].Kind = pxlMenuAction then
          LActionMap.Add(LI);
      end;

      // Clear screen before displaying menu
      TGnyUtils.ClearScreen();

      // Display title
      TGnyUtils.PrintLn('');
      TGnyUtils.PrintLn(FTitleColor + '  [ ' + FTitle + ' ]');
      TGnyUtils.PrintLn('');

      // Display items
      LNumber := 1;
      for LI := 0 to FItems.Count - 1 do
      begin
        if FItems[LI].Kind = pxlMenuSeparator then
          TGnyUtils.PrintLn('')
        else
        begin
          TGnyUtils.PrintLn('  ' + FItemNumberColor + '[%d] ' +
            FItemColor + '%s', [LNumber, FItems[LI].ItemName]);
          Inc(LNumber);
        end;
      end;

      // Display exit option
      TGnyUtils.PrintLn('');
      TGnyUtils.PrintLn('  ' + FItemNumberColor + '[0] ' +
        FExitColor + '%s', [FExitLabel]);
      TGnyUtils.PrintLn('');

      // Prompt
      TGnyUtils.Print(FPromptColor + '  ' + FPromptText);
      ReadLn(LInput);

      LChoice := StrToIntDef(Trim(LInput), -1);

      // Exit
      if LChoice = 0 then
        Break;

      // Execute action
      if (LChoice >= 1) and (LChoice <= LActionMap.Count) then
      begin
        if Assigned(FItems[LActionMap[LChoice - 1]].Callback) then
        begin
          TGnyUtils.ClearScreen();
          FItems[LActionMap[LChoice - 1]].Callback();
        end;
      end
      else
        TGnyUtils.PrintLn(FErrorColor + 'Invalid choice.');
    end;
  finally
    LActionMap.Free();
  end;
end;

end.
