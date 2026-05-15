{===============================================================================
  Ganymede™ - Embeddable Native Scripting Engine

  Copyright © 2026-present tinyBigGAMES™ LLC
  All Rights Reserved.

  See LICENSE for license information
===============================================================================}

unit Ganymede.Debug.SourceMap;

{$I Ganymede.Defines.inc}

interface

uses
  System.SysUtils,
  System.Classes,
  System.Generics.Collections,
  System.Generics.Defaults,
  Ganymede.Utils,
  Ganymede.Types;

type
  //============================================================================
  // TSourceMapEntry - Single mapping from code offset to source location
  //============================================================================
  TSourceMapEntry = record
    SourceFileIndex: Integer;   // Index into FSourceFiles list
    SourceLine: Integer;
    SourceColumn: Integer;
    CodeOffset: Cardinal;       // Byte offset from .text section start
    FuncIndex: Integer;         // Which function this belongs to
  end;

  //============================================================================
  // TSourceMapFunc - Function boundary in the source map
  //============================================================================
  TSourceMapFunc = record
    FuncIndex: Integer;
    FuncName: string;
    StartOffset: Cardinal;     // Byte offset of function start
    EndOffset: Cardinal;       // Byte offset of function end (0 = not yet set)
  end;

  //============================================================================
  // TVariableLocationKind - Where a variable lives at runtime
  //============================================================================
  TVariableLocationKind = (
    vlkStack,       // On the stack at [RBP + StackOffset]
    vlkRegister,    // In a CPU register (RegisterIndex)
    vlkMemory       // At an absolute memory address (future use)
  );

  //============================================================================
  // TVariableLocation - Describes where a variable can be read during debugging
  //============================================================================
  TVariableLocation = record
    VarName: string;
    VarType: TGnyValueType;
    LocationKind: TVariableLocationKind;
    StackOffset: Integer;       // For vlkStack: offset from RBP (negative)
    RegisterIndex: Byte;        // For vlkRegister: x64 register index
    FuncIndex: Integer;         // Which function owns this variable
    IsParam: Boolean;           // True = parameter, False = local
    StartOffset: Cardinal;      // Code offset where location becomes valid
    EndOffset: Cardinal;        // Code offset where location becomes invalid
  end;

  //============================================================================
  // TSourceMap - Maps source locations to code offsets and vice versa.
  // Shared between JIT and PE debug modes.
  //============================================================================

  { TSourceMap }
  TSourceMap = class(TGnyBaseObject)
  private
    FEntries: TList<TSourceMapEntry>;           // Sorted by CodeOffset after Sort()
    FSourceFiles: TStringList;                   // Deduplicated file paths
    FFunctions: TList<TSourceMapFunc>;           // Function boundaries
    FVariables: TList<TVariableLocation>;        // Variable locations (params + locals)
    FLastSourceLine: Integer;                    // De-duplication: last line added
    FLastSourceFileIndex: Integer;               // De-duplication: last file added
    FSorted: Boolean;                            // True after Sort() called
    FTextSectionRVA: Cardinal;                   // From .vdbg header (PE mode)

    procedure EnsureSorted();
    function FindOrAddSourceFile(const AFile: string): Integer;

  public
    constructor Create(); override;
    destructor Destroy(); override;

    // Building (during codegen)
    procedure AddEntry(const AFile: string; const ALine: Integer;
      const AColumn: Integer; const AOffset: Cardinal; const AFuncIndex: Integer);
    procedure AddFunction(const AIndex: Integer; const AName: string;
      const AStartOffset: Cardinal; const AEndOffset: Cardinal);
    procedure UpdateFunctionEnd(const AIndex: Integer; const AEndOffset: Cardinal);
    procedure Sort();
    procedure AddVariable(const AFuncIndex: Integer; const AVarName: string;
      const AVarType: TGnyValueType; const ALocationKind: TVariableLocationKind;
      const AStackOffset: Integer; const ARegisterIndex: Byte;
      const AIsParam: Boolean; const AStartOffset: Cardinal;
      const AEndOffset: Cardinal);

    // Querying (during debugging)
    function OffsetToEntry(const AOffset: Cardinal; out AEntry: TSourceMapEntry): Boolean;
    function SourceLineToOffset(const AFile: string; const ALine: Integer): Cardinal;
    function GetFunctionAtOffset(const AOffset: Cardinal): string;
    function GetFunctionBounds(const AOffset: Cardinal; out AStart: Cardinal; out AEnd: Cardinal): Boolean;
    function GetNextLineOffset(const AOffset: Cardinal): Cardinal;
    function GetSourceFile(const AIndex: Integer): string;
    function GetEntryCount(): Integer;
    function GetEntry(const AIndex: Integer): TSourceMapEntry;
    function GetFunctionCount(): Integer;
    function GetTextSectionRVA(): Cardinal;
    function GetVariablesForFunction(const AFuncIndex: Integer): TArray<TVariableLocation>;
    function GetVariableCount(): Integer;
    function GetFunctionIndexAtOffset(const AOffset: Cardinal): Integer;

    // Persistence (.vdbg binary format)
    procedure SaveToStream(const AStream: TStream; const ATextRVA: Cardinal);
    procedure LoadFromStream(const AStream: TStream);
    procedure SaveToFile(const APath: string; const ATextRVA: Cardinal);
    procedure LoadFromFile(const APath: string);

    // Debug dump
    function Dump(const AId: Integer = 0): string; override;
  end;

