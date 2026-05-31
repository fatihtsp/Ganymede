<div align="center">

![Ganymede](media/ganymede.png)

<br>

[![Discord](https://img.shields.io/discord/1457450179254026250?style=for-the-badge&logo=discord&label=Discord)](https://discord.gg/Wb6z8Wam7p) [![Follow on Bluesky](https://img.shields.io/badge/Bluesky-tinyBigGAMES-blue?style=for-the-badge&logo=bluesky)](https://bsky.app/profile/tinybiggames.com) 

</div>

> **Note:** This project is not affiliated with or connected to the RAD Studio Ganymede beta by Embarcadero.

## 🚀 What is Ganymede?

**Ganymede** is an embeddable native scripting engine. You give it source code, it compiles to **real x64 machine code** via JIT — no interpreter, no bytecode VM, no garbage collector pauses. Compiled functions are bare native pointers you can call with zero overhead, exactly like calling a C function. The engine ships as a single `Ganymede.dll` with a flat C-style API that works from any language that can load a DLL.

```
module mem fibonacci;

public routine fib(n: int64): int64;
begin
  if n <= 1 then
    return n;
  end;
  return fib(n - 1) + fib(n - 2);
end;

end.
```

**Write scripts. Get native speed.** ⚡

## 💡 Why Ganymede?

- ⚡ **Native x64 JIT.** Source compiles to real machine code — no interpreter loop, no bytecode dispatch. `fib(30)` runs at the same speed as hand-written Delphi.
- 📦 **Single DLL, zero dependencies.** The entire engine is one `Ganymede.dll`. No runtime, no framework, no package manager.
- 🔧 **Flat C API.** 39 `cdecl` exports. Integrate from Delphi, C, C++, or any language that can call a DLL.
- 🔗 **Host function binding.** Inject your native functions into the script with `gny_import_host` — scripts call them like built-ins.
- 🎯 **Zero-overhead direct calls.** `gny_get_symbol` returns a raw function pointer — cast and call with no marshalling, no boxing, no lookup cost.
- 📝 **Rich type system.** Records (packed, aligned, inherited), arrays (static + dynamic), pointers, overlays (unions), enums, sets, function pointers, managed strings — all statically typed, all compiled to native code.
- 🧩 **Module system.** Compile to in-memory JIT (`module mem`), static libraries (`module lib`), or standalone DLLs (`module dll`). Import modules from other modules.
- 🌐 **Native FFI.** Call any DLL function from script code with `external "dllname"` — no wrapper needed.
- 🔄 **Live recompilation.** Load new source, compile again on the same engine. Host imports survive across compilations.
- 🛡️ **Three optimization levels.** None (debug), basic, and full — per engine instance.

## 📂 Source Units

| Unit | Purpose |
|------|---------|
| `Ganymede.pas` | 🔷 Delphi/Free Pascal dynamic import wrapper for `Ganymede.dll`. Opaque handles and flat function calls with no dependencies on engine internals. |
| `Ganymede.h` | 🔶 C/C++ single-header dynamic loader for `Ganymede.dll`. Define `GANYMEDE_IMPLEMENTATION` in one translation unit, then include normally everywhere else. |

## 💻 System Requirements

| | Requirement |
|---|---|
| **Host OS** | 🖥️ Windows 10/11 x64 |
| **Building from source** | 🔧 Delphi 12.x or higher |


## ⚡ Getting Started

### 🔷 Delphi

Clone the repo, copy `Ganymede.dll` and `lib\pascal\Ganymede.pas` into your project, add `Ganymede` to your uses clause. No packages, no components, no third-party dependencies.

```delphi
uses
  Ganymede;

var
  LEngine: TGnyEngine;
  LResult: TGnyValue;
begin
  if not gny_load(PAnsiChar('Ganymede.dll')) then Exit;
  try
    LEngine := gny_create();
    try
      gny_load_from_string(LEngine,
        PAnsiChar(
        'module mem demo;'#10 +
        'public routine add(a: int64; b: int64): int64;'#10 +
        'begin'#10 +
        '  return a + b;'#10 +
        'end;'#10 +
        'end.'),
        PAnsiChar('demo.gny'));

      if gny_compile(LEngine) then
      begin
        gny_arg_push_int64(LEngine, 30);
        gny_arg_push_int64(LEngine, 12);
        LResult := gny_invoke(LEngine, PAnsiChar('add'), GNY_VT_INT64);
        WriteLn('add(30, 12) = ', LResult.AsInt64);  // 42
      end;
    finally
      gny_destroy(LEngine);
    end;
  finally
    gny_unload();
  end;
end;
```

### 🔶 C / C++

Copy `Ganymede.dll` and `lib\c\include\Ganymede.h` into your project. Define `GANYMEDE_IMPLEMENTATION` in exactly one `.c`/`.cpp` file before including the header. In all other files, include `Ganymede.h` normally. No build system integration required — just compile and link.

```c
#define GANYMEDE_IMPLEMENTATION
#include "Ganymede.h"
#include <stdio.h>

int main(void) {
    if (!gny_load("Ganymede.dll")) return 1;

    GnyEngine engine = gny_create();
    gny_load_from_string(engine,
        "module mem demo;\n"
        "public routine add(a: int64; b: int64): int64;\n"
        "begin\n"
        "  return a + b;\n"
        "end;\n"
        "end.",
        "demo.gny");

    if (gny_compile(engine)) {
        gny_arg_push_int64(engine, 30);
        gny_arg_push_int64(engine, 12);
        GnyValue result = gny_invoke(engine, "add", GNY_VT_INT64);
        printf("add(30, 12) = %lld\n", (long long)result.as_int64);
    }

    gny_destroy(engine);
    gny_unload();
    return 0;
}
```

## 📚 Documentation

| Document | Description |
|----------|-------------|
| [📜 Ganymede.md](docs/Ganymede.md) | Complete reference — language guide, full API reference, host interop, memory contract, and examples |

## 🤝 Contributing

Ganymede is an open project. Whether you are fixing a bug, improving documentation, or proposing a feature, contributions are welcome. **Report bugs** with a minimal reproduction — the smaller the example, the faster the fix. **Suggest features** by describing the use case first. **Submit pull requests** for bug fixes, docs, and well-scoped features. Join the [Discord](https://discord.gg/Wb6z8Wam7p) to discuss development, ask questions, and share what you are building.

## 💖 Support the Project

Ganymede is built in the open. If it saves you time or sparks something useful:

- ⭐ **Star the repo** — costs nothing, helps others find the project
- 🗣️ **Spread the word** — write a post, mention it in your community
- 💬 **[Join us on Discord](https://discord.gg/Wb6z8Wam7p)** — share what you're building, shape what comes next
- 💖 **[Become a sponsor](https://github.com/sponsors/tinyBigGAMES)** — directly funds development and documentation
- 🦋 **[Follow on Bluesky](https://bsky.app/profile/tinybiggames.com)** — stay in the loop on releases

## ⚖️ License

Ganymede is licensed under the **Apache License 2.0**. See [LICENSE](https://github.com/tinyBigGAMES/Ganymede?tab=Apache-2.0-1-ov-file#readme) for details. Apache 2.0 is a permissive open source license that lets you use, modify, and distribute Ganymede freely in both open source and commercial projects. You are not required to release your own source code. The license includes an explicit patent grant. Attribution is required — keep the copyright notice and license file in place.

## 🔗 Links

- 💬 [Discord](https://discord.gg/Wb6z8Wam7p)
- 🦋 [Bluesky](https://bsky.app/profile/tinybiggames.com)
- 🌐 [tinyBigGAMES](https://tinybiggames.com)

<div align="center">

**Ganymede™** — Embeddable Native Scripting Engine ⚡

Copyright &copy; 2026-present tinyBigGAMES™ LLC<br/>All Rights Reserved.

</div>
