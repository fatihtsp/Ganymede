{===============================================================================
  Ganymede™ - Embeddable Native Scripting Engine

  Copyright © 2026-present tinyBigGAMES™ LLC
  All Rights Reserved.

  See LICENSE for license information
===============================================================================}

unit Ganymede.JIT;

{$I Ganymede.Defines.inc}

interface

uses
  WinApi.Windows,
  System.SysUtils,
  System.Generics.Collections,
  Ganymede.Utils;

type
  //============================================================================
  // TJIT - Base class for JIT compiled code execution.
  // Holds executable memory containing compiled machine code and provides
  // methods to retrieve and invoke functions by name or pointer.
  //============================================================================

  { TJIT }
  TJIT = class(TGnyBaseObject)
  protected
    FCodeBase: Pointer;
    FCodeSize: NativeUInt;
    FSymbols: TDictionary<string, NativeUInt>;

    procedure AllocateExecutable(const ASize: NativeUInt); virtual; abstract;
    procedure FreeExecutable(); virtual; abstract;

  public
    function ResolveImport(const ALibrary: string; const ASymbol: string): Pointer; virtual; abstract;

    constructor Create(); override;
    destructor Destroy(); override;

    // Backend interface (called during BuildJIT)
    procedure SetCodeSize(const ASize: NativeUInt);
    function GetCodeBase(): Pointer;
    procedure AddSymbol(const AName: string; const AOffset: NativeUInt);

    // User API - Symbol access
    function GetSymbol(const AName: string): Pointer;
    function HasSymbol(const AName: string): Boolean;
    function GetSymbolNames(): TArray<string>;

    // User API - Dynamic invocation
    function Invoke(const APtr: Pointer; const AArgs: array of const): Int64; overload;
    function Invoke(const AName: string; const AArgs: array of const): Int64; overload;
    function InvokeFloat(const APtr: Pointer; const AArgs: array of const): Double; overload;
    function InvokeFloat(const AName: string; const AArgs: array of const): Double; overload;

    // Debug support
    property CodeBase: Pointer read FCodeBase;
    property CodeSize: NativeUInt read FCodeSize;
  end;

  //============================================================================
  // TJITWin64 - Windows x64 implementation of JIT compilation support.
  //============================================================================

  { TJITWin64 }
  TJITWin64 = class(TJIT)
  private
    FLoadedLibraries: TDictionary<string, HMODULE>;

  protected
    procedure AllocateExecutable(const ASize: NativeUInt); override;
    procedure FreeExecutable(); override;
  public
    constructor Create(); override;
    destructor Destroy(); override;
    function ResolveImport(const ALibrary: string; const ASymbol: string): Pointer; override;
  end;

implementation

//==============================================================================
// TJIT - Base
//==============================================================================

constructor TJIT.Create();
begin
  inherited Create();
  FCodeBase := nil;
  FCodeSize := 0;
  FSymbols := TDictionary<string, NativeUInt>.Create();
end;

destructor TJIT.Destroy();
begin
  FreeExecutable();
  FSymbols.Free();
  inherited Destroy();
end;

//------------------------------------------------------------------------------
// Backend Interface
//------------------------------------------------------------------------------

procedure TJIT.SetCodeSize(const ASize: NativeUInt);
begin
  if FCodeBase <> nil then
    FreeExecutable();
  AllocateExecutable(ASize);
end;

function TJIT.GetCodeBase(): Pointer;
begin
  Result := FCodeBase;
end;

procedure TJIT.AddSymbol(const AName: string; const AOffset: NativeUInt);
begin
  FSymbols.AddOrSetValue(AName, AOffset);
end;

//------------------------------------------------------------------------------
// User API - Symbol Access
//------------------------------------------------------------------------------

function TJIT.GetSymbol(const AName: string): Pointer;
var
  LOffset: NativeUInt;
begin
  if FSymbols.TryGetValue(AName, LOffset) then
    Result := Pointer(NativeUInt(FCodeBase) + LOffset)
  else
    Result := nil;
end;

function TJIT.HasSymbol(const AName: string): Boolean;
begin
  Result := FSymbols.ContainsKey(AName);
end;

function TJIT.GetSymbolNames(): TArray<string>;
begin
  Result := FSymbols.Keys.ToArray();
end;

//------------------------------------------------------------------------------
// User API - Dynamic Invocation
//------------------------------------------------------------------------------

// Dynamic call helper - sets up Win64 ABI call frame for any argument count
// Input: RCX = AFunc, RDX = AArgs, R8D = AArgCount
// Output: RAX = return value
function DynCall(AFunc: Pointer; AArgs: PInt64; AArgCount: Integer): Int64;
asm
  // Save non-volatile registers
  push rbx
  push rsi
  push rdi
  push r12
  push r13
  push r14
  push r15
  push rbp

  // Save parameters to non-volatiles
  mov r12, rcx           // r12 = function pointer
  mov r13, rdx           // r13 = args pointer
  mov r14d, r8d          // r14 = arg count

  // Calculate stack args: max(0, argcount - 4)
  xor r15d, r15d
  cmp r14d, 4
  jle @@CalcAlloc
  lea r15d, [r14d - 4]

