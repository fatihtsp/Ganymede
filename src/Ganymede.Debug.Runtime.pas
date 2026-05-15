{===============================================================================
  Ganymede™ - Embeddable Native Scripting Engine

  Copyright © 2026-present tinyBigGAMES™ LLC
  All Rights Reserved.

  See LICENSE for license information
===============================================================================}

unit Ganymede.Debug.Runtime;

{$I Ganymede.Defines.inc}

interface

uses
  WinApi.Windows,
  System.SysUtils,
  System.Generics.Collections,
  Ganymede.Utils,
  Ganymede.Types,
  Ganymede.Debug.SourceMap,
  Ganymede.Debug.Target;

type
  //============================================================================
  // TBreakpointInfo - A single breakpoint
  //============================================================================
  TBreakpointInfo = record
    ID: Integer;
    SourceFile: string;
    SourceLine: Integer;
    CodeOffset: Cardinal;
    OriginalByte: Byte;
    IsTemporary: Boolean;     // Auto-removed on hit (used for stepping)
    IsEnabled: Boolean;
    IsPatched: Boolean;       // True when INT3 is actually written
    HitCount: Integer;
    Condition: string;        // Expression to evaluate; empty = unconditional
    HitCondition: Integer;    // Break only when HitCount >= this value (0 = ignore)
  end;

  //============================================================================
  // TDebugStackFrame - A single frame in the call stack
  //============================================================================
  TDebugStackFrame = record
    FrameID: Integer;
    FunctionName: string;
    SourceFile: string;
    SourceLine: Integer;
    SourceColumn: Integer;
    CodeOffset: Cardinal;
    RBP: UInt64;
    RIP: UInt64;
  end;

  //============================================================================
  // TDebugVariable - A variable visible at the current stop point
  //============================================================================
  TDebugVariable = record
    VarName: string;
    VarValue: string;
    VarType: string;
    IsParam: Boolean;
  end;

  //============================================================================
  // TBreakpointManager - Manages breakpoints through TDebugTarget.
  // Identical logic for JIT and PE modes.
  //============================================================================

  { TBreakpointManager }
  TBreakpointManager = class(TGnyBaseObject)
  private
    FTarget: TDebugTarget;         // Reference (not owned)
    FSourceMap: TSourceMap;        // Reference (not owned)
    FBreakpoints: TList<TBreakpointInfo>;
    FNextID: Integer;

  public
    constructor Create(); override;
    destructor Destroy(); override;

    procedure SetTarget(const ATarget: TDebugTarget);
    procedure SetSourceMap(const ASourceMap: TSourceMap);

    // Set/remove breakpoints
    function SetBreakpoint(const AFile: string; const ALine: Integer;
      const ACondition: string = ''; const AHitCondition: Integer = 0): Integer;
    function RemoveBreakpoint(const AID: Integer): Boolean;
    function SetTempBreakpoint(const AOffset: Cardinal): Integer;
    procedure RemoveAllTemp();
    procedure RemoveAll();

    // Query
    function IsOurBreakpoint(const AOffset: Cardinal): Boolean;
    function GetBreakpointAt(const AOffset: Cardinal; out AInfo: TBreakpointInfo): Boolean;
    function GetBreakpointByID(const AID: Integer; out AInfo: TBreakpointInfo): Boolean;
    function GetBreakpointCount(): Integer;
    function GetBreakpoint(const AIndex: Integer): TBreakpointInfo;

    // Patching (applies/removes INT3 bytes)
    procedure ApplyAll();
    procedure PatchBreakpoint(const AIndex: Integer);
    procedure UnpatchBreakpoint(const AIndex: Integer);
  end;

  //============================================================================
  // TStackWalker - Walks the RBP chain to build a call stack.
  // Works through TDebugTarget so it's identical for JIT and PE.
  //============================================================================

  { TStackWalker }
  TStackWalker = class(TGnyBaseObject)
  public
    function WalkStack(const ATarget: TDebugTarget;
      const ASourceMap: TSourceMap;
      const AContext: TContext): TArray<TDebugStackFrame>;
  end;

  //============================================================================
  // TDebugRuntime - Coordinates breakpoints, stepping, and stack walking.
  // This is the main debug logic layer between TDebugTarget and the DAP server.
  //============================================================================

  { TDebugRuntime }
  TDebugRuntime = class(TGnyBaseObject)
  private
    FTarget: TDebugTarget;              // Reference (not owned)
    FSourceMap: TSourceMap;             // Reference (not owned)
    FBreakpoints: TBreakpointManager;   // Owned
    FStackWalker: TStackWalker;         // Owned
    FLastStopEvent: TDebugStopEvent;

  public
    constructor Create(); override;
    destructor Destroy(); override;

    procedure SetTarget(const ATarget: TDebugTarget);
    procedure SetSourceMap(const ASourceMap: TSourceMap);

    // Breakpoint management (delegates to FBreakpoints)
    function SetBreakpoint(const AFile: string; const ALine: Integer;
      const ACondition: string = ''; const AHitCondition: Integer = 0): Integer;
    function RemoveBreakpoint(const AID: Integer): Boolean;

    // Execution control
    function Continue(): Boolean;
    function StepOver(): Boolean;
    function StepIn(): Boolean;
    function StepOut(): Boolean;
    function WaitForStop(): Boolean;

    // DAP lifecycle
    procedure ConfigurationDone();

    // Inspection
    function GetCallStack(): TArray<TDebugStackFrame>;
    function GetLastStopEvent(): TDebugStopEvent;
    function GetVariables(): TArray<TDebugVariable>;
    function Evaluate(const AExpression: string): TDebugVariable;

    // Access
    function GetBreakpoints(): TBreakpointManager;
    function GetTarget(): TDebugTarget;
    function GetSourceMap(): TSourceMap;
  end;

