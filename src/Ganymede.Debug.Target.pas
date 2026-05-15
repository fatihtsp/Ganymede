{===============================================================================
  Ganymede™ - Embeddable Native Scripting Engine

  Copyright © 2026-present tinyBigGAMES™ LLC
  All Rights Reserved.

  See LICENSE for license information
===============================================================================}

unit Ganymede.Debug.Target;

{$I Ganymede.Defines.inc}

interface

uses
  WinApi.Windows,
  System.SysUtils,
  System.Classes,
  System.Generics.Collections,
  Ganymede.Utils,
  Ganymede.JIT;

const
  // x64 trap flag (bit 8 of RFLAGS)
  TRAP_FLAG = $100;

  // INT3 opcode
  INT3_OPCODE = $CC;

type
  //============================================================================
  // TDebugStopReason - Why execution stopped
  //============================================================================
  TDebugStopReason = (
    dsrNone,
    dsrBreakpoint,       // Hit an INT3 breakpoint
    dsrSingleStep,       // Completed a single-step (trap flag)
    dsrException,        // Unhandled exception in debuggee
    dsrProcessExit,      // Debuggee process exited (PE mode)
    dsrDllLoad           // A DLL was loaded (PE mode)
  );

  //============================================================================
  // TDebugStopEvent - Information about why execution stopped
  //============================================================================
  TDebugStopEvent = record
    Reason: TDebugStopReason;
    Address: UInt64;          // Address where stop occurred
    CodeOffset: Cardinal;     // Offset from .text start (computed by target)
    ThreadId: DWORD;
    ExitCode: Cardinal;       // Valid when Reason = dsrProcessExit
    ExceptionCode: Cardinal;  // Valid when Reason = dsrException
    ExceptionMessage: string; // Human-readable exception description
  end;

  //============================================================================
  // TResumeAction - What to do when resuming execution
  //============================================================================
  TResumeAction = (
    raContinue,       // Resume normal execution
    raStepOver,       // Step to next source line (same function)
    raStepIn,         // Step into function call
    raStepOut         // Step out of current function
  );

  //============================================================================
  // TDebugTarget - Abstract base for JIT and PE debug modes.
  // Provides uniform interface for memory access, execution control,
  // and address mapping. All debug components (breakpoint manager,
  // stepping, stack walker) work through this abstraction.
  //============================================================================

  { TDebugTarget }
  TDebugTarget = class(TGnyBaseObject)
  protected
    FBreakOnExceptions: Boolean;  // When True, stop on unhandled exceptions
  public
    constructor Create(); override;
    destructor Destroy(); override;

    // Memory operations
    function ReadByte(const AAddress: UInt64): Byte; virtual; abstract;
    procedure WriteByte(const AAddress: UInt64; const AValue: Byte); virtual; abstract;
    function ReadUInt64(const AAddress: UInt64): UInt64; virtual; abstract;
    function ReadBytes(const AAddress: UInt64; const ASize: Cardinal): TBytes; virtual;
    procedure FlushCode(const AAddress: UInt64; const ASize: Cardinal); virtual; abstract;

    // Execution control
    procedure Resume(); virtual; abstract;
    procedure SetTrapFlag(); virtual; abstract;
    procedure ClearTrapFlag(); virtual; abstract;

    // Thread context (captured at stop point)
    function GetContext(): TContext; virtual; abstract;
    procedure SetContext(const AContext: TContext); virtual; abstract;

    // Address mapping
    function CodeOffsetToAddress(const AOffset: Cardinal): UInt64; virtual; abstract;
    function AddressToCodeOffset(const AAddress: UInt64): Cardinal; virtual; abstract;
    function IsOurCode(const AAddress: UInt64): Boolean; virtual; abstract;

    // Single-step re-patch tracking (default: no-op / returns -1)
    procedure SetRepatchOffset(const AOffset: Integer); virtual;
    function GetRepatchOffset(): Integer; virtual;

    // Debug activation guard (default: no-op)
    // JIT target overrides to enable/disable VEH interception
    procedure SetDebugActive(const AActive: Boolean); virtual;

    // Configuration done signal (default: no-op)
    // PE target overrides to unblock the process held at initial breakpoint
    procedure SignalConfigDone(); virtual;

    // Wait until target is ready for breakpoint patching (default: no-op)
    // PE target overrides to wait for FActualImageBase to be set
    procedure WaitUntilReady(); virtual;

    // Unblock WaitForStop during shutdown (default: no-op)
    // PE target overrides to signal FStoppedEvent so the stop watcher can exit
    procedure UnblockWaitForStop(); virtual;

    // Lifecycle
    function Start(): Boolean; virtual; abstract;
    procedure Stop(); virtual; abstract;
    function WaitForStop(out AEvent: TDebugStopEvent): Boolean; virtual; abstract;
    function IsRunning(): Boolean; virtual; abstract;

    // Exception handling
    procedure SetBreakOnExceptions(const AEnabled: Boolean);
    function GetBreakOnExceptions(): Boolean;
  end;

  //============================================================================
  // TJITDebugTarget - In-process debugging via VEH + direct memory.
  // Used when Viper runs code via BuildJIT() + Invoke().
  // The VEH handler catches INT3/single-step exceptions within the
  // JIT code range, captures the thread context, and blocks until
  // the DAP server signals resume.
  //============================================================================

  { TJITDebugTarget }
  TJITDebugTarget = class(TDebugTarget)
  private
    FJIT: TJIT;                 // Reference (not owned)
    FCodeBase: PByte;
    FCodeSize: NativeUInt;
    FVEHHandle: Pointer;        // VEH registration handle
    FStoppedEvent: THandle;     // Signaled when breakpoint hit
    FResumeEvent: THandle;      // Signaled when DAP says continue
    FCapturedContext: TContext;  // Thread context captured at stop
    FStoppedReason: TDebugStopReason;
    FStoppedAddress: UInt64;
    FExceptionCode: Cardinal;   // Exception code when Reason = dsrException
    FStarted: Boolean;

    // Single-step tracking: after stepping past a breakpoint,
    // re-patch the INT3 at this offset (-1 = none pending)
    FRepatchOffset: Integer;

    // Guard flag: when False, the VEH handler passes through all exceptions.
    // Set to True only after breakpoints are patched and we're ready to debug.
    // This prevents the VEH handler from intercepting exceptions during
    // non-debug JIT invocations (e.g. diagnostic runs).
    FDebugActive: Boolean;

  public
    constructor Create(); override;
    destructor Destroy(); override;

    // Setup — call before Start()
    procedure SetJIT(const AJIT: TJIT);

    // TDebugTarget overrides — Memory
    function ReadByte(const AAddress: UInt64): Byte; override;
    procedure WriteByte(const AAddress: UInt64; const AValue: Byte); override;
    function ReadUInt64(const AAddress: UInt64): UInt64; override;
    procedure FlushCode(const AAddress: UInt64; const ASize: Cardinal); override;

    // TDebugTarget overrides — Execution control
    procedure Resume(); override;
    procedure SetTrapFlag(); override;
    procedure ClearTrapFlag(); override;

    // TDebugTarget overrides — Context
    function GetContext(): TContext; override;
    procedure SetContext(const AContext: TContext); override;

    // TDebugTarget overrides — Address mapping
    function CodeOffsetToAddress(const AOffset: Cardinal): UInt64; override;
    function AddressToCodeOffset(const AAddress: UInt64): Cardinal; override;
    function IsOurCode(const AAddress: UInt64): Boolean; override;

    // TDebugTarget overrides — Lifecycle
    function Start(): Boolean; override;
    procedure Stop(); override;
    function WaitForStop(out AEvent: TDebugStopEvent): Boolean; override;
    function IsRunning(): Boolean; override;

    // VEH callback support (called from VEH handler)
    procedure HandleBreakpointHit(const AAddress: UInt64;
      const AContext: PContext);
    procedure HandleSingleStep(const AAddress: UInt64;
      const AContext: PContext);

    // Single-step re-patch tracking
    procedure SetRepatchOffset(const AOffset: Integer); override;
    function GetRepatchOffset(): Integer; override;

    // Debug activation guard — VEH handler only intercepts when active
    procedure SetDebugActive(const AActive: Boolean); override;

    // Shutdown support
    procedure UnblockWaitForStop(); override;
  end;

  //============================================================================
  // TPEDebugTarget - Out-of-process debugging via Windows Debug API.
  // Used when Viper compiles to EXE or DLL via Build().
  // A dedicated thread runs WaitForDebugEvent in a loop, catching
  // INT3 and single-step exceptions in the debuggee process.
  //============================================================================

  TPEDebugTarget = class;

  { TPEDebugLoopThread }
  TPEDebugLoopThread = class(TThread)
  private
    FTarget: TPEDebugTarget;
    function IsTargetDll(const AEvent: TDebugEvent): Boolean;
  protected
    procedure Execute(); override;
  public
    constructor Create(const ATarget: TPEDebugTarget);
  end;

  { TPEDebugTarget }
  TPEDebugTarget = class(TDebugTarget)
  private
    FExePath: string;
    FProcessHandle: THandle;
    FMainThreadHandle: THandle;
    FProcessId: DWORD;
    FMainThreadId: DWORD;
    FActualImageBase: UInt64;        // Real load address (handles ASLR)
    FTextSectionRVA: Cardinal;       // .text section RVA from .vdbg header
    FTextSectionSize: Cardinal;      // .text section size
    FStoppedEvent: THandle;          // Signaled when breakpoint hit
    FResumeEvent: THandle;           // Signaled when DAP says continue
    FCapturedContext: TContext;       // Thread context captured at stop
    FStoppedReason: TDebugStopReason;
    FStoppedAddress: UInt64;
    FStoppedThreadId: DWORD;
    FExceptionCode: Cardinal;        // Exception code when Reason = dsrException
    FStarted: Boolean;
    FExitCode: Cardinal;
    FInitialBreakpointSeen: Boolean; // Tracks ntdll loader breakpoint
    FRepatchOffset: Integer;
    FConfigDoneEvent: THandle;       // Signaled when configurationDone arrives
    FReadyEvent: THandle;            // Signaled when debug loop reaches initial BP
    FLaunchDoneEvent: THandle;       // Signaled after CreateProcessW attempt
    FLaunchPath: string;             // Path to launch (computed in Start, used by thread)
    FLaunchSucceeded: Boolean;       // Set by debug loop thread after CreateProcessW
    FDebugLoopThread: TPEDebugLoopThread;

    // DLL debugging fields
    FDllPath: string;                  // Target DLL we're debugging
    FHostExePath: string;              // Host EXE that loads the DLL
    FIsAttachedToDll: Boolean;         // True = DLL mode, False = EXE mode
    FDllBaseAddress: UInt64;           // Actual load address of target DLL
    FDllFound: Boolean;                // Set when target DLL detected

  public
    constructor Create(); override;
    destructor Destroy(); override;

    // Setup — call before Start()
    procedure SetExePath(const APath: string);
    procedure SetTextSectionRVA(const ARVA: Cardinal);
    procedure SetTextSectionSize(const ASize: Cardinal);
    procedure SetDllMode(const ADllPath: string; const AHostExePath: string);

    // TDebugTarget overrides — Memory (via ReadProcessMemory/WriteProcessMemory)
    function ReadByte(const AAddress: UInt64): Byte; override;
    procedure WriteByte(const AAddress: UInt64; const AValue: Byte); override;
    function ReadUInt64(const AAddress: UInt64): UInt64; override;
    procedure FlushCode(const AAddress: UInt64; const ASize: Cardinal); override;

    // TDebugTarget overrides — Execution control
    procedure Resume(); override;
    procedure SetTrapFlag(); override;
    procedure ClearTrapFlag(); override;

    // TDebugTarget overrides — Context
    function GetContext(): TContext; override;
    procedure SetContext(const AContext: TContext); override;

    // TDebugTarget overrides — Address mapping
    function CodeOffsetToAddress(const AOffset: Cardinal): UInt64; override;
    function AddressToCodeOffset(const AAddress: UInt64): Cardinal; override;
    function IsOurCode(const AAddress: UInt64): Boolean; override;

    // TDebugTarget overrides — Lifecycle
    function Start(): Boolean; override;
    procedure Stop(); override;
    function WaitForStop(out AEvent: TDebugStopEvent): Boolean; override;
    function IsRunning(): Boolean; override;

    // Re-patch tracking
    procedure SetRepatchOffset(const AOffset: Integer); override;
    function GetRepatchOffset(): Integer; override;

    // Configuration done — releases process held at initial breakpoint
    procedure SignalConfigDone(); override;

    // Wait until debug loop has reached initial breakpoint (FActualImageBase set)
    procedure WaitUntilReady(); override;

    // Unblock stop watcher during shutdown
    procedure UnblockWaitForStop(); override;

    // Properties
    property ProcessHandle: THandle read FProcessHandle;
    property ExitCodeValue: Cardinal read FExitCode;
    property IsAttachedToDll: Boolean read FIsAttachedToDll;
    property DllFound: Boolean read FDllFound;
    property DllBaseAddress: UInt64 read FDllBaseAddress;
  end;

