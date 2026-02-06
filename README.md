# SuperWoW Heal Text Disabler

Patches SuperWoWhook.dll (v1.5.1) to disable the floating healing text added by SuperWoW.

## Why
SuperWoW adds floating combat text for heals but it conflicts with built-in floating text due to load order issues with `wow.exe` and causes duplicate text. This script patches the DLL so that only the client's text shows.

## Requirements
- SuperWoWhook.dll version 1.5.1 from https://github.com/balakethelock/SuperWoW
- Linux: bash (any distro)
- Windows: PowerShell (included since Windows 7)

## Usage
Place the script in the same folder as SuperWoWhook.dll.

**Linux:**
```
./patch_superwow.sh
```

**Windows:**
Double-click `patch_superwow.cmd`, or drag and drop `SuperWoWhook.dll` onto it.

## What it does

- Checks the DLL is the correct version (file size and bytes at patch locations)
- Creates a backup (SuperWoWhook.dll.bak) before making changes
- Applies two binary patches that disable the heal text
- Verifies the patches wrote correctly, restores backup if anything fails
- Detects if already patched and exits without changes
