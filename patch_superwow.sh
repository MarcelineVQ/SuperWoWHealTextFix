#!/bin/bash
set -euo pipefail

# SuperWoW Heal Text Disabler Patch (Linux)
# Patches SuperWoWhook.dll v1.5.1 to disable floating heal text

DLL="SuperWoWhook.dll"
EXPECTED_SIZE=129024

echo "=== SuperWoW Heal Text Disabler Patch ==="
echo ""

# --- Check required tools ---
MISSING=()
for tool in dd od cp stat printf; do
    if ! command -v "$tool" &>/dev/null; then
        MISSING+=("$tool")
    fi
done
if [ ${#MISSING[@]} -ne 0 ]; then
    echo "ERROR: Missing required tools: ${MISSING[*]}"
    exit 1
fi
echo "[OK] All required tools found (dd, od, cp, stat, printf)"

# --- Check file exists ---
if [ ! -f "$DLL" ]; then
    echo "ERROR: $DLL not found in current directory."
    exit 1
fi
echo "[OK] Found $DLL"

# --- Check file size ---
ACTUAL_SIZE=$(stat -c '%s' "$DLL")
if [ "$ACTUAL_SIZE" -ne "$EXPECTED_SIZE" ]; then
    echo "ERROR: File size mismatch. Expected $EXPECTED_SIZE, got $ACTUAL_SIZE."
    echo "       Make sure you are using SuperWoW version 1.5.1."
    exit 1
fi
echo "[OK] File size: $EXPECTED_SIZE bytes"

# --- Extract hex bytes at offset from disk ---
extract_hex() {
    dd if="$DLL" bs=1 skip="$1" count="$2" 2>/dev/null | od -An -tx1 -v | tr -d '[:space:]'
}

# Patch 1: Heal text disable - offset 0x4F28 (20264), 15 bytes
P1_OFF=20264
P1_LEN=15
P1_OLD="68f03b00106894d90110e839250000"
P1_NEW="eb0d7e494c494b45545552544c4553"

# Patch 2: offset 0x1E054 (123988), 4 bytes
P2_OFF=122964
P2_LEN=4
P2_OLD="293b2e3b"
P2_NEW="00000000"

# --- Verify bytes at patch locations ---
P1_CUR=$(extract_hex $P1_OFF $P1_LEN)
P2_CUR=$(extract_hex $P2_OFF $P2_LEN)

if [ "$P1_CUR" = "$P1_OLD" ] && [ "$P2_CUR" = "$P2_OLD" ]; then
    echo "[OK] Bytes at patch locations match expected unpatched values"
elif [ "$P1_CUR" = "$P1_NEW" ] && [ "$P2_CUR" = "$P2_NEW" ]; then
    echo "Already patched. Nothing to do."
    exit 0
else
    echo "ERROR: Unexpected bytes at patch locations."
    echo "  @0x4F28:  expected $P1_OLD"
    echo "            got      $P1_CUR"
    echo "  @0x1E054: expected $P2_OLD"
    echo "            got      $P2_CUR"
    echo "File may be corrupted or a different version."
    exit 1
fi

# --- Create backup ---
BAK="${DLL}.bak"
if [ -f "$BAK" ]; then
    echo "[!!] Backup $BAK already exists, not overwriting."
    echo "     Existing backup preserved."
else
    cp "$DLL" "$BAK"
    echo "[OK] Backup created: $BAK"
fi

# --- Apply patches ---
echo ""
echo "Applying patches..."

printf '\xEB\x0D\x7E\x49\x4C\x49\x4B\x45\x54\x55\x52\x54\x4C\x45\x53' | \
    dd of="$DLL" bs=1 seek=$P1_OFF conv=notrunc 2>/dev/null

printf '\x00\x00\x00\x00' | \
    dd of="$DLL" bs=1 seek=$P2_OFF conv=notrunc 2>/dev/null

# --- Verify patches by re-reading from disk ---
P1_VER=$(extract_hex $P1_OFF $P1_LEN)
P2_VER=$(extract_hex $P2_OFF $P2_LEN)

if [ "$P1_VER" = "$P1_NEW" ] && [ "$P2_VER" = "$P2_NEW" ]; then
    echo "[OK] Patch 1 applied at 0x4F28  (heal text disable)"
    echo "[OK] Patch 2 applied at 0x1E054"
    echo ""
    echo "Patch applied successfully!"
else
    echo ""
    echo "ERROR: Verification failed after patching!"
    echo "  @0x4F28:  expected $P1_NEW, got $P1_VER"
    echo "  @0x1E054: expected $P2_NEW, got $P2_VER"
    echo "Restoring from backup..."
    cp "$BAK" "$DLL"
    echo "Backup restored."
    exit 1
fi
