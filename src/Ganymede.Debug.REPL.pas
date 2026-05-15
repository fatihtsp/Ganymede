{===============================================================================
  Ganymede™ - Embeddable Native Scripting Engine

  Copyright © 2026-present tinyBigGAMES™ LLC
  All Rights Reserved.

  See LICENSE for license information
===============================================================================}

unit Ganymede.Debug.REPL;

{$I Ganymede.Defines.inc}

interface

uses
  WinApi.Windows,
  System.SysUtils,
  System.Classes,
  System.IOUtils,
  System.Generics.Collections,
  Ganymede.Utils,
  Ganymede.Debug.Server,
  Ganymede.Debug.Client;

const
  CDefaultDAPPort = 4711;
  CTimeoutContinueMS = 5000;
  CTimeoutStepMS = 2000;

type
  //============================================================================
  // TREPLBreakpoint - Local breakpoint tracking record
  //============================================================================
  TREPLBreakpoint = record
    SourceFile: string;
    SourceLine: Integer;
    Verified: Boolean;
  end;

  //============================================================================
  // TGnyNativeDebugREPL - Interactive console debugger for Viper programs.
  // Drives TGnyNativeDebugServer + TGnyNativeDebugClient over DAP/TCP.
  //============================================================================

  { TGnyNativeDebugREPL }
  TGnyNativeDebugREPL = class(TGnyBaseObject)
  private
    FServer: TGnyNativeDebugServer;
    FClient: TGnyNativeDebugClient;
    FServerThread: TThread;
    FBreakpoints: TList<TREPLBreakpoint>;
    FRunning: Boolean;
    FExePath: string;
    FPort: Integer;
    FPrompt: string;
    FTimeoutContinueMS: Integer;
    FTimeoutStepMS: Integer;

    // Command handlers
    procedure ProcessCommand(const ACommand: string);
    procedure ShowHelp();
    procedure HandleSetBreakpoint(const ACommand: string);
    procedure HandleListBreakpoints();
    procedure HandleDeleteBreakpoint(const ACommand: string);
    procedure HandleClearBreakpoints();
    procedure HandleBacktrace();
    procedure HandleLocals();
    procedure HandlePrint(const ACommand: string);
    procedure HandleContinue();
    procedure HandleNext();
    procedure HandleStepInto();
    procedure HandleStepOut();
    procedure HandleRestart();
    procedure HandleFile(const ACommand: string);
    procedure HandleVerbose(const ACommand: string);
    procedure HandleThreads();

    // Internal
    procedure StartSession();
    procedure StopSession();
    function DoDAHandshake(): Boolean;
    procedure ShowSourceContext();
    procedure SendBreakpointsForFile(const ASourceFile: string);
    procedure LoadBreakpointsFromFile(const APath: string);

  public
    constructor Create(); override;
    destructor Destroy(); override;

    procedure Run(const AExePath: string; const APort: Integer = CDefaultDAPPort);
    procedure Stop();

    property TimeoutContinueMS: Integer read FTimeoutContinueMS write FTimeoutContinueMS;
    property TimeoutStepMS: Integer read FTimeoutStepMS write FTimeoutStepMS;
  end;

implementation



//==============================================================================
// TGnyNativeDebugREPL
//==============================================================================

constructor TGnyNativeDebugREPL.Create();
begin
  inherited Create();
  FServer := nil;
  FClient := nil;
  FServerThread := nil;
  FBreakpoints := TList<TREPLBreakpoint>.Create();
  FRunning := False;
  FExePath := '';
  FPort := CDefaultDAPPort;
  FPrompt := '(viper-dbg) ';
  FTimeoutContinueMS := CTimeoutContinueMS;
  FTimeoutStepMS := CTimeoutStepMS;
end;

destructor TGnyNativeDebugREPL.Destroy();
begin
  StopSession();
  FBreakpoints.Free();
  inherited Destroy();
end;

procedure TGnyNativeDebugREPL.StopSession();
begin
  if Assigned(FClient) then
  begin
    try
      FClient.DisconnectDAP();
    except
      // Ignore errors during shutdown
    end;
    FClient.Disconnect();
    FreeAndNil(FClient);
  end;

  if Assigned(FServer) then
  begin
    FServer.StopDebugging();
    FreeAndNil(FServer);
  end;

  if Assigned(FServerThread) then
  begin
    FServerThread.WaitFor();
    FreeAndNil(FServerThread);
  end;