implementation

//==============================================================================
// Windows API declarations for VEH (Vectored Exception Handling)
//==============================================================================

const
  EXCEPTION_CONTINUE_EXECUTION = -1;
  EXCEPTION_CONTINUE_SEARCH    = 0;

  EXCEPTION_BREAKPOINT    = DWORD($80000003);
  EXCEPTION_SINGLE_STEP   = DWORD($80000004);

type
  PVECTORED_EXCEPTION_HANDLER = function(
    ExceptionInfo: PExceptionPointers): LONG; stdcall;

function AddVectoredExceptionHandler(First: ULONG;
  Handler: PVECTORED_EXCEPTION_HANDLER): Pointer; stdcall;
  external kernel32 name 'AddVectoredExceptionHandler';
function RemoveVectoredExceptionHandler(
  Handle: Pointer): ULONG; stdcall;
  external kernel32 name 'RemoveVectoredExceptionHandler';

//==============================================================================
// Global: Active JIT debug target (accessed by VEH handler)
//==============================================================================

var
  GJITTarget: TJITDebugTarget = nil;

//==============================================================================
// VEH Handler — catches INT3 and single-step within JIT code range
//==============================================================================

function JITExceptionHandler(
  AExceptionInfo: PExceptionPointers): LONG; stdcall;
