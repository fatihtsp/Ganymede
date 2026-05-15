{===============================================================================
  Ganymede™ - Embeddable Native Scripting Engine

  Copyright © 2026-present tinyBigGAMES™ LLC
  All Rights Reserved.

  See LICENSE for license information
===============================================================================}

unit Ganymede.Debug.Server;

{$I Ganymede.Defines.inc}

interface

uses
  WinApi.Windows,
  System.SysUtils,
  System.Classes,
  System.Generics.Collections,
  Ganymede.Utils,
  Ganymede.IR,
  Ganymede.JIT,
  Ganymede.Debug.SourceMap,
  Ganymede.Debug.Target,
  Ganymede.Debug.Runtime,
  Ganymede.Debug.DAP;

type
  //============================================================================
  // TDebugMode - Which output mode we're debugging
  //============================================================================
  TDebugMode = (
    dmJIT,     // In-process JIT debugging
    dmExe,     // Out-of-process EXE debugging (Phase 2)
    dmDll      // Out-of-process DLL debugging (Phase 2)
  );

  TGnyNativeDebugServer = class;

  //============================================================================
  // TDAPListenerThread - Runs the DAP message loop on a background thread
  //============================================================================

  { TDAPListenerThread }
  TDAPListenerThread = class(TThread)
  private
    FServer: TDAPServer;
  protected
    procedure Execute(); override;
  public
    constructor Create(const AServer: TDAPServer);
  end;

  //============================================================================
  // TStopWatcherThread - Waits for debug stops and notifies DAP server
  //============================================================================

  { TStopWatcherThread }
  TStopWatcherThread = class(TThread)
  private
    FDebugger: TGnyNativeDebugServer;
  protected
    procedure Execute(); override;
  public
    constructor Create(const ADebugger: TGnyNativeDebugServer);
  end;

  //============================================================================
  // TGnyNativeDebugServer - Public API for the Viper debugger.
  // Owns TErrors, creates and wires all debug components.
  // Entry points for JIT, EXE, and DLL debugging.
  //============================================================================

  { TGnyNativeDebugServer }
  TGnyNativeDebugServer = class(TGnyBaseObject)
  private
    FSourceMap: TSourceMap;
    FTarget: TDebugTarget;
    FRuntime: TDebugRuntime;
    FDAPServer: TDAPServer;
    FDAPThread: TDAPListenerThread;
    FStopWatcher: TStopWatcherThread;
    FPort: Integer;
    FMode: TDebugMode;
    FOwnSourceMap: Boolean;  // True when we created FSourceMap (EXE/DLL mode)

  public
    constructor Create(); override;
    destructor Destroy(); override;

    // JIT debugging: pass a JIT instance with compiled code + source map
    function DebugJIT(const AJIT: TJIT; const ASourceMap: TSourceMap;
      const APort: Integer = 4711): Boolean;

    // EXE debugging: pass EXE path, loads .vdbg sidecar automatically
    function DebugExe(const AExePath: string;
      const APort: Integer = 4711): Boolean;

    // DLL debugging (Phase 3 stub)
    function DebugDll(const ADllPath: string; const AHostExe: string = '';
      const APort: Integer = 4711): Boolean;

    // Shutdown
    procedure StopDebugging();

    // Error reporting — delegates to FErrors (same pattern as TGnyNative)
    function HasErrors(): Boolean;
    function HasWarnings(): Boolean;
    function HasHints(): Boolean;
    function HasFatal(): Boolean;
    function ErrorCount(): Integer;
    function WarningCount(): Integer;
    function GetErrorItems(): TList<TGnyError>;
    function GetErrorText(): string;

    // Access to internals (for advanced use)
    function GetRuntime(): TDebugRuntime;
    function GetDAPServer(): TDAPServer;
    function GetSourceMap(): TSourceMap;

    // Properties
    property Port: Integer read FPort;
    property Mode: TDebugMode read FMode;
  end;

implementation

//==============================================================================
// TDAPListenerThread
//==============================================================================

constructor TDAPListenerThread.Create(const AServer: TDAPServer);
begin
  inherited Create(True);  // Create suspended
  FreeOnTerminate := False;
  FServer := AServer;
end;

procedure TDAPListenerThread.Execute();
begin
  FServer.RunMessageLoop();
end;

//==============================================================================
// TStopWatcherThread — waits for runtime stops, notifies DAP
//==============================================================================

constructor TStopWatcherThread.Create(const ADebugger: TGnyNativeDebugServer);
begin
  inherited Create(True);
  FreeOnTerminate := False;
  FDebugger := ADebugger;