end;

procedure TGnyNativeDebugREPL.StartSession();
var
  LExePath: string;
  LPort: Integer;
begin
  LExePath := FExePath;
  LPort := FPort;

  FServer := TGnyNativeDebugServer.Create();

  // Start server on background thread (DebugExe blocks on WaitForConnection)
  FServerThread := TThread.CreateAnonymousThread(
    procedure
    begin
      FServer.DebugExe(LExePath, LPort);
    end
  );
  FServerThread.FreeOnTerminate := False;
  FServerThread.Start();

  // Give server time to start listening
  Sleep(500);

  FClient := TGnyNativeDebugClient.Create();
end;

function TGnyNativeDebugREPL.DoDAHandshake(): Boolean;
begin
  Result := False;

  if not FClient.Connect('127.0.0.1', FPort) then
  begin
    TGnyUtils.PrintLn(COLOR_RED + 'Connect failed: ' + FClient.GetLastError() + COLOR_RESET);
    Exit;
  end;
  TGnyUtils.PrintLn('Connected to debug server on port %d', [FPort]);

  if not FClient.Initialize() then
  begin
    TGnyUtils.PrintLn(COLOR_RED + 'Initialize failed: ' + FClient.GetLastError() + COLOR_RESET);
    Exit;
  end;

  if not FClient.Launch(FExePath, False) then
  begin
    TGnyUtils.PrintLn(COLOR_RED + 'Launch failed: ' + FClient.GetLastError() + COLOR_RESET);
    Exit;
  end;

  TGnyUtils.PrintLn(COLOR_GREEN + 'DAP handshake complete' + COLOR_RESET);
  Result := True;
end;

procedure TGnyNativeDebugREPL.ShowSourceContext();
var
  LFrames: TArray<TDAPClientStackFrame>;
  LSourceFile: string;
  LSourceLine: Integer;
  LLines: TStringList;
  LStart: Integer;
  LEnd: Integer;
  LI: Integer;
  LArrow: string;
begin
  LFrames := FClient.GetCallStack();
  if Length(LFrames) = 0 then
    Exit;

  LSourceFile := LFrames[0].SourceFile;
  LSourceLine := LFrames[0].SourceLine;

  if (LSourceFile = '') or (LSourceLine <= 0) then
    Exit;

  // Try to read the source file from disk
  if not TFile.Exists(LSourceFile) then
  begin
    TGnyUtils.PrintLn('  Stopped at %s:%d (%s)',
      [ExtractFileName(LSourceFile), LSourceLine, LFrames[0].FunctionName]);
    Exit;
  end;

  LLines := TStringList.Create();
  try
    LLines.LoadFromFile(LSourceFile);

    LStart := LSourceLine - 3;
    if LStart < 0 then
      LStart := 0;
    LEnd := LSourceLine + 1;
    if LEnd >= LLines.Count then
      LEnd := LLines.Count - 1;

    TGnyUtils.PrintLn('');
    for LI := LStart to LEnd do
    begin
      // Lines in TStringList are 0-based; source lines are 1-based
      if (LI + 1) = LSourceLine then
        LArrow := COLOR_YELLOW + '>>'
      else
        LArrow := '  ';
      TGnyUtils.PrintLn('%s%4d: %s%s', [LArrow, LI + 1, LLines[LI], COLOR_RESET]);
    end;
    TGnyUtils.PrintLn('');
  finally
    LLines.Free();
  end;
end;

procedure TGnyNativeDebugREPL.SendBreakpointsForFile(const ASourceFile: string);
var
  LLines: TList<Integer>;
  LI: Integer;
  LBP: TREPLBreakpoint;
begin
  // Collect all lines for this file
  LLines := TList<Integer>.Create();
  try
    for LI := 0 to FBreakpoints.Count - 1 do
    begin
      LBP := FBreakpoints[LI];
      if SameText(LBP.SourceFile, ASourceFile) then
        LLines.Add(LBP.SourceLine);
    end;

    // Send to server (empty array clears breakpoints for that file)
    FClient.SetBreakpoints(ASourceFile, LLines.ToArray());
  finally
    LLines.Free();
  end;