var
  LCode: DWORD;
  LAddr: UInt64;
begin
  // No active target — let someone else handle it
  if GJITTarget = nil then
    Exit(EXCEPTION_CONTINUE_SEARCH);

  // Debug not yet active — pass through all exceptions.
  // This allows non-debug JIT invocations to run without interference.
  if not GJITTarget.FDebugActive then
    Exit(EXCEPTION_CONTINUE_SEARCH);

  LCode := AExceptionInfo.ExceptionRecord.ExceptionCode;
  LAddr := UInt64(AExceptionInfo.ExceptionRecord.ExceptionAddress);

  // Check if within JIT code range
  if not GJITTarget.IsOurCode(LAddr) then
    Exit(EXCEPTION_CONTINUE_SEARCH);

  if LCode = EXCEPTION_BREAKPOINT then
  begin
    // INT3 hit within our code — capture context and block
    GJITTarget.HandleBreakpointHit(LAddr,
      AExceptionInfo.ContextRecord);
    // After resume, apply any context modifications (trap flag, etc.)
    Move(GJITTarget.FCapturedContext, AExceptionInfo.ContextRecord^, SizeOf(TContext));
    Result := EXCEPTION_CONTINUE_EXECUTION;
  end
  else if LCode = EXCEPTION_SINGLE_STEP then
  begin
    // Single-step completed — re-patch breakpoint if needed
    GJITTarget.HandleSingleStep(LAddr,
      AExceptionInfo.ContextRecord);
    Move(GJITTarget.FCapturedContext, AExceptionInfo.ContextRecord^, SizeOf(TContext));
    Result := EXCEPTION_CONTINUE_EXECUTION;
  end
  else if GJITTarget.FBreakOnExceptions then
  begin
    // Exception within our code and break-on-exceptions is enabled
    GJITTarget.FCapturedContext := PContext(AExceptionInfo.ContextRecord)^;
    GJITTarget.FStoppedReason := dsrException;
    GJITTarget.FStoppedAddress := LAddr;
    GJITTarget.FExceptionCode := LCode;
    SetEvent(GJITTarget.FStoppedEvent);
    WaitForSingleObject(GJITTarget.FResumeEvent, INFINITE);
    Move(GJITTarget.FCapturedContext, AExceptionInfo.ContextRecord^, SizeOf(TContext));
    Result := EXCEPTION_CONTINUE_EXECUTION;
  end
  else
    Result := EXCEPTION_CONTINUE_SEARCH;
end;

//==============================================================================
// TDebugTarget — Base
//==============================================================================

constructor TDebugTarget.Create();
begin
  inherited Create();
  FBreakOnExceptions := False;
end;

destructor TDebugTarget.Destroy();
begin
  inherited Destroy();
end;

function TDebugTarget.ReadBytes(const AAddress: UInt64;
  const ASize: Cardinal): TBytes;
var
  LI: Cardinal;
begin
  SetLength(Result, ASize);
  for LI := 0 to ASize - 1 do
    Result[LI] := ReadByte(AAddress + LI);
end;

procedure TDebugTarget.SetRepatchOffset(const AOffset: Integer);
begin
  // Default no-op — overridden by JIT and PE targets
end;

function TDebugTarget.GetRepatchOffset(): Integer;
begin
  Result := -1;
end;

procedure TDebugTarget.SetDebugActive(const AActive: Boolean);
begin
  // Default no-op — JIT target overrides to enable/disable VEH interception
end;

procedure TDebugTarget.SignalConfigDone();
begin
  // Default no-op — PE target overrides to release the held process
end;

procedure TDebugTarget.WaitUntilReady();
begin
  // Default no-op — PE target overrides to wait for FActualImageBase
end;

procedure TDebugTarget.UnblockWaitForStop();
begin
  // Default no-op — PE target overrides to signal FStoppedEvent
end;

procedure TDebugTarget.SetBreakOnExceptions(const AEnabled: Boolean);
begin
  FBreakOnExceptions := AEnabled;
end;

function TDebugTarget.GetBreakOnExceptions(): Boolean;
begin
  Result := FBreakOnExceptions;
end;

//==============================================================================
// TJITDebugTarget
//==============================================================================

constructor TJITDebugTarget.Create();
begin
  inherited Create();
  FJIT := nil;
  FCodeBase := nil;
  FCodeSize := 0;
  FVEHHandle := nil;
  FStoppedEvent := 0;
  FResumeEvent := 0;
  FillChar(FCapturedContext, SizeOf(FCapturedContext), 0);
  FStoppedReason := dsrNone;
  FStoppedAddress := 0;
  FExceptionCode := 0;
  FStarted := False;
  FRepatchOffset := -1;
  FDebugActive := False;
end;

destructor TJITDebugTarget.Destroy();
begin
  Stop();
  inherited Destroy();
end;

//------------------------------------------------------------------------------
// Setup + Lifecycle
//------------------------------------------------------------------------------

procedure TJITDebugTarget.SetJIT(const AJIT: TJIT);
begin
  FJIT := AJIT;
  FCodeBase := PByte(AJIT.CodeBase);
  FCodeSize := AJIT.CodeSize;
end;

function TJITDebugTarget.Start(): Boolean;
begin
  Result := False;

  if FJIT = nil then
  begin
    if Assigned(FErrors) then
      FErrors.Add(esFatal, 'DBG001', 'JIT not set before Start()');
    Exit;
  end;

  // Create synchronization events (auto-reset)
  FStoppedEvent := CreateEvent(nil, False, False, nil);
  FResumeEvent := CreateEvent(nil, False, False, nil);

  if (FStoppedEvent = 0) or (FResumeEvent = 0) then
  begin
    if Assigned(FErrors) then
      FErrors.Add(esFatal, 'DBG002', 'Failed to create synchronization events');
    Exit;
  end;

  // Register VEH handler (CALL_FIRST = 1)
  GJITTarget := Self;
  FVEHHandle := AddVectoredExceptionHandler(1, @JITExceptionHandler);
  if FVEHHandle = nil then
  begin
    if Assigned(FErrors) then
      FErrors.Add(esFatal, 'DBG003', 'Failed to register VEH handler');
    GJITTarget := nil;
    Exit;
  end;

  FStarted := True;
  Result := True;
