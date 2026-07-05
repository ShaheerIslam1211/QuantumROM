# QuantumROM — Local Setup (Ubuntu)

Run the same build pipeline as GitHub Actions on a local Ubuntu machine, using firmware you already have on disk. Firmware is **not** downloaded.

## Requirements

- **OS:** Ubuntu 24.04 (or compatible) — matches the Actions runner
- **Privileges:** `sudo` (the build script is invoked with `sudo`, same as CI)
- **Disk:** enough free space for firmware extraction and image build (tens of GB)

### Dependencies

Install the same packages used by `.github/workflows/sixteen.yml`:

```bash
sudo apt update
sudo apt install -y \
  p7zip-full lz4 liblz4-1 liblz4-dev libzstd1 libzstd-dev \
  build-essential android-sdk-libsparse-utils f2fs-tools fuse2fs fuse \
  e2fsprogs python3 python3-pip zipalign unzip openjdk-21-jdk \
  jq perl xxd kmod erofs-utils linux-modules-extra-$(uname -r)

sudo modprobe f2fs
```

`samloader` is **not** required for local builds (no firmware download).

Bundled tools under `bin/` (`lpunpack`, `lpmake`, `mkfs.erofs`, `extract.erofs`, `apktool.jar`, etc.) are used as-is; no extra install step.

## Expected folder structure

```text
QuantumROM/                    # repository root
├── Firmware/                  # local firmware (you provide)
│   └── SM-A165F/              # TARGET_DEVICE model
│       ├── AP_*.tar.md5
│       ├── BL_*.tar.md5
│       ├── CP_*.tar.md5
│       └── CSC_*.tar.md5
├── FW/                        # created at runtime (working copy)
├── WORK/                      # created at runtime
├── OUT/                       # created at runtime (build output)
├── QuantumROM/Devices/        # stock device configs (in repo)
├── scripts/QuantumRom.sh      # shared build functions
├── sixteen.sh                 # main ROM build entry (same as CI)
└── run_local.sh               # local orchestrator
```

Replace `SM-A165F` with your `TARGET_DEVICE` model when placing firmware.

## Expected firmware location

Place Samsung firmware packages here **before** building:

```text
Firmware/<TARGET_DEVICE>/
├── AP_*.tar.md5
├── BL_*.tar.md5
├── CP_*.tar.md5
└── CSC_*.tar.md5
```

Example for `SM-A165F`:

```text
Firmware/SM-A165F/AP_....tar.md5
Firmware/SM-A165F/BL_....tar.md5
Firmware/SM-A165F/CP_....tar.md5
Firmware/SM-A165F/CSC_....tar.md5
```

If these files are missing, `run_local.sh` exits with a message telling you where to put them. No download is attempted.

At build time, local firmware is copied into `FW/<TARGET_DEVICE>/` (the path used by GitHub Actions and `sixteen.sh`), then extracted with the existing `EXTRACT_FIRMWARE` function.

## Environment variables

`run_local.sh` exports the same variables used by the Actions workflow / `sixteen.sh`:

| Variable | Role | Default (matches workflow) |
|---|---|---|
| `STOCK_DEVICE` | Device you are porting **for** (`None` if unsupported) | `SM-A225F` |
| `USE_UI_8_TETHERING_APEX` | `True` if kernel BPF is below 5.10 | `False` |
| `TARGET_DEVICE` | Device you are porting **from** (firmware model) | `SM-A346E` |
| `TARGET_DEVICE_CSC` | CSC code (kept for parity with CI) | `BKD` |
| `TARGET_DEVICE_IMEI` | IMEI (kept for parity with CI; not used for download locally) | `353435774197736` |
| `OUTPUT_FILESYSTEM` | `erofs` / `ext4` / `f2fs` | `erofs` |

Internal directories (set by `sixteen.sh`, also exported by `run_local.sh`):

| Variable | Value |
|---|---|
| `FIRM_DIR` | `$(pwd)/FW` |
| `OUT_DIR` | `$(pwd)/OUT` |
| `WORK_DIR` | `$(pwd)/WORK` |
| `DEVICES_DIR` | `$(pwd)/QuantumROM/Devices` |

Optional CI-only items **not** required for a local build:

- `GIT_TOKEN` — GitHub release upload (`release.sh`)
- `COMPRESS_IMG_TO_XZ` — post-build zip packaging step in the workflow

## Which script to run

From the **repository root**:

```bash
chmod +x run_local.sh
./run_local.sh
```

Or with explicit arguments (same order as `sixteen.sh` / the workflow):

```bash
./run_local.sh \
  <STOCK_DEVICE> \
  <USE_UI_8_TETHERING_APEX> \
  <TARGET_DEVICE> \
  <TARGET_DEVICE_CSC> \
  <TARGET_DEVICE_IMEI> \
  <OUTPUT_FILESYSTEM>
```

Example using local `SM-A165F` firmware, porting for `SM-A165F`:

```bash
./run_local.sh SM-A165F False SM-A165F BKD 353435774197736 erofs
```

## What `run_local.sh` does

It does **not** reimplement the build. It:

1. Checks dependencies
2. Verifies firmware under `Firmware/<TARGET_DEVICE>/`
3. Creates `FW/`, `WORK/`, `OUT/`
4. Exports the environment variables above
5. Sources `scripts/QuantumRom.sh` and runs `EXTRACT_FIRMWARE` on `FW/<TARGET_DEVICE>` (same as CI)
6. Runs `sudo bash sixteen.sh ...` with the same arguments as CI

Build output images land in `OUT/`.

## GitHub Actions

Local support is additive only. `.github/workflows/sixteen.yml` is unchanged in behavior: CI still downloads firmware when `Firmware/<MODEL>/` is not present, and still runs `sixteen.sh` and the release steps as before.