implementation

//==============================================================================
// .vdbg binary format record types (Version 1)
//==============================================================================

type
  // Header: 40 bytes total
  TVDBGHeader = packed record
    Magic: array[0..3] of AnsiChar;    // 'VDBG'
    Version: UInt16;                    // Format version (1)
    Flags: UInt16;                      // Reserved flags
    TextSectionRVA: UInt32;             // .text section RVA from PE headers
    TextSectionSize: UInt32;            // .text section size (0 if unknown)
    StringTableOffset: UInt64;          // Byte offset of string table from stream start
    StringTableSize: UInt32;            // Size of string table in bytes
    SourceFileCount: UInt32;            // Number of source file entries
    VarTableCount: UInt32;              // Total variable entries across all functions
    Reserved: UInt32;                   // Padding for alignment
  end;

  // Function table entry: 24 bytes
  TVDBGFuncEntry = packed record
    NameIndex: UInt32;                  // Byte offset into string table
    StartOffset: UInt32;                // Code offset of function start
    EndOffset: UInt32;                  // Code offset of function end
    LineTableIndex: UInt32;             // Index of first line entry for this function
    LineTableCount: UInt16;             // Number of line entries for this function
    ParamCount: UInt16;                 // Phase 3: parameter count
    LocalCount: UInt16;                 // Phase 3: local variable count
    Reserved: UInt16;
  end;

  // Line table entry: 12 bytes
  TVDBGLineEntry = packed record
    CodeOffset: UInt32;                 // Byte offset from .text section start
    SourceFileIndex: UInt16;            // Index into source file table
    SourceLine: UInt16;
    SourceColumn: UInt16;
    Flags: UInt16;                      // 0 = statement, 1 = expression
  end;

  // Variable table entry: 24 bytes
  TVDBGVarEntry = packed record
    NameIndex: UInt32;                  // Byte offset into string table
    VarType: UInt8;                     // TValueType ordinal
    LocationKind: UInt8;                // TVariableLocationKind ordinal
    RegisterIndex: UInt8;               // x64 register index (for vlkRegister)
    IsParam: UInt8;                     // 1 = parameter, 0 = local
    StackOffset: Int32;                 // RBP offset (for vlkStack, negative)
    FuncIndex: UInt16;                  // Which function owns this variable
    Padding: UInt16;                    // Alignment padding
    StartOffset: UInt32;                // Code offset where valid (0 = function start)
    EndOffset: UInt32;                  // Code offset where invalid (0 = function end)
  end;

// Helper: read a null-terminated UTF-8 string from the string table at a given offset
function ReadVDBGString(const ATable: TBytes; const AOffset: UInt32): string;
var
  LPos: Integer;
  LLen: Integer;
begin
  if AOffset >= Cardinal(Length(ATable)) then
    Exit('');

  LPos := Integer(AOffset);
  LLen := 0;
  while (LPos + LLen < Length(ATable)) and (ATable[LPos + LLen] <> 0) do
    Inc(LLen);

  if LLen = 0 then
    Exit('');

  Result := TEncoding.UTF8.GetString(ATable, LPos, LLen);
end;

//==============================================================================
// TSourceMap
//==============================================================================

constructor TSourceMap.Create();
begin
  inherited Create();
  FEntries := TList<TSourceMapEntry>.Create();
  FSourceFiles := TStringList.Create();
  FSourceFiles.CaseSensitive := False;
  FFunctions := TList<TSourceMapFunc>.Create();
  FVariables := TList<TVariableLocation>.Create();
  FLastSourceLine := -1;
  FLastSourceFileIndex := -1;
  FSorted := False;
  FTextSectionRVA := 0;
end;