implementation

//==============================================================================
// TBreakpointManager
//==============================================================================

constructor TBreakpointManager.Create();
begin
  inherited Create();
  FTarget := nil;
  FSourceMap := nil;
  FBreakpoints := TList<TBreakpointInfo>.Create();
  FNextID := 1;
end;

destructor TBreakpointManager.Destroy();
begin
  RemoveAll();
  FBreakpoints.Free();
  inherited Destroy();
end;

procedure TBreakpointManager.SetTarget(const ATarget: TDebugTarget);
begin
  FTarget := ATarget;
end;

procedure TBreakpointManager.SetSourceMap(const ASourceMap: TSourceMap);
begin
  FSourceMap := ASourceMap;
end;

function TBreakpointManager.SetBreakpoint(const AFile: string;
  const ALine: Integer; const ACondition: string;
  const AHitCondition: Integer): Integer;
var
  LInfo: TBreakpointInfo;
  LOffset: Cardinal;
begin
  Result := -1;

  if (FTarget = nil) or (FSourceMap = nil) then
    Exit;

  // Resolve source line to code offset
  LOffset := FSourceMap.SourceLineToOffset(AFile, ALine);
  if LOffset = Cardinal($FFFFFFFF) then
  begin
    if Assigned(FErrors) then
      FErrors.Add(esWarning, 'DBG010',
        'No code at %s:%d', [AFile, ALine]);
    Exit;
  end;

  // Create breakpoint record (don't read memory yet — FActualImageBase
  // may not be set during initial config phase; PatchBreakpoint reads
  // the original byte when ApplyAll runs)
  LInfo.ID := FNextID;
  Inc(FNextID);
  LInfo.SourceFile := AFile;
  LInfo.SourceLine := ALine;
  LInfo.CodeOffset := LOffset;
  LInfo.OriginalByte := 0;
  LInfo.IsTemporary := False;
  LInfo.IsEnabled := True;
  LInfo.IsPatched := False;
  LInfo.HitCount := 0;
  LInfo.Condition := ACondition;
  LInfo.HitCondition := AHitCondition;

  FBreakpoints.Add(LInfo);

  // Don't patch here — ApplyAll() handles patching at the right time:
  //   - Initial breakpoints: patched during ConfigurationDone (process is
  //     suspended at loader breakpoint, FActualImageBase is guaranteed set)
  //   - Runtime breakpoints: patched via ApplyAll after the stop is processed

  Result := LInfo.ID;
