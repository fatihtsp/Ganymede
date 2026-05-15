{===============================================================================
  Ganymede™ - Embeddable Native Scripting Engine

  Copyright © 2026-present tinyBigGAMES™ LLC
  All Rights Reserved.

  See LICENSE for license information
===============================================================================}

unit Ganymede.TestDemo;

{$I Ganymede.Defines.inc}

interface

uses
  System.SysUtils,
  System.Generics.Collections,
  Ganymede.Utils;

type
  { TGnyTestDemoClass }
  TGnyTestDemoClass = class of TGnyTestDemo;

  { TGnyTestDemo }
  TGnyTestDemo = class(TGnyBaseObject)
  private
    FTitle: string;
    FRunning: Boolean;
  public
    constructor Create(); override;

    // Lifecycle — drives the main loop. Subclasses override OnXXX hooks.
    procedure Execute();

    // Signals the loop in Execute to stop after the current iteration.
    procedure Terminate();

    // Lifecycle hooks — override in subclasses. All have empty defaults.
    procedure OnSetup(); virtual;
    procedure OnShutdown(); virtual;
    procedure OnUpdate(const ADeltaTime: Double); virtual;
    procedure OnRender(); virtual;

    // Console output helpers — delegates to TGnyUtils.
    procedure Print(const AMsg: string; const AArgs: array of const);
    procedure PrintLn(const AMsg: string; const AArgs: array of const);

    // Prints every entry in AErrors with color-coded severity.
    procedure PrintErrors(const AErrors: TGnyErrors);

    // PrintErrors followed by AErrors.Clear.
    procedure FlushErrors(const AErrors: TGnyErrors);

    // Instantiates ADemoClass, runs its Execute, frees it.
    class procedure Run(const ADemoClass: TGnyTestDemoClass);

    property Title: string read FTitle write FTitle;
    property Running: Boolean read FRunning;
  end;

implementation

{ TGnyTestDemo }

constructor TGnyTestDemo.Create();
begin
  inherited;
  FTitle := '';
  FRunning := False;
end;

procedure TGnyTestDemo.Execute();
var
  LStartTick: UInt64;
  LPrevTick: UInt64;
  LNowTick: UInt64;
  LDelta: Double;
  LElapsedMs: UInt64;
  LElapsedSec: Double;
begin
  FRunning := True;
  LStartTick := TGnyUtils.GetTickCount64();
  LPrevTick := LStartTick;

  // Banner
  TGnyUtils.PrintLn('');
  TGnyUtils.PrintLn(COLOR_CYAN + COLOR_BOLD + '--- Demo: %s ---' + COLOR_RESET,
    [FTitle]);

  OnSetup();

  // Main loop — runs until Terminate is called
  while FRunning do
  begin
    LNowTick := TGnyUtils.GetTickCount64();

    // Delta time in seconds
    LDelta := (LNowTick - LPrevTick) / 1000.0;
    LPrevTick := LNowTick;

    OnUpdate(LDelta);
    OnRender();

    // Yield to OS message queue
    TGnyUtils.ProcessMessages();
  end;

  OnShutdown();

  // Summary
  LElapsedMs := TGnyUtils.GetTickCount64() - LStartTick;
  LElapsedSec := LElapsedMs / 1000.0;
  TGnyUtils.PrintLn(COLOR_GREEN + COLOR_BOLD +
    '=== %s: Done (%.3fs) ===' + COLOR_RESET, [FTitle, LElapsedSec]);
end;

procedure TGnyTestDemo.Terminate();
begin
  FRunning := False;
end;

procedure TGnyTestDemo.OnSetup();
begin
  // Empty default — override in subclass
end;

procedure TGnyTestDemo.OnShutdown();
begin
  // Empty default — override in subclass
end;

procedure TGnyTestDemo.OnUpdate(const ADeltaTime: Double);
begin
  // Empty default — override in subclass
end;

procedure TGnyTestDemo.OnRender();
begin
  // Empty default — override in subclass
end;

procedure TGnyTestDemo.Print(const AMsg: string; const AArgs: array of const);
begin
  TGnyUtils.Print(AMsg, AArgs);
end;

procedure TGnyTestDemo.PrintLn(const AMsg: string; const AArgs: array of const);
begin
  TGnyUtils.PrintLn(AMsg, AArgs);
end;

procedure TGnyTestDemo.PrintErrors(const AErrors: TGnyErrors);
var
  LItems: TList<TGnyError>;
  LI: Integer;
  LErr: TGnyError;
  LColor: string;
  LLabel: string;
begin
  if AErrors = nil then
    Exit;
  LItems := AErrors.GetItems();
  if LItems.Count = 0 then
    Exit;

  TGnyUtils.PrintLn('');
  for LI := 0 to LItems.Count - 1 do
  begin
    LErr := LItems[LI];
    case LErr.Severity of
      esHint:
      begin
        LColor := COLOR_CYAN;
        LLabel := 'HINT';
      end;
      esWarning:
      begin
        LColor := COLOR_YELLOW;
        LLabel := 'WARN';
      end;
      esError:
      begin
        LColor := COLOR_RED;
        LLabel := 'ERROR';
      end;
      esFatal:
      begin
        LColor := COLOR_MAGENTA;
        LLabel := 'FATAL';
      end;
    else
      LColor := COLOR_WHITE;
      LLabel := '?';
    end;

    if LErr.Code <> '' then
      TGnyUtils.PrintLn(LColor + '[%s] %s: %s',
        [LLabel, LErr.Code, LErr.Message])
    else
      TGnyUtils.PrintLn(LColor + '[%s] %s', [LLabel, LErr.Message]);
  end;
end;

procedure TGnyTestDemo.FlushErrors(const AErrors: TGnyErrors);
begin
  PrintErrors(AErrors);
  if AErrors <> nil then
    AErrors.Clear();
end;

{ TGnyTestDemo.Run }

class procedure TGnyTestDemo.Run(const ADemoClass: TGnyTestDemoClass);
var
  LDemo: TGnyTestDemo;
begin
  if ADemoClass = nil then
    Exit;

  LDemo := ADemoClass.Create();
  try
    LDemo.Execute();
  finally
    LDemo.Free();
  end;
end;

end.
