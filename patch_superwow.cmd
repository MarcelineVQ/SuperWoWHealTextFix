<# :
@echo off
where powershell >nul 2>&1
if errorlevel 1 (
    echo.
    echo  PowerShell is required but was not found.
    echo  PowerShell is included with Windows 7 and later.
    echo.
    pause
    exit /b 1
)
powershell -ExecutionPolicy Bypass -File "%~f0" %*
pause
exit /b
#>

# SuperWoW Heal Text Disabler Patch (Windows)
# Patches SuperWoWhook.dll v1.5.1 to disable floating heal text
#
# Usage: Double-click this script (with the DLL in the same folder)
#        or drag-and-drop SuperWoWhook.dll onto this script.

$ErrorActionPreference = 'Stop'
$dllName = 'SuperWoWhook.dll'
$expectedSize = 129024

Write-Host ''
Write-Host '  ========================================'
Write-Host '   SuperWoW Heal Text Disabler Patch'
Write-Host '  ========================================'
Write-Host ''

# --- Locate the DLL ---
$dllPath = $null

# 1) Drag-and-drop: path passed as argument
if ($args.Count -gt 0 -and (Test-Path $args[0])) {
    $dllPath = (Resolve-Path $args[0]).Path
    $leaf = Split-Path $dllPath -Leaf
    if ($leaf -ne $dllName) {
        Write-Host "  ERROR: Expected $dllName but got $leaf"
        exit 1
    }
}

# 2) Same folder as this script
if (-not $dllPath) {
    $candidate = Join-Path $PSScriptRoot $dllName
    if (Test-Path $candidate) { $dllPath = $candidate }
}

# 3) Current working directory
if (-not $dllPath) {
    if (Test-Path $dllName) { $dllPath = (Resolve-Path $dllName).Path }
}

if (-not $dllPath) {
    Write-Host "  Could not find $dllName."
    Write-Host ''
    Write-Host '  To use this patcher, either:'
    Write-Host "    - Place this script in the same folder as $dllName"
    Write-Host "      and double-click it"
    Write-Host "    - Or drag and drop $dllName onto this script"
    Write-Host ''
    Write-Host '  SuperWoW 1.5.1 is required. Get it at:'
    Write-Host '  https://github.com/balakethelock/SuperWoW'
    exit 1
}

$dllDir = Split-Path $dllPath -Parent
$bakPath = Join-Path $dllDir "$dllName.bak"

Write-Host "  Found: $dllPath"

# --- Read file ---
$bytes = [System.IO.File]::ReadAllBytes($dllPath)

# --- Check file size ---
if ($bytes.Length -ne $expectedSize) {
    Write-Host ''
    Write-Host "  ERROR: This does not appear to be the correct file."
    Write-Host "  Expected file size $expectedSize bytes, got $($bytes.Length) bytes."
    Write-Host '  Make sure you are using SuperWoW version 1.5.1.'
    exit 1
}
Write-Host "  File size OK ($expectedSize bytes)"

# --- Patch definitions ---
# Patch 1: Heal text disable (0x4F28, 15 bytes)
# Patch 2: Data patch        (0x1E054, 4 bytes)
$patches = @(
    @{
        Name   = 'Heal text disable'
        Offset = 0x4F28
        Old    = [byte[]]@(0x68,0xF0,0x3B,0x00,0x10,0x68,0x94,0xD9,0x01,0x10,0xE8,0x39,0x25,0x00,0x00)
        New    = [byte[]]@(0xEB,0x0D,0x7E,0x49,0x4C,0x49,0x4B,0x45,0x54,0x55,0x52,0x54,0x4C,0x45,0x53)
    },
    @{
        Name   = 'Data patch'
        Offset = 0x1E054
        Old    = [byte[]]@(0x29,0x3B,0x2E,0x3B)
        New    = [byte[]]@(0x00,0x00,0x00,0x00)
    }
)

# --- Byte comparison ---
function Test-Bytes($data, $offset, $expected) {
    for ($i = 0; $i -lt $expected.Length; $i++) {
        if ($data[$offset + $i] -ne $expected[$i]) { return $false }
    }
    return $true
}

# --- Check current state ---
$allOld = $true
$allNew = $true
foreach ($p in $patches) {
    if (-not (Test-Bytes $bytes $p.Offset $p.Old)) { $allOld = $false }
    if (-not (Test-Bytes $bytes $p.Offset $p.New)) { $allNew = $false }
}

if ($allOld) {
    Write-Host '  File verified - ready to patch'
} elseif ($allNew) {
    Write-Host ''
    Write-Host '  This file is already patched! Nothing to do.'
    exit 0
} else {
    Write-Host ''
    Write-Host '  ERROR: This file does not match the expected SuperWoW 1.5.1.'
    Write-Host '  It may be a different version or already modified.'
    Write-Host ''
    Write-Host '  Get the correct version at:'
    Write-Host '  https://github.com/balakethelock/SuperWoW'
    exit 1
}

# --- Create backup ---
if (Test-Path $bakPath) {
    Write-Host "  Backup already exists: $bakPath"
} else {
    Copy-Item $dllPath $bakPath
    Write-Host "  Backup saved: $bakPath"
}

# --- Apply patches in memory ---
foreach ($p in $patches) {
    for ($i = 0; $i -lt $p.New.Length; $i++) {
        $bytes[$p.Offset + $i] = $p.New[$i]
    }
}

# --- Write patched file to disk ---
[System.IO.File]::WriteAllBytes($dllPath, $bytes)

# --- Re-read and verify ---
$verify = [System.IO.File]::ReadAllBytes($dllPath)
$verified = $true
foreach ($p in $patches) {
    if (-not (Test-Bytes $verify $p.Offset $p.New)) {
        $verified = $false
    }
}

if ($verified) {
    Write-Host ''
    Write-Host '  Patch applied successfully!'
    Write-Host ''
    Write-Host '  Floating heal text has been disabled.'
    Write-Host '  Your original file was saved as SuperWoWhook.dll.bak'
} else {
    Write-Host ''
    Write-Host '  ERROR: Something went wrong during patching!'
    Write-Host '  Restoring your original file from backup...'
    Copy-Item $bakPath $dllPath
    Write-Host '  Original file restored. No changes were made.'
    exit 1
}