@@CalcAlloc:
  // Alloc = 32 (shadow) + r15 * 8 (stack args)
  lea eax, [r15d * 8 + 32]

  // Align to 16 bytes for call (we're 8-misaligned after pushes)
  test eax, 15
  jnz @@AllocStack
  add eax, 8

@@AllocStack:
  mov ebx, eax
  sub rsp, rbx

  // Copy stack args (indices 4+)
  test r15d, r15d
  jz @@SetupRegs

  xor ecx, ecx
  lea r10, [rsp + 32]

@@CopyStackArgs:
  cmp ecx, r15d
  jge @@SetupRegs
  lea eax, [ecx + 4]
  mov rax, [r13 + rax * 8]
  mov [r10 + rcx * 8], rax
  inc ecx
  jmp @@CopyStackArgs

@@SetupRegs:
  // Load register args (first 4) into BOTH integer and XMM registers.
  // Win64 ABI: integer args go in RCX/RDX/R8/R9, float args go in
  // XMM0/XMM1/XMM2/XMM3 — same positional slot. We load both so the
  // callee reads whichever register type it expects ("shotgun" approach).
  cmp r14d, 1
  jl @@Call
  mov rcx, [r13]
  movq xmm0, rcx

  cmp r14d, 2
  jl @@Call
  mov rdx, [r13 + 8]
  movq xmm1, rdx

  cmp r14d, 3
  jl @@Call
  mov r8, [r13 + 16]
  movq xmm2, r8

  cmp r14d, 4
  jl @@Call
  mov r9, [r13 + 24]
  movq xmm3, r9

@@Call:
  call r12

  add rsp, rbx

  pop rbp
  pop r15
  pop r14
  pop r13
  pop r12
  pop rdi
  pop rsi
  pop rbx
end;

//------------------------------------------------------------------------------
// User API - Dynamic Invocation (Float Return)
//------------------------------------------------------------------------------

// Identical to DynCall but returns Double — Delphi reads XMM0 instead of RAX.
// Win64 ABI returns floats in XMM0; the callee already puts the value there,
// so the assembly body is the same — only the Delphi return type changes.
function DynCallFloat(AFunc: Pointer; AArgs: PInt64; AArgCount: Integer): Double;
asm
  push rbx
  push rsi
  push rdi
  push r12
  push r13
  push r14
  push r15
  push rbp

  mov r12, rcx
  mov r13, rdx
  mov r14d, r8d

  xor r15d, r15d
  cmp r14d, 4
  jle @@CalcAlloc
  lea r15d, [r14d - 4]

@@CalcAlloc:
  lea eax, [r15d * 8 + 32]
  test eax, 15
  jnz @@AllocStack
  add eax, 8

@@AllocStack:
  mov ebx, eax
  sub rsp, rbx

  test r15d, r15d
  jz @@SetupRegs

  xor ecx, ecx
  lea r10, [rsp + 32]

@@CopyStackArgs:
  cmp ecx, r15d
  jge @@SetupRegs
  lea eax, [ecx + 4]
  mov rax, [r13 + rax * 8]
  mov [r10 + rcx * 8], rax
  inc ecx
  jmp @@CopyStackArgs

@@SetupRegs:
  // Shotgun: load both integer and XMM registers for each position
  cmp r14d, 1
  jl @@Call
  mov rcx, [r13]
  movq xmm0, rcx

  cmp r14d, 2
  jl @@Call
  mov rdx, [r13 + 8]
  movq xmm1, rdx

  cmp r14d, 3
  jl @@Call
  mov r8, [r13 + 16]
  movq xmm2, r8

  cmp r14d, 4
  jl @@Call
  mov r9, [r13 + 24]
  movq xmm3, r9

@@Call:
  call r12
  // Return value is in XMM0 — Delphi reads it automatically because
  // this function is declared as returning Double

  add rsp, rbx

  pop rbp
  pop r15
  pop r14
  pop r13
  pop r12
  pop rdi
  pop rsi
  pop rbx
end;

//------------------------------------------------------------------------------
// Internal: Convert array of const to array of Int64
// Integers are stored directly; Doubles are bit-cast so the shotgun
// asm loads the correct bit pattern into both GPR and XMM registers.
//------------------------------------------------------------------------------

function VarRecsToInt64Array(const AArgs: array of const): TArray<Int64>;
var
  I: Integer;
  LFloat: Double;