end;

procedure TJITDebugTarget.Stop();
begin
  if not FStarted then
    Exit;

  // Remove VEH handler
  if FVEHHandle <> nil then
  begin
    RemoveVectoredExceptionHandler(FVEHHandle);
    FVEHHandle := nil;
  end;

  // Clear global
  if GJITTarget = Self then
    GJITTarget := nil;

  // Close events
  if FStoppedEvent <> 0 then
  begin
    CloseHandle(FStoppedEvent);
    FStoppedEvent := 0;
  end;
  if FResumeEvent <> 0 then
  begin
    CloseHandle(FResumeEvent);
    FResumeEvent := 0;
  end;

  FStarted := False;
end;

function TJITDebugTarget.IsRunning(): Boolean;
begin
  Result := FStarted;
end;

function TJITDebugTarget.WaitForStop(out AEvent: TDebugStopEvent): Boolean;
begin
  // Block until the VEH handler signals that a breakpoint was hit
  Result := WaitForSingleObject(FStoppedEvent, INFINITE) = WAIT_OBJECT_0;
  if Result then
  begin
    AEvent.Reason := FStoppedReason;
    AEvent.Address := FStoppedAddress;
    AEvent.CodeOffset := AddressToCodeOffset(FStoppedAddress);
    AEvent.ThreadId := GetCurrentThreadId();
    AEvent.ExitCode := 0;
    AEvent.ExceptionCode := FExceptionCode;
    if FStoppedReason = dsrException then
      AEvent.ExceptionMessage := Format('Exception 0x%x at 0x%x',
        [FExceptionCode, FStoppedAddress])
    else
      AEvent.ExceptionMessage := '';
  end;
end;

procedure TJITDebugTarget.Resume();
begin
  // Signal the VEH handler thread to continue execution
  SetEvent(FResumeEvent);
end;

procedure TJITDebugTarget.SetTrapFlag();
begin
  // Set trap flag in captured context — applied when VEH resumes
  FCapturedContext.EFlags := FCapturedContext.EFlags or TRAP_FLAG;
end;

procedure TJITDebugTarget.ClearTrapFlag();
begin
  // Clear trap flag in captured context
  FCapturedContext.EFlags := FCapturedContext.EFlags and (not TRAP_FLAG);
end;

//------------------------------------------------------------------------------
// Memory Operations (direct in-process access)
//------------------------------------------------------------------------------

function TJITDebugTarget.ReadByte(const AAddress: UInt64): Byte;
begin
  Result := PByte(AAddress)^;
end;

procedure TJITDebugTarget.WriteByte(const AAddress: UInt64; const AValue: Byte);
begin
  PByte(AAddress)^ := AValue;
end;

function TJITDebugTarget.ReadUInt64(const AAddress: UInt64): UInt64;
begin
  Result := PUInt64(AAddress)^;
end;

procedure TJITDebugTarget.FlushCode(const AAddress: UInt64; const ASize: Cardinal);
begin
  // JIT memory is RWX — flush instruction cache to ensure coherency
  FlushInstructionCache(GetCurrentProcess(), Pointer(AAddress), ASize);
end;

//------------------------------------------------------------------------------
// Thread Context
//------------------------------------------------------------------------------

function TJITDebugTarget.GetContext(): TContext;
begin
  Result := FCapturedContext;
end;

procedure TJITDebugTarget.SetContext(const AContext: TContext);
begin
  FCapturedContext := AContext;
end;

//------------------------------------------------------------------------------
// Address Mapping
//------------------------------------------------------------------------------

function TJITDebugTarget.CodeOffsetToAddress(const AOffset: Cardinal): UInt64;
begin
  Result := UInt64(FCodeBase) + AOffset;
end;

function TJITDebugTarget.AddressToCodeOffset(const AAddress: UInt64): Cardinal;
begin
  Result := Cardinal(AAddress - UInt64(FCodeBase));
end;

function TJITDebugTarget.IsOurCode(const AAddress: UInt64): Boolean;
begin
  Result := (AAddress >= UInt64(FCodeBase)) and
            (AAddress < UInt64(FCodeBase) + FCodeSize);
end;

//------------------------------------------------------------------------------
// VEH Callback Handlers (called from the VEH handler function)
//------------------------------------------------------------------------------

procedure TJITDebugTarget.HandleBreakpointHit(const AAddress: UInt64;
  const AContext: PContext);
begin
  // Save the full thread context
  Move(AContext^, FCapturedContext, SizeOf(TContext));

  // VEH delivers RIP pointing AT the INT3 byte (not past it),
  // so no adjustment is needed — unlike Windows Debug API.

  FStoppedReason := dsrBreakpoint;
  FStoppedAddress := FCapturedContext.Rip;

  // Signal the DAP thread that we stopped
  SetEvent(FStoppedEvent);

  // Block the JIT execution thread until DAP says resume
  WaitForSingleObject(FResumeEvent, INFINITE);
end;

procedure TJITDebugTarget.HandleSingleStep(const AAddress: UInt64;
  const AContext: PContext);
begin
  // Save context
  Move(AContext^, FCapturedContext, SizeOf(TContext));

  // Clear the trap flag so we don't keep single-stepping
  ClearTrapFlag();

  // If we were stepping past a breakpoint, re-patch the INT3
  // and silently continue — this is an internal re-patch, not a user step
  if FRepatchOffset >= 0 then
  begin
    WriteByte(CodeOffsetToAddress(Cardinal(FRepatchOffset)), INT3_OPCODE);
    FlushCode(CodeOffsetToAddress(Cardinal(FRepatchOffset)), 1);
    FRepatchOffset := -1;
    // Do NOT signal FStoppedEvent or block — just resume silently
    Exit;
  end;

  FStoppedReason := dsrSingleStep;
  FStoppedAddress := AAddress;

  // Signal DAP thread
  SetEvent(FStoppedEvent);

  // Block until DAP says resume
  WaitForSingleObject(FResumeEvent, INFINITE);
end;

//------------------------------------------------------------------------------
// Single-step re-patch tracking
//------------------------------------------------------------------------------

procedure TJITDebugTarget.SetRepatchOffset(const AOffset: Integer);
begin
  FRepatchOffset := AOffset;
end;

function TJITDebugTarget.GetRepatchOffset(): Integer;
begin
  Result := FRepatchOffset;
end;