end;

function TBreakpointManager.RemoveBreakpoint(const AID: Integer): Boolean;
var
  LI: Integer;
begin
  Result := False;
  for LI := 0 to FBreakpoints.Count - 1 do
  begin
    if FBreakpoints[LI].ID = AID then
    begin
      // Restore original byte if patched
      if FBreakpoints[LI].IsPatched then
        UnpatchBreakpoint(LI);
      FBreakpoints.Delete(LI);
      Result := True;
      Exit;
    end;
  end;
end;

function TBreakpointManager.SetTempBreakpoint(const AOffset: Cardinal): Integer;
var
  LInfo: TBreakpointInfo;
  LAddr: UInt64;
begin
  if FTarget = nil then
    Exit(-1);

  LAddr := FTarget.CodeOffsetToAddress(AOffset);

  LInfo.ID := FNextID;
  Inc(FNextID);
  LInfo.SourceFile := '';
  LInfo.SourceLine := 0;
  LInfo.CodeOffset := AOffset;
  LInfo.OriginalByte := FTarget.ReadByte(LAddr);
  LInfo.IsTemporary := True;
  LInfo.IsEnabled := True;
  LInfo.IsPatched := False;
  LInfo.HitCount := 0;
  LInfo.Condition := '';
  LInfo.HitCondition := 0;

  FBreakpoints.Add(LInfo);
  PatchBreakpoint(FBreakpoints.Count - 1);

  Result := LInfo.ID;
end;

procedure TBreakpointManager.RemoveAllTemp();
var
  LI: Integer;
begin
  for LI := FBreakpoints.Count - 1 downto 0 do
  begin
    if FBreakpoints[LI].IsTemporary then
    begin
      if FBreakpoints[LI].IsPatched then
        UnpatchBreakpoint(LI);
      FBreakpoints.Delete(LI);
    end;
  end;
end;

procedure TBreakpointManager.RemoveAll();
var
  LI: Integer;
begin
  for LI := FBreakpoints.Count - 1 downto 0 do
  begin
    if FBreakpoints[LI].IsPatched then
      UnpatchBreakpoint(LI);
  end;
  FBreakpoints.Clear();
end;

function TBreakpointManager.IsOurBreakpoint(const AOffset: Cardinal): Boolean;
var
  LI: Integer;
begin
  Result := False;
  for LI := 0 to FBreakpoints.Count - 1 do
  begin
    if FBreakpoints[LI].IsEnabled and (FBreakpoints[LI].CodeOffset = AOffset) then
      Exit(True);
  end;
end;

function TBreakpointManager.GetBreakpointAt(const AOffset: Cardinal;
  out AInfo: TBreakpointInfo): Boolean;
var
  LI: Integer;
begin
  Result := False;
  for LI := 0 to FBreakpoints.Count - 1 do
  begin
    if FBreakpoints[LI].CodeOffset = AOffset then
    begin
      AInfo := FBreakpoints[LI];
      Result := True;
      Exit;
    end;
  end;
end;

function TBreakpointManager.GetBreakpointByID(const AID: Integer;
  out AInfo: TBreakpointInfo): Boolean;
var
  LI: Integer;
begin
  Result := False;
  for LI := 0 to FBreakpoints.Count - 1 do
  begin
    if FBreakpoints[LI].ID = AID then
    begin
      AInfo := FBreakpoints[LI];
      Result := True;
      Exit;
    end;
  end;
end;

function TBreakpointManager.GetBreakpointCount(): Integer;
begin
  Result := FBreakpoints.Count;
end;

function TBreakpointManager.GetBreakpoint(const AIndex: Integer): TBreakpointInfo;
begin
  Result := FBreakpoints[AIndex];