begin
  SetLength(Result, Length(AArgs));
  for I := 0 to High(AArgs) do
  begin
    case AArgs[I].VType of
      vtInteger:
        Result[I] := AArgs[I].VInteger;

      vtInt64:
        Result[I] := AArgs[I].VInt64^;

      vtBoolean:
        Result[I] := Int64(Ord(AArgs[I].VBoolean));

      vtExtended:
        begin
          // Extended -> Double -> bit-cast to Int64
          LFloat := AArgs[I].VExtended^;
          Result[I] := PInt64(@LFloat)^;
        end;

      vtPointer:
        Result[I] := Int64(AArgs[I].VPointer);

      vtObject:
        Result[I] := Int64(AArgs[I].VObject);

      vtClass:
        Result[I] := Int64(AArgs[I].VClass);

      vtInterface:
        Result[I] := Int64(AArgs[I].VInterface);

      vtPChar:
        Result[I] := Int64(AArgs[I].VPChar);

      vtPWideChar:
        Result[I] := Int64(AArgs[I].VPWideChar);
    else
      raise Exception.CreateFmt(
        'Unsupported argument type at index %d (VType=%d)', [I, AArgs[I].VType]);
    end;
  end;
end;

//------------------------------------------------------------------------------
// User API - Dynamic Invocation (array of const overloads)
//------------------------------------------------------------------------------

function TJIT.Invoke(const APtr: Pointer; const AArgs: array of const): Int64;
var
  LArgs: TArray<Int64>;
begin
  if APtr = nil then
    raise Exception.Create('Cannot invoke nil pointer');

  LArgs := VarRecsToInt64Array(AArgs);
  if Length(LArgs) = 0 then
    Result := DynCall(APtr, nil, 0)
  else
    Result := DynCall(APtr, @LArgs[0], Length(LArgs));
end;

function TJIT.Invoke(const AName: string; const AArgs: array of const): Int64;
var
  LPtr: Pointer;
begin
  LPtr := GetSymbol(AName);
  if LPtr = nil then
    raise Exception.CreateFmt('Symbol not found: %s', [AName]);
  Result := Invoke(LPtr, AArgs);
end;

function TJIT.InvokeFloat(const APtr: Pointer; const AArgs: array of const): Double;
var
  LArgs: TArray<Int64>;
begin
  if APtr = nil then
    raise Exception.Create('Cannot invoke nil pointer');

  LArgs := VarRecsToInt64Array(AArgs);
  if Length(LArgs) = 0 then
    Result := DynCallFloat(APtr, nil, 0)
  else
    Result := DynCallFloat(APtr, @LArgs[0], Length(LArgs));
end;

function TJIT.InvokeFloat(const AName: string; const AArgs: array of const): Double;
var
  LPtr: Pointer;
begin
  LPtr := GetSymbol(AName);
  if LPtr = nil then
    raise Exception.CreateFmt('Symbol not found: %s', [AName]);
  Result := InvokeFloat(LPtr, AArgs);
end;

//==============================================================================
// TJITWin64
//==============================================================================

constructor TJITWin64.Create();
begin
  inherited Create();
  FLoadedLibraries := TDictionary<string, HMODULE>.Create();
end;

destructor TJITWin64.Destroy();
var
  LHandle: HMODULE;
begin
  // Free loaded libraries
  for LHandle in FLoadedLibraries.Values do
    FreeLibrary(LHandle);
  FLoadedLibraries.Free();

  inherited Destroy();
end;

procedure TJITWin64.AllocateExecutable(const ASize: NativeUInt);
begin
  FCodeBase := VirtualAlloc(nil, ASize, MEM_COMMIT or MEM_RESERVE, PAGE_EXECUTE_READWRITE);
  if FCodeBase = nil then
    raise Exception.CreateFmt('Failed to allocate executable memory: %d bytes (error %d)',
      [ASize, GetLastError()]);
  FCodeSize := ASize;
end;

procedure TJITWin64.FreeExecutable();
begin
  if FCodeBase <> nil then
  begin
    VirtualFree(FCodeBase, 0, MEM_RELEASE);
    FCodeBase := nil;
    FCodeSize := 0;
  end;
end;

function TJITWin64.ResolveImport(const ALibrary: string; const ASymbol: string): Pointer;
var
  LHandle: HMODULE;
  LKey: string;
begin
  LKey := ALibrary.ToLower();

  if not FLoadedLibraries.TryGetValue(LKey, LHandle) then
  begin
    LHandle := LoadLibraryW(PWideChar(ALibrary));
    if LHandle = 0 then
      raise Exception.CreateFmt('Failed to load library: %s (error %d)',
        [ALibrary, GetLastError()]);
    FLoadedLibraries.Add(LKey, LHandle);
  end;

  Result := GetProcAddress(LHandle, PAnsiChar(AnsiString(ASymbol)));
  if Result = nil then
    raise Exception.CreateFmt('Failed to find symbol: %s in %s (error %d)',
      [ASymbol, ALibrary, GetLastError()]);
end;

end.