destructor TSourceMap.Destroy();
begin
  FVariables.Free();
  FFunctions.Free();
  FSourceFiles.Free();
  FEntries.Free();
  inherited Destroy();
end;

//------------------------------------------------------------------------------
// Private Helpers
//------------------------------------------------------------------------------

function TSourceMap.FindOrAddSourceFile(const AFile: string): Integer;
begin
  Result := FSourceFiles.IndexOf(AFile);
  if Result < 0 then
  begin
    Result := FSourceFiles.Count;
    FSourceFiles.Add(AFile);
  end;
end;

procedure TSourceMap.EnsureSorted();
begin
  if not FSorted then
    Sort();
end;

//------------------------------------------------------------------------------
// Building (during codegen)
//------------------------------------------------------------------------------

procedure TSourceMap.AddEntry(const AFile: string; const ALine: Integer;
  const AColumn: Integer; const AOffset: Cardinal; const AFuncIndex: Integer);
var
  LEntry: TSourceMapEntry;
  LFileIndex: Integer;
begin
  // De-duplicate: skip consecutive entries for the same source line + file
  LFileIndex := FindOrAddSourceFile(AFile);
  if (LFileIndex = FLastSourceFileIndex) and (ALine = FLastSourceLine) then
    Exit;

  LEntry.SourceFileIndex := LFileIndex;
  LEntry.SourceLine := ALine;
  LEntry.SourceColumn := AColumn;
  LEntry.CodeOffset := AOffset;
  LEntry.FuncIndex := AFuncIndex;

  FEntries.Add(LEntry);
  FLastSourceLine := ALine;
  FLastSourceFileIndex := LFileIndex;
  FSorted := False;
end;

procedure TSourceMap.AddFunction(const AIndex: Integer; const AName: string;
  const AStartOffset: Cardinal; const AEndOffset: Cardinal);
var
  LFunc: TSourceMapFunc;
begin
  LFunc.FuncIndex := AIndex;
  LFunc.FuncName := AName;
  LFunc.StartOffset := AStartOffset;
  LFunc.EndOffset := AEndOffset;
  FFunctions.Add(LFunc);
end;

procedure TSourceMap.UpdateFunctionEnd(const AIndex: Integer; const AEndOffset: Cardinal);
var
  LI: Integer;
  LFunc: TSourceMapFunc;
begin
  for LI := 0 to FFunctions.Count - 1 do
  begin
    if FFunctions[LI].FuncIndex = AIndex then
    begin
      LFunc := FFunctions[LI];
      LFunc.EndOffset := AEndOffset;
      FFunctions[LI] := LFunc;
      Exit;
    end;
  end;
end;

procedure TSourceMap.Sort();
var
  LComparer: IComparer<TSourceMapEntry>;
begin
  LComparer := TComparer<TSourceMapEntry>.Construct(
    function(const ALeft: TSourceMapEntry; const ARight: TSourceMapEntry): Integer
    begin
      Result := Integer(ALeft.CodeOffset) - Integer(ARight.CodeOffset);
    end
  );
  FEntries.Sort(LComparer);
  FSorted := True;
end;

procedure TSourceMap.AddVariable(const AFuncIndex: Integer; const AVarName: string;
  const AVarType: TGnyValueType; const ALocationKind: TVariableLocationKind;
  const AStackOffset: Integer; const ARegisterIndex: Byte;
  const AIsParam: Boolean; const AStartOffset: Cardinal;
  const AEndOffset: Cardinal);
var
  LVar: TVariableLocation;
begin
  LVar.VarName := AVarName;
  LVar.VarType := AVarType;
  LVar.LocationKind := ALocationKind;
  LVar.StackOffset := AStackOffset;
  LVar.RegisterIndex := ARegisterIndex;
  LVar.FuncIndex := AFuncIndex;
  LVar.IsParam := AIsParam;
  LVar.StartOffset := AStartOffset;
  LVar.EndOffset := AEndOffset;
  FVariables.Add(LVar);
end;

//------------------------------------------------------------------------------
// Querying (during debugging)
//------------------------------------------------------------------------------

function TSourceMap.OffsetToEntry(const AOffset: Cardinal; out AEntry: TSourceMapEntry): Boolean;
var
  LLow: Integer;
  LHigh: Integer;
  LMid: Integer;
  LBestIdx: Integer;
begin
  Result := False;
  if FEntries.Count = 0 then
    Exit;

  EnsureSorted();

  // Binary search for the largest CodeOffset <= AOffset
  LLow := 0;
  LHigh := FEntries.Count - 1;
  LBestIdx := -1;

  while LLow <= LHigh do
  begin
    LMid := (LLow + LHigh) div 2;
    if FEntries[LMid].CodeOffset <= AOffset then
    begin
      LBestIdx := LMid;
      LLow := LMid + 1;
    end
    else
      LHigh := LMid - 1;
  end;

  if LBestIdx >= 0 then
  begin
    AEntry := FEntries[LBestIdx];
    Result := True;
  end;