procedure TJITDebugTarget.SetDebugActive(const AActive: Boolean);
begin
  FDebugActive := AActive;
end;

procedure TJITDebugTarget.UnblockWaitForStop();
begin
  // Signal FStoppedEvent so the stop watcher thread can wake up and exit
  if FStoppedEvent <> 0 then
    SetEvent(FStoppedEvent);
end;

//==============================================================================
// TPEDebugLoopThread
//==============================================================================

constructor TPEDebugLoopThread.Create(const ATarget: TPEDebugTarget);
begin
  inherited Create(True);  // Create suspended
  FreeOnTerminate := False;
  FTarget := ATarget;
end;

function TPEDebugLoopThread.IsTargetDll(const AEvent: TDebugEvent): Boolean;
var
  LNamePtr: Pointer;
  LBytesRead: NativeUInt;
  LNameBuf: array[0..519] of Byte;
  LDllName: string;
  LTargetName: string;
begin
  Result := False;

  // lpImageName is a pointer (in debuggee address space) to a pointer
  // to the DLL name string. Read the pointer first.
  if AEvent.LoadDll.lpImageName = nil then
    Exit;

  LNamePtr := nil;
  if not ReadProcessMemory(FTarget.FProcessHandle,
    AEvent.LoadDll.lpImageName, @LNamePtr, SizeOf(Pointer),
    LBytesRead) then
    Exit;

  if LNamePtr = nil then
    Exit;

  // Now read the actual name string from that pointer
  FillChar(LNameBuf, SizeOf(LNameBuf), 0);
  if not ReadProcessMemory(FTarget.FProcessHandle,
    LNamePtr, @LNameBuf[0], 520, LBytesRead) then
    Exit;

  // fUnicode flag indicates whether name is Unicode or ANSI
  if AEvent.LoadDll.fUnicode <> 0 then
    LDllName := PWideChar(@LNameBuf[0])
  else
    LDllName := string(PAnsiChar(@LNameBuf[0]));

  if LDllName = '' then
    Exit;

  // Compare filename portion (case-insensitive)
  LTargetName := ExtractFileName(FTarget.FDllPath);
  Result := SameText(ExtractFileName(LDllName), LTargetName);
end;

procedure TPEDebugLoopThread.Execute();
var
  LEvent: TDebugEvent;
  LContinueStatus: DWORD;
  LExCode: DWORD;
  LExAddr: UInt64;
  LContext: TContext;
  LRepatch: Integer;
  LSI: TStartupInfoW;
  LPI: TProcessInformation;