end;

//------------------------------------------------------------------------------
// Breakpoint Patching
//------------------------------------------------------------------------------

procedure TBreakpointManager.ApplyAll();
var
  LI: Integer;
begin
  for LI := 0 to FBreakpoints.Count - 1 do
  begin
    if FBreakpoints[LI].IsEnabled and (not FBreakpoints[LI].IsPatched) then
      PatchBreakpoint(LI);
  end;
end;

procedure TBreakpointManager.PatchBreakpoint(const AIndex: Integer);
var
  LInfo: TBreakpointInfo;
  LAddr: UInt64;
begin
  LInfo := FBreakpoints[AIndex];
  if LInfo.IsPatched then
    Exit;

  LAddr := FTarget.CodeOffsetToAddress(LInfo.CodeOffset);

  // Save original byte and write INT3
  LInfo.OriginalByte := FTarget.ReadByte(LAddr);
  FTarget.WriteByte(LAddr, INT3_OPCODE);
  FTarget.FlushCode(LAddr, 1);
  LInfo.IsPatched := True;

  FBreakpoints[AIndex] := LInfo;
end;

procedure TBreakpointManager.UnpatchBreakpoint(const AIndex: Integer);
var
  LInfo: TBreakpointInfo;
  LAddr: UInt64;
begin
  LInfo := FBreakpoints[AIndex];
  if not LInfo.IsPatched then
    Exit;

  LAddr := FTarget.CodeOffsetToAddress(LInfo.CodeOffset);

  // Restore original byte
  FTarget.WriteByte(LAddr, LInfo.OriginalByte);
  FTarget.FlushCode(LAddr, 1);
  LInfo.IsPatched := False;

  FBreakpoints[AIndex] := LInfo;
end;

//==============================================================================
// TStackWalker
//==============================================================================

function TStackWalker.WalkStack(const ATarget: TDebugTarget;
  const ASourceMap: TSourceMap;
  const AContext: TContext): TArray<TDebugStackFrame>;
var
  LFrame: TDebugStackFrame;
  LFrameID: Integer;
  LRIP: UInt64;
  LRBP: UInt64;
  LOffset: Cardinal;
  LEntry: TSourceMapEntry;
  LFound: Boolean;
begin
  SetLength(Result, 0);
  LFrameID := 0;
  LRIP := AContext.Rip;
  LRBP := AContext.Rbp;

  while ATarget.IsOurCode(LRIP) do
  begin
    LOffset := ATarget.AddressToCodeOffset(LRIP);
    LFound := ASourceMap.OffsetToEntry(LOffset, LEntry);

    LFrame.FrameID := LFrameID;
    LFrame.CodeOffset := LOffset;
    LFrame.RBP := LRBP;
    LFrame.RIP := LRIP;

    if LFound then
    begin
      LFrame.FunctionName := ASourceMap.GetFunctionAtOffset(LOffset);
      LFrame.SourceFile := ASourceMap.GetSourceFile(LEntry.SourceFileIndex);
      LFrame.SourceLine := LEntry.SourceLine;
      LFrame.SourceColumn := LEntry.SourceColumn;
    end
    else
    begin
      LFrame.FunctionName := Format('0x%x', [LRIP]);
      LFrame.SourceFile := '';
      LFrame.SourceLine := 0;
      LFrame.SourceColumn := 0;
    end;

    Result := Result + [LFrame];
    Inc(LFrameID);

    // Walk up one frame via RBP chain
    // Standard x64 frame: [RBP] = saved RBP, [RBP+8] = return address
    if LRBP = 0 then
      Break;

    try
      LRIP := ATarget.ReadUInt64(LRBP + 8);  // Saved return address
      LRBP := ATarget.ReadUInt64(LRBP);       // Saved RBP
    except
      // Memory read failed — end of valid stack
      Break;
    end;

    // Safety: stop if we've gone too deep or RBP is zero/invalid
    if (LRBP = 0) or (LFrameID > 256) then
      Break;
  end;