end;

function TSourceMap.SourceLineToOffset(const AFile: string; const ALine: Integer): Cardinal;
var
  LI: Integer;
  LFileIndex: Integer;
begin
  Result := Cardinal($FFFFFFFF);  // Invalid sentinel
  LFileIndex := FSourceFiles.IndexOf(AFile);
  if LFileIndex < 0 then
    Exit;

  EnsureSorted();

  // Find the first entry matching this file + line
  for LI := 0 to FEntries.Count - 1 do
  begin
    if (FEntries[LI].SourceFileIndex = LFileIndex) and
       (FEntries[LI].SourceLine = ALine) then
    begin
      Result := FEntries[LI].CodeOffset;
      Exit;
    end;
  end;
end;

function TSourceMap.GetFunctionAtOffset(const AOffset: Cardinal): string;
var
  LI: Integer;
begin
  Result := '';
  for LI := 0 to FFunctions.Count - 1 do
  begin
    if (AOffset >= FFunctions[LI].StartOffset) and
       ((FFunctions[LI].EndOffset = 0) or (AOffset < FFunctions[LI].EndOffset)) then
    begin
      Result := FFunctions[LI].FuncName;
      Exit;
    end;
  end;
end;

function TSourceMap.GetFunctionBounds(const AOffset: Cardinal;
  out AStart: Cardinal; out AEnd: Cardinal): Boolean;
var
  LI: Integer;
begin
  Result := False;
  for LI := 0 to FFunctions.Count - 1 do
  begin
    if (AOffset >= FFunctions[LI].StartOffset) and
       ((FFunctions[LI].EndOffset = 0) or (AOffset < FFunctions[LI].EndOffset)) then
    begin
      AStart := FFunctions[LI].StartOffset;
      AEnd := FFunctions[LI].EndOffset;
      Result := True;
      Exit;
    end;
  end;
end;

function TSourceMap.GetNextLineOffset(const AOffset: Cardinal): Cardinal;
var
  LEntry: TSourceMapEntry;
  LI: Integer;
  LCurrentLine: Integer;
begin
  Result := Cardinal($FFFFFFFF);  // Invalid sentinel

  // Find current line
  if not OffsetToEntry(AOffset, LEntry) then
    Exit;
  LCurrentLine := LEntry.SourceLine;

  // Walk forward through sorted entries to find the next different source line
  // within the same function
  EnsureSorted();
  for LI := 0 to FEntries.Count - 1 do
  begin
    if (FEntries[LI].CodeOffset > AOffset) and
       (FEntries[LI].SourceLine <> LCurrentLine) and
       (FEntries[LI].FuncIndex = LEntry.FuncIndex) then
    begin
      Result := FEntries[LI].CodeOffset;
      Exit;
    end;
  end;
end;

function TSourceMap.GetSourceFile(const AIndex: Integer): string;
begin
  if (AIndex >= 0) and (AIndex < FSourceFiles.Count) then
    Result := FSourceFiles[AIndex]
  else
    Result := '';
end;

function TSourceMap.GetEntryCount(): Integer;
begin
  Result := FEntries.Count;
end;

function TSourceMap.GetEntry(const AIndex: Integer): TSourceMapEntry;
begin
  Result := FEntries[AIndex];
end;

function TSourceMap.GetFunctionCount(): Integer;
begin
  Result := FFunctions.Count;
end;

function TSourceMap.GetTextSectionRVA(): Cardinal;
begin
  Result := FTextSectionRVA;
end;

function TSourceMap.GetVariablesForFunction(const AFuncIndex: Integer): TArray<TVariableLocation>;
var
  LI: Integer;
  LCount: Integer;
begin
  LCount := 0;
  for LI := 0 to FVariables.Count - 1 do
  begin
    if FVariables[LI].FuncIndex = AFuncIndex then
      Inc(LCount);
  end;

  SetLength(Result, LCount);
  LCount := 0;
  for LI := 0 to FVariables.Count - 1 do
  begin
    if FVariables[LI].FuncIndex = AFuncIndex then
    begin
      Result[LCount] := FVariables[LI];
      Inc(LCount);
    end;
  end;
end;

function TSourceMap.GetVariableCount(): Integer;
begin
  Result := FVariables.Count;
end;