end;

procedure TStopWatcherThread.Execute();
begin
  while not Terminated do
  begin
    // Block until the debug runtime reports a stop
    if FDebugger.FRuntime.WaitForStop() then
    begin
      if Terminated then
        Break;
      // Notify the DAP server about the stop
      FDebugger.FDAPServer.ProcessStopEvent();
    end
    else
      Break;  // WaitForStop failed — target gone
  end;
end;

//==============================================================================
// TGnyNativeDebugger
//==============================================================================

constructor TGnyNativeDebugServer.Create();
begin
  inherited Create();
  FSourceMap := nil;
  FTarget := nil;
  FRuntime := nil;
  FDAPServer := nil;
  FDAPThread := nil;
  FStopWatcher := nil;
  FPort := 0;
  FMode := dmJIT;
  FOwnSourceMap := False;
end;

destructor TGnyNativeDebugServer.Destroy();
begin
  StopDebugging();
  inherited Destroy();
end;

//------------------------------------------------------------------------------
// DebugJIT — JIT mode entry point
//------------------------------------------------------------------------------

function TGnyNativeDebugServer.DebugJIT(const AJIT: TJIT;
  const ASourceMap: TSourceMap; const APort: Integer): Boolean;
var
  LJITTarget: TJITDebugTarget;
begin
  Result := False;
  FPort := APort;
  FMode := dmJIT;
  FSourceMap := ASourceMap;

  // Create JIT debug target
  LJITTarget := TJITDebugTarget.Create();
  LJITTarget.SetErrors(FErrors);
  LJITTarget.SetJIT(AJIT);
  FTarget := LJITTarget;

  // Create debug runtime (breakpoints, stepping, stack walker)
  FRuntime := TDebugRuntime.Create();
  FRuntime.SetErrors(FErrors);
  FRuntime.SetTarget(FTarget);
  FRuntime.SetSourceMap(FSourceMap);

  // Create DAP server
  FDAPServer := TDAPServer.Create();
  FDAPServer.SetErrors(FErrors);
  FDAPServer.SetRuntime(FRuntime);
  FDAPServer.SetSourceMap(FSourceMap);

  // Start TCP listener
  if not FDAPServer.StartListening(APort) then
  begin
    FErrors.Add(esFatal, 'DBG100',
      'Failed to start DAP server on port %d', [APort]);
    Exit;
  end;

  Status('DAP server listening on port %d — attach your debugger', [APort]);

  // Wait for client connection (blocking)
  if not FDAPServer.WaitForConnection() then
  begin
    FErrors.Add(esFatal, 'DBG101', 'No client connected');
    Exit;
  end;

  Status('Debugger client connected');

  // Start the JIT debug target (registers VEH handler)
  if not FTarget.Start() then
  begin
    FErrors.Add(esFatal, 'DBG102', 'Failed to start debug target');
    Exit;
  end;

  // Start DAP message loop on background thread
  FDAPThread := TDAPListenerThread.Create(FDAPServer);
  FDAPThread.Start();

  // Start stop watcher thread (bridges runtime stops → DAP events)
  FStopWatcher := TStopWatcherThread.Create(Self);
  FStopWatcher.Start();

  Status('Debug session active — waiting for configurationDone');
  Result := True;
end;

//------------------------------------------------------------------------------
// DebugExe — PE mode entry point
//------------------------------------------------------------------------------

function TGnyNativeDebugServer.DebugExe(const AExePath: string;
  const APort: Integer): Boolean;
var
  LPETarget: TPEDebugTarget;
  LVdbgPath: string;