begin
  // CreateProcessW MUST be called on the same thread as WaitForDebugEvent
  // (Windows Debug API requirement)
  FillChar(LSI, SizeOf(LSI), 0);
  LSI.cb := SizeOf(LSI);
  FillChar(LPI, SizeOf(LPI), 0);

  if not CreateProcessW(
    PWideChar(FTarget.FLaunchPath),
    nil,
    nil, nil,
    False,
    DEBUG_ONLY_THIS_PROCESS or CREATE_UNICODE_ENVIRONMENT,
    nil,
    PWideChar(ExtractFilePath(FTarget.FLaunchPath)),
    LSI, LPI) then
  begin
    FTarget.FLaunchSucceeded := False;
    SetEvent(FTarget.FLaunchDoneEvent);
    Exit;
  end;

  FTarget.FProcessHandle := LPI.hProcess;
  FTarget.FMainThreadHandle := LPI.hThread;
  FTarget.FProcessId := LPI.dwProcessId;
  FTarget.FMainThreadId := LPI.dwThreadId;
  FTarget.FLaunchSucceeded := True;
  SetEvent(FTarget.FLaunchDoneEvent);

  while not Terminated do
  begin
    // Use a timeout so we can check Terminated periodically
    if not WaitForDebugEvent(LEvent, 200) then
      Continue;

    LContinueStatus := DBG_CONTINUE;

    case LEvent.dwDebugEventCode of
      CREATE_PROCESS_DEBUG_EVENT:
      begin
        // Capture actual image base (handles ASLR)
        FTarget.FActualImageBase :=
          UInt64(LEvent.CreateProcessInfo.lpBaseOfImage);
        FTarget.FProcessHandle := LEvent.CreateProcessInfo.hProcess;
        FTarget.FMainThreadHandle := LEvent.CreateProcessInfo.hThread;
        FTarget.FMainThreadId := LEvent.dwThreadId;

        // Close the image file handle (we don't need it)
        if LEvent.CreateProcessInfo.hFile <> 0 then
          CloseHandle(LEvent.CreateProcessInfo.hFile);
      end;

      EXCEPTION_DEBUG_EVENT:
      begin
        LExCode := LEvent.Exception.ExceptionRecord.ExceptionCode;
        LExAddr := UInt64(LEvent.Exception.ExceptionRecord.ExceptionAddress);

        if LExCode = EXCEPTION_BREAKPOINT then
        begin
          // Skip the initial loader breakpoint from ntdll
          if not FTarget.FInitialBreakpointSeen then
          begin
            FTarget.FInitialBreakpointSeen := True;

            // Signal that FActualImageBase is set and we're ready for patching
            SetEvent(FTarget.FReadyEvent);

            // Hold the process here until configurationDone arrives.
            // This gives the DAP client time to send setBreakpoints
            // before the debuggee runs its code.
            WaitForSingleObject(FTarget.FConfigDoneEvent, INFINITE);

            if Terminated then
            begin
              ContinueDebugEvent(LEvent.dwProcessId, LEvent.dwThreadId,
                DBG_CONTINUE);
              Break;
            end;

            ContinueDebugEvent(LEvent.dwProcessId, LEvent.dwThreadId,
              DBG_CONTINUE);
            Continue;
          end;

          // Check if this is within our code
          if FTarget.IsOurCode(LExAddr) then
          begin
            // Capture thread context
            FillChar(LContext, SizeOf(LContext), 0);
            LContext.ContextFlags := CONTEXT_FULL;
            GetThreadContext(FTarget.FMainThreadHandle, LContext);

            // INT3 advances RIP past 0xCC — back up by 1
            Dec(LContext.Rip);
            SetThreadContext(FTarget.FMainThreadHandle, LContext);

            FTarget.FCapturedContext := LContext;
            FTarget.FStoppedReason := dsrBreakpoint;
            FTarget.FStoppedAddress := LContext.Rip;
            FTarget.FStoppedThreadId := LEvent.dwThreadId;

            // Signal DAP thread that we stopped
            SetEvent(FTarget.FStoppedEvent);

            // Block until DAP tells us what to do
            WaitForSingleObject(FTarget.FResumeEvent, INFINITE);

            if Terminated then
            begin
              ContinueDebugEvent(LEvent.dwProcessId, LEvent.dwThreadId,
                DBG_CONTINUE);
              Break;
            end;

            // Apply any context modifications (trap flag, RIP changes)
            SetThreadContext(FTarget.FMainThreadHandle,
              FTarget.FCapturedContext);

            ContinueDebugEvent(LEvent.dwProcessId, LEvent.dwThreadId,
              DBG_CONTINUE);
            Continue;
          end
          else
          begin
            // Not our breakpoint — let the process handle it
            LContinueStatus := DBG_EXCEPTION_NOT_HANDLED;
          end;
        end
        else if LExCode = EXCEPTION_SINGLE_STEP then
        begin
          // Re-patch breakpoint if we were stepping past one
          LRepatch := FTarget.FRepatchOffset;
          if LRepatch >= 0 then
          begin
            FTarget.WriteByte(
              FTarget.CodeOffsetToAddress(Cardinal(LRepatch)), INT3_OPCODE);
            FTarget.FlushCode(
              FTarget.CodeOffsetToAddress(Cardinal(LRepatch)), 1);
            FTarget.FRepatchOffset := -1;

            // This was an internal re-patch step (continue past breakpoint),
            // NOT a user-requested step — clear trap flag and resume silently
            FillChar(LContext, SizeOf(LContext), 0);
            LContext.ContextFlags := CONTEXT_FULL;
            GetThreadContext(FTarget.FMainThreadHandle, LContext);
            LContext.EFlags := LContext.EFlags and (not TRAP_FLAG);
            SetThreadContext(FTarget.FMainThreadHandle, LContext);

            ContinueDebugEvent(LEvent.dwProcessId, LEvent.dwThreadId,
              DBG_CONTINUE);
            Continue;
          end;

          // User-requested single step (step over/in/out) — report to DAP
          FillChar(LContext, SizeOf(LContext), 0);
          LContext.ContextFlags := CONTEXT_FULL;
          GetThreadContext(FTarget.FMainThreadHandle, LContext);

          // Clear trap flag
          LContext.EFlags := LContext.EFlags and (not TRAP_FLAG);
          SetThreadContext(FTarget.FMainThreadHandle, LContext);

          FTarget.FCapturedContext := LContext;
          FTarget.FStoppedReason := dsrSingleStep;
          FTarget.FStoppedAddress := LContext.Rip;
          FTarget.FStoppedThreadId := LEvent.dwThreadId;

          // Signal DAP thread
          SetEvent(FTarget.FStoppedEvent);

          // Block until DAP tells us what to do
          WaitForSingleObject(FTarget.FResumeEvent, INFINITE);

          if Terminated then
          begin
            ContinueDebugEvent(LEvent.dwProcessId, LEvent.dwThreadId,
              DBG_CONTINUE);
            Break;
          end;

          // Apply context
          SetThreadContext(FTarget.FMainThreadHandle,
            FTarget.FCapturedContext);

          ContinueDebugEvent(LEvent.dwProcessId, LEvent.dwThreadId,
            DBG_CONTINUE);
          Continue;
        end
        else
        begin
          // Other exceptions — break into debugger if enabled, else pass through
          if FTarget.FBreakOnExceptions and FTarget.IsOurCode(LExAddr) then
          begin
            FillChar(LContext, SizeOf(LContext), 0);
            LContext.ContextFlags := CONTEXT_FULL;
            GetThreadContext(FTarget.FMainThreadHandle, LContext);

            FTarget.FCapturedContext := LContext;
            FTarget.FStoppedReason := dsrException;
            FTarget.FStoppedAddress := LExAddr;
            FTarget.FStoppedThreadId := LEvent.dwThreadId;
            FTarget.FExceptionCode := LExCode;

            SetEvent(FTarget.FStoppedEvent);
            WaitForSingleObject(FTarget.FResumeEvent, INFINITE);

            if Terminated then
            begin
              ContinueDebugEvent(LEvent.dwProcessId, LEvent.dwThreadId,
                DBG_CONTINUE);
              Break;
            end;

            SetThreadContext(FTarget.FMainThreadHandle,
              FTarget.FCapturedContext);

            ContinueDebugEvent(LEvent.dwProcessId, LEvent.dwThreadId,
              DBG_EXCEPTION_NOT_HANDLED);
            Continue;
          end
          else if LEvent.Exception.dwFirstChance = 1 then
            LContinueStatus := DBG_EXCEPTION_NOT_HANDLED;
        end;
      end;

      LOAD_DLL_DEBUG_EVENT:
      begin
        // Check if this is our target DLL (only in DLL debug mode)
        if FTarget.FIsAttachedToDll and (not FTarget.FDllFound) then
        begin
          if IsTargetDll(LEvent) then
          begin
            FTarget.FDllBaseAddress :=
              UInt64(LEvent.LoadDll.lpBaseOfDll);
            FTarget.FDllFound := True;

            // Signal the runtime so it can apply breakpoints
            FTarget.FStoppedReason := dsrDllLoad;
            FTarget.FStoppedAddress := 0;
            FTarget.FStoppedThreadId := LEvent.dwThreadId;

            SetEvent(FTarget.FStoppedEvent);

            // Block until runtime has applied breakpoints and tells us to go
            WaitForSingleObject(FTarget.FResumeEvent, INFINITE);

            if Terminated then
            begin
              if LEvent.LoadDll.hFile <> 0 then
                CloseHandle(LEvent.LoadDll.hFile);
              ContinueDebugEvent(LEvent.dwProcessId, LEvent.dwThreadId,
                DBG_CONTINUE);
              Break;
            end;
          end;
        end;

        // Close the DLL file handle
        if LEvent.LoadDll.hFile <> 0 then
          CloseHandle(LEvent.LoadDll.hFile);
      end;

      EXIT_PROCESS_DEBUG_EVENT:
      begin
        FTarget.FExitCode := LEvent.ExitProcess.dwExitCode;
        FTarget.FStoppedReason := dsrProcessExit;
        FTarget.FStoppedAddress := 0;
        FTarget.FStarted := False;

        // Signal DAP thread that the process has exited
        SetEvent(FTarget.FStoppedEvent);

        ContinueDebugEvent(LEvent.dwProcessId, LEvent.dwThreadId,
          DBG_CONTINUE);
        Break;
      end;
    end;

    ContinueDebugEvent(LEvent.dwProcessId, LEvent.dwThreadId,
      LContinueStatus);
  end;
end;

//==============================================================================
// TPEDebugTarget
//==============================================================================