function TSourceMap.GetFunctionIndexAtOffset(const AOffset: Cardinal): Integer;
var
  LI: Integer;
  LFunc: TSourceMapFunc;
begin
  Result := -1;
  for LI := 0 to FFunctions.Count - 1 do
  begin
    LFunc := FFunctions[LI];
    if (AOffset >= LFunc.StartOffset) and
       ((LFunc.EndOffset = 0) or (AOffset < LFunc.EndOffset)) then
    begin
      Result := LFunc.FuncIndex;
      Exit;
    end;
  end;
end;

//------------------------------------------------------------------------------
// Persistence (.vdbg binary format)
//------------------------------------------------------------------------------

procedure TSourceMap.SaveToStream(const AStream: TStream; const ATextRVA: Cardinal);
var
  LHeader: TVDBGHeader;
  LFuncEntry: TVDBGFuncEntry;
  LLineEntry: TVDBGLineEntry;
  LVarEntry: TVDBGVarEntry;
  LI: Integer;
  LJ: Integer;
  LFunc: TSourceMapFunc;
  LEntry: TSourceMapEntry;
  LVar: TVariableLocation;
  LStringTable: TBytes;
  LStringOffsets: TDictionary<string, UInt32>;
  LStringStream: TBytesStream;
  LUtf8: TBytes;
  LZero: Byte;
  LStreamStart: Int64;
  LLineIndex: UInt32;
  LLineCount: UInt32;
  LFuncCount: Cardinal;
  LSourceFileOffsets: TArray<UInt32>;
  LSourceFileOffset: UInt32;
