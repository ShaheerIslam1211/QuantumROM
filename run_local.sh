#!/bin/bash
#
# Local orchestrator for QuantumROM on Ubuntu.
# Calls the same scripts as .github/workflows/sixteen.yml.
# Uses firmware from Firmware/<TARGET_DEVICE>/ only (no download).
#

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$REPO_ROOT"

# Defaults match .github/workflows/sixteen.yml inputs
STOCK_DEVICE="${1:-SM-A225F}"
USE_UI_8_TETHERING_APEX="${2:-False}"
TARGET_DEVICE="${3:-SM-A346E}"
TARGET_DEVICE_CSC="${4:-BKD}"
TARGET_DEVICE_IMEI="${5:-353435774197736}"
OUTPUT_FILESYSTEM="${6:-erofs}"

LOCAL_FIRM_DIR="$REPO_ROOT/Firmware/$TARGET_DEVICE"
FIRM_WORK_DIR="$REPO_ROOT/FW/$TARGET_DEVICE"

stage() {
    echo ""
    echo "========================================"
    echo "  $1"
    echo "========================================"
}

fail_firmware() {
    echo ""
    echo "ERROR: Local firmware for $TARGET_DEVICE was not found."
    echo ""
    echo "Place Samsung firmware packages here:"
    echo ""
    echo "  Firmware/$TARGET_DEVICE/"
    echo "  ├── AP_*.tar.md5"
    echo "  ├── BL_*.tar.md5"
    echo "  ├── CP_*.tar.md5"
    echo "  └── CSC_*.tar.md5"
    echo ""
    echo "Example:"
    echo "  Firmware/SM-A165F/AP_....tar.md5"
    echo "  Firmware/SM-A165F/BL_....tar.md5"
    echo "  Firmware/SM-A165F/CP_....tar.md5"
    echo "  Firmware/SM-A165F/CSC_....tar.md5"
    echo ""
    echo "See LOCAL_SETUP.md for details."
    exit 1
}

# --- Stage: dependencies ---
stage "Stage 1/5: Check dependencies"

MISSING=()
for cmd in 7z lz4 python3 java jq perl xxd simg2img zipalign tar; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        MISSING+=("$cmd")
    fi
done

if [ "${#MISSING[@]}" -gt 0 ]; then
    echo "Missing required commands: ${MISSING[*]}"
    echo ""
    echo "Install dependencies (Ubuntu, same as GitHub Actions):"
    echo "  sudo apt update"
    echo "  sudo apt install -y p7zip-full lz4 liblz4-1 liblz4-dev libzstd1 libzstd-dev \\"
    echo "    build-essential android-sdk-libsparse-utils f2fs-tools fuse2fs fuse \\"
    echo "    e2fsprogs python3 python3-pip zipalign unzip openjdk-21-jdk \\"
    echo "    jq perl xxd kmod erofs-utils linux-modules-extra-\$(uname -r)"
    echo "  sudo modprobe f2fs"
    echo ""
    echo "See LOCAL_SETUP.md."
    exit 1
fi

if [ ! -f "$REPO_ROOT/scripts/QuantumRom.sh" ] || [ ! -f "$REPO_ROOT/sixteen.sh" ]; then
    echo "ERROR: Run this script from the QuantumROM repository root."
    exit 1
fi

echo "Dependencies OK."

# --- Stage: firmware ---
stage "Stage 2/5: Verify local firmware"

if [ ! -d "$LOCAL_FIRM_DIR" ]; then
    fail_firmware
fi

for pattern in "AP_*.tar.md5" "BL_*.tar.md5" "CP_*.tar.md5" "CSC_*.tar.md5"; do
    # shellcheck disable=SC2086
    if ! ls "$LOCAL_FIRM_DIR"/$pattern >/dev/null 2>&1; then
        echo "Missing required file(s): Firmware/$TARGET_DEVICE/$pattern"
        fail_firmware
    fi
done

echo "Found local firmware in: $LOCAL_FIRM_DIR"
ls -1 "$LOCAL_FIRM_DIR"/*.tar.md5

# --- Stage: environment (same as GitHub Actions / sixteen.sh) ---
stage "Stage 3/5: Export environment variables"

export STOCK_DEVICE
export USE_UI_8_TETHERING_APEX
export TARGET_DEVICE
export TARGET_DEVICE_CSC
export TARGET_DEVICE_IMEI
export OUTPUT_FILESYSTEM

export FIRM_DIR="$REPO_ROOT/FW"
export OUT_DIR="$REPO_ROOT/OUT"
export WORK_DIR="$REPO_ROOT/WORK"
export APKTOOL="$REPO_ROOT/bin/java/apktool.jar"
export DEVICES_DIR="$REPO_ROOT/QuantumROM/Devices"
export VNDKS_COLLECTION="$REPO_ROOT/QuantumROM/vndks"
export BUILD_PARTITIONS="product,system_ext,system"

echo "STOCK_DEVICE=$STOCK_DEVICE"
echo "USE_UI_8_TETHERING_APEX=$USE_UI_8_TETHERING_APEX"
echo "TARGET_DEVICE=$TARGET_DEVICE"
echo "TARGET_DEVICE_CSC=$TARGET_DEVICE_CSC"
echo "TARGET_DEVICE_IMEI=$TARGET_DEVICE_IMEI"
echo "OUTPUT_FILESYSTEM=$OUTPUT_FILESYSTEM"
echo "FIRM_DIR=$FIRM_DIR"
echo "WORK_DIR=$WORK_DIR"
echo "OUT_DIR=$OUT_DIR"

mkdir -p "$FIRM_DIR" "$WORK_DIR" "$OUT_DIR"

# STOCK_DEVICE validation (same check as the workflow)
if [ "$STOCK_DEVICE" != "None" ] && [ ! -d "$DEVICES_DIR/$STOCK_DEVICE" ]; then
    echo "ERROR: $STOCK_DEVICE is not supported with this tool."
    echo "Supported devices live under QuantumROM/Devices/, or set STOCK_DEVICE to None."
    exit 1
fi

# --- Stage: prepare FW from local Firmware/ (no download) ---
stage "Stage 4/5: Prepare firmware in FW/ (local only)"

# Use existing DOWNLOAD_FIRMWARE local path: copies Firmware/<MODEL> -> FW/<MODEL>
# when local packages are present (no network download).
# shellcheck disable=SC1091
source "$REPO_ROOT/scripts/QuantumRom.sh"
DOWNLOAD_FIRMWARE "$TARGET_DEVICE" "$TARGET_DEVICE_CSC" "$TARGET_DEVICE_IMEI" "FW"

if [ ! -d "$FIRM_WORK_DIR" ]; then
    echo "ERROR: Failed to prepare firmware at $FIRM_WORK_DIR"
    exit 1
fi

echo "Extracting firmware (EXTRACT_FIRMWARE)..."
EXTRACT_FIRMWARE "FW/$TARGET_DEVICE"

# --- Stage: build (same entry as GitHub Actions) ---
stage "Stage 5/5: Start ROM build (sixteen.sh)"

sudo bash "$REPO_ROOT/sixteen.sh" \
    "$STOCK_DEVICE" \
    "$USE_UI_8_TETHERING_APEX" \
    "$TARGET_DEVICE" \
    "$TARGET_DEVICE_CSC" \
    "$TARGET_DEVICE_IMEI" \
    "$OUTPUT_FILESYSTEM"

echo ""
echo "Build finished. Output images are in: $OUT_DIR"