end;

//==============================================================================
// TDebugRuntime
//==============================================================================

constructor TDebugRuntime.Create();
begin
  inherited Create();
  FTarget := nil;
  FSourceMap := nil;
  FBreakpoints := TBreakpointManager.Create();
  FStackWalker := TStackWalker.Create();
  FillChar(FLastStopEvent, SizeOf(FLastStopEvent), 0);
end;

destructor TDebugRuntime.Destroy();
begin
  FStackWalker.Free();
  FBreakpoints.Free();
  inherited Destroy();
end;

procedure TDebugRuntime.SetTarget(const ATarget: TDebugTarget);
begin
  FTarget := ATarget;
  FBreakpoints.SetTarget(ATarget);
end;

procedure TDebugRuntime.SetSourceMap(const ASourceMap: TSourceMap);
begin
  FSourceMap := ASourceMap;
  FBreakpoints.SetSourceMap(ASourceMap);
end;

//------------------------------------------------------------------------------
// Breakpoint delegation
//------------------------------------------------------------------------------

function TDebugRuntime.SetBreakpoint(const AFile: string;
  const ALine: Integer; const ACondition: string;
  const AHitCondition: Integer): Integer;
begin
  Result := FBreakpoints.SetBreakpoint(AFile, ALine, ACondition, AHitCondition);
end;

function TDebugRuntime.RemoveBreakpoint(const AID: Integer): Boolean;
begin
  Result := FBreakpoints.RemoveBreakpoint(AID);
end;

//------------------------------------------------------------------------------
// DAP Lifecycle
//------------------------------------------------------------------------------

procedure TDebugRuntime.ConfigurationDone();
begin
  // Wait until the debug loop thread has reached the initial breakpoint
  // (FActualImageBase is set, process memory is accessible)
  if FTarget <> nil then
    FTarget.WaitUntilReady();

  // Apply all breakpoints while the process is still held at the loader breakpoint
  FBreakpoints.ApplyAll();

  // Activate VEH interception — breakpoints are patched, safe to intercept now
  if FTarget <> nil then
    FTarget.SetDebugActive(True);

  // Signal the target to release the process
  if FTarget <> nil then
    FTarget.SignalConfigDone();
end;

//------------------------------------------------------------------------------
// Execution Control
//------------------------------------------------------------------------------

function TDebugRuntime.Continue(): Boolean;
var
  LBPInfo: TBreakpointInfo;
  LOffset: Cardinal;
  LContext: TContext;
begin
  Result := False;
  if FTarget = nil then
    Exit;

  LContext := FTarget.GetContext();

  // Guard: if no valid stop context yet (Rip=0), just resume without
  // trying to step past a breakpoint — there's nothing to step past
  if LContext.Rip = 0 then
  begin
    FTarget.Resume();
    Result := True;
    Exit;
  end;

  LOffset := FTarget.AddressToCodeOffset(LContext.Rip);

  // If we're stopped at a breakpoint, we need to step past it first:
  // 1. Restore original byte
  // 2. Set trap flag for single-step
  // 3. Tell target to re-patch after the single-step
  if FBreakpoints.GetBreakpointAt(LOffset, LBPInfo) and LBPInfo.IsPatched then
  begin
    // Restore original byte so we can execute the real instruction
    FTarget.WriteByte(FTarget.CodeOffsetToAddress(LOffset), LBPInfo.OriginalByte);
    FTarget.FlushCode(FTarget.CodeOffsetToAddress(LOffset), 1);

    // Set trap flag — after executing one instruction, the single-step
    // exception fires and the VEH handler re-patches the INT3
    FTarget.SetTrapFlag();

    // Tell the target to re-patch at this offset after single-step
    FTarget.SetRepatchOffset(Integer(LOffset));
  end;

  // Resume execution
  FTarget.Resume();
  Result := True;
end;

function TDebugRuntime.StepOver(): Boolean;
var
  LContext: TContext;
  LCurrentOffset: Cardinal;
  LNextOffset: Cardinal;