end;

procedure TGnyNativeDebugREPL.LoadBreakpointsFromFile(const APath: string);
var
  LLines: TStringList;
  LLine: string;
  LColonPos: Integer;
  LBP: TREPLBreakpoint;
begin
  LLines := TStringList.Create();
  try
    LLines.LoadFromFile(APath);
    for LLine in LLines do
    begin
      LColonPos := Pos(':', Trim(LLine));
      if LColonPos > 1 then
      begin
        LBP.SourceFile := Copy(Trim(LLine), 1, LColonPos - 1);
        LBP.SourceLine := StrToIntDef(Copy(Trim(LLine), LColonPos + 1, MaxInt), -1);
        LBP.Verified := False;
        if (LBP.SourceFile <> '') and (LBP.SourceLine > 0) then
          FBreakpoints.Add(LBP);
      end;
    end;

    TGnyUtils.PrintLn('Loaded %d breakpoint(s) from %s',
      [FBreakpoints.Count, ExtractFileName(APath)]);
  finally
    LLines.Free();
  end;
end;

procedure TGnyNativeDebugREPL.Run(const AExePath: string; const APort: Integer);
var
  LCommand: string;
  LBreakpointFile: string;
  LFiles: TDictionary<string, Boolean>;
  LBP: TREPLBreakpoint;
  LKey: string;
begin
  FExePath := AExePath;
  FPort := APort;

  if not TFile.Exists(FExePath) then
  begin
    TGnyUtils.PrintLn(COLOR_RED + 'Executable not found: ' + FExePath + COLOR_RESET);
    Exit;
  end;

  TGnyUtils.PrintLn('');
  TGnyUtils.PrintLn(COLOR_CYAN + '=== Viper Debug REPL ===' + COLOR_RESET);
  TGnyUtils.PrintLn('Executable: %s', [FExePath]);
  TGnyUtils.PrintLn('');

  // Start server + client
  StartSession();

  // DAP handshake
  if not DoDAHandshake() then
  begin
    StopSession();
    Exit;
  end;

  // Set up callbacks
  FClient.OnStopped :=
    procedure(const AReason: string; const AThreadId: Integer)
    begin
      TGnyUtils.PrintLn('  [stopped] %s (thread %d)', [AReason, AThreadId]);
    end;
  FClient.OnExited :=
    procedure(const AExitCode: Integer)
    begin
      TGnyUtils.PrintLn('  [exited] code %d', [AExitCode]);
    end;
  FClient.OnOutput :=
    procedure(const AOutput: string)
    begin
      TGnyUtils.Print(AOutput);
    end;

  // Load breakpoints from sidecar file if it exists
  LBreakpointFile := TPath.ChangeExtension(FExePath, '.breakpoints');
  if TFile.Exists(LBreakpointFile) then
    LoadBreakpointsFromFile(LBreakpointFile);

  // Send all breakpoints to server (grouped by file)
  if FBreakpoints.Count > 0 then
  begin
    LFiles := TDictionary<string, Boolean>.Create();
    try
      for LBP in FBreakpoints do
        LFiles.AddOrSetValue(LBP.SourceFile, True);
      for LKey in LFiles.Keys do
        SendBreakpointsForFile(LKey);
    finally
      LFiles.Free();
    end;
  end;

  // Start execution
  if not FClient.ConfigurationDone() then
  begin
    TGnyUtils.PrintLn(COLOR_RED + 'ConfigurationDone failed: ' +
      FClient.GetLastError() + COLOR_RESET);
    StopSession();
    Exit;
  end;

  TGnyUtils.PrintLn(COLOR_GREEN + 'Running...' + COLOR_RESET);

  // Wait for first stop (breakpoint or exit)
  FClient.ProcessPendingEvents(FTimeoutContinueMS);

  if FClient.State = dcsStopped then
  begin
    ShowSourceContext();
    TGnyUtils.PrintLn(COLOR_CYAN + '=== INTERACTIVE REPL ===' + COLOR_RESET);
    ShowHelp();
    TGnyUtils.PrintLn('');
  end
  else if FClient.State = dcsExited then
  begin
    TGnyUtils.PrintLn(COLOR_YELLOW + 'Program exited without stopping.' + COLOR_RESET);
    StopSession();
    Exit;
  end;

  // Main REPL loop
  FRunning := True;
  while FRunning do
  begin
    Write(FPrompt);
    ReadLn(LCommand);
    LCommand := Trim(LCommand);
    ProcessCommand(LCommand);
  end;

  TGnyUtils.PrintLn('');
  TGnyUtils.PrintLn(COLOR_GREEN + 'REPL session complete.' + COLOR_RESET);
  StopSession();
