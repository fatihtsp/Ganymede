{===============================================================================
  Ganymede™ - Embeddable Native Scripting Engine

  Copyright © 2026-present tinyBigGAMES™ LLC
  All Rights Reserved.

  See LICENSE for license information
===============================================================================}


unit Ganymede.Runtime;

{$I Ganymede.Defines.inc}

interface

uses
  Ganymede.Types,
  Ganymede.IR;

//------------------------------------------------------------------------------
// Compile-time helpers for print/println
// Called from codegen to emit printf calls with correct arguments
//------------------------------------------------------------------------------
procedure viper_write(const AIR: TIR; const AArgs: array of TIRExpr);
procedure viper_writeln(const AIR: TIR; const AArgs: array of TIRExpr);

type
  //============================================================================
  // TRuntime - Base runtime class with virtual methods for platform-
  // specific runtime library injection into the IR.
  //============================================================================

  { TRuntime }
  TRuntime = class
  public
    procedure AddAll(const AIR: TIR; const AOptLevel: Integer);
    procedure AddSystem(const AIR: TIR; const AOptLevel: Integer);
    procedure AddIO(const AIR: TIR);
    procedure AddMemory(const AIR: TIR; const AOptLevel: Integer);
    procedure AddStrings(const AIR: TIR);
    procedure AddTypes(const AIR: TIR);
    procedure AddIntrinsics(const AIR: TIR);
    procedure AddExceptions(const AIR: TIR);
    procedure AddCommandLine(const AIR: TIR);
  end;

implementation

//------------------------------------------------------------------------------
// Compile-time helpers for print/println
//------------------------------------------------------------------------------

procedure viper_write(const AIR: TIR; const AArgs: array of TIRExpr);
begin
  if Length(AArgs) > 0 then
    AIR.Call('printf', AArgs);
end;