begin
  Result := False;
  if (FTarget = nil) or (FSourceMap = nil) then
    Exit;

  LContext := FTarget.GetContext();
  LCurrentOffset := FTarget.AddressToCodeOffset(LContext.Rip);

  // Find the next source line offset within the same function
  LNextOffset := FSourceMap.GetNextLineOffset(LCurrentOffset);
  if LNextOffset = Cardinal($FFFFFFFF) then
  begin
    // No next line in this function — do a step-out instead
    Result := StepOut();
    Exit;
  end;

  // Set a temporary breakpoint at the next line
  FBreakpoints.SetTempBreakpoint(LNextOffset);

  // Continue execution (handles stepping past current breakpoint)
  Result := Continue();
end;

function TDebugRuntime.StepIn(): Boolean;
var
  LContext: TContext;
  LAddr: UInt64;
  LOpcode: Byte;
  LRel32: Int32;
  LCallTarget: UInt64;
  LTargetOffset: Cardinal;
begin
  Result := False;
  if (FTarget = nil) or (FSourceMap = nil) then
    Exit;

  LContext := FTarget.GetContext();
  LAddr := LContext.Rip;

  // Check if current instruction is a CALL rel32 (opcode E8)
  // This is the most common call form in Viper-generated code
  LOpcode := FTarget.ReadByte(LAddr);
  if LOpcode = $E8 then
  begin
    // Read the 32-bit relative displacement
    LRel32 := Int32(FTarget.ReadByte(LAddr + 1)) or
              (Int32(FTarget.ReadByte(LAddr + 2)) shl 8) or
              (Int32(FTarget.ReadByte(LAddr + 3)) shl 16) or
              (Int32(FTarget.ReadByte(LAddr + 4)) shl 24);

    // CALL rel32: target = RIP + 5 + rel32
    LCallTarget := LAddr + 5 + UInt64(LRel32);

    // Only step into if the target is within our code
    if FTarget.IsOurCode(LCallTarget) then
    begin
      LTargetOffset := FTarget.AddressToCodeOffset(LCallTarget);
      FBreakpoints.SetTempBreakpoint(LTargetOffset);
      Result := Continue();
      Exit;
    end;
  end;

  // Not a CALL we can decode, or target is external — fall back to StepOver
  Result := StepOver();
end;

function TDebugRuntime.StepOut(): Boolean;
var
  LContext: TContext;
  LReturnAddr: UInt64;
  LReturnOffset: Cardinal;
begin
  Result := False;
  if FTarget = nil then
    Exit;

  LContext := FTarget.GetContext();

  // Read return address from [RBP+8] (standard x64 frame)
  if LContext.Rbp = 0 then
    Exit;  // No valid frame pointer

  try
    LReturnAddr := FTarget.ReadUInt64(LContext.Rbp + 8);
  except
    Exit;  // Memory read failed
  end;

  // Only set breakpoint if return address is in our code
  if not FTarget.IsOurCode(LReturnAddr) then
  begin
    // Returning to non-Viper code — just continue
    Result := Continue();
    Exit;
  end;

  LReturnOffset := FTarget.AddressToCodeOffset(LReturnAddr);
  FBreakpoints.SetTempBreakpoint(LReturnOffset);
  Result := Continue();
end;

function TDebugRuntime.WaitForStop(): Boolean;
var
  LEvent: TDebugStopEvent;
  LBPInfo: TBreakpointInfo;
  LI: Integer;
  LFound: Boolean;
  LShouldBreak: Boolean;
  LCondVar: TDebugVariable;