end;

procedure TGnyNativeDebugREPL.Stop();
begin
  FRunning := False;
end;

//------------------------------------------------------------------------------
// ProcessCommand — dispatch user input to handlers
//------------------------------------------------------------------------------

procedure TGnyNativeDebugREPL.ProcessCommand(const ACommand: string);
begin
  if ACommand = '' then
    Exit;

  if ACommand = 'quit' then
    FRunning := False
  else if (ACommand = 'h') or (ACommand = 'help') then
    ShowHelp()
  else if ACommand.StartsWith('b ') then
    HandleSetBreakpoint(ACommand)
  else if ACommand = 'bl' then
    HandleListBreakpoints()
  else if ACommand.StartsWith('bd ') then
    HandleDeleteBreakpoint(ACommand)
  else if ACommand = 'bc' then
    HandleClearBreakpoints()
  else if ACommand = 'bt' then
    HandleBacktrace()
  else if ACommand = 'locals' then
    HandleLocals()
  else if ACommand.StartsWith('p ') then
    HandlePrint(ACommand)
  else if ACommand = 'c' then
    HandleContinue()
  else if ACommand = 'n' then
    HandleNext()
  else if ACommand = 's' then
    HandleStepInto()
  else if ACommand = 'finish' then
    HandleStepOut()
  else if ACommand = 'r' then
    HandleRestart()
  else if ACommand.StartsWith('file ') then
    HandleFile(ACommand)
  else if ACommand.StartsWith('verbose ') then
    HandleVerbose(ACommand)
  else if ACommand = 'threads' then
    HandleThreads()
  else if ACommand = 'src' then
    ShowSourceContext()
  else
    TGnyUtils.PrintLn(COLOR_RED + 'Unknown command: ' + ACommand + COLOR_RESET);
end;

//------------------------------------------------------------------------------
// ShowHelp
//------------------------------------------------------------------------------

procedure TGnyNativeDebugREPL.ShowHelp();
begin
  TGnyUtils.PrintLn('Commands:');
  TGnyUtils.PrintLn('  ' + COLOR_CYAN + 'h, help' + COLOR_RESET + '         - Show this help');
  TGnyUtils.PrintLn('  ' + COLOR_CYAN + 'b <file>:<line>' + COLOR_RESET + ' - Set breakpoint');
  TGnyUtils.PrintLn('  ' + COLOR_CYAN + 'bl' + COLOR_RESET + '              - List breakpoints');
  TGnyUtils.PrintLn('  ' + COLOR_CYAN + 'bd <id>' + COLOR_RESET + '         - Delete breakpoint by ID');
  TGnyUtils.PrintLn('  ' + COLOR_CYAN + 'bc' + COLOR_RESET + '              - Clear all breakpoints');
  TGnyUtils.PrintLn('  ' + COLOR_CYAN + 'bt' + COLOR_RESET + '              - Show call stack (backtrace)');
  TGnyUtils.PrintLn('  ' + COLOR_CYAN + 'locals' + COLOR_RESET + '          - Show local variables');
  TGnyUtils.PrintLn('  ' + COLOR_CYAN + 'p <expr>' + COLOR_RESET + '        - Print/evaluate expression');
  TGnyUtils.PrintLn('  ' + COLOR_CYAN + 'c' + COLOR_RESET + '               - Continue execution');
  TGnyUtils.PrintLn('  ' + COLOR_CYAN + 'n' + COLOR_RESET + '               - Next (step over)');
  TGnyUtils.PrintLn('  ' + COLOR_CYAN + 's' + COLOR_RESET + '               - Step into');
  TGnyUtils.PrintLn('  ' + COLOR_CYAN + 'finish' + COLOR_RESET + '          - Step out');
  TGnyUtils.PrintLn('  ' + COLOR_CYAN + 'r' + COLOR_RESET + '               - Restart program');
  TGnyUtils.PrintLn('  ' + COLOR_CYAN + 'file <path>' + COLOR_RESET + '     - Load different executable');
  TGnyUtils.PrintLn('  ' + COLOR_CYAN + 'src' + COLOR_RESET + '             - Show source context');
  TGnyUtils.PrintLn('  ' + COLOR_CYAN + 'threads' + COLOR_RESET + '         - Show threads');
  TGnyUtils.PrintLn('  ' + COLOR_CYAN + 'verbose on/off' + COLOR_RESET + '  - Toggle DAP message logging');
  TGnyUtils.PrintLn('  ' + COLOR_CYAN + 'quit' + COLOR_RESET + '            - Exit REPL');