begin
  EnsureSorted();

  LStreamStart := AStream.Position;

  // Build string table — collect all unique strings with byte offsets
  LStringStream := TBytesStream.Create();
  LStringOffsets := TDictionary<string, UInt32>.Create();
  try
    LZero := 0;

    // Add source file paths (in FSourceFiles order)
    SetLength(LSourceFileOffsets, FSourceFiles.Count);
    for LI := 0 to FSourceFiles.Count - 1 do
    begin
      if not LStringOffsets.ContainsKey(FSourceFiles[LI]) then
      begin
        LStringOffsets.Add(FSourceFiles[LI], UInt32(LStringStream.Size));
        LUtf8 := TEncoding.UTF8.GetBytes(FSourceFiles[LI]);
        if Length(LUtf8) > 0 then
          LStringStream.WriteBuffer(LUtf8[0], Length(LUtf8));
        LStringStream.WriteBuffer(LZero, 1);
      end;
      LSourceFileOffsets[LI] := LStringOffsets[FSourceFiles[LI]];
    end;

    // Add function names
    for LI := 0 to FFunctions.Count - 1 do
    begin
      if not LStringOffsets.ContainsKey(FFunctions[LI].FuncName) then
      begin
        LStringOffsets.Add(FFunctions[LI].FuncName, UInt32(LStringStream.Size));
        LUtf8 := TEncoding.UTF8.GetBytes(FFunctions[LI].FuncName);
        if Length(LUtf8) > 0 then
          LStringStream.WriteBuffer(LUtf8[0], Length(LUtf8));
        LStringStream.WriteBuffer(LZero, 1);
      end;
    end;

    // Add variable names
    for LI := 0 to FVariables.Count - 1 do
    begin
      if not LStringOffsets.ContainsKey(FVariables[LI].VarName) then
      begin
        LStringOffsets.Add(FVariables[LI].VarName, UInt32(LStringStream.Size));
        LUtf8 := TEncoding.UTF8.GetBytes(FVariables[LI].VarName);
        if Length(LUtf8) > 0 then
          LStringStream.WriteBuffer(LUtf8[0], Length(LUtf8));
        LStringStream.WriteBuffer(LZero, 1);
      end;
    end;

    LStringTable := Copy(LStringStream.Bytes, 0, LStringStream.Size);
  finally
    LStringStream.Free();
  end;

  try
    // Write header (placeholder — StringTableOffset patched at the end)
    FillChar(LHeader, SizeOf(LHeader), 0);
    LHeader.Magic[0] := 'V';
    LHeader.Magic[1] := 'D';
    LHeader.Magic[2] := 'B';
    LHeader.Magic[3] := 'G';
    LHeader.Version := 1;
    LHeader.Flags := 0;
    LHeader.TextSectionRVA := ATextRVA;
    LHeader.TextSectionSize := 0;
    LHeader.StringTableOffset := 0;
    LHeader.StringTableSize := Cardinal(Length(LStringTable));
    LHeader.SourceFileCount := Cardinal(FSourceFiles.Count);
    LHeader.VarTableCount := Cardinal(FVariables.Count);
    LHeader.Reserved := 0;
    AStream.WriteBuffer(LHeader, SizeOf(LHeader));

    // Write source file table (UInt32 string offsets, one per source file)
    for LI := 0 to FSourceFiles.Count - 1 do
    begin
      LSourceFileOffset := LSourceFileOffsets[LI];
      AStream.WriteBuffer(LSourceFileOffset, SizeOf(UInt32));
    end;

    // Write function table
    LFuncCount := Cardinal(FFunctions.Count);
    AStream.WriteBuffer(LFuncCount, SizeOf(Cardinal));

    LLineIndex := 0;
    for LI := 0 to FFunctions.Count - 1 do
    begin
      LFunc := FFunctions[LI];
      FillChar(LFuncEntry, SizeOf(LFuncEntry), 0);

      if LStringOffsets.ContainsKey(LFunc.FuncName) then
        LFuncEntry.NameIndex := LStringOffsets[LFunc.FuncName]
      else
        LFuncEntry.NameIndex := 0;
      LFuncEntry.StartOffset := LFunc.StartOffset;
      LFuncEntry.EndOffset := LFunc.EndOffset;

      // Count line entries belonging to this function
      LLineCount := 0;
      for LJ := 0 to FEntries.Count - 1 do
      begin
        if FEntries[LJ].FuncIndex = LFunc.FuncIndex then
          Inc(LLineCount);
      end;

      LFuncEntry.LineTableIndex := LLineIndex;
      LFuncEntry.LineTableCount := UInt16(LLineCount);

      // Count params and locals for this function from variable table
      LFuncEntry.ParamCount := 0;
      LFuncEntry.LocalCount := 0;
      for LJ := 0 to FVariables.Count - 1 do
      begin
        if FVariables[LJ].FuncIndex = LFunc.FuncIndex then
        begin
          if FVariables[LJ].IsParam then
            Inc(LFuncEntry.ParamCount)
          else
            Inc(LFuncEntry.LocalCount);
        end;
      end;
      LFuncEntry.Reserved := 0;

      AStream.WriteBuffer(LFuncEntry, SizeOf(LFuncEntry));
      Inc(LLineIndex, LLineCount);
    end;

    // Write line table (entries are already sorted by CodeOffset)
    for LI := 0 to FEntries.Count - 1 do
    begin
      LEntry := FEntries[LI];
      FillChar(LLineEntry, SizeOf(LLineEntry), 0);
      LLineEntry.CodeOffset := LEntry.CodeOffset;
      LLineEntry.SourceFileIndex := UInt16(LEntry.SourceFileIndex);
      LLineEntry.SourceLine := UInt16(LEntry.SourceLine);
      LLineEntry.SourceColumn := UInt16(LEntry.SourceColumn);
      LLineEntry.Flags := 0;
      AStream.WriteBuffer(LLineEntry, SizeOf(LLineEntry));
    end;

    // Write variable table (params + locals for all functions)
    for LI := 0 to FVariables.Count - 1 do
    begin
      LVar := FVariables[LI];
      FillChar(LVarEntry, SizeOf(LVarEntry), 0);
      if LStringOffsets.ContainsKey(LVar.VarName) then
        LVarEntry.NameIndex := LStringOffsets[LVar.VarName]
      else
        LVarEntry.NameIndex := 0;
      LVarEntry.VarType := UInt8(Ord(LVar.VarType));
      LVarEntry.LocationKind := UInt8(Ord(LVar.LocationKind));
      LVarEntry.RegisterIndex := LVar.RegisterIndex;
      if LVar.IsParam then
        LVarEntry.IsParam := 1
      else
        LVarEntry.IsParam := 0;
      LVarEntry.StackOffset := LVar.StackOffset;
      LVarEntry.FuncIndex := UInt16(LVar.FuncIndex);
      LVarEntry.Padding := 0;
      LVarEntry.StartOffset := LVar.StartOffset;
      LVarEntry.EndOffset := LVar.EndOffset;
      AStream.WriteBuffer(LVarEntry, SizeOf(LVarEntry));
    end;

    // Record string table position, then write string table
    LHeader.StringTableOffset := UInt64(AStream.Position - LStreamStart);
    if Length(LStringTable) > 0 then
      AStream.WriteBuffer(LStringTable[0], Length(LStringTable));

    // Patch header with actual StringTableOffset
    AStream.Position := LStreamStart;
    AStream.WriteBuffer(LHeader, SizeOf(LHeader));
    AStream.Position := AStream.Size;

  finally
    LStringOffsets.Free();
  end;
end;

