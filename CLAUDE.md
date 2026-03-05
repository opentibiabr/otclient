# CLAUDE.md — AI Assistant Guide for OTClient

This file provides guidance for AI assistants (Claude Code and similar tools) working on this codebase.

---

## Project Overview

**OTClient** is an open-source, cross-platform C++20/Lua Tibia client with modern graphics, performance optimizations, and extensibility. It supports protocol versions 7.6 through 15.11 and targets Windows, Linux, macOS, Android (NDK), and WebAssembly (Emscripten).

The architecture is split between:
- A **C++ framework** (`src/framework/`) providing low-level systems (graphics, networking, UI, scripting)
- A **C++ client** (`src/client/`) implementing game-specific logic
- A **Lua module system** (`modules/`) for all game UI and high-level features

---

## Repository Structure

```
otclient/
├── src/
│   ├── client/          # Game logic (creatures, map, items, UI widgets)
│   ├── framework/       # Core subsystems (see below)
│   │   ├── core/        # Application lifecycle, threading, event dispatch
│   │   ├── graphics/    # OpenGL rendering, shaders, textures, particles
│   │   ├── ui/          # Widget system, layout engine
│   │   ├── luaengine/   # LuaJIT scripting integration
│   │   ├── net/         # TCP/HTTP/WebSocket networking
│   │   ├── sound/       # OpenAL audio
│   │   ├── input/       # Keyboard and mouse handling
│   │   ├── otml/        # OTClient Template Markup Language
│   │   ├── stdext/      # Standard library extensions
│   │   ├── platform/    # OS abstraction layer
│   │   ├── proxy/       # Proxy support
│   │   ├── discord/     # Discord RPC (optional)
│   │   └── html/        # HTML rendering support
│   ├── protobuf/        # Protocol buffer definitions
│   ├── tools/           # Build utilities (e.g., datdump)
│   └── main.cpp         # Application entry point
├── modules/             # 73 Lua modules (UI, gameplay features)
├── data/                # Fonts, images, sounds, styles, particles, locales
├── tests/               # Google Test unit tests (map, otml, stdext)
├── cmake/               # CMake helper modules
├── tools/               # Development/build scripts
├── android/             # Android NDK build config
├── browser/             # WebAssembly/Emscripten config
├── vc18/                # Visual Studio project files
├── docs/                # Developer documentation
├── CMakeLists.txt       # Top-level CMake configuration
├── src/CMakeLists.txt   # Source compilation rules (878 lines)
├── CMakePresets.json    # Platform-specific build presets
├── vcpkg.json           # vcpkg dependency manifest
├── init.lua             # Lua initialization entry point
├── meta.lua             # Lua type hints (IDE support, ~130KB)
└── config.ini           # Runtime graphics/font configuration
```

---

## Build System

### Requirements
- CMake 3.16+
- C++23-capable compiler (GCC 9+, MSVC, Clang)
- vcpkg for dependency management

### Common Build Commands

```bash
# Configure (Linux, Release)
cmake --preset linux-release

# Build
cmake --build build/linux-release

# Configure with specific options
cmake -B build -DCMAKE_BUILD_TYPE=Release \
  -DOTCLIENT_FRAMEWORK_GRAPHICS=ON \
  -DOTCLIENT_FRAMEWORK_SOUND=ON \
  -DOTCLIENT_BUILD_TESTS=ON

# Run tests
cd build && ctest --output-on-failure
```

### Build Presets (CMakePresets.json)
| Preset | Platform | Notes |
|---|---|---|
| `windows-release` / `windows-debug` | Windows + Ninja | |
| `linux-release` / `linux-debug` | Linux | Default development |
| `wasm-release` | WebAssembly | Requires Emscripten |
| `android-*` | Android | Requires NDK |