end;

//------------------------------------------------------------------------------
// Breakpoint handlers
//------------------------------------------------------------------------------

procedure TGnyNativeDebugREPL.HandleSetBreakpoint(const ACommand: string);
var
  LColonPos: Integer;
  LFile: string;
  LLine: Integer;
  LBP: TREPLBreakpoint;
begin
  // Format: b <file>:<line>
  LColonPos := Pos(':', ACommand);
  if LColonPos > 3 then
  begin
    LFile := Trim(Copy(ACommand, 3, LColonPos - 3));
    LLine := StrToIntDef(Trim(Copy(ACommand, LColonPos + 1, MaxInt)), -1);

    if (LFile <> '') and (LLine > 0) then
    begin
      LBP.SourceFile := LFile;
      LBP.SourceLine := LLine;
      LBP.Verified := False;
      FBreakpoints.Add(LBP);
      SendBreakpointsForFile(LFile);
      TGnyUtils.PrintLn(COLOR_GREEN + 'Breakpoint set at %s:%d' + COLOR_RESET,
        [LFile, LLine]);
    end
    else
      TGnyUtils.PrintLn(COLOR_RED + 'Invalid format. Use: b <file>:<line>' + COLOR_RESET);
  end
  else
    TGnyUtils.PrintLn(COLOR_RED + 'Invalid format. Use: b <file>:<line>' + COLOR_RESET);
end;

procedure TGnyNativeDebugREPL.HandleListBreakpoints();
var
  LI: Integer;
  LBP: TREPLBreakpoint;
begin
  if FBreakpoints.Count = 0 then
  begin
    TGnyUtils.PrintLn('No breakpoints set');
    Exit;
  end;

  TGnyUtils.PrintLn('Breakpoints (%d):', [FBreakpoints.Count]);
  for LI := 0 to FBreakpoints.Count - 1 do
  begin
    LBP := FBreakpoints[LI];
    TGnyUtils.PrintLn('  #%d: %s:%d', [LI + 1, LBP.SourceFile, LBP.SourceLine]);
  end;
end;

procedure TGnyNativeDebugREPL.HandleDeleteBreakpoint(const ACommand: string);
var
  LIndex: Integer;
  LBP: TREPLBreakpoint;
  LFile: string;
begin
  // Format: bd <id> (1-based)
  LIndex := StrToIntDef(Trim(Copy(ACommand, 4, MaxInt)), -1);
  if (LIndex < 1) or (LIndex > FBreakpoints.Count) then
  begin
    TGnyUtils.PrintLn(COLOR_RED + 'Invalid breakpoint ID' + COLOR_RESET);
    Exit;
  end;

  LBP := FBreakpoints[LIndex - 1];
  LFile := LBP.SourceFile;
  FBreakpoints.Delete(LIndex - 1);

  // Re-send remaining breakpoints for that file
  SendBreakpointsForFile(LFile);
  TGnyUtils.PrintLn(COLOR_GREEN + 'Breakpoint #%d deleted' + COLOR_RESET, [LIndex]);
end;

