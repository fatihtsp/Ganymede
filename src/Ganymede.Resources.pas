{===============================================================================
  Ganymede™ - Embeddable Native Scripting Engine

  Copyright © 2026-present tinyBigGAMES™ LLC
  All Rights Reserved.

  See LICENSE for license information
===============================================================================}

unit Ganymede.Resources;

{$I Ganymede.Defines.inc}

interface

resourcestring

  //--------------------------------------------------------------------------
  // Severity Names
  //--------------------------------------------------------------------------
  RSSeverityHint    = 'Hint';
  RSSeverityWarning = 'Warning';
  RSSeverityError   = 'Error';
  RSSeverityFatal   = 'Fatal';
  RSSeverityNote    = 'Note';
  RSSeverityUnknown = 'Unknown';

  //--------------------------------------------------------------------------
  // Error Format Strings
  //--------------------------------------------------------------------------
  RSErrorFormatSimple              = '%s %s: %s';
  RSErrorFormatWithLocation        = '%s: %s %s: %s';
  RSErrorFormatRelatedSimple       = '  %s: %s';
  RSErrorFormatRelatedWithLocation = '  %s: %s: %s';

  //--------------------------------------------------------------------------
  // Fatal / I/O Messages
  //--------------------------------------------------------------------------
  RSFatalFileNotFound  = 'File not found: ''%s''';
  RSFatalFileReadError = 'Cannot read file ''%s'': %s';
  RSFatalInternalError = 'Internal error: %s';

  //--------------------------------------------------------------------------
  // Lexer Messages
  //--------------------------------------------------------------------------
  RSLexerUnterminatedComment       = 'Unterminated comment starting at line %d, column %d';
  RSLexerUnterminatedInterpolation = 'Unterminated interpolation starting at line %d, column %d';
  RSLexerUnterminatedVerbatim      = 'Unterminated verbatim block';
  RSLexerUnterminatedAttrValue     = 'Unterminated quoted attribute value';
  RSLexerExpectedTagName           = 'Expected tag name after ''{''';
  RSLexerInvalidEscape             = 'Invalid escape sequence ''\%s'', treating ''\'' as literal';
  RSLexerEmptyInterpolation        = 'Empty interpolation expression';
  RSLexerEmptyAttrValue            = 'Empty attribute value after ''=''';
  RSLexerUnclosedBrace             = 'Unclosed ''{'' at end of input (%d unclosed)';
  RSLexerUnterminatedString        = 'Unterminated string starting at line %d, column %d';

  //--------------------------------------------------------------------------
  // Lexer Status Messages
  //--------------------------------------------------------------------------
  RSLexerStatusStart    = 'Tokenizing (%d chars)...';
  RSLexerStatusComplete = 'Tokenized %d tokens (%d errors)';

  //--------------------------------------------------------------------------
  // Parser Messages
  //--------------------------------------------------------------------------
  RSParserUnexpectedToken = 'Unexpected token at line %d, column %d';
  RSParserUnclosedTag     = 'Unclosed tag ''%s''';
  RSParserElseOutsideIf   = '{else}/{elseif} outside of {if}';
  RSParserMissingCondition = 'Missing condition for ''%s''';
  RSParserMissingBinding   = 'Missing binding name for {each}';
  RSParserMissingName      = 'Missing name for ''%s''';

  //--------------------------------------------------------------------------
  // Parser Status Messages
  //--------------------------------------------------------------------------
  RSParserStatusStart    = 'Parsing (%d tokens)...';
  RSParserStatusComplete = 'Parsed %d nodes (%d errors)';

  //--------------------------------------------------------------------------
  // Expression Parser Messages
  //--------------------------------------------------------------------------
  RSExprUnexpectedToken = 'Unexpected token in expression: ''%s''';
  RSExprUnclosedParen   = 'Unclosed parenthesis in expression';
  RSExprEmpty           = 'Empty expression';
  RSExprUnterminatedStr = 'Unterminated string in expression';

  //--------------------------------------------------------------------------
  // Expression Parser Status Messages
  //--------------------------------------------------------------------------
  RSExprStatusStart    = 'Evaluating expression (%d chars)...';
  RSExprStatusComplete = 'Expression evaluated (%d nodes, %d errors)';

  //--------------------------------------------------------------------------
  // Semantic Analysis Messages
  //--------------------------------------------------------------------------
  RSSemElseOutsideIf    = '{%s} found outside of {if}';
  RSSemMissingCondition  = 'Missing condition for {%s}';
  RSSemMissingName       = 'Missing name for {%s}';
  RSSemMissingPath       = 'Missing path for {get} or {include}';
  RSSemInvalidNesting    = '{%s} cannot be nested inside {%s}';
  RSSemUnknownComponent  = 'Unknown component ''%s'' in {call}';
  RSSemDuplicateDef      = 'Duplicate component definition ''%s''';
  RSSemExprInvalid       = 'Invalid expression: ''%s''';
  RSSemVoidHasContent    = 'Void tag {%s} must not have content';
  RSSemMetaPosition      = '{meta} must appear before content-producing tags';
  RSSemDefParamOrder     = 'Required parameter ''%s'' appears after optional parameter in {def %s}';

  //--------------------------------------------------------------------------
  // Semantic Analysis Status Messages
  //--------------------------------------------------------------------------
  RSSemStatusStart    = 'Analyzing...';
  RSSemPhaseA         = 'Validating structure...';
  RSSemPhaseC         = 'Registering components...';
  RSSemStatusComplete = 'Analysis complete (%d errors)';

  //--------------------------------------------------------------------------
  // Environment Messages
  //--------------------------------------------------------------------------
  RSEnvPopGlobal = 'Cannot pop the global scope';

  //--------------------------------------------------------------------------
  // Builtins Messages
  //--------------------------------------------------------------------------
  RSBuiltinUnknown  = 'Unknown function ''%s''';
  RSBuiltinArgCount = 'Function ''%s'' expects %d arguments, got %d';
  RSBuiltinType     = 'Type error in function ''%s'': %s';

  //--------------------------------------------------------------------------
  // Pipe Messages
  //--------------------------------------------------------------------------
  RSPipeUnknownFunc = 'Unknown pipe function ''%s''';

  //--------------------------------------------------------------------------
  // Interpreter Messages
  //--------------------------------------------------------------------------
  RSInterpIterationLimit = 'Maximum iteration limit exceeded';
  RSInterpRecursionLimit = 'Maximum recursion depth exceeded';
  RSInterpOutputLimit    = 'Maximum output size exceeded';
  RSInterpUnknownTag     = 'Unknown tag ''%s''';
  RSInterpDivZero        = 'Division by zero';
  RSInterpTypeError      = 'Type error: %s';
  RSInterpStrictUndefinedVar = 'Undefined variable ''%s'' (strict mode)';
  RSInterpStrictTypeError    = 'Type error in expression (strict mode): %s';
  RSInterpCircularInclude    = 'Circular include detected: ''%s''';

  //--------------------------------------------------------------------------
  // Interpreter Status Messages
  //--------------------------------------------------------------------------
  RSInterpStatusStart    = 'Rendering...';
  RSInterpStatusComplete = 'Rendered %d chars (%d errors)';
  RSInterpIncludeNotFound  = 'Include file not found: ''%s''';
  RSInterpIncludeResolving = 'Including ''%s''...';

  //--------------------------------------------------------------------------
  // JSON Messages
  //--------------------------------------------------------------------------
  RSJsonUnexpected   = 'Expected ''%s'' but found ''%s'' in JSON';
  RSJsonUnterminated = 'Unterminated string in JSON';

  //--------------------------------------------------------------------------
  // JSON Status Messages
  //--------------------------------------------------------------------------
  RSJsonStatusStart    = 'Parsing JSON (%d chars)...';
  RSJsonStatusComplete = 'JSON parsed (%d errors)';

  //--------------------------------------------------------------------------
  // Engine Messages
  //--------------------------------------------------------------------------
  RSEngineEmptySource  = 'Empty source';
  RSEngineRenderFailed = 'Render failed: no AST';
  RSEngineFileSaveFailed = 'Failed to save output to file: ''%s''';

  //--------------------------------------------------------------------------
  // Engine Status Messages
  //--------------------------------------------------------------------------
  RSEngineStatusConvert   = 'Converting...';
  RSEngineStatusSaveFile  = 'Saving to file...';
  RSEngineStatusComplete  = 'Complete (%d chars, %d errors)';

  //--------------------------------------------------------------------------
  // GPU Status Messages
  //--------------------------------------------------------------------------
  RSGPUStatusInitSDL             = 'Initializing SDL video...';
  RSGPUStatusInitSDLDone         = 'SDL video initialized';
  RSGPUStatusShaderCrossInit     = 'Initializing ShaderCross...';
  RSGPUStatusShaderCrossInitDone = 'ShaderCross initialized';
  RSGPUStatusDeviceCreating      = 'Creating GPU device (Vulkan)...';
  RSGPUStatusDeviceCreated       = 'GPU device created (driver: %s)';
  RSGPUStatusShaderCompiling     = 'Compiling %s shader...';
  RSGPUStatusShaderCompiled      = '%s shader compiled';
  RSGPUStatusPipelineCreating    = 'Creating %s pipeline (%s blend)...';
  RSGPUStatusPipelineCreated     = '%s pipeline created (%s blend)';
  RSGPUStatusBufferCreating      = 'Creating GPU buffers (%d vertices, %d indices)...';
  RSGPUStatusBufferCreated       = 'GPU buffers created';
  RSGPUStatusMSAACreating        = 'Creating MSAA texture (%dx%d, %dx samples)...';
  RSGPUStatusMSAACreated         = 'MSAA texture created';
  RSGPUStatusMSAADestroyed       = 'MSAA texture released';
  RSGPUStatusWindowClaimed       = 'Window claimed for GPU device';
  RSGPUStatusWindowReleased      = 'Window released from GPU device';
  RSGPUStatusShutdown            = 'GPU device shutting down...';
  RSGPUStatusShutdownDone        = 'GPU device shut down';

  //--------------------------------------------------------------------------
  // GPU Error Messages
  //--------------------------------------------------------------------------
  RSGPUErrorSDLInitFailed           = 'SDL_Init failed: %s';
  RSGPUErrorFuncNotLoaded           = 'Required function not loaded: %s';
  RSGPUErrorShaderCrossInitFailed   = 'ShaderCross initialization failed: %s';
  RSGPUErrorDeviceFailed            = 'GPU device creation failed: %s';
  RSGPUErrorWindowClaimFailed       = 'Failed to claim window for GPU: %s';
  RSGPUErrorHLSLToSPIRVFailed      = 'HLSL to SPIRV compilation failed (%s): %s';
  RSGPUErrorSPIRVReflectFailed     = 'SPIRV reflection failed (%s): %s';
  RSGPUErrorSPIRVToShaderFailed    = 'SPIRV to GPU shader compilation failed (%s): %s';
  RSGPUErrorPipelineFailed          = 'Pipeline creation failed (%s/%s): %s';
  RSGPUErrorBufferFailed            = 'GPU buffer creation failed: %s';
  RSGPUErrorTransferBufferFailed    = 'Transfer buffer creation failed: %s';
  RSGPUErrorMSAATextureFailed       = 'MSAA texture creation failed: %s';
  RSGPUErrorCommandBufferFailed     = 'Failed to acquire command buffer';
  RSGPUErrorSwapchainFailed         = 'Failed to acquire swapchain texture';

  //--------------------------------------------------------------------------
  // Window Status Messages
  //--------------------------------------------------------------------------
  RSWindowStatusCreating  = 'Creating window ''%s'' (%dx%d)...';
  RSWindowStatusCreated   = 'Window created (physical: %dx%d, DPI: %.2f)';
  RSWindowStatusClosed    = 'Window closed';
  RSWindowStatusResize    = 'Window resized to %dx%d';
  RSWindowStatusDPIChange = 'DPI scale changed to %.2f';

  //--------------------------------------------------------------------------
  // Window Error Messages
  //--------------------------------------------------------------------------
  RSWindowErrorCreateFailed = 'Window creation failed: %s';

  //--------------------------------------------------------------------------
  // Canvas Status Messages
  //--------------------------------------------------------------------------
  RSCanvasStatusInit     = 'Canvas initialized';
  RSCanvasStatusPresent  = 'Present: %d verts, %d indices, %d batches';

  //--------------------------------------------------------------------------
  // Canvas Error Messages
  //--------------------------------------------------------------------------
  RSCanvasErrorBufferFull = 'Canvas %s buffer full (max %d)';
  RSCanvasErrorInitFailed = 'Canvas Init requires valid GPU device and window';

  //--------------------------------------------------------------------------
  // Font Status Messages
  //--------------------------------------------------------------------------
  RSFontStatusCreated       = 'Font loaded: %s (%.1fpt, SDF=%s)';
  RSFontStatusDestroyed     = 'Font destroyed';
  RSFontStatusEngineCreated = 'GPU text engine created';

  //--------------------------------------------------------------------------
  // Font Error Messages
  //--------------------------------------------------------------------------
  RSFontErrorLoadFailed     = 'Failed to load font: %s';
  RSFontErrorSDFFailed      = 'Failed to enable SDF for font: %s';
  RSFontErrorEngineFailed   = 'Failed to create GPU text engine: %s';
  RSFontErrorTextFailed     = 'Failed to create text object';
  RSFontErrorDrawDataFailed = 'Failed to get GPU text draw data';

  //--------------------------------------------------------------------------
  // Image Status Messages
  //--------------------------------------------------------------------------
  RSImageStatusLoaded        = 'Image loaded: %s (%dx%d)';
  RSImageStatusCreatedTarget = 'Render target created (%dx%d)';
  RSImageStatusUnloaded      = 'Image unloaded';

  //--------------------------------------------------------------------------
  // Image Error Messages
  //--------------------------------------------------------------------------
  RSImageErrorLoadFailed          = 'Failed to load image: %s';
  RSImageErrorCreateTargetFailed  = 'Failed to create render target: %s';
  RSImageErrorSamplerFailed       = 'Image sampler creation failed: %s';
  RSImageErrorMemoryFailed        = 'Failed to load image from memory: %s';
  RSImageErrorCommandBuffer       = 'Failed to acquire command buffer for image upload';

  //--------------------------------------------------------------------------
  // Shader Status Messages
  //--------------------------------------------------------------------------
  RSShaderStatusCompiling = 'Compiling user shader...';
  RSShaderStatusCompiled  = 'User shader compiled (%d pipelines created)';
  RSShaderStatusDestroyed = 'User shader destroyed';

  //--------------------------------------------------------------------------
  // Shader Error Messages
  //--------------------------------------------------------------------------
  RSShaderErrorBodyEmpty    = 'Shader body is empty';
  RSShaderErrorSourceEmpty  = 'Shader source is empty';
  RSShaderErrorCompileFailed = 'User shader compilation failed: %s';
  RSShaderErrorPipelineFailed = 'User shader pipeline creation failed (%s blend): %s';
  RSShaderErrorFileNotFound = 'Shader file not found: %s';
  RSShaderErrorFileRead     = 'Failed to read shader file: %s';

  //--------------------------------------------------------------------------
  // Audio Status Messages
  //--------------------------------------------------------------------------
  RSAudioStatusInit            = 'Audio mixer initialized';
  RSAudioStatusShutdown        = 'Audio mixer shut down';
  RSAudioStatusMusicLoaded     = 'Music loaded: %s';
  RSAudioStatusMusicMemLoaded  = 'Music loaded from memory';
  RSAudioStatusSoundLoaded     = 'Sound loaded: %s (predecoded: %s)';
  RSAudioStatusSoundMemLoaded  = 'Sound loaded from memory (predecoded: %s)';
  RSAudioStatusMusicUnloaded   = 'Music unloaded';
  RSAudioStatusSoundUnloaded   = 'Sound unloaded';

  //--------------------------------------------------------------------------
  // Audio Error Messages
  //--------------------------------------------------------------------------
  RSAudioErrorInitFailed       = 'MIX_Init failed';
  RSAudioErrorMixerFailed      = 'Failed to create audio mixer: %s';
  RSAudioErrorTrackFailed      = 'Failed to create audio track: %s';
  RSAudioErrorMusicLoadFailed  = 'Failed to load music: %s';
  RSAudioErrorSoundLoadFailed  = 'Failed to load sound: %s';
  RSAudioErrorMusicMemFailed   = 'Failed to load music from memory: %s';
  RSAudioErrorSoundMemFailed   = 'Failed to load sound from memory: %s';
  RSAudioErrorPlayFailed       = 'Failed to play audio: %s';
  RSAudioErrorNoFreeTrack      = 'No free sound track available (max %d)';
  RSAudioErrorIOFailed         = 'Failed to create IO stream from memory: %s';

  //--------------------------------------------------------------------------
  // Timer Status Messages
  //--------------------------------------------------------------------------
  RSTimerStatusCreated = 'Timer manager created';

  //--------------------------------------------------------------------------
  // Timer Error Messages
  //--------------------------------------------------------------------------
  RSTimerErrorNoFreeSlot    = 'No free timer slot available (max %d)';
  RSTimerErrorCallbackFailed = 'Timer callback raised exception: %s';

  //--------------------------------------------------------------------------
  // Tween Status Messages
  //--------------------------------------------------------------------------
  RSTweenStatusCreated = 'Tween manager created';

  //--------------------------------------------------------------------------
  // Tween Error Messages
  //--------------------------------------------------------------------------
  RSTweenErrorNoFreeSlot      = 'No free tween slot available (max %d)';
  RSTweenErrorCallbackFailed  = 'Tween completion callback raised exception: %s';

  //--------------------------------------------------------------------------
  // Sprite Status Messages
  //--------------------------------------------------------------------------
  RSSpriteStatusLoaded   = 'Sprite sheet loaded: %s (%dx%d)';
  RSSpriteStatusUnloaded = 'Sprite sheet unloaded';

  //--------------------------------------------------------------------------
  // Sprite Error Messages
  //--------------------------------------------------------------------------
  RSSpriteErrorLoadFailed    = 'Failed to load sprite sheet: %s';
  RSSpriteErrorInvalidImage  = 'Invalid or unloaded image for sprite sheet';
  RSSpriteErrorNoImage       = 'No image loaded in sprite sheet';
  RSSpriteErrorNoFrames      = 'Animation ''%s'' has no frames';
  RSSpriteErrorAnimNotFound  = 'Animation not found: ''%s''';
  RSSpriteErrorNoSheet       = 'Sprite has no sheet assigned';

  //--------------------------------------------------------------------------
  // GUI Status Messages
  //--------------------------------------------------------------------------
  RSGUIStatusCreated        = 'GUI context created';
  RSGUIStatusShutdown       = 'GUI context destroyed';
  RSGUIStatusStyleDark      = 'GUI style set to Dark';
  RSGUIStatusStyleLight     = 'GUI style set to Light';
  RSGUIStatusStyleClassic   = 'GUI style set to Classic';
  RSGUIStatusDPIScale       = 'GUI DPI scale updated: %.2f';

  //--------------------------------------------------------------------------
  // GUI Error Messages
  //--------------------------------------------------------------------------
  RSGUIErrorInitFailed      = 'GUI initialization failed: %s';
  RSGUIErrorNoCanvas        = 'GUI requires a valid canvas';
  RSGUIErrorContextFailed   = 'Failed to create ImGui context';
  RSGUIErrorBackendSDL      = 'ImGui SDL3 backend initialization failed';
  RSGUIErrorBackendGPU      = 'ImGui SDL_GPU3 backend initialization failed';

  //--------------------------------------------------------------------------
  // Particle Status Messages
  //--------------------------------------------------------------------------
  RSParticleStatusInit      = 'Particle emitter initialized (pool: %d)';
  RSParticleStatusCleared   = 'Particle emitter cleared (%d particles killed)';

  //--------------------------------------------------------------------------
  // Particle Error Messages
  //--------------------------------------------------------------------------
  RSParticleErrorNoCanvas   = 'Particle emitter requires a valid canvas';
  RSParticleErrorPoolFull   = 'Particle pool full (%d/%d)';

  //--------------------------------------------------------------------------
  // Scene Status Messages
  //--------------------------------------------------------------------------
  RSSceneStatusPush    = 'Scene pushed: %s (depth: %d)';
  RSSceneStatusPop     = 'Scene popped (depth: %d)';
  RSSceneStatusSwitch  = 'Scene switched to: %s (depth: %d)';

  //--------------------------------------------------------------------------
  // Scene Error Messages
  //--------------------------------------------------------------------------
  RSSceneErrorStackFull  = 'Scene stack full (max %d)';
  RSSceneErrorStackEmpty = 'Cannot pop: scene stack is empty';

  //--------------------------------------------------------------------------
  // Tilemap Status Messages
  //--------------------------------------------------------------------------
  RSTilemapStatusCreated    = 'Tilemap created (%dx%d, tile %dx%d, %d layers)';
  RSTilemapStatusResized    = 'Tilemap resized to %dx%d';
  RSTilemapStatusLoaded     = 'Tilemap loaded: %s (%dx%d, %d layers)';
  RSTilemapStatusSaved      = 'Tilemap saved: %s';

  //--------------------------------------------------------------------------
  // Tilemap Error Messages
  //--------------------------------------------------------------------------
  RSTilemapErrorNoCanvas    = 'Tilemap requires a valid canvas';
  RSTilemapErrorNoTileset   = 'Tilemap requires a valid tileset image';
  RSTilemapErrorLayerIndex  = 'Tilemap layer index out of range: %d';
  RSTilemapErrorLoadFailed  = 'Failed to load tilemap: %s';
  RSTilemapErrorSaveFailed  = 'Failed to save tilemap: %s';

  //--------------------------------------------------------------------------
  // Transition Status Messages
  //--------------------------------------------------------------------------
  RSTransitionStatusInit    = 'Transition system initialized (%dx%d)';
  RSTransitionStatusStart   = 'Transition started: %s (%.1fs)';
  RSTransitionStatusDone    = 'Transition complete';

  //--------------------------------------------------------------------------
  // Transition Error Messages
  //--------------------------------------------------------------------------
  RSTransitionErrorNotInit  = 'Transition system not initialized';

  //--------------------------------------------------------------------------
  // PostFX Status Messages
  //--------------------------------------------------------------------------
  RSPostFXStatusInit        = 'PostFX initialized (%dx%d, %d effects available)';
  RSPostFXStatusShutdown    = 'PostFX shut down';
  RSPostFXStatusTextures    = 'PostFX textures created (%dx%d scene, %d bloom mips)';
  RSPostFXStatusEnabled     = 'PostFX effect enabled: %s';
  RSPostFXStatusDisabled    = 'PostFX effect disabled: %s';
  RSPostFXStatusShaderOk    = 'PostFX shader compiled: %s';

  //--------------------------------------------------------------------------
  // PostFX Error Messages
  //--------------------------------------------------------------------------
  RSPostFXErrorNoGPU        = 'PostFX requires a valid GPU device';
  RSPostFXErrorTextureFail  = 'PostFX texture creation failed: %s';
  RSPostFXErrorShaderFail   = 'PostFX shader compilation failed for %s: %s';

  //--------------------------------------------------------------------------
  // Script Lexer Error Messages
  //--------------------------------------------------------------------------
  RSScriptUnexpectedChar      = 'Unexpected character: ''%s''';
  RSScriptUnterminatedString  = 'Unterminated string literal';
  RSScriptUnterminatedComment = 'Unterminated block comment';
  RSScriptInvalidEscape       = 'Invalid escape sequence: ''\%s''';
  RSScriptInvalidHexLiteral   = 'Invalid hexadecimal literal';
  RSScriptInvalidNumberLit    = 'Invalid number literal';
  RSScriptInvalidFloatLit     = 'Invalid float literal: ''%s''';
  RSScriptInvalidCharLit      = 'Invalid character literal';
  RSScriptEmptyCharLit        = 'Empty character literal';

  RSScriptInvalidDirective    = 'Invalid directive';

  //--------------------------------------------------------------------------
  // Script Lexer Status Messages
  //--------------------------------------------------------------------------
  RSScriptLexerStatusStart    = 'Tokenizing (%d chars)...';
  RSScriptLexerStatusComplete = 'Tokenized %d tokens (%d errors)';

  //--------------------------------------------------------------------------
  // Script Parser Error Messages
  //--------------------------------------------------------------------------
  RSScriptExpected            = 'Expected %s, got ''%s''';
  RSScriptExpectedExpr        = 'Expected expression, got ''%s''';
  RSScriptExpectedStmt        = 'Expected statement, got ''%s''';
  RSScriptExpectedIdent       = 'Expected identifier';
  RSScriptExpectedType        = 'Expected type annotation';
  RSScriptUnexpectedToken     = 'Unexpected token: ''%s''';

  //--------------------------------------------------------------------------
  // Script Semantic Analysis Error Messages
  //--------------------------------------------------------------------------
  RSScriptUndeclaredIdent     = 'Undeclared identifier: ''%s''';
  RSScriptDuplicateDecl       = 'Duplicate declaration: ''%s''';
  RSScriptConstAssign         = 'Cannot assign to constant ''%s''';
  RSScriptBreakOutsideLoop    = '''break'' used outside of a loop';
  RSScriptContinueOutsideLoop = '''continue'' used outside of a loop';
  RSScriptYieldOutsideFunc    = '''yield'' used outside of a function';
  RSScriptTypeMismatch        = 'Type mismatch: expected %s, got %s';
  RSScriptArgCountMismatch    = 'Expected %d arguments, got %d';
  RSScriptNotCallable         = 'Expression is not callable';
  RSScriptCircularImport      = 'Circular import detected: ''%s''';
  RSScriptModuleNotFound      = 'Module not found: ''%s''';
  RSScriptNotIndexable        = 'Expression is not indexable';
  RSScriptNoFieldAccess       = 'Cannot access field on type %s';

  //--------------------------------------------------------------------------
  // Script IR Lowering Error Messages
  //--------------------------------------------------------------------------
  RSScriptIRUnsupportedNode   = 'Unsupported AST node in IR lowering: %s';
  RSScriptMatchLabelNotConst  = 'Match label must be a constant integer expression';

  //--------------------------------------------------------------------------
  // Script Optimizer Messages
  //--------------------------------------------------------------------------
  RSScriptOptFolded           = 'Constant folded %d instructions in %s';
  RSScriptOptDCE              = 'Eliminated %d dead instructions in %s';
  RSScriptOptInlined          = 'Inlined function %s at %d call sites';
  RSScriptOptCSE              = 'Eliminated %d common subexpressions in %s';

  //--------------------------------------------------------------------------
  // Script Compiler Error Messages
  //--------------------------------------------------------------------------
  RSScriptCompilerTooManyRegs   = 'Function ''%s'' requires %d registers (max 256)';
  RSScriptCompilerUnmappedReg   = 'Internal error: unmapped SSA register %d';
  RSScriptCompilerBadJumpTarget = 'Internal error: jump target block %d not found';
  RSScriptCompilerUnsupportedOp = 'Internal error: unsupported IR opcode %d';
  RSScriptCompilerNoFunctions   = 'No functions to compile';
  RSScriptCompilerDone          = 'Compiled %d functions (%d instructions in main)';

  //--------------------------------------------------------------------------
  // Script Bytecode Serialization Error Messages
  //--------------------------------------------------------------------------
  RSScriptBytecodeNoProto        = 'No function prototype to serialize';
  RSScriptBytecodeWriteFailed    = 'Bytecode write failed: %s';
  RSScriptBytecodeReadFailed     = 'Bytecode read failed: %s';
  RSScriptBytecodeBadMagic       = 'Invalid bytecode magic (expected PXSC)';
  RSScriptBytecodeBadVersion     = 'Unsupported bytecode version %d.%d';
  RSScriptBytecodeCRCFailed      = 'Bytecode CRC32 checksum mismatch';
  RSScriptBytecodeBadDebugMagic  = 'Invalid debug info magic (expected DBUG)';
  RSScriptBytecodeNoFunctions    = 'Bytecode contains no functions';
  RSScriptBytecodeFileFailed     = 'Bytecode file operation failed for ''%s'': %s';

  //--------------------------------------------------------------------------
  // Script VM Error Messages
  //--------------------------------------------------------------------------
  RSScriptVMError              = 'VM error: %s';
  RSScriptVMRuntimeError       = 'Runtime error at PC %d: %s';
  RSScriptVMStackOverflow      = 'Stack overflow';
  RSScriptVMNoProto            = 'No function prototype to execute';
  RSScriptVMNotCallable        = 'Attempt to call a %s value';
  RSScriptVMBadArith           = 'Attempt to perform arithmetic on %s and %s';
  RSScriptVMBadUnary           = 'Attempt to perform unary operation on %s';
  RSScriptVMBadCompare         = 'Attempt to compare %s and %s';
  RSScriptVMBadConvert         = 'Cannot convert %s to %s';
  RSScriptVMNotImplemented     = 'Opcode not yet implemented: %s';
  RSScriptVMUnknownOpcode      = 'Unknown opcode: %d';
  RSScriptVMNilIndex           = 'Attempt to index with nil';
  RSScriptVMBadIndexTarget     = 'Attempt to index a %s value';
  RSScriptVMBadFieldTarget     = 'Attempt to access field on a %s value';
  RSScriptVMBadConcat          = 'Attempt to concatenate %s and %s';
  RSScriptVMBadLength          = 'Attempt to get length of a %s value';
  RSScriptVMStringConvert      = 'Cannot convert %s to string';
  RSScriptVMCoroutineDead      = 'Cannot resume a dead coroutine';
  RSScriptVMCoroutineRunning   = 'Cannot resume a running coroutine';
  RSScriptVMYieldOutside       = 'Cannot yield from outside a coroutine';
  RSScriptVMNotResumable       = 'Attempt to resume a %s value';

  //--------------------------------------------------------------------------
  // Script Host API Error Messages
  //--------------------------------------------------------------------------
  RSScriptHostError            = 'Host API error: %s';
  RSScriptHostLoadFailed       = 'Failed to load script: compilation produced errors';
  RSScriptHostNoProto          = 'No script loaded — call LoadFromString or LoadFromFile first';
  RSScriptHostNotFound         = 'Script function ''%s'' not found in globals';
  RSScriptHostNotCallable      = 'Global ''%s'' is not a callable value';
  RSScriptHostCallFailed       = 'Host function ''%s'' raised an error: %s';
  RSScriptHostFileRead         = 'Failed to read script file ''%s'': %s';
  RSScriptHostBytecodeLoad     = 'Failed to load bytecode: %s';

  //--------------------------------------------------------------------------
  // Script Standard Library Error Messages
  //--------------------------------------------------------------------------
  RSScriptStdAssertFailed      = 'Assertion failed';
  RSScriptStdAssertFailedMsg   = 'Assertion failed: %s';
  RSScriptStdBadArgType        = 'Bad argument #%d to ''%s'': expected %s, got %s';
  RSScriptStdBadArgCount       = 'Bad argument count to ''%s'': expected at least %d, got %d';
  RSScriptStdConvertFailed     = 'Cannot convert ''%s'' to %s';
  RSScriptStdSortNotCallable   = 'Sort comparison function is not callable';
  RSScriptStdFormatBadSpec     = 'Invalid format specifier: ''%%%s''';
  RSScriptStdSubOutOfRange     = 'String index out of range';
  RSScriptStdInsertOutOfRange  = 'Position out of range in table.insert';
  RSScriptStdRemoveOutOfRange  = 'Position out of range in table.remove';

  //--------------------------------------------------------------------------
  // Script Debugger Messages
  //--------------------------------------------------------------------------
  RSScriptDbgBreakpoint        = 'Breakpoint hit at %s:%d in %s';
  RSScriptDbgStepComplete      = 'Step complete at %s:%d in %s';
  RSScriptDbgNoDebugInfo       = 'No debug info available for function ''%s''';
  RSScriptDbgInvalidFrame      = 'Invalid frame index: %d (frame count: %d)';
  RSScriptDbgNotPaused         = 'Debugger is not paused';

  //--------------------------------------------------------------------------
  // Native Backend Messages
  //--------------------------------------------------------------------------
  RSBackendOutputPath         = 'Output path not specified';
  RSBackendBuildFailed        = 'Build failed - no output generated';
  RSBackendWriteFailed        = 'Error writing output: %s';
  RSBackendNoActiveFunc       = 'No active function';

  //--------------------------------------------------------------------------
  // Native Codegen Messages
  //--------------------------------------------------------------------------
  RSCodeGenNilRoot            = 'AST root is nil';
  RSCodeGenNoConfig           = 'No language config set';
  RSCodegenNoCode             = 'No code generated';
  RSCodegenRunFailed          = 'Run failed: %s';
  RSCodegenCOFFFailed         = 'COFF generation failed, cannot create .lib';
  RSCodegenJITFailed          = 'JIT execution failed: %s';

  //--------------------------------------------------------------------------
  // Native Compiler Messages
  //--------------------------------------------------------------------------
  RSCompilerModuleNotFound    = 'Module not found: ''%s''';
  RSCompilerNoSource          = 'No source file specified';
  RSCompilerSourceNotFound    = 'Source file not found: ''%s''';

  //--------------------------------------------------------------------------
  // Native IR Messages
  //--------------------------------------------------------------------------
  RSIRNoActiveFunction        = 'No active function';
  RSIRUnknownType             = 'Unknown type: ''%s''';
  RSIRUnknownBaseType         = 'Unknown base type: ''%s''';
  RSIROverloadCLinkage        = 'Overloaded routine ''%s'' cannot use C linkage';
  RSIRVariadicOverload        = 'Variadic routine ''%s'' cannot be overloaded';
  RSIRBitFieldNoRecord        = 'Bit field declared outside record';
  RSIRBitFieldWidth           = 'Bit field width exceeds type size (%d)';
  RSIRAlreadyBuildingRecord   = 'Already building a record type';
  RSIRAlreadyBuildingUnion    = 'Already building a union type';
  RSIRAlreadyBuildingEnum     = 'Already building an enum type';
  RSIRAlreadyAnonRecord       = 'Already building an anonymous record';
  RSIRAlreadyAnonUnion        = 'Already building an anonymous union';
  RSIRNotBuildingRecord       = 'Not building a record type';
  RSIRNotBuildingUnion        = 'Not building a union type';
  RSIRNotBuildingEnum         = 'Not building an enum type';
  RSIRNotBuildingRecordUnion  = 'Not building a record or union';
  RSIRNotBuildingRoutine      = 'Not building a routine type';
  RSIRBaseNotRecord           = 'Base type is not a record';
  RSIRBeginRecordNeedsUnion   = 'BeginRecord requires active union context';
  RSIRBeginUnionNeedsRecord   = 'BeginUnion requires active record context';
  RSIREnumNoValues            = 'Enum type has no values';
  RSIREnumRangeTooLarge       = 'Enum range too large';
  RSIRUnknownEnumType         = 'Unknown enum type: ''%s''';
  RSIRTypeNotEnum             = 'Type is not an enum: ''%s''';
  RSIRTypeNotSet              = 'Type is not a set: ''%s''';
  RSIRUnknownSetType          = 'Unknown set type: ''%s''';
  RSIRInvalidSetRange         = 'Invalid set range';
  RSIRSetRangeTooLarge        = 'Set range too large';
  RSIRSizeOfUnknown           = 'SizeOf: unknown type: ''%s''';
  RSIRAlignOfUnknown          = 'AlignOf: unknown type: ''%s''';
  RSIRLenNotApplicable        = 'Len not applicable to type: ''%s''';
  RSIRLenUnknown              = 'Len: unknown type: ''%s''';
  RSIRLowNotApplicable        = 'Low not applicable to type: ''%s''';
  RSIRLowUnknown              = 'Low: unknown type: ''%s''';
  RSIRHighNotApplicable       = 'High not applicable to type: ''%s''';
  RSIRHighUnknown             = 'High: unknown type: ''%s''';

  //--------------------------------------------------------------------------
  // Native Linker Messages
  //--------------------------------------------------------------------------
  RSLinkerCOFFTooSmall        = 'COFF file too small: ''%s''';
  RSLinkerNotAMD64            = 'Not an AMD64 COFF object: ''%s'' (machine=$%.4x)';
  RSLinkerARTooSmall          = 'AR file too small: ''%s''';
  RSLinkerARBadSig            = 'Invalid AR signature: ''%s''';
  RSLinkerObjNotFound         = 'Object file not found: ''%s''';
  RSLinkerLibNotFound         = 'Library file not found: ''%s''';

  //--------------------------------------------------------------------------
  // Native SSA Messages
  //--------------------------------------------------------------------------
  RSSSAUnknownFunction        = 'Unknown function: ''%s''';

  //--------------------------------------------------------------------------
  // Native Warning Messages
  //--------------------------------------------------------------------------
  RSWarnIconNotFound          = 'Icon file not found: ''%s''';
  RSWarnIconFailed            = 'Failed to load icon: ''%s''';
  RSWarnManifestFailed        = 'Failed to embed manifest';
  RSWarnVersionInfoFailed     = 'Failed to embed version info: ''%s''';

  //--------------------------------------------------------------------------
  // Native Lexer Messages
  //--------------------------------------------------------------------------
  RSNativeLexerTokenizing           = 'Tokenizing %s...';
  RSNativeLexerUnterminatedString   = 'Unterminated string literal';
  RSNativeLexerUnterminatedComment  = 'Unterminated comment';
  RSNativeLexerInvalidEscape        = 'Invalid escape character: ''%s''';
  RSNativeLexerInvalidHexEscape     = 'Invalid hex escape sequence';
  RSNativeLexerInvalidNumber        = 'Invalid number: ''%s''';
  RSNativeLexerUnexpectedChar       = 'Unexpected character: ''%s''';
  RSNativeLexerFileNotFound         = 'File not found: ''%s''';
  RSNativeLexerFileReadError        = 'Error reading file ''%s'': %s';
  RSNativeLexerInvalidFilename      = 'Invalid filename ''%s'': %s';
  RSNativeLexerDirectiveError       = 'Directive error: %s';
  RSNativeLexerCondMissingArg       = '%s requires an argument';
  RSNativeLexerCondUnmatched        = 'Unmatched %s without @if';
  RSNativeLexerCondDuplicate        = 'Duplicate @else/@elseif in conditional block';
  RSNativeLexerCondUnterminated     = 'Unterminated conditional block';

  //--------------------------------------------------------------------------
  // Native Parser Errors
  //--------------------------------------------------------------------------
  SNativeErr_P001 = 'Expected %s but found ''%s''';
  SNativeErr_P002 = 'Expected %s but reached end of file';
  SNativeErr_P003 = 'Unexpected token in expression: ''%s''';
  SNativeErr_P004 = 'Unexpected token: ''%s''';
  SNativeErr_P005 = 'Expected declaration (const, type, var, routine) or ''begin'' but found ''%s''';

  //--------------------------------------------------------------------------
  // Native Semantic Errors
  //--------------------------------------------------------------------------
  SNativeErr_S100_ModuleKind = 'Unknown module kind: ''%s''';
  SNativeErr_S100_DupVar     = 'Duplicate variable declaration: ''%s''';
  SNativeErr_S101 = 'Duplicate constant declaration: ''%s''';
  SNativeErr_S102 = 'Duplicate type declaration: ''%s''';
  SNativeErr_S110 = 'Duplicate routine declaration: ''%s''';
  SNativeErr_S111 = 'Duplicate parameter declaration: ''%s''';
  SNativeErr_S120 = 'Undeclared routine: ''%s''';
  SNativeErr_S130 = 'Undefined identifier: ''%s''';
  SNativeErr_S131 = 'Expression has no effect: ''%s''';
  SNativeErr_S132 = '''%s'' is a type, not a callable routine. ' +
                    'Use named field initializers: %s(field: value)';
  SNativeErr_S140_ImportKind = 'Cannot import ''%s'': only module unit files (.vpu) can be imported';
  SNativeErr_S141 = 'Undefined routine ''%s'' in module ''%s''';
  SNativeErr_S142 = 'Undefined symbol ''%s'' in module ''%s''';
  SNativeErr_S202 = 'Unknown optimize level: ''%s''. ' +
                    'Valid values: debug, releasesafe, releasefast, releasesmall';
  SNativeErr_S203 = 'Unknown directive: ''%s''';
  SNativeErr_S204 = 'Invalid addverinfo value: ''%s''. Valid values: on, off';
  SNativeErr_S205 = 'Expected integer value for ''%s'', got: ''%s''';
  SNativeWarn_W200 = 'Overloaded routine ''%s'' cannot use C linkage; ' +
                     'defaulting to C++ linkage';