### Key CMake Options
| Option | Default | Description |
|---|---|---|
| `OTCLIENT_BUILD_TESTS` | ON | Build Google Test suite |
| `OTCLIENT_FRAMEWORK_GRAPHICS` | ON | OpenGL rendering |
| `OTCLIENT_FRAMEWORK_SOUND` | ON | OpenAL audio |
| `OTCLIENT_FRAMEWORK_NET` | ON | Networking |
| `OTCLIENT_FRAMEWORK_XML` | ON | XML parsing |
| `OTCLIENT_PROTOBUF` | ON | Protocol buffer support |

### Compile-Time Configuration
`src/framework/config.h` controls optional features at compile time:
- Encryption support
- Discord Rich Presence
- Sprite sheet mode

---

## Testing

Tests live in `tests/` and use Google Test:

```bash
# Build and run all tests
cmake --build build --target tests
cd build && ctest --output-on-failure

# Run a specific test binary
./build/tests/map_test
./build/tests/otml_test
./build/tests/stdext_test
```

Tests cover:
- `tests/map/` — map loading and logic
- `tests/otml/` — OTML markup parsing
- `tests/stdext/` — standard extension utilities

Tests are disabled for Android builds.

---

## Coding Conventions

### C++ Style
- **Standard:** C++23 (minimum C++20 required)
- **Header guards:** `#pragma once`
- **Copyright header:** MIT license block at top of every source file

### Naming
| Item | Convention | Example |
|---|---|---|
| Classes | PascalCase | `Creature`, `MapView`, `Tile` |
| Methods | camelCase | `setHealthPercent()`, `getTopThing()` |
| Private members | `m_` prefix | `m_position`, `m_things` |
| Constants / enums | UPPER_CASE | `FULL_GROUND`, `NOT_PATHABLE` |
| Globals (singletons) | `g_` prefix | `g_game`, `g_app`, `g_lua` |

### Design Patterns
- **Singleton:** All major subsystems are accessed via `g_` globals (e.g., `g_game`, `g_dispatcher`, `g_lua`)
- **Manager pattern:** `ThingtypeManager`, `CreatureManager` manage collections of typed objects
- **Smart pointers:** Use `Ptr<T>` type aliases (wraps `std::shared_ptr`)
- **Observer/Event:** `g_dispatcher` handles async events; avoid raw callbacks where possible
- **Lua bindings:** Annotate classes with `@bindclass` or `@bindsingleton` for Lua exposure

### Include Order
1. Framework headers
2. Client headers
3. Third-party/system headers

---

## Lua Module System

All game UI and high-level gameplay features are implemented in Lua under `modules/`.

### Module Structure
Each module is a directory with:
```
modules/game_feature/
├── game_feature.otui    # UI layout (OTML format)
├── game_feature.lua     # Main Lua logic
└── ...
```

### Key Modules
| Module | Purpose |
|---|---|
| `corelib/` | Base library loaded by all modules |
| `client/` | Core client interface and lifecycle |
| `client_options/` | Settings and configuration UI |
| `game_battle/` | Battle list |
| `game_containers/` | Backpack/container management |
| `game_console/` | In-game chat console |
| `game_minimap/` | Minimap display |
| `game_attachedeffects/` | Visual effects (auras, wings, particles) |
| `game_cyclopedia/` | In-game encyclopedia |
| `game_market/` | Market/trading post |

### Lua Globals
- `g_game` — Game state and actions
- `g_app` — Application lifecycle
- `g_lua` — Lua engine access
- `g_dispatcher` — Async event dispatch
- `g_map` — Map data access
- `g_creatures` — Creature registry
- `connect(object, { event = handler })` — Event binding pattern

### OTML (OTClient Template Markup Language)
UI layouts use `.otui` files in OTML format. See `docs/otml-variables.md` for variable system documentation.

---

## Key Source Files