begin
  Result := False;
  FPort := APort;
  FMode := dmExe;

  // Validate EXE exists
  if not FileExists(AExePath) then
  begin
    FErrors.Add(esError, 'DBG200', 'EXE not found: %s', [AExePath]);
    Exit;
  end;

  // Load .vdbg debug info sidecar file
  LVdbgPath := ChangeFileExt(AExePath, '.vdbg');
  if not FileExists(LVdbgPath) then
  begin
    FErrors.Add(esError, 'DBG202',
      'Debug info file not found: %s — rebuild with debug mode enabled',
      [LVdbgPath]);
    Exit;
  end;

  FSourceMap := TSourceMap.Create();
  FOwnSourceMap := True;
  try
    FSourceMap.LoadFromFile(LVdbgPath);
  except
    on E: Exception do
    begin
      FErrors.Add(esError, 'DBG203',
        'Failed to load debug info: %s', [E.Message]);
      FreeAndNil(FSourceMap);
      FOwnSourceMap := False;
      Exit;
    end;
  end;

  // Create PE debug target
  LPETarget := TPEDebugTarget.Create();
  LPETarget.SetErrors(FErrors);
  LPETarget.SetExePath(AExePath);
  LPETarget.SetTextSectionRVA(FSourceMap.GetTextSectionRVA());
  FTarget := LPETarget;

  // Create debug runtime (breakpoints, stepping, stack walker)
  FRuntime := TDebugRuntime.Create();
  FRuntime.SetErrors(FErrors);
  FRuntime.SetTarget(FTarget);
  FRuntime.SetSourceMap(FSourceMap);

  // Create DAP server
  FDAPServer := TDAPServer.Create();
  FDAPServer.SetErrors(FErrors);
  FDAPServer.SetRuntime(FRuntime);
  FDAPServer.SetSourceMap(FSourceMap);

  // Start TCP listener
  if not FDAPServer.StartListening(APort) then
  begin
    FErrors.Add(esFatal, 'DBG100',
      'Failed to start DAP server on port %d', [APort]);
    Exit;
  end;

  Status('DAP server listening on port %d — attach your debugger', [APort]);

  // Wait for client connection (blocking)
  if not FDAPServer.WaitForConnection() then
  begin
    FErrors.Add(esFatal, 'DBG101', 'No client connected');
    Exit;
  end;

  Status('Debugger client connected');

  // Start the PE debug target (launches the process with DEBUG_ONLY_THIS_PROCESS)
  if not FTarget.Start() then
  begin
    FErrors.Add(esFatal, 'DBG102', 'Failed to start debug target');
    Exit;
  end;

  Status('Debuggee launched: %s', [AExePath]);

  // Start DAP message loop on background thread
  FDAPThread := TDAPListenerThread.Create(FDAPServer);
  FDAPThread.Start();

  // Start stop watcher thread (bridges runtime stops → DAP events)
  FStopWatcher := TStopWatcherThread.Create(Self);
  FStopWatcher.Start();

  Status('Debug session active — waiting for configurationDone');
  Result := True;
end;

function TGnyNativeDebugServer.DebugDll(const ADllPath: string;
  const AHostExe: string; const APort: Integer): Boolean;
var
  LPETarget: TPEDebugTarget;
  LVdbgPath: string;
begin
  Result := False;
  FPort := APort;
  FMode := dmDll;

  // Validate DLL exists
  if not FileExists(ADllPath) then
  begin
    FErrors.Add(esError, 'DBG200', 'DLL not found: %s', [ADllPath]);
    Exit;
  end;

  // Validate host EXE is provided and exists
  if AHostExe = '' then
  begin
    FErrors.Add(esError, 'DBG204',
      'Host EXE required for DLL debugging — specify a host application that loads the DLL');
    Exit;
  end;

  if not FileExists(AHostExe) then
  begin
    FErrors.Add(esError, 'DBG205', 'Host EXE not found: %s', [AHostExe]);
    Exit;
  end;

  // Load .vdbg debug info sidecar file for the DLL
  LVdbgPath := ChangeFileExt(ADllPath, '.vdbg');
  if not FileExists(LVdbgPath) then
  begin
    FErrors.Add(esError, 'DBG202',
      'Debug info file not found: %s — rebuild with debug mode enabled',
      [LVdbgPath]);
    Exit;
  end;

  FSourceMap := TSourceMap.Create();
  FOwnSourceMap := True;
  try
    FSourceMap.LoadFromFile(LVdbgPath);
  except
    on E: Exception do
    begin
      FErrors.Add(esError, 'DBG203',
        'Failed to load debug info: %s', [E.Message]);
      FreeAndNil(FSourceMap);
      FOwnSourceMap := False;
      Exit;
    end;
  end;

  // Create PE debug target in DLL mode
  LPETarget := TPEDebugTarget.Create();
  LPETarget.SetErrors(FErrors);
  LPETarget.SetTextSectionRVA(FSourceMap.GetTextSectionRVA());
  LPETarget.SetDllMode(ADllPath, AHostExe);
  FTarget := LPETarget;

  // Create debug runtime (breakpoints, stepping, stack walker)
  FRuntime := TDebugRuntime.Create();
  FRuntime.SetErrors(FErrors);
  FRuntime.SetTarget(FTarget);
  FRuntime.SetSourceMap(FSourceMap);

  // Create DAP server
  FDAPServer := TDAPServer.Create();
  FDAPServer.SetErrors(FErrors);
  FDAPServer.SetRuntime(FRuntime);
  FDAPServer.SetSourceMap(FSourceMap);

  // Start TCP listener
  if not FDAPServer.StartListening(APort) then
  begin
    FErrors.Add(esFatal, 'DBG100',
      'Failed to start DAP server on port %d', [APort]);
    Exit;
  end;

  Status('DAP server listening on port %d — attach your debugger', [APort]);

  // Wait for client connection (blocking)
  if not FDAPServer.WaitForConnection() then
  begin
    FErrors.Add(esFatal, 'DBG101', 'No client connected');
    Exit;
  end;

  Status('Debugger client connected');

  // Start the PE debug target (launches the host EXE with DEBUG_ONLY_THIS_PROCESS)
  if not FTarget.Start() then
  begin
    FErrors.Add(esFatal, 'DBG102', 'Failed to start debug target');
    Exit;
  end;

  Status('Host launched: %s — waiting for DLL: %s',
    [AHostExe, ExtractFileName(ADllPath)]);

  // Start DAP message loop on background thread
  FDAPThread := TDAPListenerThread.Create(FDAPServer);
  FDAPThread.Start();

  // Start stop watcher thread (bridges runtime stops → DAP events)
  // The runtime handles dsrDllLoad internally (applies breakpoints + resumes)
  FStopWatcher := TStopWatcherThread.Create(Self);
  FStopWatcher.Start();

  Status('Debug session active — waiting for configurationDone');
  Result := True;