constructor TPEDebugTarget.Create();
begin
  inherited Create();
  FExePath := '';
  FProcessHandle := 0;
  FMainThreadHandle := 0;
  FProcessId := 0;
  FMainThreadId := 0;
  FActualImageBase := 0;
  FTextSectionRVA := 0;
  FTextSectionSize := 0;
  FStoppedEvent := 0;
  FResumeEvent := 0;
  FillChar(FCapturedContext, SizeOf(FCapturedContext), 0);
  FStoppedReason := dsrNone;
  FStoppedAddress := 0;
  FStoppedThreadId := 0;
  FStarted := False;
  FExitCode := 0;
  FExceptionCode := 0;
  FInitialBreakpointSeen := False;
  FRepatchOffset := -1;
  FConfigDoneEvent := 0;
  FReadyEvent := 0;
  FLaunchDoneEvent := 0;
  FLaunchPath := '';
  FLaunchSucceeded := False;
  FDebugLoopThread := nil;
  FDllPath := '';
  FHostExePath := '';
  FIsAttachedToDll := False;
  FDllBaseAddress := 0;
  FDllFound := False;
end;

destructor TPEDebugTarget.Destroy();
begin
  Stop();
  inherited Destroy();
end;

//------------------------------------------------------------------------------
// Setup
//------------------------------------------------------------------------------

procedure TPEDebugTarget.SetExePath(const APath: string);
begin
  FExePath := APath;
end;

procedure TPEDebugTarget.SetTextSectionRVA(const ARVA: Cardinal);
begin
  FTextSectionRVA := ARVA;
end;

procedure TPEDebugTarget.SetTextSectionSize(const ASize: Cardinal);
begin
  FTextSectionSize := ASize;
end;

procedure TPEDebugTarget.SetDllMode(const ADllPath: string;
  const AHostExePath: string);
begin
  FDllPath := ADllPath;
  FHostExePath := AHostExePath;
  FIsAttachedToDll := True;
  FDllBaseAddress := 0;
  FDllFound := False;
end;

//------------------------------------------------------------------------------
// Lifecycle
//------------------------------------------------------------------------------

function TPEDebugTarget.Start(): Boolean;
var
  LLaunchPath: string;
begin
  Result := False;

  // In DLL mode, we launch the host EXE (not the DLL itself)
  if FIsAttachedToDll then
  begin
    if FHostExePath = '' then
    begin
      if Assigned(FErrors) then
        FErrors.Add(esFatal, 'DBG010', 'Host EXE path not set for DLL debugging');
      Exit;
    end;
    if not FileExists(FHostExePath) then
    begin
      if Assigned(FErrors) then
        FErrors.Add(esFatal, 'DBG011', 'Host EXE not found: %s', [FHostExePath]);
      Exit;
    end;
    LLaunchPath := FHostExePath;
  end
  else
  begin
    if FExePath = '' then
    begin
      if Assigned(FErrors) then
        FErrors.Add(esFatal, 'DBG010', 'EXE path not set before Start()');
      Exit;
    end;
    if not FileExists(FExePath) then
    begin
      if Assigned(FErrors) then
        FErrors.Add(esFatal, 'DBG011', 'EXE not found: %s', [FExePath]);
      Exit;
    end;
    LLaunchPath := FExePath;
  end;

  // Store launch path for the debug loop thread
  FLaunchPath := LLaunchPath;
  FLaunchSucceeded := False;

  // Create synchronization events
  FStoppedEvent := CreateEvent(nil, False, False, nil);     // Auto-reset
  FResumeEvent := CreateEvent(nil, False, False, nil);      // Auto-reset
  FConfigDoneEvent := CreateEvent(nil, True, False, nil);   // Manual-reset
  FReadyEvent := CreateEvent(nil, True, False, nil);        // Manual-reset
  FLaunchDoneEvent := CreateEvent(nil, True, False, nil);   // Manual-reset

  if (FStoppedEvent = 0) or (FResumeEvent = 0) or
     (FConfigDoneEvent = 0) or (FReadyEvent = 0) or
     (FLaunchDoneEvent = 0) then
  begin
    if Assigned(FErrors) then
      FErrors.Add(esFatal, 'DBG012', 'Failed to create synchronization events');
    Exit;
  end;

  FInitialBreakpointSeen := False;

  // Start the debug loop thread — it will call CreateProcessW
  // (Windows requires WaitForDebugEvent on the same thread as CreateProcessW)
  FDebugLoopThread := TPEDebugLoopThread.Create(Self);
  FDebugLoopThread.Start();

  // Wait for the thread to finish launching the process
  WaitForSingleObject(FLaunchDoneEvent, INFINITE);

  if not FLaunchSucceeded then
  begin
    if Assigned(FErrors) then
      FErrors.Add(esFatal, 'DBG013', 'Debug loop failed to launch process');
    Exit;
  end;

  FStarted := True;
  Result := True;
end;

procedure TPEDebugTarget.Stop();
begin
  if not FStarted then
    Exit;

  FStarted := False;

  // Terminate the debug loop thread
  if FDebugLoopThread <> nil then
  begin
    FDebugLoopThread.Terminate();
    // Unblock the thread if it's waiting on FResumeEvent or FConfigDoneEvent
    if FConfigDoneEvent <> 0 then
      SetEvent(FConfigDoneEvent);
    if FReadyEvent <> 0 then
      SetEvent(FReadyEvent);
    if FLaunchDoneEvent <> 0 then
      SetEvent(FLaunchDoneEvent);
    if FResumeEvent <> 0 then
      SetEvent(FResumeEvent);
    FDebugLoopThread.WaitFor();
    FreeAndNil(FDebugLoopThread);
  end;

  // Terminate the debuggee process if still running
  if FProcessHandle <> 0 then
  begin
    TerminateProcess(FProcessHandle, 1);
    CloseHandle(FProcessHandle);
    FProcessHandle := 0;
  end;

  if FMainThreadHandle <> 0 then
  begin
    CloseHandle(FMainThreadHandle);
    FMainThreadHandle := 0;
  end;

  // Close events
  if FStoppedEvent <> 0 then
  begin
    CloseHandle(FStoppedEvent);
    FStoppedEvent := 0;
  end;
  if FResumeEvent <> 0 then
  begin
    CloseHandle(FResumeEvent);
    FResumeEvent := 0;
  end;
  if FConfigDoneEvent <> 0 then
  begin
    CloseHandle(FConfigDoneEvent);
    FConfigDoneEvent := 0;
  end;
  if FReadyEvent <> 0 then
  begin
    CloseHandle(FReadyEvent);
    FReadyEvent := 0;
  end;
  if FLaunchDoneEvent <> 0 then
  begin
    CloseHandle(FLaunchDoneEvent);
    FLaunchDoneEvent := 0;
  end;
end;

function TPEDebugTarget.IsRunning(): Boolean;
begin
  Result := FStarted;
end;