procedure TGnyNativeDebugREPL.HandleClearBreakpoints();
var
  LFiles: TDictionary<string, Boolean>;
  LBP: TREPLBreakpoint;
  LKey: string;
begin
  // Collect unique files before clearing
  LFiles := TDictionary<string, Boolean>.Create();
  try
    for LBP in FBreakpoints do
      LFiles.AddOrSetValue(LBP.SourceFile, True);

    FBreakpoints.Clear();

    // Send empty breakpoint sets for each file
    for LKey in LFiles.Keys do
      FClient.SetBreakpoints(LKey, []);
  finally
    LFiles.Free();
  end;

  TGnyUtils.PrintLn(COLOR_GREEN + 'All breakpoints cleared' + COLOR_RESET);
end;

//------------------------------------------------------------------------------
// Inspection handlers
//------------------------------------------------------------------------------

procedure TGnyNativeDebugREPL.HandleBacktrace();
var
  LFrames: TArray<TDAPClientStackFrame>;
  LI: Integer;
begin
  if FClient.State <> dcsStopped then
  begin
    TGnyUtils.PrintLn(COLOR_RED + 'Not stopped' + COLOR_RESET);
    Exit;
  end;

  LFrames := FClient.GetCallStack();
  if Length(LFrames) = 0 then
  begin
    TGnyUtils.PrintLn('No stack frames');
    Exit;
  end;

  TGnyUtils.PrintLn('Call stack (%d frames):', [Length(LFrames)]);
  for LI := 0 to High(LFrames) do
    TGnyUtils.PrintLn('  #%d: %s at %s:%d',
      [LI, LFrames[LI].FunctionName, LFrames[LI].SourceFile, LFrames[LI].SourceLine]);
end;

procedure TGnyNativeDebugREPL.HandleLocals();
var
  LFrames: TArray<TDAPClientStackFrame>;
  LScopes: TArray<TDAPClientScope>;
  LVars: TArray<TDAPClientVariable>;
  LI: Integer;
  LJ: Integer;
begin
  if FClient.State <> dcsStopped then
  begin
    TGnyUtils.PrintLn(COLOR_RED + 'Not stopped' + COLOR_RESET);
    Exit;
  end;

  LFrames := FClient.GetCallStack();
  if Length(LFrames) = 0 then
  begin
    TGnyUtils.PrintLn(COLOR_RED + 'No stack frames' + COLOR_RESET);
    Exit;
  end;

  // Get scopes for top frame
  LScopes := FClient.GetScopes(LFrames[0].FrameID);
  if Length(LScopes) = 0 then
  begin
    TGnyUtils.PrintLn('No scopes available');
    Exit;
  end;

  // Get variables for each scope
  for LI := 0 to High(LScopes) do
  begin
    TGnyUtils.PrintLn('%s:', [LScopes[LI].ScopeName]);
    LVars := FClient.GetVariables(LScopes[LI].VariablesReference);
    if Length(LVars) = 0 then
      TGnyUtils.PrintLn('  (none)')
    else
    begin
      for LJ := 0 to High(LVars) do
      begin
        if LVars[LJ].VarType <> '' then
          TGnyUtils.PrintLn('  %s (%s) = %s',
            [LVars[LJ].VarName, LVars[LJ].VarType, LVars[LJ].VarValue])
        else
          TGnyUtils.PrintLn('  %s = %s',
            [LVars[LJ].VarName, LVars[LJ].VarValue]);
      end;
    end;
  end;
end;

procedure TGnyNativeDebugREPL.HandlePrint(const ACommand: string);
var
  LExpr: string;
  LResult: string;
begin
  // Extract expression after 'p '
  LExpr := Trim(Copy(ACommand, 3, MaxInt));
  if LExpr = '' then
  begin
    TGnyUtils.PrintLn(COLOR_YELLOW + 'Usage: p <variable>' + COLOR_RESET);
    Exit;
  end;

  if FClient.State <> dcsStopped then
  begin
    TGnyUtils.PrintLn(COLOR_RED + 'Not stopped' + COLOR_RESET);
    Exit;
  end;

  LResult := FClient.Evaluate(LExpr);
  if LResult <> '' then
    TGnyUtils.PrintLn('%s = %s', [LExpr, LResult])
  else
  begin
    if FClient.HasError() then
      TGnyUtils.PrintLn(COLOR_RED + '%s' + COLOR_RESET, [FClient.GetLastError()])
    else
      TGnyUtils.PrintLn(COLOR_YELLOW + 'Variable ''%s'' not found' + COLOR_RESET, [LExpr]);
  end;