end;

//------------------------------------------------------------------------------
// Shutdown
//------------------------------------------------------------------------------

procedure TGnyNativeDebugServer.StopDebugging();
begin
  // Stop watcher thread first (it reads from runtime)
  if FStopWatcher <> nil then
  begin
    FStopWatcher.Terminate();
    // Signal FStoppedEvent so WaitForStop unblocks (not FResumeEvent!)
    if FTarget <> nil then
      FTarget.UnblockWaitForStop();
    FStopWatcher.WaitFor();
    FreeAndNil(FStopWatcher);
  end;

  // Close sockets first — this causes recv() in the DAP thread to return -1,
  // which makes ReadMessage return nil, which exits RunMessageLoop
  if FDAPServer <> nil then
    FDAPServer.StopServer();

  // Now the DAP thread can be safely joined
  if FDAPThread <> nil then
  begin
    FDAPThread.Terminate();
    FDAPThread.WaitFor();
    FreeAndNil(FDAPThread);
  end;

  // Free the DAP server object (sockets already closed above)
  FreeAndNil(FDAPServer);

  // Stop runtime (removes breakpoints)
  FreeAndNil(FRuntime);

  // Stop target (unregisters VEH / terminates process)
  if FTarget <> nil then
  begin
    FTarget.Stop();
    FreeAndNil(FTarget);
  end;

  // Free source map if we created it (EXE/DLL mode)
  if FOwnSourceMap then
  begin
    FreeAndNil(FSourceMap);
    FOwnSourceMap := False;
  end
  else
    FSourceMap := nil;  // JIT mode — not owned by us
end;

//------------------------------------------------------------------------------
// Error Reporting — delegates to FErrors
//------------------------------------------------------------------------------

function TGnyNativeDebugServer.HasErrors(): Boolean;
begin
  Result := FErrors.HasErrors();
end;

function TGnyNativeDebugServer.HasWarnings(): Boolean;
begin
  Result := FErrors.HasWarnings();
end;

function TGnyNativeDebugServer.HasHints(): Boolean;
begin
  Result := FErrors.HasHints();
end;

function TGnyNativeDebugServer.HasFatal(): Boolean;
begin
  Result := FErrors.HasFatal();
end;

function TGnyNativeDebugServer.ErrorCount(): Integer;
begin
  Result := FErrors.ErrorCount();
end;

function TGnyNativeDebugServer.WarningCount(): Integer;
begin
  Result := FErrors.WarningCount();
end;

function TGnyNativeDebugServer.GetErrorItems(): TList<TGnyError>;
begin
  Result := FErrors.GetItems();
end;

function TGnyNativeDebugServer.GetErrorText(): string;
begin
  Result := FErrors.ToString();
end;

//------------------------------------------------------------------------------
// Accessors
//------------------------------------------------------------------------------

function TGnyNativeDebugServer.GetRuntime(): TDebugRuntime;
begin
  Result := FRuntime;
end;

function TGnyNativeDebugServer.GetDAPServer(): TDAPServer;
begin
  Result := FDAPServer;
end;

function TGnyNativeDebugServer.GetSourceMap(): TSourceMap;
begin
  Result := FSourceMap;
end;

end.