function TPEDebugTarget.WaitForStop(out AEvent: TDebugStopEvent): Boolean;
begin
  // Block until the debug loop thread signals a stop
  Result := WaitForSingleObject(FStoppedEvent, INFINITE) = WAIT_OBJECT_0;
  if Result then
  begin
    AEvent.Reason := FStoppedReason;
    AEvent.Address := FStoppedAddress;
    if FStoppedAddress <> 0 then
      AEvent.CodeOffset := AddressToCodeOffset(FStoppedAddress)
    else
      AEvent.CodeOffset := 0;
    AEvent.ThreadId := FStoppedThreadId;
    AEvent.ExitCode := FExitCode;
    AEvent.ExceptionCode := FExceptionCode;
    if FStoppedReason = dsrException then
      AEvent.ExceptionMessage := Format('Exception 0x%x at 0x%x',
        [FExceptionCode, FStoppedAddress])
    else
      AEvent.ExceptionMessage := '';
  end;
end;

//------------------------------------------------------------------------------
// Execution Control
//------------------------------------------------------------------------------

procedure TPEDebugTarget.Resume();
begin
  // Signal the debug loop thread to ContinueDebugEvent
  SetEvent(FResumeEvent);
end;

procedure TPEDebugTarget.SetTrapFlag();
begin
  // Set trap flag in captured context — applied when debug loop resumes
  FCapturedContext.EFlags := FCapturedContext.EFlags or TRAP_FLAG;
end;

procedure TPEDebugTarget.ClearTrapFlag();
begin
  FCapturedContext.EFlags := FCapturedContext.EFlags and (not TRAP_FLAG);
end;

//------------------------------------------------------------------------------
// Memory Operations (via ReadProcessMemory / WriteProcessMemory)
//------------------------------------------------------------------------------

function TPEDebugTarget.ReadByte(const AAddress: UInt64): Byte;
var
  LBytesRead: NativeUInt;
begin
  Result := 0;
  if not ReadProcessMemory(FProcessHandle, Pointer(AAddress),
    @Result, 1, LBytesRead) then
  begin
    if Assigned(FErrors) then
      FErrors.Add(esError, 'DBG020',
        'ReadProcessMemory failed at $%x: %s',
        [AAddress, SysErrorMessage(GetLastError())]);
  end;
end;

procedure TPEDebugTarget.WriteByte(const AAddress: UInt64;
  const AValue: Byte);
var
  LBytesWritten: NativeUInt;
begin
  if not WriteProcessMemory(FProcessHandle, Pointer(AAddress),
    @AValue, 1, LBytesWritten) then
  begin
    if Assigned(FErrors) then
      FErrors.Add(esError, 'DBG021',
        'WriteProcessMemory failed at $%x: %s',
        [AAddress, SysErrorMessage(GetLastError())]);
  end;
end;

function TPEDebugTarget.ReadUInt64(const AAddress: UInt64): UInt64;
var
  LBytesRead: NativeUInt;
begin
  Result := 0;
  if not ReadProcessMemory(FProcessHandle, Pointer(AAddress),
    @Result, 8, LBytesRead) then
  begin
    if Assigned(FErrors) then
      FErrors.Add(esError, 'DBG022',
        'ReadProcessMemory (UInt64) failed at $%x: %s',
        [AAddress, SysErrorMessage(GetLastError())]);
  end;
end;

procedure TPEDebugTarget.FlushCode(const AAddress: UInt64;
  const ASize: Cardinal);
begin
  FlushInstructionCache(FProcessHandle, Pointer(AAddress), ASize);
end;

//------------------------------------------------------------------------------
// Thread Context
//------------------------------------------------------------------------------

function TPEDebugTarget.GetContext(): TContext;
begin
  Result := FCapturedContext;
end;

procedure TPEDebugTarget.SetContext(const AContext: TContext);
begin
  FCapturedContext := AContext;
end;

//------------------------------------------------------------------------------
// Address Mapping (handles ASLR)
//------------------------------------------------------------------------------

function TPEDebugTarget.CodeOffsetToAddress(const AOffset: Cardinal): UInt64;
var
  LBase: UInt64;
begin
  // In DLL mode, offsets are relative to DLL's .text section
  if FIsAttachedToDll then
    LBase := FDllBaseAddress
  else
    LBase := FActualImageBase;

  Result := LBase + UInt64(FTextSectionRVA) + UInt64(AOffset);
end;

function TPEDebugTarget.AddressToCodeOffset(const AAddress: UInt64): Cardinal;
var
  LBase: UInt64;
  LTextStart: UInt64;
begin
  if FIsAttachedToDll then
    LBase := FDllBaseAddress
  else
    LBase := FActualImageBase;

  LTextStart := LBase + UInt64(FTextSectionRVA);

  // Guard against underflow: if address is below .text start, return sentinel
  if (AAddress = 0) or (AAddress < LTextStart) then
  begin
    Result := Cardinal($FFFFFFFF);
    Exit;
  end;

  Result := Cardinal(AAddress - LTextStart);
end;

function TPEDebugTarget.IsOurCode(const AAddress: UInt64): Boolean;
var
  LBase: UInt64;
  LTextStart: UInt64;
begin
  if FIsAttachedToDll then
  begin
    // Before DLL is loaded, nothing is "our code"
    if not FDllFound then
      Exit(False);
    LBase := FDllBaseAddress;
  end
  else
    LBase := FActualImageBase;

  LTextStart := LBase + UInt64(FTextSectionRVA);

  // If we know the .text size, use it for precise bounds
  if FTextSectionSize > 0 then
    Result := (AAddress >= LTextStart) and
              (AAddress < LTextStart + UInt64(FTextSectionSize))
  else
    // Without size info, check if address is above .text start
    // and within a reasonable range (16 MB)
    Result := (AAddress >= LTextStart) and
              (AAddress < LTextStart + $1000000);
end;

//------------------------------------------------------------------------------
// Re-patch tracking
//------------------------------------------------------------------------------

procedure TPEDebugTarget.SetRepatchOffset(const AOffset: Integer);
begin
  FRepatchOffset := AOffset;
end;

function TPEDebugTarget.GetRepatchOffset(): Integer;
begin
  Result := FRepatchOffset;
end;

procedure TPEDebugTarget.SignalConfigDone();
begin
  // Release the process held at the initial breakpoint
  if FConfigDoneEvent <> 0 then
    SetEvent(FConfigDoneEvent);
end;

procedure TPEDebugTarget.WaitUntilReady();
var
  LWaitMS: Integer;
begin
  // Poll until the debug loop thread has processed CREATE_PROCESS_DEBUG_EVENT
  // and set FActualImageBase, or timeout after 10 seconds
  LWaitMS := 0;
  while (FActualImageBase = 0) and (LWaitMS < 10000) do
  begin
    Sleep(10);
    Inc(LWaitMS, 10);
  end;
end;

procedure TPEDebugTarget.UnblockWaitForStop();
begin
  // Signal FStoppedEvent so the stop watcher thread can wake up and exit
  if FStoppedEvent <> 0 then
    SetEvent(FStoppedEvent);
end;

end.