procedure TSourceMap.LoadFromStream(const AStream: TStream);
var
  LHeader: TVDBGHeader;
  LFuncEntry: TVDBGFuncEntry;
  LLineEntry: TVDBGLineEntry;
  LVarEntry: TVDBGVarEntry;
  LI: Integer;
  LJ: Integer;
  LFuncCount: Cardinal;
  LFunc: TSourceMapFunc;
  LEntry: TSourceMapEntry;
  LVar: TVariableLocation;
  LStringTable: TBytes;
  LStreamStart: Int64;
  LLineTableBytes: Int64;
  LLineEntryCount: Integer;
  LSourceFileOffset: UInt32;
begin
  // Clear existing data
  FEntries.Clear();
  FSourceFiles.Clear();
  FFunctions.Clear();
  FVariables.Clear();
  FLastSourceLine := -1;
  FLastSourceFileIndex := -1;
  FSorted := False;

  LStreamStart := AStream.Position;

  // Read and verify header
  if AStream.Read(LHeader, SizeOf(LHeader)) <> SizeOf(LHeader) then
    raise Exception.Create('Invalid .vdbg file: header too short');

  if (LHeader.Magic[0] <> 'V') or (LHeader.Magic[1] <> 'D') or
     (LHeader.Magic[2] <> 'B') or (LHeader.Magic[3] <> 'G') then
    raise Exception.Create('Invalid .vdbg file: bad magic');

  if LHeader.Version <> 1 then
    raise Exception.CreateFmt('Unsupported .vdbg version: %d', [LHeader.Version]);

  // Save PE layout info for debug target address mapping
  FTextSectionRVA := LHeader.TextSectionRVA;

  // Read string table (needed to resolve names)
  if LHeader.StringTableSize > 0 then
  begin
    SetLength(LStringTable, LHeader.StringTableSize);
    AStream.Position := LStreamStart + Int64(LHeader.StringTableOffset);
    if AStream.Read(LStringTable[0], LHeader.StringTableSize) <> Integer(LHeader.StringTableSize) then
      raise Exception.Create('Invalid .vdbg file: string table truncated');
  end
  else
    SetLength(LStringTable, 0);

  // Seek back to after header
  AStream.Position := LStreamStart + SizeOf(LHeader);

  // Read source file table
  for LI := 0 to Integer(LHeader.SourceFileCount) - 1 do
  begin
    if AStream.Read(LSourceFileOffset, SizeOf(UInt32)) <> SizeOf(UInt32) then
      raise Exception.CreateFmt('Invalid .vdbg file: source file entry %d truncated', [LI]);
    FSourceFiles.Add(ReadVDBGString(LStringTable, LSourceFileOffset));
  end;

  // Read function table
  if AStream.Read(LFuncCount, SizeOf(Cardinal)) <> SizeOf(Cardinal) then
    raise Exception.Create('Invalid .vdbg file: function count missing');

  for LI := 0 to Integer(LFuncCount) - 1 do
  begin
    if AStream.Read(LFuncEntry, SizeOf(LFuncEntry)) <> SizeOf(LFuncEntry) then
      raise Exception.CreateFmt('Invalid .vdbg file: function entry %d truncated', [LI]);

    LFunc.FuncIndex := LI;
    LFunc.FuncName := ReadVDBGString(LStringTable, LFuncEntry.NameIndex);
    LFunc.StartOffset := LFuncEntry.StartOffset;
    LFunc.EndOffset := LFuncEntry.EndOffset;
    FFunctions.Add(LFunc);
  end;

  // Read line table (space between function table and variable table)
  // Total bytes before string table = line entries + variable entries
  LLineTableBytes := (LStreamStart + Int64(LHeader.StringTableOffset)) - AStream.Position
    - Int64(LHeader.VarTableCount) * SizeOf(TVDBGVarEntry);
  if LLineTableBytes < 0 then
    raise Exception.Create('Invalid .vdbg file: section overlap');
  LLineEntryCount := Integer(LLineTableBytes) div SizeOf(TVDBGLineEntry);

  for LI := 0 to LLineEntryCount - 1 do
  begin
    if AStream.Read(LLineEntry, SizeOf(LLineEntry)) <> SizeOf(LLineEntry) then
      raise Exception.CreateFmt('Invalid .vdbg file: line entry %d truncated', [LI]);

    LEntry.CodeOffset := LLineEntry.CodeOffset;
    LEntry.SourceFileIndex := Integer(LLineEntry.SourceFileIndex);
    LEntry.SourceLine := Integer(LLineEntry.SourceLine);
    LEntry.SourceColumn := Integer(LLineEntry.SourceColumn);
    LEntry.FuncIndex := -1;
    FEntries.Add(LEntry);
  end;

  // Read variable table
  for LI := 0 to Integer(LHeader.VarTableCount) - 1 do
  begin
    if AStream.Read(LVarEntry, SizeOf(LVarEntry)) <> SizeOf(LVarEntry) then
      raise Exception.CreateFmt('Invalid .vdbg file: variable entry %d truncated', [LI]);

    LVar.VarName := ReadVDBGString(LStringTable, LVarEntry.NameIndex);
    LVar.VarType := TGnyValueType(LVarEntry.VarType);
    LVar.LocationKind := TVariableLocationKind(LVarEntry.LocationKind);
    LVar.RegisterIndex := LVarEntry.RegisterIndex;
    LVar.IsParam := (LVarEntry.IsParam <> 0);
    LVar.StackOffset := LVarEntry.StackOffset;
    LVar.FuncIndex := Integer(LVarEntry.FuncIndex);
    LVar.StartOffset := LVarEntry.StartOffset;
    LVar.EndOffset := LVarEntry.EndOffset;
    FVariables.Add(LVar);
  end;

  // Resolve FuncIndex for each line entry using function offset boundaries
  for LI := 0 to FEntries.Count - 1 do
  begin
    LEntry := FEntries[LI];
    for LJ := 0 to FFunctions.Count - 1 do
    begin
      if (LEntry.CodeOffset >= FFunctions[LJ].StartOffset) and
         ((FFunctions[LJ].EndOffset = 0) or (LEntry.CodeOffset < FFunctions[LJ].EndOffset)) then
      begin
        LEntry.FuncIndex := FFunctions[LJ].FuncIndex;
        FEntries[LI] := LEntry;
        Break;
      end;
    end;
  end;

  // Entries were saved sorted by CodeOffset; mark as sorted
  FSorted := True;