const
  //--------------------------------------------------------------------------
  // Native Backend Error Codes
  //--------------------------------------------------------------------------
  ERR_BACKEND_OUTPUT_PATH     = 'B0001';
  ERR_BACKEND_BUILD_FAILED    = 'B0002';
  ERR_BACKEND_WRITE_FAILED    = 'B0003';
  ERR_BACKEND_NO_ACTIVE_FUNC  = 'B0004';

  //--------------------------------------------------------------------------
  // Native Codegen Error Codes
  //--------------------------------------------------------------------------
  ERR_CODEGEN_NIL_ROOT        = 'C0001';
  ERR_CODEGEN_NO_CONFIG       = 'C0002';
  ERR_CODEGEN_NO_CODE         = 'C0003';
  ERR_CODEGEN_RUN_FAILED      = 'C0004';
  ERR_CODEGEN_COFF_FAILED     = 'C0005';
  ERR_CODEGEN_JIT_FAILED      = 'C0006';

  //--------------------------------------------------------------------------
  // Native Compiler Error Codes
  //--------------------------------------------------------------------------
  ERR_COMPILER_MODULE_NOT_FOUND = 'M0001';
  ERR_COMPILER_NO_SOURCE        = 'M0002';

  //--------------------------------------------------------------------------
  // Native IR Error Codes
  //--------------------------------------------------------------------------
  ERR_IR_NO_ACTIVE_FUNCTION   = 'I0001';
  ERR_IR_UNKNOWN_TYPE         = 'I0002';
  ERR_IR_TYPE_BUILD           = 'I0003';
  ERR_IR_OVERLOAD_C_LINKAGE   = 'I0004';
  ERR_IR_VARIADIC_OVERLOAD    = 'I0005';

  //--------------------------------------------------------------------------
  // Native Lexer Error Codes
  //--------------------------------------------------------------------------
  ERR_LEXER_UNTERMINATED_STRING  = 'L0001';
  ERR_LEXER_UNTERMINATED_COMMENT = 'L0002';
  ERR_LEXER_INVALID_ESCAPE       = 'L0003';
  ERR_LEXER_INVALID_HEX_ESCAPE   = 'L0004';
  ERR_LEXER_INVALID_NUMBER       = 'L0005';
  ERR_LEXER_UNEXPECTED_CHAR      = 'L0006';
  ERR_LEXER_FILE_NOT_FOUND       = 'L0007';
  ERR_LEXER_FILE_READ_ERROR      = 'L0008';
  ERR_LEXER_INVALID_FILENAME     = 'L0009';
  ERR_LEXER_DIRECTIVE_ERROR      = 'L0010';
  ERR_LEXER_COND_MISSING_ARG     = 'L0011';
  ERR_LEXER_COND_UNMATCHED       = 'L0012';
  ERR_LEXER_COND_DUPLICATE       = 'L0013';
  ERR_LEXER_COND_UNTERMINATED    = 'L0014';

  //--------------------------------------------------------------------------
  // Native Linker Error Codes
  //--------------------------------------------------------------------------
  ERR_LINKER_COFF_TOO_SMALL   = 'K0001';
  ERR_LINKER_NOT_AMD64        = 'K0002';
  ERR_LINKER_AR_TOO_SMALL     = 'K0003';
  ERR_LINKER_AR_BAD_SIG       = 'K0004';
  ERR_LINKER_OBJ_NOT_FOUND    = 'K0005';
  ERR_LINKER_LIB_NOT_FOUND    = 'K0006';

  //--------------------------------------------------------------------------
  // Native SSA Error Codes
  //--------------------------------------------------------------------------
  ERR_SSA_UNKNOWN_FUNCTION    = 'A0001';

  //--------------------------------------------------------------------------
  // Native Warning Codes
  //--------------------------------------------------------------------------
  WRN_MANIFEST_FAILED         = 'W0001';
  WRN_ICON_NOT_FOUND          = 'W0002';
  WRN_ICON_FAILED             = 'W0003';
  WRN_VERSIONINFO_FAILED      = 'W0004';

implementation

end.