begin
  Result := False;
  if FTarget = nil then
    Exit;

  while True do
  begin
    if not FTarget.WaitForStop(LEvent) then
      Exit;

    // DLL load event: apply breakpoints and resume transparently
    if LEvent.Reason = dsrDllLoad then
    begin
      FBreakpoints.ApplyAll();
      FTarget.Resume();
      Continue;  // Loop back to wait for the next stop
    end;

    FLastStopEvent := LEvent;

    // If we stopped at a breakpoint, update hit count and check conditions
    if LEvent.Reason = dsrBreakpoint then
    begin
      LFound := False;
      LShouldBreak := True;

      for LI := 0 to FBreakpoints.GetBreakpointCount() - 1 do
      begin
        if FBreakpoints.GetBreakpoint(LI).CodeOffset = LEvent.CodeOffset then
        begin
          LBPInfo := FBreakpoints.GetBreakpoint(LI);
          Inc(LBPInfo.HitCount);
          FBreakpoints.FBreakpoints[LI] := LBPInfo;
          LFound := True;

          // Check hit condition (break only when HitCount >= threshold)
          if (LBPInfo.HitCondition > 0) and
             (LBPInfo.HitCount < LBPInfo.HitCondition) then
            LShouldBreak := False;

          // Check expression condition (evaluate variable, skip if falsy)
          if LShouldBreak and (LBPInfo.Condition <> '') then
          begin
            LCondVar := Evaluate(LBPInfo.Condition);
            if (LCondVar.VarValue = '') or
               (LCondVar.VarValue = '0') or
               SameText(LCondVar.VarValue, 'false') then
              LShouldBreak := False;
          end;

          Break;
        end;
      end;

      // Condition not met — silently resume and wait for next stop
      if LFound and (not LShouldBreak) then
      begin
        FBreakpoints.RemoveAllTemp();
        Self.Continue();
        Continue;  // Loop back to WaitForStop
      end;
    end;

    // All conditions met (or not a conditional breakpoint) — stop here
    Break;
  end;

  // Remove temporary breakpoints (used by stepping)
  FBreakpoints.RemoveAllTemp();

  Result := True;
end;

//------------------------------------------------------------------------------
// Inspection
//------------------------------------------------------------------------------

function TDebugRuntime.GetCallStack(): TArray<TDebugStackFrame>;
var
  LContext: TContext;
begin
  if (FTarget = nil) or (FSourceMap = nil) then
  begin
    SetLength(Result, 0);
    Exit;
  end;

  LContext := FTarget.GetContext();
  Result := FStackWalker.WalkStack(FTarget, FSourceMap, LContext);
end;

function TDebugRuntime.GetLastStopEvent(): TDebugStopEvent;
begin
  Result := FLastStopEvent;
end;

function TDebugRuntime.GetVariables(): TArray<TDebugVariable>;
var
  LFuncIndex: Integer;
  LVars: TArray<TVariableLocation>;
  LI: Integer;
  LContext: TContext;
  LAddress: UInt64;
  LBytes: TBytes;
  LSize: Integer;
  LVar: TVariableLocation;
  LResult: TDebugVariable;
  LResultList: TList<TDebugVariable>;