| File | Role |
|---|---|
| `src/main.cpp` | Application entry point |
| `src/client/client.h/cpp` | Game client core / game loop |
| `src/client/game.h/cpp` | Game state management |
| `src/client/creature.h/cpp` | Creature entity |
| `src/client/map.h/cpp` | Map data structure |
| `src/client/mapview.h/cpp` | Map rendering |
| `src/framework/core/application.h/cpp` | App lifecycle |
| `src/framework/luaengine/luainterface.h/cpp` | C++/Lua bridge |
| `src/framework/graphics/drawpoolmanager.h/cpp` | Rendering pipeline |
| `src/framework/net/protocol.h/cpp` | Network protocol base |

---

## Dependencies (vcpkg)

Core dependencies managed via `vcpkg.json`:

| Library | Purpose |
|---|---|
| `asio` | Async I/O |
| `luajit` | Lua scripting (not used on Android/WASM) |
| `opengl` / `glew` / `angle` | Graphics |
| `openal-soft` | Audio |
| `openssl` | TLS/cryptography |
| `protobuf` | Network protocol buffers |
| `physfs` | Virtual filesystem |
| `fmt` | String formatting |
| `nlohmann-json` | JSON parsing |
| `pugixml` | XML parsing |
| `zlib` / `liblzma` | Compression |
| `freetype` | Font rendering |
| `parallel-hashmap` | High-performance hash maps |
| `abseil` | Google utilities |
| `discord-rpc` | Discord Rich Presence (optional) |
| `cpp-httplib` | HTTP client |

---

## Platform Notes

| Platform | Toolchain | Notes |
|---|---|---|
| Linux | GCC/Clang + CMake | Primary development platform |
| Windows | MSVC or Ninja | vc18/ has VS project files |
| macOS | Clang + CMake | Same flow as Linux |
| Android | NDK | `android/` directory; LuaJIT disabled |
| WebAssembly | Emscripten | `browser/` directory; LuaJIT disabled |

---

## Development Workflow

### Branching
- Main branch: `main` (remote), `master` (local default)
- Feature branches follow: `feature/description` or `fix/description`
- AI-assisted branches: `claude/<task-name>-<session-id>`

### Commit Style
Commits use conventional commit style with scope and optional PR reference:
```
feat: add wheel of destiny system (#1234)
fix: correct creature health bar rendering
build: enable conditional protobuf compilation (#1627)
```

### Pull Request Guidelines
See `.github/PULL_REQUEST_TEMPLATE.md`. PRs are auto-labeled via `.github/labeler.yml` based on changed paths.

---

## Common Pitfalls & AI Assistant Notes

1. **C++/Lua boundary:** Changes to C++ classes exposed to Lua require updating both the C++ binding and `meta.lua` for IDE type hints.

2. **Singleton access:** Never instantiate framework subsystems directly. Always use the `g_` global (e.g., use `g_game` not `new Game()`).

3. **Thread safety:** The client uses multiple thread pools. Mutations to game state must go through `g_dispatcher` to be safe. Direct cross-thread access is a bug.

4. **OTML vs Lua UI:** UI layout belongs in `.otui` files (OTML format); behavior belongs in `.lua` files. Keep them separate.

5. **Platform conditionals:** Code that differs by platform should use CMake feature flags and `#ifdef` guards from `config.h`, not ad-hoc platform detection.

6. **Smart pointers:** Use `Ptr<T>` (the project's `shared_ptr` alias) for heap-allocated game objects. Raw pointers are acceptable only for non-owning observer references.

7. **Protobuf support:** Protobuf is conditionally compiled. Guard protobuf-dependent code with `#ifdef FRAMEWORK_PROTOBUF`.

8. **String encoding:** See `docs/string-encoding-policy.md` for encoding conventions. The project uses UTF-8 throughout.

9. **Module loading order:** Lua modules depend on `corelib/` being loaded first. Do not reorder the module load sequence in `init.lua` without understanding dependencies.

10. **Test coverage:** New C++ utilities in `src/framework/stdext/` should have corresponding tests in `tests/stdext/`. Map and OTML changes likewise.