end;

//------------------------------------------------------------------------------
// Execution control handlers
//------------------------------------------------------------------------------

procedure TGnyNativeDebugREPL.HandleContinue();
begin
  if FClient.State <> dcsStopped then
  begin
    TGnyUtils.PrintLn(COLOR_RED + 'Not stopped' + COLOR_RESET);
    Exit;
  end;

  TGnyUtils.PrintLn('Continuing...');
  if FClient.Continue() then
  begin
    FClient.ProcessPendingEvents(FTimeoutContinueMS);
    if FClient.State = dcsStopped then
    begin
      TGnyUtils.PrintLn(COLOR_GREEN + 'Stopped' + COLOR_RESET);
      ShowSourceContext();
    end
    else if FClient.State = dcsExited then
      TGnyUtils.PrintLn(COLOR_YELLOW + 'Program exited' + COLOR_RESET);
  end
  else
    TGnyUtils.PrintLn(COLOR_RED + 'Continue failed: ' + FClient.GetLastError() + COLOR_RESET);
end;

procedure TGnyNativeDebugREPL.HandleNext();
begin
  if FClient.State <> dcsStopped then
  begin
    TGnyUtils.PrintLn(COLOR_RED + 'Not stopped' + COLOR_RESET);
    Exit;
  end;

  TGnyUtils.PrintLn('Stepping over...');
  if FClient.StepOver() then
  begin
    FClient.ProcessPendingEvents(FTimeoutStepMS);
    if FClient.State = dcsStopped then
      ShowSourceContext()
    else if FClient.State = dcsExited then
      TGnyUtils.PrintLn(COLOR_YELLOW + 'Program exited' + COLOR_RESET);
  end
  else
    TGnyUtils.PrintLn(COLOR_RED + 'Step failed: ' + FClient.GetLastError() + COLOR_RESET);
end;

procedure TGnyNativeDebugREPL.HandleStepInto();
begin
  if FClient.State <> dcsStopped then
  begin
    TGnyUtils.PrintLn(COLOR_RED + 'Not stopped' + COLOR_RESET);
    Exit;
  end;

  TGnyUtils.PrintLn('Stepping into...');
  if FClient.StepIn() then
  begin
    FClient.ProcessPendingEvents(FTimeoutStepMS);
    if FClient.State = dcsStopped then
      ShowSourceContext()
    else if FClient.State = dcsExited then
      TGnyUtils.PrintLn(COLOR_YELLOW + 'Program exited' + COLOR_RESET);
  end
  else
    TGnyUtils.PrintLn(COLOR_RED + 'Step failed: ' + FClient.GetLastError() + COLOR_RESET);
end;

procedure TGnyNativeDebugREPL.HandleStepOut();
begin
  if FClient.State <> dcsStopped then
  begin
    TGnyUtils.PrintLn(COLOR_RED + 'Not stopped' + COLOR_RESET);
    Exit;
  end;

  TGnyUtils.PrintLn('Stepping out...');
  if FClient.StepOut() then
  begin
    FClient.ProcessPendingEvents(FTimeoutStepMS);
    if FClient.State = dcsStopped then
      ShowSourceContext()
    else if FClient.State = dcsExited then
      TGnyUtils.PrintLn(COLOR_YELLOW + 'Program exited' + COLOR_RESET);
  end
  else
    TGnyUtils.PrintLn(COLOR_RED + 'Step failed: ' + FClient.GetLastError() + COLOR_RESET);
end;

//------------------------------------------------------------------------------
// Restart, File, Verbose, Threads
//------------------------------------------------------------------------------

procedure TGnyNativeDebugREPL.HandleRestart();
var
  LSavedBreakpoints: TList<TREPLBreakpoint>;
  LBP: TREPLBreakpoint;
  LFiles: TDictionary<string, Boolean>;
  LKey: string;
