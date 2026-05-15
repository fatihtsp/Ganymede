{===============================================================================
  Ganymede™ - Embeddable Native Scripting Engine

  Copyright © 2026-present tinyBigGAMES™ LLC
  All Rights Reserved.

  See LICENSE for license information
===============================================================================}

unit Ganymede.TestCase;

{$I Ganymede.Defines.inc}

interface

uses
  System.SysUtils,
  System.Generics.Collections,
  Ganymede.Utils;

type

  { TGnyTestCaseClass }
  TGnyTestCaseClass = class of TGnyTestCase;

  { TGnyTestCase }
  TGnyTestCase = class(TGnyBaseObject)
  private
    FTitle: string;
    FAllPassed: Boolean;
    FSectionIndex: Integer;
    FPause: Boolean;
  protected
    // Subclasses implement the actual test body here. Called by
    // Execute between banner and summary. Inside Run the subclass calls
    // Section / Check / FlushErrors freely.
    procedure Run(); overload; virtual; abstract;
  public
    constructor Create(); override;

    // One-shot entry point: prints the banner, invokes Run, prints the
    // pass/fail summary. Resets FAllPassed / FSectionIndex up front so
    // the same instance can be re-executed if the caller wants.
    procedure Execute();

    // Prints a dim, auto-numbered sub-section header. Each call
    // increments FSectionIndex, so the caller never writes numbers.
    procedure Section(const ATitle: string); overload;
    procedure Section(const ATitle: string;
      const AArgs: array of const); overload;

    // Records one assertion. Prints [PASS] green / [FAIL] red and
    // flips FAllPassed to False on any failure. The test's overall
    // result is the AND of every Check call in Run.
    procedure Check(const ACondition: Boolean; const ALabel: string); overload;
    procedure Check(const ACondition: Boolean; const ALabel: string;
      const AArgs: array of const); overload;

    // Prints every entry in AErrors with color-coded severity
    // (HINT / WARN / ERROR / FATAL). Nil-safe, empty-safe.
    procedure PrintErrors(const AErrors: TGnyErrors);

    // PrintErrors followed by AErrors.Clear — use this at the end of
    // each object's lifetime in a test so subsequent checks aren't
    // polluted by stale entries from a prior operation.
    procedure FlushErrors(const AErrors: TGnyErrors);

    // Instantiates ATestClass, runs its Execute, frees it. Returns the
    // test's overall pass flag so a caller can chain or aggregate
    // multiple test runs. Safe to call repeatedly.
    class function Run(const ATestClass: TGnyTestCaseClass): Boolean; overload;

    property Title: string read FTitle write FTitle;
    property AllPassed: Boolean read FAllPassed;
    property Pause: Boolean read FPause write FPause;
  end;

implementation

{ TGnyTestCase }

constructor TGnyTestCase.Create();
begin
  inherited;
  FTitle := '';
  FAllPassed := True;
  FSectionIndex := 0;
  FPause := False;
end;

procedure TGnyTestCase.Execute();
begin
  // Reset so the same instance can be Execute'd multiple times.
  FAllPassed := True;
  FSectionIndex := 0;

  // Banner
  TGnyUtils.PrintLn('');
  TGnyUtils.PrintLn(COLOR_CYAN + COLOR_BOLD + '--- %s ---' + COLOR_RESET,
    [FTitle]);

  Run();

  // Summary
  if FAllPassed then
    TGnyUtils.PrintLn(COLOR_GREEN + COLOR_BOLD +
      '=== %s: ALL PASSED ===' + COLOR_RESET, [FTitle])
  else
    TGnyUtils.PrintLn(COLOR_RED + COLOR_BOLD +
      '=== %s: FAILED ===' + COLOR_RESET, [FTitle]);

  if FPause then
    TGnyUtils.Pause();
end;

procedure TGnyTestCase.Section(const ATitle: string);
begin
  Inc(FSectionIndex);
  TGnyUtils.PrintLn('');
  TGnyUtils.PrintLn(COLOR_BLUE + '  [ %d. %s ]' + COLOR_RESET,
    [FSectionIndex, ATitle]);
end;

procedure TGnyTestCase.Section(const ATitle: string;
  const AArgs: array of const);
begin
  Section(Format(ATitle, AArgs));
end;

procedure TGnyTestCase.Check(const ACondition: Boolean; const ALabel: string);
begin
  if ACondition then
    TGnyUtils.PrintLn(COLOR_GREEN + '  [PASS] ' + COLOR_RESET + '%s',
      [ALabel])
  else
  begin
    TGnyUtils.PrintLn(COLOR_RED + '  [FAIL] ' + COLOR_RESET + '%s',
      [ALabel]);
    FAllPassed := False;
  end;
end;

procedure TGnyTestCase.Check(const ACondition: Boolean; const ALabel: string;
  const AArgs: array of const);
begin
  Check(ACondition, Format(ALabel, AArgs));
end;

procedure TGnyTestCase.PrintErrors(const AErrors: TGnyErrors);
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
    begin
      if not LErr.Range.IsEmpty() then
        TGnyUtils.PrintLn(LColor + '[%s] %s %s: %s',
          [LLabel, LErr.Range.ToPointString(), LErr.Code, LErr.Message])
      else
        TGnyUtils.PrintLn(LColor + '[%s] %s: %s',
          [LLabel, LErr.Code, LErr.Message]);
    end
    else
    begin
      if not LErr.Range.IsEmpty() then
        TGnyUtils.PrintLn(LColor + '[%s] %s %s',
          [LLabel, LErr.Range.ToPointString(), LErr.Message])
      else
        TGnyUtils.PrintLn(LColor + '[%s] %s', [LLabel, LErr.Message]);
    end;
  end;
end;

procedure TGnyTestCase.FlushErrors(const AErrors: TGnyErrors);
begin
  PrintErrors(AErrors);
  if AErrors <> nil then
    AErrors.Clear();
end;

{ TGnyTestCase.Run }

class function TGnyTestCase.Run(const ATestClass: TGnyTestCaseClass): Boolean;
var
  LTest: TGnyTestCase;
begin
  Result := False;
  if ATestClass = nil then
    Exit;

  // Virtual constructor dispatch — ATestClass.Create() runs the
  // most-derived override, so we actually get a fully-initialized
  // subclass instance even though LTest is declared as the base.
  LTest := ATestClass.Create();
  try
    LTest.Execute();
    Result := LTest.AllPassed;
  finally
    LTest.Free();
  end;
end;

end.