begin
  Result := nil;
  if (FTarget = nil) or (FSourceMap = nil) then
    Exit;

  // Find which function we stopped in
  LFuncIndex := FSourceMap.GetFunctionIndexAtOffset(FLastStopEvent.CodeOffset);
  if LFuncIndex < 0 then
    Exit;

  // Get variables declared in this function
  LVars := FSourceMap.GetVariablesForFunction(LFuncIndex);
  if Length(LVars) = 0 then
    Exit;

  // Capture thread context for RBP
  LContext := FTarget.GetContext();

  LResultList := TList<TDebugVariable>.Create();
  try
    for LI := 0 to High(LVars) do
    begin
      LVar := LVars[LI];
      LResult.VarName := LVar.VarName;
      LResult.IsParam := LVar.IsParam;

      // Determine byte size from type
      case LVar.VarType of
        vtInt8, vtUInt8:   LSize := 1;
        vtInt16, vtUInt16: LSize := 2;
        vtInt32, vtUInt32, vtFloat32: LSize := 4;
        vtInt64, vtUInt64, vtFloat64, vtPointer: LSize := 8;
      else
        LSize := 8;
      end;

      // Type name string for DAP
      case LVar.VarType of
        vtVoid:    LResult.VarType := 'void';
        vtInt8:    LResult.VarType := 'i8';
        vtInt16:   LResult.VarType := 'i16';
        vtInt32:   LResult.VarType := 'i32';
        vtInt64:   LResult.VarType := 'i64';
        vtUInt8:   LResult.VarType := 'u8';
        vtUInt16:  LResult.VarType := 'u16';
        vtUInt32:  LResult.VarType := 'u32';
        vtUInt64:  LResult.VarType := 'u64';
        vtFloat32: LResult.VarType := 'f32';
        vtFloat64: LResult.VarType := 'f64';
        vtPointer: LResult.VarType := 'ptr';
      else
        LResult.VarType := 'unknown';
      end;

      // Read value from stack
      LResult.VarValue := '???';
      if LVar.LocationKind = vlkStack then
      begin
        LAddress := UInt64(Int64(LContext.Rbp) + LVar.StackOffset);
        try
          LBytes := FTarget.ReadBytes(LAddress, Cardinal(LSize));
          if Length(LBytes) = LSize then
          begin
            case LVar.VarType of
              vtInt8:
                LResult.VarValue := IntToStr(ShortInt(LBytes[0]));
              vtUInt8:
                LResult.VarValue := IntToStr(LBytes[0]);
              vtInt16:
                LResult.VarValue := IntToStr(SmallInt(PWord(@LBytes[0])^));
              vtUInt16:
                LResult.VarValue := IntToStr(PWord(@LBytes[0])^);
              vtInt32:
                LResult.VarValue := IntToStr(PInteger(@LBytes[0])^);
              vtUInt32:
                LResult.VarValue := IntToStr(PCardinal(@LBytes[0])^);
              vtInt64:
                LResult.VarValue := IntToStr(PInt64(@LBytes[0])^);
              vtUInt64:
                LResult.VarValue := UIntToStr(PUInt64(@LBytes[0])^);
              vtFloat32:
                LResult.VarValue := FormatFloat('0.######', PSingle(@LBytes[0])^);
              vtFloat64:
                LResult.VarValue := FormatFloat('0.##############', PDouble(@LBytes[0])^);
              vtPointer:
                LResult.VarValue := Format('0x%x', [PUInt64(@LBytes[0])^]);
            else
              LResult.VarValue := Format('0x%x', [PUInt64(@LBytes[0])^]);
            end;
          end;
        except
          // ReadBytes failed (invalid address, process gone, etc.)
          LResult.VarValue := '<unreadable>';
        end;
      end;

      LResultList.Add(LResult);
    end;

    Result := LResultList.ToArray();
  finally
    LResultList.Free();
  end;
end;

//------------------------------------------------------------------------------
// Expression evaluation — looks up a single variable by name in current frame
//------------------------------------------------------------------------------

function TDebugRuntime.Evaluate(const AExpression: string): TDebugVariable;
var
  LVars: TArray<TDebugVariable>;
  LI: Integer;
  LExpr: string;
begin
  // Default: not found
  Result.VarName := AExpression;
  Result.VarValue := '';
  Result.VarType := '';
  Result.IsParam := False;

  LExpr := Trim(AExpression);
  if LExpr = '' then
    Exit;

  // Get all variables for the current frame, then filter by name
  LVars := GetVariables();
  for LI := 0 to High(LVars) do
  begin
    if SameText(LVars[LI].VarName, LExpr) then
    begin
      Result := LVars[LI];
      Exit;
    end;
  end;
end;

//------------------------------------------------------------------------------
// Accessors
//------------------------------------------------------------------------------

function TDebugRuntime.GetBreakpoints(): TBreakpointManager;
begin
  Result := FBreakpoints;
end;

function TDebugRuntime.GetTarget(): TDebugTarget;
begin
  Result := FTarget;
end;

function TDebugRuntime.GetSourceMap(): TSourceMap;
begin
  Result := FSourceMap;
end;

end.