begin
  TGnyUtils.PrintLn('Restarting program...');

  // Save breakpoints before teardown
  LSavedBreakpoints := TList<TREPLBreakpoint>.Create();
  try
    for LBP in FBreakpoints do
      LSavedBreakpoints.Add(LBP);

    // Full teardown
    StopSession();

    // Restore breakpoints
    FBreakpoints.Clear();
    for LBP in LSavedBreakpoints do
      FBreakpoints.Add(LBP);
  finally
    LSavedBreakpoints.Free();
  end;

  // Re-create server + client
  StartSession();

  // Re-do DAP handshake
  if not DoDAHandshake() then
  begin
    TGnyUtils.PrintLn(COLOR_RED + 'Restart failed during handshake' + COLOR_RESET);
    StopSession();
    Exit;
  end;

  // Re-set callbacks
  FClient.OnStopped :=
    procedure(const AReason: string; const AThreadId: Integer)
    begin
      TGnyUtils.PrintLn('  [stopped] %s (thread %d)', [AReason, AThreadId]);
    end;
  FClient.OnExited :=
    procedure(const AExitCode: Integer)
    begin
      TGnyUtils.PrintLn('  [exited] code %d', [AExitCode]);
    end;
  FClient.OnOutput :=
    procedure(const AOutput: string)
    begin
      TGnyUtils.Print(AOutput);
    end;

  // Re-send all breakpoints (grouped by file)
  if FBreakpoints.Count > 0 then
  begin
    LFiles := TDictionary<string, Boolean>.Create();
    try
      for LBP in FBreakpoints do
        LFiles.AddOrSetValue(LBP.SourceFile, True);
      for LKey in LFiles.Keys do
        SendBreakpointsForFile(LKey);
    finally
      LFiles.Free();
    end;
    TGnyUtils.PrintLn('Restored %d breakpoint(s)', [FBreakpoints.Count]);
  end;

  // Start execution
  if not FClient.ConfigurationDone() then
  begin
    TGnyUtils.PrintLn(COLOR_RED + 'ConfigurationDone failed: ' +
      FClient.GetLastError() + COLOR_RESET);
    Exit;
  end;

  TGnyUtils.PrintLn(COLOR_GREEN + 'Program restarted!' + COLOR_RESET);

  // Wait for first stop
  FClient.ProcessPendingEvents(FTimeoutContinueMS);

  if FClient.State = dcsStopped then
    ShowSourceContext()
  else if FClient.State = dcsExited then
    TGnyUtils.PrintLn(COLOR_YELLOW + 'Program exited' + COLOR_RESET);
end;

procedure TGnyNativeDebugREPL.HandleFile(const ACommand: string);
var
  LPath: string;
begin
  LPath := Trim(Copy(ACommand, 6, MaxInt));

  if not TFile.Exists(LPath) then
  begin
    TGnyUtils.PrintLn(COLOR_RED + 'File not found: ' + LPath + COLOR_RESET);
    Exit;
  end;

  FExePath := LPath;
  FBreakpoints.Clear();
  TGnyUtils.PrintLn(COLOR_GREEN + 'Loaded: ' + FExePath + COLOR_RESET);
  TGnyUtils.PrintLn('Breakpoints cleared. Use ''r'' to run.');
end;

procedure TGnyNativeDebugREPL.HandleVerbose(const ACommand: string);
begin
  if ACommand = 'verbose on' then
  begin
    FClient.VerboseLogging := True;
    TGnyUtils.PrintLn(COLOR_GREEN + 'Verbose logging enabled' + COLOR_RESET);
  end
  else if ACommand = 'verbose off' then
  begin
    FClient.VerboseLogging := False;
    TGnyUtils.PrintLn(COLOR_GREEN + 'Verbose logging disabled' + COLOR_RESET);
  end
  else
    TGnyUtils.PrintLn(COLOR_RED + 'Usage: verbose on|off' + COLOR_RESET);
end;

procedure TGnyNativeDebugREPL.HandleThreads();
begin
  // Viper is single-threaded — hardcode response
  TGnyUtils.PrintLn('Threads (1):');
  TGnyUtils.PrintLn('  Thread 1: main');
end;

end.