end;

procedure TSourceMap.SaveToFile(const APath: string; const ATextRVA: Cardinal);
var
  LStream: TFileStream;
begin
  LStream := TFileStream.Create(APath, fmCreate);
  try
    SaveToStream(LStream, ATextRVA);
  finally
    LStream.Free();
  end;
end;

procedure TSourceMap.LoadFromFile(const APath: string);
var
  LStream: TFileStream;
begin
  LStream := TFileStream.Create(APath, fmOpenRead or fmShareDenyWrite);
  try
    LoadFromStream(LStream);
  finally
    LStream.Free();
  end;
end;

//------------------------------------------------------------------------------
// Debug dump
//------------------------------------------------------------------------------

function TSourceMap.Dump(const AId: Integer): string;
var
  LI: Integer;
  LEntry: TSourceMapEntry;
  LFunc: TSourceMapFunc;
  LVar: TVariableLocation;
  LSB: TStringBuilder;
begin
  EnsureSorted();

  LSB := TStringBuilder.Create();
  try
    LSB.AppendLine(Format('=== Source Map: %d entries, %d functions, %d files, %d variables ===',
      [FEntries.Count, FFunctions.Count, FSourceFiles.Count, FVariables.Count]));

    // Dump functions
    for LI := 0 to FFunctions.Count - 1 do
    begin
      LFunc := FFunctions[LI];
      LSB.AppendLine(Format('  Func[%d] %s: offset $%x..$%x',
        [LFunc.FuncIndex, LFunc.FuncName, LFunc.StartOffset, LFunc.EndOffset]));
    end;

    // Dump entries
    for LI := 0 to FEntries.Count - 1 do
    begin
      LEntry := FEntries[LI];
      LSB.AppendLine(Format('  $%06x -> %s:%d:%d (func %d)',
        [LEntry.CodeOffset, GetSourceFile(LEntry.SourceFileIndex),
         LEntry.SourceLine, LEntry.SourceColumn, LEntry.FuncIndex]));
    end;

    // Dump variables
    for LI := 0 to FVariables.Count - 1 do
    begin
      LVar := FVariables[LI];
      if LVar.IsParam then
        LSB.AppendLine(Format('  Var[%d] param %s: type=%d stack=[RBP%d] func=%d',
          [LI, LVar.VarName, Ord(LVar.VarType), LVar.StackOffset, LVar.FuncIndex]))
      else
        LSB.AppendLine(Format('  Var[%d] local %s: type=%d stack=[RBP%d] func=%d',
          [LI, LVar.VarName, Ord(LVar.VarType), LVar.StackOffset, LVar.FuncIndex]));
    end;

    Result := LSB.ToString();
  finally
    LSB.Free();
  end;
end;

end.