procedure viper_writeln(const AIR: TIR; const AArgs: array of TIRExpr);
begin
  if Length(AArgs) > 0 then
    AIR.Call('printf', AArgs);
  AIR.Call('printf', [AIR.Str(#10)]);
end;

//==============================================================================
// TRuntime - System Essentials
//==============================================================================
procedure TRuntime.AddAll(const AIR: TIR; const AOptLevel: Integer);
begin
  AddIO(AIR);
  AddMemory(AIR, AOptLevel);
  AddStrings(AIR);
  AddIntrinsics(AIR);
  AddExceptions(AIR);
  AddCommandLine(AIR);
  AddSystem(AIR, AOptLevel);
end;


procedure TRuntime.AddSystem(const AIR: TIR; const AOptLevel: Integer);
begin
  //----------------------------------------------------------------------------
  // Import Windows system functions
  //----------------------------------------------------------------------------
  AIR.Import('kernel32.dll', 'ExitProcess', [gvtUInt32], gvtVoid, False);

  //----------------------------------------------------------------------------
  // Gny_Halt(AExitCode: Int32)
  // Terminates the process with the specified exit code.
  // At opt level 0, calls Gny_ReportLeaks before ExitProcess for heap
  // leak detection in debug builds.
  //----------------------------------------------------------------------------
  AIR.Func('Gny_Halt', gvtVoid, False, plC, False)
     .Param('AExitCode', gvtInt32);
  // Free command line args before leak reporting
  AIR.Call('Gny_FreeCommandLine', []);
  if AOptLevel = 0 then
    AIR.Call('Gny_ReportLeaks', []);
  AIR.Call('ExitProcess', [AIR.Get('AExitCode')])
  .EndFunc();
end;

//==============================================================================
// TRuntime - I/O
//==============================================================================

procedure TRuntime.AddIO(const AIR: TIR);
begin
  //----------------------------------------------------------------------------
  // Import C runtime printf (variadic) - used by viper_write/viper_writeln helpers
  //----------------------------------------------------------------------------
  AIR.Import('msvcrt.dll', 'printf', [gvtPointer], gvtInt32, True);

  //----------------------------------------------------------------------------
  // Import Windows console functions for UTF-8 support
  //----------------------------------------------------------------------------
  AIR.Import('kernel32.dll', 'SetConsoleOutputCP', [gvtUInt32], gvtInt32, False);
  AIR.Import('kernel32.dll', 'SetConsoleCP', [gvtUInt32], gvtInt32, False);

  //----------------------------------------------------------------------------
  // Gny_InitConsole()
  // Initializes the console for UTF-8 output. Called at program startup.
  //----------------------------------------------------------------------------
  AIR.Func('Gny_InitConsole', gvtVoid, False, plC, True)
     // Set console output code page to UTF-8 (65001)
     .Call('SetConsoleOutputCP', [AIR.MakeInt64(65001)])
     // Set console input code page to UTF-8 (65001)
     .Call('SetConsoleCP', [AIR.MakeInt64(65001)])
     .Return()
  .EndFunc();
end;

//==============================================================================
// TRuntime - Memory Management
//==============================================================================

procedure TRuntime.AddMemory(const AIR: TIR; const AOptLevel: Integer);
begin
  //----------------------------------------------------------------------------
  // Import Windows heap functions
  //----------------------------------------------------------------------------
  AIR.Import('kernel32.dll', 'GetProcessHeap', [], gvtPointer, False);
  AIR.Import('kernel32.dll', 'HeapAlloc', [gvtPointer, gvtUInt32, gvtUInt64], gvtPointer, False);
  AIR.Import('kernel32.dll', 'HeapFree', [gvtPointer, gvtUInt32, gvtPointer], gvtInt32, False);
  AIR.Import('kernel32.dll', 'HeapReAlloc', [gvtPointer, gvtUInt32, gvtPointer, gvtUInt64], gvtPointer, False);
  AIR.Import('kernel32.dll', 'HeapSize', [gvtPointer, gvtUInt32, gvtPointer], gvtUInt64, False);

  //----------------------------------------------------------------------------
  // Debug heap tracking (only when optimization level = 0)
  //----------------------------------------------------------------------------
  if AOptLevel = 0 then
  begin
    AIR.Global('Gny_AllocCount', gvtUInt64);
    AIR.Global('Gny_FreeCount', gvtUInt64);
  end;

  //----------------------------------------------------------------------------
  // Gny_GetMem(ASize: UInt64): Pointer
  // Allocates ASize bytes from the process heap
  //----------------------------------------------------------------------------
  AIR.Func('Gny_GetMem', gvtPointer, False, plC, False)
     .Param('ASize', gvtUInt64)
     .Local('LHeap', gvtPointer)
     .Local('LResult', gvtPointer);

  AIR.Assign('LHeap', AIR.Invoke('GetProcessHeap', []));
  AIR.Assign('LResult', AIR.Invoke('HeapAlloc', [AIR.Get('LHeap'), AIR.MakeInt64(0), AIR.Get('ASize')]));

  if AOptLevel = 0 then
    AIR.Assign('Gny_AllocCount', AIR.Add(AIR.Get('Gny_AllocCount'), AIR.MakeInt64(1)));

  AIR.Return(AIR.Get('LResult'));
  AIR.EndFunc();

  //----------------------------------------------------------------------------
  // Gny_FreeMem(APtr: Pointer)
  // Frees memory previously allocated by Gny_GetMem
  //----------------------------------------------------------------------------
  AIR.Func('Gny_FreeMem', gvtVoid, False, plC, False)
     .Param('APtr', gvtPointer)
     .Local('LHeap', gvtPointer);

  // Guard: do nothing if pointer is nil
  AIR.When(AIR.Eq(AIR.Get('APtr'), AIR.Null()))
     .Return()
  .EndWhen();

  AIR.Assign('LHeap', AIR.Invoke('GetProcessHeap', []));
  AIR.Call('HeapFree', [AIR.Get('LHeap'), AIR.MakeInt64(0), AIR.Get('APtr')]);

  if AOptLevel = 0 then
    AIR.Assign('Gny_FreeCount', AIR.Add(AIR.Get('Gny_FreeCount'), AIR.MakeInt64(1)));

  AIR.Return();
  AIR.EndFunc();

  //----------------------------------------------------------------------------
  // Gny_ReAllocMem(APtr: Pointer; ANewSize: UInt64): Pointer
  // Reallocates memory block to new size
  //----------------------------------------------------------------------------
  AIR.Func('Gny_ReAllocMem', gvtPointer, False, plC, False)
     .Param('APtr', gvtPointer)
     .Param('ANewSize', gvtUInt64)
     .Local('LHeap', gvtPointer)
     .Assign('LHeap', AIR.Invoke('GetProcessHeap', []))
     .Return(AIR.Invoke('HeapReAlloc', [AIR.Get('LHeap'), AIR.MakeInt64(0), AIR.Get('APtr'), AIR.Get('ANewSize')]))
  .EndFunc();

  //----------------------------------------------------------------------------
  // Gny_AllocMem(ASize: UInt64): Pointer
  // Allocates and zero-initializes memory (uses HEAP_ZERO_MEMORY = 0x08)
  //----------------------------------------------------------------------------
  AIR.Func('Gny_AllocMem', gvtPointer, False, plC, False)
     .Param('ASize', gvtUInt64)
     .Local('LHeap', gvtPointer)
     .Local('LResult', gvtPointer);

  AIR.Assign('LHeap', AIR.Invoke('GetProcessHeap', []));
  AIR.Assign('LResult', AIR.Invoke('HeapAlloc', [AIR.Get('LHeap'), AIR.MakeInt64(8), AIR.Get('ASize')]));

  if AOptLevel = 0 then
    AIR.Assign('Gny_AllocCount', AIR.Add(AIR.Get('Gny_AllocCount'), AIR.MakeInt64(1)));

  AIR.Return(AIR.Get('LResult'));
  AIR.EndFunc();

  //----------------------------------------------------------------------------
  // Gny_MemSize(APtr: Pointer): UInt64
  // Returns the size of an allocated memory block
  //----------------------------------------------------------------------------
  AIR.Func('Gny_MemSize', gvtUInt64, False, plC, False)
     .Param('APtr', gvtPointer)
     .Local('LHeap', gvtPointer)
     .Assign('LHeap', AIR.Invoke('GetProcessHeap', []))
     .Return(AIR.Invoke('HeapSize', [AIR.Get('LHeap'), AIR.MakeInt64(0), AIR.Get('APtr')]))
  .EndFunc();

  //----------------------------------------------------------------------------
  // Gny_ReportLeaks() - Debug only
  // Prints allocation summary to console
  //----------------------------------------------------------------------------
  if AOptLevel = 0 then
  begin
    AIR.Func('Gny_ReportLeaks', gvtVoid, False, plC, True);
    AIR.Call('printf', [AIR.Str('[Heap] Allocs: %llu, Frees: %llu, Leaked: %lld' + #10),
                        AIR.Get('Gny_AllocCount'),
                        AIR.Get('Gny_FreeCount'),
                        AIR.Sub(AIR.Get('Gny_AllocCount'), AIR.Get('Gny_FreeCount'))]);
    AIR.Return();
    AIR.EndFunc();
  end;
end;

//==============================================================================
// TRuntime - String Management
//==============================================================================
//
// String Layout (TStringRec - 40 bytes):
//   Offset  0: RefCount  (Int64)  - Reference count, -1 = immortal literal
//   Offset  8: Length    (UInt64) - Length in bytes (not including null)
//   Offset 16: Capacity  (UInt64) - Allocated capacity of data buffer
//   Offset 24: Data      (Pointer)- Pointer to UTF-8 bytes (null-terminated)
//   Offset 32: Data16    (Pointer)- Cached UTF-16 conversion (lazily allocated)
//
// A string variable is a pointer to TStringRec (8 bytes).
// nil pointer = empty string.
//
//==============================================================================

procedure TRuntime.AddStrings(const AIR: TIR);
var
  LDeref: TIRExpr;
begin
  //----------------------------------------------------------------------------
  // Import C runtime for memory copy
  //----------------------------------------------------------------------------
  AIR.Import('ntdll.dll', 'memcpy', [gvtPointer, gvtPointer, gvtUInt64], gvtPointer, False);
  AIR.Import('ntdll.dll', 'memset', [gvtPointer, gvtInt32, gvtUInt64], gvtPointer, False);
  AIR.Import('ntdll.dll', 'memcmp', [gvtPointer, gvtPointer, gvtUInt64], gvtInt32, False);
  AIR.Import('kernel32.dll', 'MultiByteToWideChar', [gvtUInt32, gvtUInt32, gvtPointer, gvtInt32, gvtPointer, gvtInt32], gvtInt32, False);

  //----------------------------------------------------------------------------
  // Ensure string types are defined (idempotent - may already be defined)
  //----------------------------------------------------------------------------
  AddTypes(AIR);

  //----------------------------------------------------------------------------
  // Gny_StrAlloc(ACapacity: UInt64): Pointer
  // Allocates a new string with the specified capacity.
  // RefCount = 1, Length = 0, Data buffer allocated and null-terminated.
  //----------------------------------------------------------------------------
  AIR.Func('Gny_StrAlloc', gvtPointer, False, plC, False)
     .Param('ACapacity', gvtUInt64)
     .Local('LRec', gvtPointer)
     .Local('LData', gvtPointer)
     // Allocate the TStringRec struct (40 bytes)
     .Assign('LRec', AIR.Invoke('Gny_GetMem', [AIR.MakeInt64(40)]))
     // Allocate data buffer (capacity + 1 for null terminator)
     .Assign('LData', AIR.Invoke('Gny_GetMem', [AIR.Add(AIR.Get('ACapacity'), AIR.MakeInt64(1))]));

  // Initialize fields
  LDeref := AIR.Deref(AIR.Get('LRec'), 'TStringRec');
  AIR.SetVal(AIR.GetField(LDeref, 'RefCount'), AIR.MakeInt64(1));

  LDeref := AIR.Deref(AIR.Get('LRec'), 'TStringRec');
  AIR.SetVal(AIR.GetField(LDeref, 'Length'), AIR.MakeInt64(0));

  LDeref := AIR.Deref(AIR.Get('LRec'), 'TStringRec');
  AIR.SetVal(AIR.GetField(LDeref, 'Capacity'), AIR.Get('ACapacity'));

  LDeref := AIR.Deref(AIR.Get('LRec'), 'TStringRec');
  AIR.SetVal(AIR.GetField(LDeref, 'Data'), AIR.Get('LData'));

  LDeref := AIR.Deref(AIR.Get('LRec'), 'TStringRec');
  AIR.SetVal(AIR.GetField(LDeref, 'Data16'), AIR.Null());

  // Null-terminate the empty string and return
  AIR.Call('memset', [AIR.Get('LData'), AIR.MakeInt64(0), AIR.MakeInt64(1)])
     .Return(AIR.Get('LRec'))
  .EndFunc();

  //----------------------------------------------------------------------------
  // Gny_StrFree(AStr: Pointer)
  // Frees the string's data buffer and the TStringRec struct.
  // Does nothing if AStr is nil.
  //----------------------------------------------------------------------------
  AIR.Func('Gny_StrFree', gvtVoid, False, plC, False)
     .Param('AStr', gvtPointer)
     .Local('LData', gvtPointer)
     .Local('LData16', gvtPointer)
     // if AStr = nil then exit
     .When(AIR.Eq(AIR.Get('AStr'), AIR.Null()))
        .Return()
     .EndWhen();

  // Free UTF-16 cache if present
  LDeref := AIR.Deref(AIR.Get('AStr'), 'TStringRec');
  AIR.Assign('LData16', AIR.GetField(LDeref, 'Data16'))
     .When(AIR.Ne(AIR.Get('LData16'), AIR.Null()))
        .Call('Gny_FreeMem', [AIR.Get('LData16')])
     .EndWhen();

  // Free data buffer
  LDeref := AIR.Deref(AIR.Get('AStr'), 'TStringRec');
  AIR.Assign('LData', AIR.GetField(LDeref, 'Data'))
     .When(AIR.Ne(AIR.Get('LData'), AIR.Null()))
        .Call('Gny_FreeMem', [AIR.Get('LData')])
     .EndWhen()
     // Free struct
     .Call('Gny_FreeMem', [AIR.Get('AStr')])
     .Return()
  .EndFunc();

  //----------------------------------------------------------------------------
  // Gny_StrAddRef(AStr: Pointer)
  // Increments the reference count if not nil and not immortal (-1).
  //----------------------------------------------------------------------------
  AIR.Func('Gny_StrAddRef', gvtVoid, False, plC, False)
     .Param('AStr', gvtPointer)
     .Local('LRefCount', gvtInt64)
     // if AStr = nil then exit
     .When(AIR.Eq(AIR.Get('AStr'), AIR.Null()))
        .Return()
     .EndWhen();

  // Get current refcount
  LDeref := AIR.Deref(AIR.Get('AStr'), 'TStringRec');
  AIR.Assign('LRefCount', AIR.GetField(LDeref, 'RefCount'))
     // if RefCount = -1 (immortal) then exit
     .When(AIR.Eq(AIR.Get('LRefCount'), AIR.MakeInt64(-1)))
        .Return()
     .EndWhen();

  // Increment refcount
  LDeref := AIR.Deref(AIR.Get('AStr'), 'TStringRec');
  AIR.SetVal(AIR.GetField(LDeref, 'RefCount'), AIR.Add(AIR.Get('LRefCount'), AIR.MakeInt64(1)))
     .Return()
  .EndFunc();

  //----------------------------------------------------------------------------
  // Gny_StrRelease(AStr: Pointer)
  // Decrements the reference count. Frees the string if count reaches zero.
  // Does nothing if nil or immortal (-1).
  //----------------------------------------------------------------------------
  AIR.Func('Gny_StrRelease', gvtVoid, False, plC, False)
     .Param('AStr', gvtPointer)
     .Local('LRefCount', gvtInt64)
     // if AStr = nil then exit
     .When(AIR.Eq(AIR.Get('AStr'), AIR.Null()))
        .Return()
     .EndWhen();

  // Get current refcount
  LDeref := AIR.Deref(AIR.Get('AStr'), 'TStringRec');
  AIR.Assign('LRefCount', AIR.GetField(LDeref, 'RefCount'))
     // if RefCount = -1 (immortal) then exit
     .When(AIR.Eq(AIR.Get('LRefCount'), AIR.MakeInt64(-1)))
        .Return()
     .EndWhen()
     // Decrement refcount
     .Assign('LRefCount', AIR.Sub(AIR.Get('LRefCount'), AIR.MakeInt64(1)));

  LDeref := AIR.Deref(AIR.Get('AStr'), 'TStringRec');
  AIR.SetVal(AIR.GetField(LDeref, 'RefCount'), AIR.Get('LRefCount'))
     // if RefCount = 0 then free
     .When(AIR.Eq(AIR.Get('LRefCount'), AIR.MakeInt64(0)))
        .Call('Gny_StrFree', [AIR.Get('AStr')])
     .EndWhen()
     .Return()
  .EndFunc();

  //----------------------------------------------------------------------------
  // Gny_ReleaseOnDetach(AReason: Int32; AStr: Pointer)
  // Conditionally releases a managed string during DLL unload.
  // Only releases when AReason = 0 (DLL_PROCESS_DETACH).
  // Called by SSA cleanup pass for managed globals in DllMain.
  //----------------------------------------------------------------------------
  AIR.Func('Gny_ReleaseOnDetach', gvtVoid, False, plC, False)
     .Param('AReason', gvtInt32)
     .Param('AStr', gvtPointer)
     // Only release on DLL_PROCESS_DETACH (reason = 0)
     .When(AIR.Eq(AIR.Get('AReason'), AIR.Int32(0)))
        .Call('Gny_StrRelease', [AIR.Get('AStr')])
     .EndWhen()
     .Return()
  .EndFunc();

  //----------------------------------------------------------------------------
  // Gny_StrFromLiteral(AData: Pointer; ALen: UInt64): Pointer
  // Creates a new string from static literal data.
  // Copies the data, sets length, null-terminates.
  //----------------------------------------------------------------------------
  AIR.Func('Gny_StrFromLiteral', gvtPointer, False, plC, False)
     .Param('AData', gvtPointer)
     .Param('ALen', gvtUInt64)
     .Local('LRec', gvtPointer)
     .Local('LData', gvtPointer)
     // Allocate string with capacity = length
     .Assign('LRec', AIR.Invoke('Gny_StrAlloc', [AIR.Get('ALen')]));

  // Get data pointer
  LDeref := AIR.Deref(AIR.Get('LRec'), 'TStringRec');
  AIR.Assign('LData', AIR.GetField(LDeref, 'Data'))
     // Copy literal data
     .Call('memcpy', [AIR.Get('LData'), AIR.Get('AData'), AIR.Get('ALen')]);

  // Set length
  LDeref := AIR.Deref(AIR.Get('LRec'), 'TStringRec');
  AIR.SetVal(AIR.GetField(LDeref, 'Length'), AIR.Get('ALen'))
     // Null terminate (memset at data+len)
     .Call('memset', [AIR.Add(AIR.Get('LData'), AIR.Get('ALen')), AIR.MakeInt64(0), AIR.MakeInt64(1)])
     .Return(AIR.Get('LRec'))
  .EndFunc();

  //----------------------------------------------------------------------------
  // Gny_StrFromChar(AChar: UInt64): Pointer
  // Creates a new string from a single character.
  // Allocates string, stores char, sets length to 1, null-terminates.
  //----------------------------------------------------------------------------
  AIR.Func('Gny_StrFromChar', gvtPointer, False, plC, False)
     .Param('AChar', gvtUInt64)
     .Local('LRec', gvtPointer)
     .Local('LData', gvtPointer)
     // Allocate string with capacity = 1
     .Assign('LRec', AIR.Invoke('Gny_StrAlloc', [AIR.MakeInt64(1)]));

  // Get data pointer
  LDeref := AIR.Deref(AIR.Get('LRec'), 'TStringRec');
  AIR.Assign('LData', AIR.GetField(LDeref, 'Data'))
     // Store char byte at data[0]
     .Call('memset', [AIR.Get('LData'), AIR.Get('AChar'), AIR.MakeInt64(1)]);

  // Set length to 1
  LDeref := AIR.Deref(AIR.Get('LRec'), 'TStringRec');
  AIR.SetVal(AIR.GetField(LDeref, 'Length'), AIR.MakeInt64(1))
     // Null terminate at data[1]
     .Call('memset', [AIR.Add(AIR.Get('LData'), AIR.MakeInt64(1)), AIR.MakeInt64(0), AIR.MakeInt64(1)])
     .Return(AIR.Get('LRec'))
  .EndFunc();

  //----------------------------------------------------------------------------
  // Gny_StrConcat(AStr1, AStr2: Pointer): Pointer
  // Creates a new string that is the concatenation of AStr1 and AStr2.
  // Handles nil strings as empty.
  //----------------------------------------------------------------------------
  AIR.Func('Gny_StrConcat', gvtPointer, False, plC, False)
     .Param('AStr1', gvtPointer)
     .Param('AStr2', gvtPointer)
     .Local('LLen1', gvtUInt64)
     .Local('LLen2', gvtUInt64)
     .Local('LTotalLen', gvtUInt64)
     .Local('LRec', gvtPointer)
     .Local('LData', gvtPointer)
     .Local('LData1', gvtPointer)
     .Local('LData2', gvtPointer)
     // Get length of first string (0 if nil)
     .When(AIR.Eq(AIR.Get('AStr1'), AIR.Null()))
        .Assign('LLen1', AIR.MakeInt64(0))
     .Otherwise();

  LDeref := AIR.Deref(AIR.Get('AStr1'), 'TStringRec');
  AIR.Assign('LLen1', AIR.GetField(LDeref, 'Length'))
     .EndWhen()
     // Get length of second string (0 if nil)
     .When(AIR.Eq(AIR.Get('AStr2'), AIR.Null()))
        .Assign('LLen2', AIR.MakeInt64(0))
     .Otherwise();

  LDeref := AIR.Deref(AIR.Get('AStr2'), 'TStringRec');
  AIR.Assign('LLen2', AIR.GetField(LDeref, 'Length'))
     .EndWhen()
     // Total length
     .Assign('LTotalLen', AIR.Add(AIR.Get('LLen1'), AIR.Get('LLen2')))
     // Allocate new string
     .Assign('LRec', AIR.Invoke('Gny_StrAlloc', [AIR.Get('LTotalLen')]));

  // Get data pointer of result
  LDeref := AIR.Deref(AIR.Get('LRec'), 'TStringRec');
  AIR.Assign('LData', AIR.GetField(LDeref, 'Data'))
     // Copy first string if not empty
     .When(AIR.Gt(AIR.Get('LLen1'), AIR.MakeInt64(0)));

  LDeref := AIR.Deref(AIR.Get('AStr1'), 'TStringRec');
  AIR.Assign('LData1', AIR.GetField(LDeref, 'Data'))
        .Call('memcpy', [AIR.Get('LData'), AIR.Get('LData1'), AIR.Get('LLen1')])
     .EndWhen()
     // Copy second string if not empty
     .When(AIR.Gt(AIR.Get('LLen2'), AIR.MakeInt64(0)));

  LDeref := AIR.Deref(AIR.Get('AStr2'), 'TStringRec');
  AIR.Assign('LData2', AIR.GetField(LDeref, 'Data'))
        .Call('memcpy', [AIR.Add(AIR.Get('LData'), AIR.Get('LLen1')), AIR.Get('LData2'), AIR.Get('LLen2')])
     .EndWhen();

  // Set length and null-terminate
  LDeref := AIR.Deref(AIR.Get('LRec'), 'TStringRec');
  AIR.SetVal(AIR.GetField(LDeref, 'Length'), AIR.Get('LTotalLen'))
     .Call('memset', [AIR.Add(AIR.Get('LData'), AIR.Get('LTotalLen')), AIR.MakeInt64(0), AIR.MakeInt64(1)])
     .Return(AIR.Get('LRec'))
  .EndFunc();

  //----------------------------------------------------------------------------
  // Gny_StrAssign(ADest: Pointer; ASrc: Pointer)
  // Assignment with automatic reference counting.
  // ADest is pointer to a string variable (pointer to pointer to TStringRec).
  // Automatically AddRefs source and releases old dest value.
  // Self-assignment safe: AddRef before Release prevents use-after-free.
  //----------------------------------------------------------------------------
  AIR.Func('Gny_StrAssign', gvtVoid, False, plC, False)
     .Param('ADest', gvtPointer)   // Pointer to the string variable
     .Param('ASrc', gvtPointer)    // Source string (TStringRec pointer)
     .Local('LOld', gvtPointer)
     // Get old value from destination
     .Assign('LOld', AIR.Deref(AIR.Get('ADest'), gvtPointer))
     // AddRef the source FIRST (self-assignment safe: refcount 1->2)
     .Call('Gny_StrAddRef', [AIR.Get('ASrc')])
     // Store new value
     .SetVal(AIR.Deref(AIR.Get('ADest'), gvtPointer), AIR.Get('ASrc'))
     // Release old value LAST (self-assignment safe: refcount 2->1)
     .Call('Gny_StrRelease', [AIR.Get('LOld')])
     .Return()
  .EndFunc();

  //----------------------------------------------------------------------------
  // Gny_StrLen(AStr: Pointer): UInt64
  // Returns the length of the string in bytes. Returns 0 if nil.
  //----------------------------------------------------------------------------
  AIR.Func('Gny_StrLen', gvtUInt64, False, plC, False)
     .Param('AStr', gvtPointer)
     .When(AIR.Eq(AIR.Get('AStr'), AIR.Null()))
        .Return(AIR.MakeInt64(0))
     .EndWhen();

  LDeref := AIR.Deref(AIR.Get('AStr'), 'TStringRec');
  AIR.Return(AIR.GetField(LDeref, 'Length'))
  .EndFunc();

  //----------------------------------------------------------------------------
  // Gny_StrCompare(AStr1, AStr2: Pointer): Int64
  // Lexicographic comparison. Returns <0 if AStr1<AStr2, 0 if equal, >0 if AStr1>AStr2.
  // Nil is treated as less than any non-nil string.
  //----------------------------------------------------------------------------
  AIR.Func('Gny_StrCompare', gvtInt64, False, plC, False)
     .Param('AStr1', gvtPointer)
     .Param('AStr2', gvtPointer)
     .Local('LLen1', gvtUInt64)
     .Local('LLen2', gvtUInt64)
     .Local('LMinLen', gvtUInt64)
     .Local('LData1', gvtPointer)
     .Local('LData2', gvtPointer)
     .Local('LResult', gvtInt32)
     // Check AStr1 nil
     .When(AIR.Eq(AIR.Get('AStr1'), AIR.Null()))
        // AStr1 is nil - check AStr2
        .When(AIR.Eq(AIR.Get('AStr2'), AIR.Null()))
           .Return(AIR.MakeInt64(0))   // Both nil -> equal
        .EndWhen()
        .Return(AIR.MakeInt64(-1))     // AStr1 nil, AStr2 not nil -> less than
     .EndWhen()
     // AStr1 not nil - check AStr2
     .When(AIR.Eq(AIR.Get('AStr2'), AIR.Null()))
        .Return(AIR.MakeInt64(1))      // AStr1 not nil, AStr2 nil -> greater than
     .EndWhen();

  // Get lengths
  LDeref := AIR.Deref(AIR.Get('AStr1'), 'TStringRec');
  AIR.Assign('LLen1', AIR.GetField(LDeref, 'Length'));
  LDeref := AIR.Deref(AIR.Get('AStr2'), 'TStringRec');
  AIR.Assign('LLen2', AIR.GetField(LDeref, 'Length'));

  // Get data pointers
  LDeref := AIR.Deref(AIR.Get('AStr1'), 'TStringRec');
  AIR.Assign('LData1', AIR.GetField(LDeref, 'Data'));
  LDeref := AIR.Deref(AIR.Get('AStr2'), 'TStringRec');
  AIR.Assign('LData2', AIR.GetField(LDeref, 'Data'));

  // LMinLen = min(LLen1, LLen2)
  AIR.When(AIR.Lt(AIR.Get('LLen1'), AIR.Get('LLen2')))
       .Assign('LMinLen', AIR.Get('LLen1'))
     .Otherwise()
       .Assign('LMinLen', AIR.Get('LLen2'))
     .EndWhen();

  // LResult = memcmp(LData1, LData2, LMinLen)
  AIR.Assign('LResult', AIR.Invoke('memcmp', [AIR.Get('LData1'), AIR.Get('LData2'), AIR.Get('LMinLen')]))
     // If memcmp result < 0, return -1
     .When(AIR.Lt(AIR.Get('LResult'), AIR.MakeInt64(0)))
        .Return(AIR.MakeInt64(-1))
     .EndWhen()
     // If memcmp result > 0, return 1
     .When(AIR.Gt(AIR.Get('LResult'), AIR.MakeInt64(0)))
        .Return(AIR.MakeInt64(1))
     .EndWhen()
     // memcmp returned 0, compare by length
     .When(AIR.Lt(AIR.Get('LLen1'), AIR.Get('LLen2')))
        .Return(AIR.MakeInt64(-1))
     .EndWhen()
     .When(AIR.Gt(AIR.Get('LLen1'), AIR.Get('LLen2')))
        .Return(AIR.MakeInt64(1))
     .EndWhen()
     .Return(AIR.MakeInt64(0))
  .EndFunc();

  //----------------------------------------------------------------------------
  // Gny_StrData(AStr: Pointer): Pointer
  // Returns pointer to the UTF-8 data (for pchar() conversion).
  // Returns nil if string is nil.
  //----------------------------------------------------------------------------
  AIR.Func('Gny_StrData', gvtPointer, False, plC, False)
     .Param('AStr', gvtPointer)
     .When(AIR.Eq(AIR.Get('AStr'), AIR.Null()))
        .Return(AIR.Null())
     .EndWhen();

  LDeref := AIR.Deref(AIR.Get('AStr'), 'TStringRec');
  AIR.Return(AIR.GetField(LDeref, 'Data'))
  .EndFunc();

  //----------------------------------------------------------------------------
  // Gny_StrUtf16(AStr: Pointer): Pointer
  // Returns pointer to cached UTF-16 data. Converts from UTF-8 on first call.
  // Returns nil if string is nil.
  //----------------------------------------------------------------------------
  AIR.Func('Gny_StrUtf16', gvtPointer, False, plC, False)
     .Param('AStr', gvtPointer)
     .Local('LData16', gvtPointer)
     .Local('LData', gvtPointer)
     .Local('LLen', gvtUInt64)
     .Local('LWideLen', gvtInt32)
     .Local('LBuf', gvtPointer)
     // if AStr = nil then return nil
     .When(AIR.Eq(AIR.Get('AStr'), AIR.Null()))
        .Return(AIR.Null())
     .EndWhen();

  // Check if already cached
  LDeref := AIR.Deref(AIR.Get('AStr'), 'TStringRec');
  AIR.Assign('LData16', AIR.GetField(LDeref, 'Data16'))
     .When(AIR.Ne(AIR.Get('LData16'), AIR.Null()))
        .Return(AIR.Get('LData16'))
     .EndWhen();

  // Get UTF-8 data pointer and length
  LDeref := AIR.Deref(AIR.Get('AStr'), 'TStringRec');
  AIR.Assign('LData', AIR.GetField(LDeref, 'Data'));

  LDeref := AIR.Deref(AIR.Get('AStr'), 'TStringRec');
  AIR.Assign('LLen', AIR.GetField(LDeref, 'Length'));

  // Query required buffer size (CP_UTF8 = 65001)
  AIR.Assign('LWideLen', AIR.Invoke('MultiByteToWideChar',
        [AIR.MakeInt64(65001), AIR.MakeInt64(0), AIR.Get('LData'), AIR.Get('LLen'), AIR.Null(), AIR.MakeInt64(0)]))
     // Allocate buffer: (LWideLen + 1) * 2 bytes for UTF-16 + null terminator
     .Assign('LBuf', AIR.Invoke('Gny_GetMem',
        [AIR.Mul(AIR.Add(AIR.Get('LWideLen'), AIR.MakeInt64(1)), AIR.MakeInt64(2))]))
     // Convert UTF-8 to UTF-16
     .Call('MultiByteToWideChar',
        [AIR.MakeInt64(65001), AIR.MakeInt64(0), AIR.Get('LData'), AIR.Get('LLen'), AIR.Get('LBuf'), AIR.Get('LWideLen')]);

  // Null-terminate (2 bytes of zero)
  AIR.Call('memset', [AIR.Add(AIR.Get('LBuf'), AIR.Mul(AIR.Get('LWideLen'), AIR.MakeInt64(2))), AIR.MakeInt64(0), AIR.MakeInt64(2)]);

  // Store in cache
  LDeref := AIR.Deref(AIR.Get('AStr'), 'TStringRec');
  AIR.SetVal(AIR.GetField(LDeref, 'Data16'), AIR.Get('LBuf'))
     .Return(AIR.Get('LBuf'))
  .EndFunc();

  //----------------------------------------------------------------------------
  // Gny_StrLiteralUtf16(AData: Pointer; ALen: UInt64): Pointer
  // Converts UTF-8 literal data to UTF-16. Returns pointer to allocated buffer.
  // Unlike Gny_StrUtf16, this takes raw data pointer + length (no TStringRec).
  //----------------------------------------------------------------------------
  AIR.Func('Gny_StrLiteralUtf16', gvtPointer, False, plC, False)
     .Param('AData', gvtPointer)
     .Param('ALen', gvtUInt64)
     .Local('LWideLen', gvtInt32)
     .Local('LBuf', gvtPointer)
     // Query required buffer size (CP_UTF8 = 65001)
     .Assign('LWideLen', AIR.Invoke('MultiByteToWideChar',
        [AIR.MakeInt64(65001), AIR.MakeInt64(0), AIR.Get('AData'), AIR.Get('ALen'), AIR.Null(), AIR.MakeInt64(0)]))
     // Allocate buffer: (LWideLen + 1) * 2 bytes
     .Assign('LBuf', AIR.Invoke('Gny_GetMem',
        [AIR.Mul(AIR.Add(AIR.Get('LWideLen'), AIR.MakeInt64(1)), AIR.MakeInt64(2))]))
     // Convert UTF-8 to UTF-16
     .Call('MultiByteToWideChar',
        [AIR.MakeInt64(65001), AIR.MakeInt64(0), AIR.Get('AData'), AIR.Get('ALen'), AIR.Get('LBuf'), AIR.Get('LWideLen')])
     // Null-terminate (2 bytes of zero)
     .Call('memset', [AIR.Add(AIR.Get('LBuf'), AIR.Mul(AIR.Get('LWideLen'), AIR.MakeInt64(2))), AIR.MakeInt64(0), AIR.MakeInt64(2)])
     .Return(AIR.Get('LBuf'))
  .EndFunc();
end;

//==============================================================================
// TRuntime - String Type Definitions
//==============================================================================
// Defines TStringRec and 'string' pointer type only.
// Called early in TGnyNative.Create() so user code can reference 'string' type.
// Safe to call multiple times - checks if types already exist.
//==============================================================================

procedure TRuntime.AddTypes(const AIR: TIR);
begin
  // Define TStringRec type
  AIR.DefineRecord('TStringRec')
     .Field('RefCount', gvtInt64)
     .Field('Length', gvtUInt64)
     .Field('Capacity', gvtUInt64)
     .Field('Data', gvtPointer)
     .Field('Data16', gvtPointer)
  .EndRecord();

  // Register 'string' as a pointer to TStringRec
  AIR.DefinePointer('string', 'TStringRec', False);

  // Register 'wstring' as a raw pointer type (PWideChar, no backing record)
  AIR.DefinePointer('wstring');
end;

//==============================================================================
// TRuntime - Language Intrinsics
//==============================================================================
//
// Unified intrinsic functions that the frontend maps keywords to.
// These dispatch across types (strings, wstrings, dynamic arrays, etc).
//
//==============================================================================

procedure TRuntime.AddIntrinsics(const AIR: TIR);
begin
  //----------------------------------------------------------------------------
  // Import wcslen for wide string length (msvcrt — same as printf)
  //----------------------------------------------------------------------------
  AIR.Import('msvcrt.dll', 'wcslen', [gvtPointer], gvtUInt64, False);

  //----------------------------------------------------------------------------
  // Gny_WStrLen(AStr: Pointer): UInt64
  // Returns the length of a raw wchar_t* string (number of wide characters).
  // Returns 0 if nil.
  //----------------------------------------------------------------------------
  AIR.Func('Gny_WStrLen', gvtUInt64, False, plC, False)
     .Param('AStr', gvtPointer)
     .When(AIR.Eq(AIR.Get('AStr'), AIR.Null()))
        .Return(AIR.MakeInt64(0))
     .EndWhen()
     .Return(AIR.Invoke('wcslen', [AIR.Get('AStr')]))
  .EndFunc();

  //----------------------------------------------------------------------------
  // Gny_WStrConcat(AStr1, AStr2: Pointer): Pointer
  // Concatenates two raw wchar_t* wide strings. Allocates new buffer via
  // Gny_GetMem. Caller is responsible for freeing. Handles nil as empty.
  //----------------------------------------------------------------------------
  AIR.Func('Gny_WStrConcat', gvtPointer, False, plC, False)
     .Param('AStr1', gvtPointer)
     .Param('AStr2', gvtPointer)
     .Local('LLen1', gvtUInt64)
     .Local('LLen2', gvtUInt64)
     .Local('LTotalLen', gvtUInt64)
     .Local('LBuf', gvtPointer)
     // Get length of first string (0 if nil)
     .When(AIR.Eq(AIR.Get('AStr1'), AIR.Null()))
        .Assign('LLen1', AIR.MakeInt64(0))
     .Otherwise()
        .Assign('LLen1', AIR.Invoke('wcslen', [AIR.Get('AStr1')]))
     .EndWhen()
     // Get length of second string (0 if nil)
     .When(AIR.Eq(AIR.Get('AStr2'), AIR.Null()))
        .Assign('LLen2', AIR.MakeInt64(0))
     .Otherwise()
        .Assign('LLen2', AIR.Invoke('wcslen', [AIR.Get('AStr2')]))
     .EndWhen()
     // Total length in wide chars
     .Assign('LTotalLen', AIR.Add(AIR.Get('LLen1'), AIR.Get('LLen2')))
     // Allocate buffer: (LTotalLen + 1) * 2 bytes
     .Assign('LBuf', AIR.Invoke('Gny_GetMem',
        [AIR.Mul(AIR.Add(AIR.Get('LTotalLen'), AIR.MakeInt64(1)), AIR.MakeInt64(2))]))
     // Copy first string if not empty
     .When(AIR.Gt(AIR.Get('LLen1'), AIR.MakeInt64(0)))
        .Call('memcpy', [AIR.Get('LBuf'), AIR.Get('AStr1'),
           AIR.Mul(AIR.Get('LLen1'), AIR.MakeInt64(2))])
     .EndWhen()
     // Copy second string after first
     .When(AIR.Gt(AIR.Get('LLen2'), AIR.MakeInt64(0)))
        .Call('memcpy', [AIR.Add(AIR.Get('LBuf'), AIR.Mul(AIR.Get('LLen1'), AIR.MakeInt64(2))),
           AIR.Get('AStr2'), AIR.Mul(AIR.Get('LLen2'), AIR.MakeInt64(2))])
     .EndWhen()
     // Null terminate (2 bytes of zero)
     .Call('memset', [AIR.Add(AIR.Get('LBuf'), AIR.Mul(AIR.Get('LTotalLen'), AIR.MakeInt64(2))),
        AIR.MakeInt64(0), AIR.MakeInt64(2)])
     .Return(AIR.Get('LBuf'))
  .EndFunc();

  //----------------------------------------------------------------------------
  // Gny_WStrCompare(AStr1, AStr2: Pointer): Int64
  // Lexicographic comparison of two raw wchar_t* wide strings.
  // Returns -1, 0, or 1. Nil is treated as less than any non-nil string.
  //----------------------------------------------------------------------------
  AIR.Func('Gny_WStrCompare', gvtInt64, False, plC, False)
     .Param('AStr1', gvtPointer)
     .Param('AStr2', gvtPointer)
     .Local('LLen1', gvtUInt64)
     .Local('LLen2', gvtUInt64)
     .Local('LMinLen', gvtUInt64)
     .Local('LResult', gvtInt32)
     // Check AStr1 nil
     .When(AIR.Eq(AIR.Get('AStr1'), AIR.Null()))
        // AStr1 is nil — check AStr2
        .When(AIR.Eq(AIR.Get('AStr2'), AIR.Null()))
           .Return(AIR.MakeInt64(0))   // Both nil -> equal
        .EndWhen()
        .Return(AIR.MakeInt64(-1))     // AStr1 nil, AStr2 not nil -> less than
     .EndWhen()
     // AStr1 not nil — check AStr2
     .When(AIR.Eq(AIR.Get('AStr2'), AIR.Null()))
        .Return(AIR.MakeInt64(1))      // AStr1 not nil, AStr2 nil -> greater than
     .EndWhen()
     // Get lengths
     .Assign('LLen1', AIR.Invoke('wcslen', [AIR.Get('AStr1')]))
     .Assign('LLen2', AIR.Invoke('wcslen', [AIR.Get('AStr2')]))
     // LMinLen = min(LLen1, LLen2)
     .When(AIR.Lt(AIR.Get('LLen1'), AIR.Get('LLen2')))
        .Assign('LMinLen', AIR.Get('LLen1'))
     .Otherwise()
        .Assign('LMinLen', AIR.Get('LLen2'))
     .EndWhen()
     // LResult = memcmp(AStr1, AStr2, LMinLen * 2)
     .Assign('LResult', AIR.Invoke('memcmp', [AIR.Get('AStr1'), AIR.Get('AStr2'),
        AIR.Mul(AIR.Get('LMinLen'), AIR.MakeInt64(2))]))
     // If memcmp result < 0, return -1
     .When(AIR.Lt(AIR.Get('LResult'), AIR.MakeInt64(0)))
        .Return(AIR.MakeInt64(-1))
     .EndWhen()
     // If memcmp result > 0, return 1
     .When(AIR.Gt(AIR.Get('LResult'), AIR.MakeInt64(0)))
        .Return(AIR.MakeInt64(1))
     .EndWhen()
     // memcmp returned 0, compare by length
     .When(AIR.Lt(AIR.Get('LLen1'), AIR.Get('LLen2')))
        .Return(AIR.MakeInt64(-1))
     .EndWhen()
     .When(AIR.Gt(AIR.Get('LLen1'), AIR.Get('LLen2')))
        .Return(AIR.MakeInt64(1))
     .EndWhen()
     .Return(AIR.MakeInt64(0))
  .EndFunc();

  //----------------------------------------------------------------------------
  // Gny_WStrFromLiteral(AData: Pointer, AWideLen: Int64): Pointer
  // Creates a heap-allocated copy of a UTF-16 literal. AWideLen is the number
  // of wide characters (not bytes). Allocates (AWideLen+1)*2 bytes and null-
  // terminates. Caller is responsible for freeing via Gny_FreeMem.
  //----------------------------------------------------------------------------
  AIR.Func('Gny_WStrFromLiteral', gvtPointer, False, plC, False)
     .Param('AData', gvtPointer)
     .Param('AWideLen', gvtInt64)
     .Local('LBuf', gvtPointer)
     // Allocate buffer: (AWideLen + 1) * 2 bytes
     .Assign('LBuf', AIR.Invoke('Gny_GetMem',
        [AIR.Mul(AIR.Add(AIR.Get('AWideLen'), AIR.MakeInt64(1)), AIR.MakeInt64(2))]))
     // Copy AWideLen * 2 bytes from literal data
     .Call('memcpy', [AIR.Get('LBuf'), AIR.Get('AData'),
        AIR.Mul(AIR.Get('AWideLen'), AIR.MakeInt64(2))])
     // Null-terminate (2 bytes of zero)
     .Call('memset', [AIR.Add(AIR.Get('LBuf'),
        AIR.Mul(AIR.Get('AWideLen'), AIR.MakeInt64(2))),
        AIR.MakeInt64(0), AIR.MakeInt64(2)])
     .Return(AIR.Get('LBuf'))
  .EndFunc();

  //----------------------------------------------------------------------------
  // Gny_Utf8(AWStr: Pointer): Pointer
  // Converts a raw wchar_t* wide string to a heap-allocated UTF-8 char*.
  // Returns nil if input is nil. Caller is responsible for freeing.
  //----------------------------------------------------------------------------
  AIR.Func('Gny_Utf8', gvtPointer, False, plC, False)
     .Param('AWStr', gvtPointer)
     .VarDecl('LLen', gvtInt32)
     .VarDecl('LBuf', gvtPointer)
     // if AWStr = nil then return nil
     .When(AIR.Eq(AIR.Get('AWStr'), AIR.Null()))
        .Return(AIR.Null())
     .EndWhen()
     // Query required buffer size (CP_UTF8 = 65001, -1 = null-terminated)
     .Let('LLen', AIR.Invoke('WideCharToMultiByte',
        [AIR.MakeInt64(65001), AIR.MakeInt64(0), AIR.Get('AWStr'), AIR.MakeInt64(-1),
         AIR.Null(), AIR.MakeInt64(0), AIR.Null(), AIR.Null()]))
     // Allocate buffer
     .Let('LBuf', AIR.Invoke('Gny_GetMem', [AIR.Get('LLen')]))
     // Convert wide to UTF-8
     .Call('WideCharToMultiByte',
        [AIR.MakeInt64(65001), AIR.MakeInt64(0), AIR.Get('AWStr'), AIR.MakeInt64(-1),
         AIR.Get('LBuf'), AIR.Get('LLen'), AIR.Null(), AIR.Null()])
     .Return(AIR.Get('LBuf'))
  .EndFunc();

  //----------------------------------------------------------------------------
  // Gny_Len(ATag: Int64, AVal: Pointer): UInt64
  // Unified len() intrinsic. Dispatches to the correct length routine
  // based on a compile-time type tag injected by the codegen.
  //   Tag 0 = string  → Gny_StrLen (managed TStringRec)
  //   Tag 1 = wstring → Gny_WStrLen (raw wchar_t*)
  //   Tag 2 = dynarray → Gny_DynLen (length header at ptr-8)
  //----------------------------------------------------------------------------
  AIR.Func('Gny_Len', gvtUInt64, False, plC, False)
     .Param('ATag', gvtInt64)
     .Param('AVal', gvtPointer)

     // Tag 0: string (managed TStringRec)
     .When(AIR.Eq(AIR.Get('ATag'), AIR.MakeInt64(0)))
        .Return(AIR.Invoke('Gny_StrLen', [AIR.Get('AVal')]))
     .EndWhen()

     // Tag 1: wstring (raw wchar_t*)
     .When(AIR.Eq(AIR.Get('ATag'), AIR.MakeInt64(1)))
        .Return(AIR.Invoke('Gny_WStrLen', [AIR.Get('AVal')]))
     .EndWhen()

     // Tag 2: dynarray (length at ptr - 8)
     .When(AIR.Eq(AIR.Get('ATag'), AIR.MakeInt64(2)))
        .Return(AIR.Invoke('Gny_DynLen', [AIR.Get('AVal')]))
     .EndWhen()

     // Unknown tag — return 0
     .Return(AIR.MakeInt64(0))
  .EndFunc();

  //----------------------------------------------------------------------------
  // Gny_DynLen(APtr: Pointer): UInt64
  // Returns the length of a dynamic array. The length is stored as an Int64
  // at (APtr - 8), i.e. in the 8 bytes immediately before the data pointer.
  // Returns 0 if APtr is nil.
  //----------------------------------------------------------------------------
  AIR.Func('Gny_DynLen', gvtUInt64, False, plC, False)
     .Param('APtr', gvtPointer)
     .Local('LHeader', gvtPointer)
     .When(AIR.Eq(AIR.Get('APtr'), AIR.Null()))
        .Return(AIR.MakeInt64(0))
     .EndWhen()
     // Length is at APtr - 8
     .Let('LHeader', AIR.Sub(AIR.Get('APtr'), AIR.MakeInt64(8)))
     .Return(AIR.Deref(AIR.Get('LHeader'), gvtUInt64))
  .EndFunc();

  //----------------------------------------------------------------------------
  // Gny_SetLength(AVar: Pointer, ANewLen: Int64, AElemSize: Int64)
  // Allocates or reallocates a dynamic array.
  // AVar = address of the pointer variable (passed by reference).
  // Layout: [Length:Int64][Element0][Element1]...
  // The pointer stored in *AVar points to Element0 (past the header).
  //----------------------------------------------------------------------------
  AIR.Func('Gny_SetLength', gvtVoid, False, plC, False)
     .Param('AVar', gvtPointer)
     .Param('ANewLen', gvtInt64)
     .Param('AElemSize', gvtInt64)
     .Local('LOldPtr', gvtPointer)
     .Local('LBlock', gvtPointer)
     .Local('LDataPtr', gvtPointer);

  // Read old pointer from *AVar
  AIR.Let('LOldPtr', AIR.Deref(AIR.Get('AVar'), gvtPointer));

  // Free old block if not nil (old block starts at OldPtr - 8)
  AIR.When(AIR.Ne(AIR.Get('LOldPtr'), AIR.Null()))
     .Call('Gny_FreeMem', [AIR.Sub(AIR.Get('LOldPtr'), AIR.MakeInt64(8))])
  .EndWhen();

  // Allocate new block: 8 bytes header + ANewLen * AElemSize (zero-initialized)
  AIR.Let('LBlock', AIR.Invoke('Gny_AllocMem',
     [AIR.Add(AIR.MakeInt64(8), AIR.Mul(AIR.Get('ANewLen'), AIR.Get('AElemSize')))]));

  // Store length in the header (first 8 bytes)
  AIR.SetVal(AIR.Deref(AIR.Get('LBlock'), gvtInt64), AIR.Get('ANewLen'));

  // Data pointer = block + 8
  AIR.Let('LDataPtr', AIR.Add(AIR.Get('LBlock'), AIR.MakeInt64(8)));

  // Store data pointer into *AVar
  AIR.SetVal(AIR.Deref(AIR.Get('AVar'), gvtPointer), AIR.Get('LDataPtr'));

  AIR.Return();
  AIR.EndFunc();

  //----------------------------------------------------------------------------
  // Gny_DynFree(APtr: Pointer)
  // Frees a dynamic array. APtr is the data pointer (block starts at APtr-8).
  // Does nothing if APtr is nil. Used by the cleanup pass for managed locals.
  //----------------------------------------------------------------------------
  AIR.Func('Gny_DynFree', gvtVoid, False, plC, False)
     .Param('APtr', gvtPointer)
     .When(AIR.Eq(AIR.Get('APtr'), AIR.Null()))
        .Return()
     .EndWhen()
     .Call('Gny_FreeMem', [AIR.Sub(AIR.Get('APtr'), AIR.MakeInt64(8))])
     .Return()
  .EndFunc();
end;
//
// Exception Context (stored in TLS):
//   - Code: Int32 (stored as pointer in TLS slot)
//   - Message: Pointer to heap-allocated UTF-8 string
//
// TLS slots are allocated at runtime initialization via Gny_InitExceptions.
// When raising, the message is copied to heap (runtime owns it).
// When a new exception is raised, old message is freed first.
//
//==============================================================================

procedure TRuntime.AddExceptions(const AIR: TIR);
begin
  //----------------------------------------------------------------------------
  // Import Windows TLS functions
  //----------------------------------------------------------------------------
  AIR.Import('kernel32.dll', 'TlsAlloc', [], gvtUInt32, False);
  AIR.Import('kernel32.dll', 'TlsGetValue', [gvtUInt32], gvtPointer, False);
  AIR.Import('kernel32.dll', 'TlsSetValue', [gvtUInt32, gvtPointer], gvtInt32, False);
  AIR.Import('kernel32.dll', 'RaiseException', [gvtUInt32, gvtUInt32, gvtUInt32, gvtPointer], gvtVoid, False);
  AIR.Import('ntdll.dll', 'strlen', [gvtPointer], gvtUInt64, False);
  // memcpy already imported in AddStrings, but import again to be safe
  AIR.Import('ntdll.dll', 'memcpy', [gvtPointer, gvtPointer, gvtUInt64], gvtPointer, False);

  //----------------------------------------------------------------------------
  // Global variables for TLS slot indices
  //----------------------------------------------------------------------------
  AIR.Global('Gny_TlsExcCode', gvtUInt32);   // TLS slot for exception code
  AIR.Global('Gny_TlsExcMsg', gvtUInt32);    // TLS slot for exception message

  //----------------------------------------------------------------------------
  // Gny_InitExceptions()
  // Allocates TLS slots. Must be called at process/thread startup.
  //----------------------------------------------------------------------------
  AIR.Func('Gny_InitExceptions', gvtVoid, False, plC, False)
     .Assign('Gny_TlsExcCode', AIR.Invoke('TlsAlloc', []))
     .Assign('Gny_TlsExcMsg', AIR.Invoke('TlsAlloc', []))
     .Return()
  .EndFunc();

  //----------------------------------------------------------------------------
  // Gny_SetException(ACode: Int32; AMsg: Pointer)
  // Internal helper: stores code and copies message to TLS.
  // Frees old message if present.
  //----------------------------------------------------------------------------
  AIR.Func('Gny_SetException', gvtVoid, False, plC, False)
     .Param('ACode', gvtInt32)
     .Param('AMsg', gvtPointer)
     .Local('LOldMsg', gvtPointer)
     .Local('LLen', gvtUInt64)
     .Local('LNewMsg', gvtPointer)
     // Get and free old message if any
     .Assign('LOldMsg', AIR.Invoke('TlsGetValue', [AIR.Get('Gny_TlsExcMsg')]))
     .When(AIR.Ne(AIR.Get('LOldMsg'), AIR.Null()))
        .Call('Gny_FreeMem', [AIR.Get('LOldMsg')])
     .EndWhen()
     // Copy new message if not nil
     .When(AIR.Ne(AIR.Get('AMsg'), AIR.Null()))
        .Assign('LLen', AIR.Invoke('strlen', [AIR.Get('AMsg')]))
        .Assign('LNewMsg', AIR.Invoke('Gny_GetMem', [AIR.Add(AIR.Get('LLen'), AIR.MakeInt64(1))]))
        .Call('memcpy', [AIR.Get('LNewMsg'), AIR.Get('AMsg'), AIR.Add(AIR.Get('LLen'), AIR.MakeInt64(1))])
        .Call('TlsSetValue', [AIR.Get('Gny_TlsExcMsg'), AIR.Get('LNewMsg')])
     .Otherwise()
        .Call('TlsSetValue', [AIR.Get('Gny_TlsExcMsg'), AIR.Null()])
     .EndWhen()
     // Store code (cast to pointer for TLS)
     .Call('TlsSetValue', [AIR.Get('Gny_TlsExcCode'), AIR.Get('ACode')])
     .Return()
  .EndFunc();

  //----------------------------------------------------------------------------
  // Gny_Raise(AMsg: Pointer)
  // Raises exception with default code (1) and message.
  //----------------------------------------------------------------------------
  AIR.Func('Gny_Raise', gvtVoid, False, plC, False)
     .Param('AMsg', gvtPointer)
     .Call('Gny_SetException', [AIR.MakeInt64(1), AIR.Get('AMsg')])
     // RaiseException(0xE0505858, 0, 0, nil) - 'PXX' custom exception
     .Call('RaiseException', [AIR.MakeInt64($E0505858), AIR.MakeInt64(0), AIR.MakeInt64(0), AIR.Null()])
     .Return()
  .EndFunc();

  //----------------------------------------------------------------------------
  // Gny_RaiseCode(ACode: Int32; AMsg: Pointer)
  // Raises exception with custom code and message.
  //----------------------------------------------------------------------------
  AIR.Func('Gny_RaiseCode', gvtVoid, False, plC, False)
     .Param('ACode', gvtInt32)
     .Param('AMsg', gvtPointer)
     .Call('Gny_SetException', [AIR.Get('ACode'), AIR.Get('AMsg')])
     // RaiseException(0xE0505858, 0, 0, nil) - 'PXX' custom exception
     .Call('RaiseException', [AIR.MakeInt64($E0505858), AIR.MakeInt64(0), AIR.MakeInt64(0), AIR.Null()])
     .Return()
  .EndFunc();

  //----------------------------------------------------------------------------
  // Gny_GetExceptionCode(): Int32
  // Returns the current exception code from TLS.
  //----------------------------------------------------------------------------
  AIR.Func('Gny_GetExceptionCode', gvtInt32, False, plC, False)
     .Return(AIR.Invoke('TlsGetValue', [AIR.Get('Gny_TlsExcCode')]))
  .EndFunc();

  //----------------------------------------------------------------------------
  // Gny_GetExceptionMessage(): Pointer
  // Returns pointer to the current exception message from TLS.
  //----------------------------------------------------------------------------
  AIR.Func('Gny_GetExceptionMessage', gvtPointer, False, plC, False)
     .Return(AIR.Invoke('TlsGetValue', [AIR.Get('Gny_TlsExcMsg')]))
  .EndFunc();

  //----------------------------------------------------------------------------
  // Gny_SEHFilter(AExcPtrs: Pointer): Int32
  // SEH filter function called by __C_specific_handler for except scopes.
  // Extracts the Windows exception code from EXCEPTION_POINTERS and stores
  // it in TLS so Gny_GetExceptionCode() returns the correct value for
  // hardware exceptions (e.g. div-by-zero = 0xC0000094).
  // For our custom software exceptions (code = 0xE0505858), Gny_Raise/
  // Gny_RaiseCode already called Gny_SetException, so we skip.
  // Returns 1 (EXCEPTION_EXECUTE_HANDLER) to always handle the exception.
  //----------------------------------------------------------------------------
  AIR.Func('Gny_SEHFilter', gvtInt32, False, plC, False)
     .Param('AExcPtrs', gvtPointer)
     .Local('LExcRecord', gvtPointer)
     .Local('LRaw', gvtInt64)
     .Local('LCode', gvtInt64)
     // ExceptionRecord = *(EXCEPTION_POINTERS*) — first field at offset 0
     .Assign('LExcRecord', AIR.Deref(AIR.Get('AExcPtrs')))
     // Load 8 bytes from ExceptionRecord offset 0 (ExceptionCode + ExceptionFlags)
     .Assign('LRaw', AIR.Deref(AIR.Get('LExcRecord')))
     // Mask to lower 32 bits to isolate ExceptionCode (DWORD)
     .Assign('LCode', AIR.BitAnd(AIR.Get('LRaw'), AIR.MakeInt64($FFFFFFFF)))
     // If not our custom exception marker, store the hardware exception code
     .When(AIR.Ne(AIR.Get('LCode'), AIR.MakeInt64(Int64($E0505858))))
        .Call('Gny_SetException', [AIR.Get('LCode'), AIR.Null()])
     .EndWhen()
     // Always handle the exception
     .Return(AIR.MakeInt64(1))
  .EndFunc();
end;

//==============================================================================
// TRuntime - Command Line
//==============================================================================

procedure TRuntime.AddCommandLine(const AIR: TIR);
begin
  //----------------------------------------------------------------------------
  // Import Windows command-line functions
  //----------------------------------------------------------------------------
  AIR.Import('kernel32.dll', 'GetCommandLineW', [], gvtPointer, False);
  AIR.Import('shell32.dll', 'CommandLineToArgvW', [gvtPointer, gvtPointer], gvtPointer, False);
  AIR.Import('kernel32.dll', 'LocalFree', [gvtPointer], gvtPointer, False);
  AIR.Import('kernel32.dll', 'WideCharToMultiByte',
    [gvtUInt32, gvtUInt32, gvtPointer, gvtInt32, gvtPointer, gvtInt32, gvtPointer, gvtPointer],
    gvtInt32, False);
  AIR.Import('kernel32.dll', 'GetModuleFileNameW',
    [gvtPointer, gvtPointer, gvtUInt32], gvtUInt32, False);

  //----------------------------------------------------------------------------
  // Globals for argc/argv storage
  //----------------------------------------------------------------------------
  AIR.Global('Gny_Argc', gvtInt64);
  AIR.Global('Gny_Argv', gvtPointer);

  //----------------------------------------------------------------------------
  // Gny_InitCommandLine()
  // Parses command line, converts wide strings to UTF-8.
  // Uses a simple indexed loop to convert each wide string argument.
  //----------------------------------------------------------------------------
  AIR.Func('Gny_InitCommandLine', gvtVoid, False, plC, False)
     .Local('LCmdLine', gvtPointer)
     .Local('LWargv', gvtPointer)
     .Local('LArgc', gvtInt32)
     .Local('i', gvtInt64)
     .Local('LWidePtr', gvtPointer)
     .Local('LLen', gvtInt32)
     .Local('LUtf8', gvtPointer)
     .Local('LWideBuf', gvtPointer);

  // Get wide command line and parse it
  AIR.Assign('LArgc', AIR.MakeInt64(0))  // Zero full 8-byte slot before 32-bit write by CommandLineToArgvW
     .Assign('LCmdLine', AIR.Invoke('GetCommandLineW', []))
     .Assign('LWargv', AIR.Invoke('CommandLineToArgvW',
        [AIR.Get('LCmdLine'), AIR.AddrOf('LArgc')]))
     .Assign('Gny_Argc', AIR.Get('LArgc'))
     .Assign('Gny_Argv', AIR.Invoke('Gny_GetMem',
        [AIR.Mul(AIR.Get('Gny_Argc'), AIR.MakeInt64(8))]));

  // Loop: i = 0
  AIR.Assign('i', AIR.MakeInt64(0));

  // While i < Gny_Argc
  AIR.Loop(AIR.Lt(AIR.Get('i'), AIR.Get('Gny_Argc')));

  // LWidePtr := LWargv[i] (load pointer at offset i*8)
  AIR.Assign('LWidePtr', AIR.Deref(
     AIR.Add(AIR.Get('LWargv'), AIR.Mul(AIR.Get('i'), AIR.MakeInt64(8))),
     gvtPointer));

  // LLen := WideCharToMultiByte(CP_UTF8, 0, LWidePtr, -1, nil, 0, nil, nil)
  AIR.Assign('LLen', AIR.Invoke('WideCharToMultiByte',
     [AIR.MakeInt64(65001), AIR.MakeInt64(0), AIR.Get('LWidePtr'), AIR.MakeInt64(-1),
      AIR.Null(), AIR.MakeInt64(0), AIR.Null(), AIR.Null()]));

  // LUtf8 := Gny_GetMem(LLen)
  AIR.Assign('LUtf8', AIR.Invoke('Gny_GetMem', [AIR.Get('LLen')]));

  // WideCharToMultiByte(CP_UTF8, 0, LWidePtr, -1, LUtf8, LLen, nil, nil)
  AIR.Call('WideCharToMultiByte',
     [AIR.MakeInt64(65001), AIR.MakeInt64(0), AIR.Get('LWidePtr'), AIR.MakeInt64(-1),
      AIR.Get('LUtf8'), AIR.Get('LLen'), AIR.Null(), AIR.Null()]);

  // Gny_Argv[i] := LUtf8
  AIR.SetVal(
     AIR.Deref(AIR.Add(AIR.Get('Gny_Argv'), AIR.Mul(AIR.Get('i'), AIR.MakeInt64(8))), gvtPointer),
     AIR.Get('LUtf8'));

  // i := i + 1
  AIR.Assign('i', AIR.Add(AIR.Get('i'), AIR.MakeInt64(1)));

  AIR.EndLoop();

  // Free the wide argv array (allocated by CommandLineToArgvW)
  AIR.Call('LocalFree', [AIR.Get('LWargv')]);

  //--------------------------------------------------------------------------
  // Replace argv[0] with full absolute path via GetModuleFileNameW
  //--------------------------------------------------------------------------
  // Allocate wide buffer (MAX_PATH = 260 wchars = 520 bytes)
  AIR.Assign('LWideBuf', AIR.Invoke('Gny_GetMem', [AIR.MakeInt64(520)]));

  // GetModuleFileNameW(nil, LWideBuf, 260)
  AIR.Call('GetModuleFileNameW',
     [AIR.Null(), AIR.Get('LWideBuf'), AIR.MakeInt64(260)]);

  // Get UTF-8 length
  AIR.Assign('LLen', AIR.Invoke('WideCharToMultiByte',
     [AIR.MakeInt64(65001), AIR.MakeInt64(0), AIR.Get('LWideBuf'), AIR.MakeInt64(-1),
      AIR.Null(), AIR.MakeInt64(0), AIR.Null(), AIR.Null()]));

  // Allocate UTF-8 buffer
  AIR.Assign('LUtf8', AIR.Invoke('Gny_GetMem', [AIR.Get('LLen')]));

  // Convert wide -> UTF-8
  AIR.Call('WideCharToMultiByte',
     [AIR.MakeInt64(65001), AIR.MakeInt64(0), AIR.Get('LWideBuf'), AIR.MakeInt64(-1),
      AIR.Get('LUtf8'), AIR.Get('LLen'), AIR.Null(), AIR.Null()]);

  // Free old argv[0] (it was allocated by Gny_GetMem in the loop above)
  AIR.Call('Gny_FreeMem', [AIR.Deref(
     AIR.Get('Gny_Argv'), gvtPointer)]);

  // Store new UTF-8 path as argv[0]
  AIR.SetVal(
     AIR.Deref(AIR.Get('Gny_Argv'), gvtPointer),
     AIR.Get('LUtf8'));

  // Free wide buffer
  AIR.Call('Gny_FreeMem', [AIR.Get('LWideBuf')])
     .Return()
  .EndFunc();

  //----------------------------------------------------------------------------
  // Gny_FreeCommandLine()
  // Frees all allocated UTF-8 strings and the argv array.
  // Called by Gny_Halt before leak reporting.
  //----------------------------------------------------------------------------
  AIR.Func('Gny_FreeCommandLine', gvtVoid, False, plC, False)
     .Local('i', gvtInt64)
     .Local('LPtr', gvtPointer);

  // Guard: if Gny_Argv is nil (InitCommandLine was never called), skip cleanup
  AIR.When(AIR.Eq(AIR.Get('Gny_Argv'), AIR.Null()))
     .Return()
  .EndWhen();

  // Loop: free each UTF-8 string
  AIR.Assign('i', AIR.MakeInt64(0));

  AIR.Loop(AIR.Lt(AIR.Get('i'), AIR.Get('Gny_Argc')));

  // LPtr := Gny_Argv[i]
  AIR.Assign('LPtr', AIR.Deref(
     AIR.Add(AIR.Get('Gny_Argv'), AIR.Mul(AIR.Get('i'), AIR.MakeInt64(8))),
     gvtPointer));

  // Free the UTF-8 string
  AIR.Call('Gny_FreeMem', [AIR.Get('LPtr')]);

  // i := i + 1
  AIR.Assign('i', AIR.Add(AIR.Get('i'), AIR.MakeInt64(1)));

  AIR.EndLoop();

  // Free the argv array itself
  AIR.Call('Gny_FreeMem', [AIR.Get('Gny_Argv')])
     .Return()
  .EndFunc();

  //----------------------------------------------------------------------------
  // Gny_ParamCount(): Int64
  // Returns argc - 1 (Pascal semantics: excludes program name).
  //----------------------------------------------------------------------------
  AIR.Func('Gny_ParamCount', gvtInt64, False, plC, False)
     .Return(AIR.Sub(AIR.Get('Gny_Argc'), AIR.MakeInt64(1)))
  .EndFunc();

  //----------------------------------------------------------------------------
  // Gny_ParamStr(AIndex: Int64): Pointer
  // Returns pointer to UTF-8 string at given index.
  // Returns nil if index out of range.
  //----------------------------------------------------------------------------
  AIR.Func('Gny_ParamStr', gvtPointer, False, plC, False)
     .Param('AIndex', gvtInt64);

  // Check bounds: AIndex < 0
  AIR.When(AIR.Lt(AIR.Get('AIndex'), AIR.MakeInt64(0)))
     .Return(AIR.Null())
  .EndWhen();

  // Check bounds: AIndex >= Gny_Argc
  AIR.When(AIR.Ge(AIR.Get('AIndex'), AIR.Get('Gny_Argc')))
     .Return(AIR.Null())
  .EndWhen();

  // Return Gny_Argv[AIndex]
  AIR.Return(AIR.Deref(
     AIR.Add(AIR.Get('Gny_Argv'), AIR.Mul(AIR.Get('AIndex'), AIR.MakeInt64(8))),
     gvtPointer))
  .EndFunc();
end;

end.
