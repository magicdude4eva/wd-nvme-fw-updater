# wd-nvme-fw-updater
Automated NVMe firmware updater for Western Digital SSDs on Linux. Features dependency checks, slot selection, and activation mode control. Compatible with Arch Linux and nvme-cli.

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
- **Verbose Logging** — Debug output for troubleshooting
- **Full Feature Parity** — Equivalent to the [Python reference implementation](https://github.com/not-a-feature/wd_fw_update)

## Requirements

- Linux system with root/sudo access
- NVMe drive from Western Digital
- `nvme-cli` (for device interaction)
- `curl` (for downloading firmware)
- `xmllint` (for parsing firmware metadata)
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
7. **Slot Selection** — Allows user to choose target firmware slot
8. **Mode Selection** — Allows user to choose activation mode
9. **Firmware Download** — Downloads firmware file
10. **User Confirmation** — Shows summary and requires confirmation
11. **Firmware Flashing** — Executes firmware update
12. **Completion** — Provides instructions for next steps

## Safety Features

- ✓ Automatic dependency verification
- ✓ Firmware validation before flashing
- ✓ User confirmation before making changes
- ✓ Slot read-only status detection
- ✓ Activation mode capability detection
- ✓ Automatic temporary file cleanup
- ✓ Proper error messages and exit codes

## Feature Comparison

This bash implementation provides **feature parity** with the [Python wd_fw_update tool](https://github.com/not-a-feature/wd_fw_update):

| Feature | Bash | Python |
|---------|------|--------|
| Device discovery | ✓ | ✓ |
| Firmware version filtering | ✓ | ✓ |
| Dependency management | ✓ | ✓ |
| Slot selection | ✓ | ✓ |
| Activation modes | ✓ | ✓ |
| SSL error handling | ✓ | ✓ |
| Manual mode | ✓ | ✓ |
| Verbose logging | ✓ | ✓ |
| Info mode | ✓ | ✓ |
| **Distribution Support** | **Arch, Debian, Fedora** | **Any (Python)** |

## Notes

- The official WD Dashboard was EOL as of January 23, 2025
- This tool uses the community firmware endpoints that may change
- Always back up your data before firmware updates
- Some activation modes may require a system reboot
- Firmware updates typically take a few seconds
