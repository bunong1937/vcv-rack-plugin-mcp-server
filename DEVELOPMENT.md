# Local Development Guide

Everything you need to build, run, and test `vcv-rack-mcp-server` locally
without touching GitHub Actions.

---

## Overview of the dev loop

```
edit C++ → make install → restart Rack → test HTTP → test MCP
```

Each iteration takes about 5–10 seconds for an incremental build.

---

## 1. One-time setup

No manual SDK or dependency downloads required. Both `make` and `cmake` fetch
the Rack SDK and `cpp-httplib` automatically on the first run, and cache them
in `build/_deps/` for subsequent builds.

If you already have a Rack SDK and want to skip the download:

```bash
# macOS/Linux
export RACK_DIR="$HOME/Rack-SDK"

# Windows (Command Prompt)
set RACK_DIR=%USERPROFILE%\Rack-SDK

# Windows (PowerShell)
$env:RACK_DIR="$env:USERPROFILE\Rack-SDK"
```

### Windows setup

For development on Windows, choose one of these toolchains:

#### Option A: MSYS2 + MinGW-w64 (recommended)

1. Install [MSYS2](https://www.msys2.org/)
2. Open MSYS2 MINGW64 terminal
3. Install build tools:
   ```bash
   pacman -S mingw-w64-x86_64-cmake mingw-w64-x86_64-gcc mingw-w64-x86_64-ninja make jq zip
   ```
4. Use the MINGW64 terminal for all build commands

#### Option B: Visual Studio Build Tools

1. Install [Visual Studio Build Tools 2019 or 2022](https://visualstudio.microsoft.com/downloads/) with C++ workload
2. Use "Developer Command Prompt for VS" for all build commands
3. Note: `make` is not available; use CMake directly

### Install Python MCP server deps (once)

```bash
# macOS/Linux
pip install mcp httpx

# Windows
python -m pip install mcp httpx
```

---

## 2. The inner build loop

```bash
# Build + install directly into Rack's plugins folder (downloads deps on first run)
make install
```

`make install` copies the compiled plugin into your Rack user folder automatically:

| OS | Plugins folder |
| --- | --- |
| macOS | `~/Documents/Rack2/plugins/` |
| Linux | `~/.Rack2/plugins/` |
| Windows | `%APPDATA%\Rack2\plugins\` |

Then **restart Rack** (plugins are loaded at startup). Search for **"Rack MCP Server"** in the module browser.

### Available make targets

| Target | What it does |
| --- | --- |
| `make` | Configure (download deps) + build |
| `make install` | Build + copy plugin to Rack plugins folder |
| `make dist` | Build + package as `.zip` in `dist/` |
| `make clean` | Remove `build/` and `dist/` |

### CMake directly (IDE / VS Code / CLion)

```bash
cmake -B build
cmake --build build --parallel
cmake --install build
```

Pass `-DRACK_DIR=/path/to/Rack-SDK` to use an existing SDK.

#### Windows: CMake with Visual Studio

```cmd
cmake -B build -G "Visual Studio 17 2022" -A x64
cmake --build build --config Release --parallel
cmake --install build
```

### Tip: faster iteration without restarting Rack

**macOS/Linux:**

```bash
# Terminal 1 — rebuild + reinstall on every save
find src -name "*.cpp" -o -name "*.hpp" | entr -c make install

# Terminal 2 — relaunch Rack after each build (macOS)
pkill -x "Rack" ; sleep 0.5 ; open -a "VCV Rack 2 Free"
```

**Windows (PowerShell):**

```powershell
# Terminal 1 — rebuild on every save (requires PSWatch module)
Install-Module PSWatch  # one-time
Watch-Command -Path .\src -Filter *.cpp,*.hpp -Command { make install }

# Terminal 2 — relaunch Rack after each build
Stop-Process -Name "Rack" -ErrorAction SilentlyContinue ; Start-Sleep -Seconds 0.5 ; Start-Process "C:\Program Files\VCV\Rack2Free\Rack.exe"
```

---

## 3. Check Rack's log for errors

If the plugin fails to load or crashes, check the log first:

| OS | Log location |
| --- | --- |
| macOS | `~/Documents/Rack2/log.txt` |
| Linux | `~/.Rack2/log.txt` |
| Windows | `%APPDATA%\Rack2\log.txt` |

```bash
# macOS/Linux
tail -f ~/Documents/Rack2/log.txt

# Windows (PowerShell)
Get-Content $env:APPDATA\Rack2\log.txt -Wait -Tail 50
```

A successful load looks like:

```
[INFO  src/plugin/Plugin.cpp:76] Loaded plugin VCVRackMcpServer
[INFO  ...] [RackMcpServer] HTTP server starting on port 2600
```

---

## 4. Test the HTTP server directly

With Rack running and the module enabled, test endpoints with `curl`:

```bash
BASE="http://127.0.0.1:2600"

# Is the server up?
curl -s $BASE/status | jq .

# List modules in the current patch
curl -s $BASE/modules | jq .

# Search the library
curl -s "$BASE/library?q=oscillator" | jq .
curl -s "$BASE/library?tags=VCO" | jq .

# Add a module (use slugs from /library)
curl -s -X POST $BASE/modules/add \
  -H "Content-Type: application/json" \
  -d '{"plugin":"Fundamental","slug":"VCO","x":100,"y":0}' | jq .

# Inspect a module (replace 42 with the returned id)
curl -s $BASE/modules/42 | jq .

# Set a param
curl -s -X POST $BASE/modules/42/params \
  -H "Content-Type: application/json" \
  -d '{"params":[{"id":0,"value":0.5}]}' | jq .

# Connect two modules
curl -s -X POST $BASE/cables \
  -H "Content-Type: application/json" \
  -d '{"outputModuleId":42,"outputId":0,"inputModuleId":43,"inputId":0}' | jq .

# List cables
curl -s $BASE/cables | jq .

# Save patch
curl -s -X POST $BASE/patch/save \
  -H "Content-Type: application/json" \
  -d '{"path":"/tmp/test.vcv"}' | jq .
```

---

## 5. Test the MCP server

The MCP server is now embedded directly in the C++ plugin and exposed over HTTP. There is no longer a separate Python wrapper.

### Interactive inspector (recommended)

You can use the MCP Inspector to test the tools manually:

```bash
# Install the MCP CLI
pip install "mcp[cli]"

# Start the inspector pointing at the Rack MCP endpoint
# (Requires Rack to be running with the module enabled)
mcp dev http://127.0.0.1:2600/mcp
```

This opens a browser UI where you can call every tool (e.g., `vcvrack_get_status`, `vcvrack_add_module`) and see the exact JSON exchanged.

### Test with Claude Desktop

Add to your Claude Desktop config file:

**macOS**: `~/Library/Application Support/Claude/claude_desktop_config.json`

**Windows**: `%APPDATA%\Claude\claude_desktop_config.json`

**Linux**: `~/.config/Claude/claude_desktop_config.json`

```json
{
  "mcpServers": {
    "vcvrack": {
      "type": "http",
      "url": "http://127.0.0.1:2600/mcp"
    }
  }
}
```

Restart Claude Desktop, then try:

> *"What modules do I have in my current patch?"*
> *"Add a VCO from Fundamental and connect its sine output to the Audio module input."*

---

## 6. Debug builds

```bash
cmake -B build -DCMAKE_BUILD_TYPE=Debug
cmake --build build --parallel
cmake --install build
```

Run Rack from the terminal to see the crash output directly:

```bash
# macOS
/Applications/VCV\ Rack\ 2\ Free.app/Contents/MacOS/Rack

# Linux
./Rack

# Windows
& "C:\Program Files\VCV\Rack2Free\Rack.exe"
```

For deeper debugging (GDB / LLDB), build Rack from source and attach to the
process — see the [Rack building docs](https://vcvrack.com/manual/Building).

#### Windows: Debugging with Visual Studio

1. Build with Visual Studio generator:
   ```cmd
   cmake -B build -G "Visual Studio 17 2022" -A x64 -DCMAKE_BUILD_TYPE=Debug
   ```
2. Open the generated `build/VCVRackMcpServer.sln` in Visual Studio
3. Set breakpoints and attach to the Rack process for debugging

---

## 7. Checklist before pushing

```bash
# Clean build from scratch (catches missing includes)
make clean && make

# Verify plugin.json is valid JSON
# macOS/Linux
python3 -c "import json; json.load(open('plugin.json')); print('plugin.json OK')"
# Windows
python -c "import json; json.load(open('plugin.json')); print('plugin.json OK')"

# Quick HTTP smoke test (Rack must be running with module enabled)
curl -sf http://127.0.0.1:2600/status | python3 -m json.tool

# Run integration tests
# macOS/Linux
python3 tests/test_server.py
# Windows
python tests/test_server.py
```

---

## Quick reference

| Task | Command (macOS/Linux) | Command (Windows) |
| --- | --- | --- |
| Build | `make` | `make` or `cmake --build build` |
| Build + install | `make install` | `make install` or `cmake --install build` |
| Package for release | `make dist` | `make dist` |
| Clean | `make clean` | `make clean` or `rmdir /s /q build dist` |
| CMake configure | `cmake -B build` | `cmake -B build -G "Visual Studio 17 2022"` |
| CMake build + install | `cmake --build build && cmake --install build` | `cmake --build build --config Release && cmake --install build` |
| Test HTTP | `curl -s http://127.0.0.1:2600/status \| jq .` | `curl -s http://127.0.0.1:2600/status` |
| Inspect MCP tools | `mcp dev http://127.0.0.1:2600/mcp` | `mcp dev http://127.0.0.1:2600/mcp` |
| Watch Rack log | `tail -f ~/Documents/Rack2/log.txt` | `Get-Content $env:APPDATA\Rack2\log.txt -Wait` |
