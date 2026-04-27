# build_dxt.ps1 — builds vcvrack-mcp-server.mcpb (Claude Desktop Extension)
#
# Usage: .\build_dxt.ps1 [-Version X.Y.Z]
#   -Version   override version (default: read from plugin.json)

param(
    [string]$Version = ""
)

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

# Read version from plugin.json if not overridden
if ([string]::IsNullOrEmpty($Version)) {
    $PluginJson = Get-Content (Join-Path $ScriptDir "plugin.json") -Raw | ConvertFrom-Json
    $Version = $PluginJson.version
}

Write-Host "Building vcvrack-mcp-server v$Version ..."

# Create staging directory
$Stage = Join-Path $env:TEMP "dxt-build-$([System.Guid]::NewGuid().ToString().Substring(0,8))"
New-Item -ItemType Directory -Path $Stage -Force | Out-Null

# Ensure cleanup on exit
$CleanupScript = {
    if (Test-Path $using:Stage) {
        Remove-Item -Recurse -Force $using:Stage
    }
}
Register-EngineEvent -SourceIdentifier Powershell.Exiting -Action $CleanupScript | Out-Null

# Create manifest.json
$ManifestContent = @"
{
  "dxt_version": "0.1",
  "name": "vcvrack-mcp-server",
  "display_name": "VCV Rack MCP Server",
  "version": "$Version",
  "description": "Control VCV Rack from Claude. Build patches, add modules, connect cables and tweak parameters using natural language.",
  "long_description": "Connects Claude Desktop to a running VCV Rack instance via the MCP Server module (Neural Harmonics). Once the module is loaded in your rack and toggled ON, Claude can build complete patches, search the plugin library, place and wire modules, adjust parameters, and save/load patches.",
  "author": {
    "name": "Claudio Bisegni",
    "url": "https://github.com/Neural-Harmonics"
  },
  "repository": {
    "type": "git",
    "url": "https://github.com/Neural-Harmonics/vcv-rack-plugin-mcp-server"
  },
  "documentation": "https://github.com/Neural-Harmonics/vcv-rack-plugin-mcp-server/blob/main/README.md",
  "icon": "icon.png",
  "server": {
    "type": "python",
    "entry_point": "vcvrack_client.py",
    "mcp_config": {
      "command": "python",
      "args": [
        "`${__dirname}/vcvrack_client.py",
        "--mcp-server",
        "--port",
        "`${user_config.port}"
      ]
    }
  },
  "user_config": {
    "port": {
      "type": "number",
      "title": "Server Port",
      "description": "Port configured in the MCP Server module inside VCV Rack (default: 2600).",
      "default": 2600,
      "required": false
    }
  },
  "tools": [
    { "name": "vcvrack_get_status",         "description": "Get VCV Rack server status" },
    { "name": "vcvrack_get_rack_layout",    "description": "Get rack spatial layout and suggested positions" },
    { "name": "vcvrack_search_library",     "description": "Search installed plugins and modules" },
    { "name": "vcvrack_add_module",         "description": "Add a module to the patch" },
    { "name": "vcvrack_delete_module",      "description": "Remove a module" },
    { "name": "vcvrack_add_cable",          "description": "Connect two ports with a cable" },
    { "name": "vcvrack_delete_cable",       "description": "Remove a cable" },
    { "name": "vcvrack_get_params",         "description": "Get module parameters" },
    { "name": "vcvrack_set_params",         "description": "Set module parameters" },
    { "name": "vcvrack_list_modules",       "description": "List all modules in the patch" },
    { "name": "vcvrack_list_cables",        "description": "List all cables in the patch" }
  ],
  "compatibility": {
    "claude_desktop": ">=0.10.0",
    "platforms": ["darwin", "win32", "linux"]
  }
}
"@

Set-Content -Path (Join-Path $Stage "manifest.json") -Value $ManifestContent -Encoding UTF8

# Copy required files
$ClientPy = Join-Path $ScriptDir "dxt\vcvrack_client.py"
if (Test-Path $ClientPy) {
    Copy-Item $ClientPy (Join-Path $Stage "vcvrack_client.py")
}

$IconPng = Join-Path $ScriptDir "dxt\icon.png"
if (Test-Path $IconPng) {
    Copy-Item $IconPng (Join-Path $Stage "icon.png")
}

# Create output zip (PowerShell uses Compress-Archive)
$OutFile = Join-Path $ScriptDir "vcvrack-mcp-server.mcpb"
if (Test-Path $OutFile) {
    Remove-Item $OutFile -Force
}

# Use .NET ZipFile for better control
Add-Type -AssemblyName System.IO.Compression.FileSystem
$TempZip = Join-Path $env:TEMP "dxt-temp.zip"
if (Test-Path $TempZip) {
    Remove-Item $TempZip -Force
}

[System.IO.Compression.ZipFile]::CreateFromDirectory($Stage, $TempZip)
Move-Item $TempZip $OutFile -Force

$FileSize = (Get-Item $OutFile).Length / 1MB
Write-Host "Built: $OutFile ($([math]::Round($FileSize, 2)) MB)"

# Cleanup
if (Test-Path $Stage) {
    Remove-Item -Recurse -Force $Stage
}
