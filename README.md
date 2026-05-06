# wd-nvme-fw-updater
Automated NVMe firmware updater for Western Digital SSDs on Linux. Features dependency checks, slot selection, and activation mode control. Compatible with Arch Linux and nvme-cli.

## ⚠️ IMPORTANT FIRMWARE UPDATE WARNING ⚠️

**⚠️ FIRMWARE UPDATES CAN POTENTIALLY DAMAGE YOUR DRIVE AND CAUSE DATA LOSS! ⚠️**

Before proceeding with any firmware update:
- **BACK UP ALL IMPORTANT DATA FIRST** — There is a risk of data loss during firmware updates
- **VERIFY YOU HAVE THE CORRECT FIRMWARE** — Using the wrong firmware can brick your drive
- **SELECT THE CORRECT DRIVE** — Double-check you're updating the intended NVMe device
- **UNDERSTAND THE RISKS** — Some drives may become unbootable if the update fails
- **HAVE A RECOVERY PLAN** — In case the update fails, be prepared to recover your system

This tool is provided **AS-IS** without warranty of any kind. The authors are not responsible for any damage that may occur.

Use at your own risk!

---

## Features

- **Automatic Dependency Management** — Detects and installs dependencies for Arch, Debian/Ubuntu, and Fedora
- **Device Discovery** — Automatically finds all connected NVME devices
- **Smart Version Filtering** — Only shows newer firmware versions (numeric comparison with "WD" suffix handling)
- **Firmware Slot Management** — Allows selection of target firmware slot
- **Flexible Activation Modes** — Choose between 4 activation modes:
  - Mode 0: Download only (manual activation)
  - Mode 1: Activate immediately
  - Mode 2: Activate after reboot (recommended)
  - Mode 3: Activate with power loss (if supported)
- **SSL Error Handling** — Optional flag to ignore certificate validation errors
- **Manual Mode** — Override version checks if needed

## Requirements

- Linux system with root/sudo access
- NVMe drive from Western Digital
- `nvme-cli` (for device interaction)
- `curl` (for downloading firmware)
- `xmllint` (for parsing firmware metadata)
- `jq` (optional, for better JSON parsing)
- `bash` 4.0+

## Supported Distributions

- **Arch Linux** and derivations (Manjaro, etc.)
- **Debian/Ubuntu** and derivations (Linux Mint, etc.)
- **Fedora/RHEL/CentOS** and derivations (Rocky Linux, etc.)

The script automatically detects your distribution and installs dependencies using the appropriate package manager.

## Installation

```bash
git clone https://github.com/magicdude4eva/wd-nvme-fw-updater
cd wd-nvme-fw-updater
chmod +x nvme_fw_upgrade.sh
```

## Usage

### Interactive Firmware Update
```bash
./nvme_fw_upgrade.sh
```

### Show Device Information
```bash
./nvme_fw_upgrade.sh -i
```

### Manual Mode (Skip Version Checks)
```bash
./nvme_fw_upgrade.sh -m
```

### Debug Output
```bash
./nvme_fw_upgrade.sh -vv
```

### All Available Options
```bash
./nvme_fw_upgrade.sh --help
```

## How It Works

1. **Dependency Check** — Verifies and installs required tools
2. **Device Detection** — Discovers connected NVME devices
3. **Device Selection** — Allows user to select target drive
4. **Firmware Discovery** — Fetches available firmware versions from WD
5. **Version Selection** — Shows newer firmware versions (or all in manual mode)
6. **Dependency Verification** — Ensures firmware is compatible
7. **Slot Selection** — Allows user to choose target firmware slot (defaults to slot 2)
8. **Mode Selection** — Allows user to choose activation mode (defaults to mode 3 if supported)
9. **Firmware Download** — Downloads firmware file
10. **User Confirmation** — Shows summary and requires confirmation
11. **Firmware Flashing** — Executes firmware update
12. **Completion** — Provides instructions for next steps

## Notes

- The official WD Dashboard was EOL as of January 23, 2025
- This tool uses the community firmware endpoints that may change
- **⚠️ FIRMWARE UPDATES ARE IRREVERSIBLE — PROCEED WITH EXTREME CAUTION ⚠️**
- Always back up your data before firmware updates
- Some activation modes may require a system reboot
- Firmware updates typically take a few seconds
- The script now defaults to slot 2 and mode 3 (immediate activation) when supported
- Professional banner with safety warnings displayed before all operations
- Improved column-aligned output for better readability

## Screenshots
I tested this on a Framework 16 Laptop with both my NVMEs:

1) Viewing device information:
<img width="870" height="880" alt="image" src="https://github.com/user-attachments/assets/0be1512c-310a-4f90-8eef-5bb613d05bf0" />

2) Performing a forced update:
<img width="1138" height="1294" alt="image" src="https://github.com/user-attachments/assets/d73fc261-5ad3-47df-ab6f-b8387202d583" />
