# Copilot Instructions for wd-nvme-fw-updater

## Overview

This repository contains a bash implementation of an automated NVMe firmware updater for Western Digital SSDs on Linux. The script is a functional equivalent of the [Python reference implementation](https://github.com/not-a-feature/wd_fw_update) and handles dependency checking, device discovery, firmware version selection, slot management, and firmware flashing with optional activation modes. The bash version provides broader Linux compatibility without Python dependencies.

## Project Structure

**Single-file codebase:** The entire application is in `nvme_fw_upgrade.sh` (850+ lines, 25 functions).

### Supported Linux Distributions

- **Arch Linux & Manjaro** (pacman)
- **Debian/Ubuntu/Linux Mint** (apt-get)
- **Fedora/RHEL/CentOS** (dnf)
- Any derived distribution that inherits from the above

The script auto-detects the distribution via `/etc/os-release` and `ID_LIKE` field for compatibility with derived distros.

### Architecture

The script follows a structured pipeline architecture with feature parity to the Python implementation:

1. **Logging Layer** — Three-level logging (ERROR, INFO, DEBUG) controlled by `LOG_LEVEL` global
2. **Dependency Management** — Detection and installation for Arch Linux, Debian/Ubuntu, and Fedora (with distro-specific package managers)
3. **Device Discovery** — Lists and detects NVME devices via `nvme` CLI tool
4. **Firmware Resolution** — Fetches device list from WD API, queries firmware URLs
5. **Interactive Workflow** — Step-by-step user prompts for device, firmware version, slot, and activation mode
6. **Firmware Update** — Downloads firmware and executes `nvme fw-download` and `nvme fw-commit` commands

### Key Functions by Category

**Logging:**
- `log_error()`, `log_info()`, `log_debug()`

**Dependency Management:**
- `command_exists()`, `check_missing_dependencies()`
- `install_dependencies_arch()`, `install_dependencies_debian()`, `install_dependencies_fedora()`
- `install_dependencies()` — Detects OS via `/etc/os-release` and routes to appropriate installer

**Device & Firmware Discovery:**
- `get_devices()` — Returns list of `/dev/nvmeX` devices
- `ask_device()` — Interactive device selection (auto-selects if only one device)
- `get_model_properties()` — Extracts model info from `nvme id-ctrl` JSON output
- `print_info()` — Displays device details

**Firmware Resolution:**
- `get_fw_url()` — Fetches WD device list from XML endpoint, finds matching device model
- `ask_fw_version()` — Presents available firmware versions for user selection (with numeric version comparison)
- `get_upgrade_url()` — Constructs download URL for selected firmware version

**User Interaction:**
- `ask_slot()` — Prompts for firmware slot (excludes read-only slot 1 if applicable)
- `ask_mode()` — Prompts for activation mode (0=no-activate, 1=activate, 2=activate-after-reboot, 3=activate-with-power-loss)

**Firmware Update:**
- `update_fw()` — Downloads firmware file and runs `nvme fw-download` + `nvme fw-commit`
- `get_curl_opts()` — Builds curl options (handles SSL errors, verbose mode)

**Entry Points:**
- `main_interactive()` — Orchestrates the 8-step user workflow
- `main_info()` — Information-only mode (device discovery + display)
- `main()` — Argument parsing and entry point
- `cleanup()` — Trap handler for temporary file cleanup

## Usage & Commands

### Running the Script

```bash
# Interactive firmware update
./nvme_fw_upgrade.sh

# Show version information
./nvme_fw_upgrade.sh --version

# Show available drives and their firmware info
./nvme_fw_upgrade.sh -i

# Update with manual mode (skip version checks) and debug output
./nvme_fw_upgrade.sh -m -vv

# Ignore SSL certificate errors when downloading firmware
./nvme_fw_upgrade.sh --ignore-ssl-errors

# Verbose output
./nvme_fw_upgrade.sh -v
```

### Supported Options

- `-h, --help` — Show help message
- `--version` — Show version information
- `-i, --info` — Print device information only
- `-m, --manual` — Disable version and dependency checks
- `--ignore-ssl-errors` — Ignore HTTPS/SSL errors during downloads
- `-v, --verbose` — Enable INFO-level logging
- `-vv, --very-verbose` — Enable DEBUG-level logging

## Feature Parity with Python Implementation

This bash script implements all major features of the [Python reference implementation](https://github.com/not-a-feature/wd_fw_update):

✓ Device discovery and selection
✓ Firmware version comparison (numeric, with "WD" suffix handling)
✓ Dependency checking and installation
✓ SSL error handling
✓ Manual mode for bypassing version checks
✓ Slot selection with firmware status display
✓ Activation mode selection (0-3)
✓ Firmware download with validation
✓ Confirmation prompt before flashing
✓ Proper exit codes and error messages
✓ Info mode for displaying device information

## Key Implementation Details

### Firmware Version Parsing (Critical)

**Python logic:** `url.split("/")[3]` extracts 4th path component
**Bash equivalent:** `awk -F'/' '{print $(NF-1)}'` extracts 2nd-to-last path component

Example URL: `https://sddashboarddownloads.sandisk.com/wdDashboard/firmware/WD_Black_SN850X/070015WD/device_properties.xml`

Extracted version: `070015WD`

### Firmware Version Comparison

- Strip "WD" suffix: `current_fw_int="${CURRENT_FW%WD}"` → "070015"
- Convert to integer for numeric comparison: `((version_int > current_fw_int))`
- Only show newer versions in normal mode; show all in manual mode

### Code Organization

- **Function sections marked with banners** — `## Section Name ##` with `#` separators (25 chars wide)
- **Function naming** — `verb_noun()` pattern (e.g., `get_devices`, `ask_device`, `check_missing_dependencies`)
- **Error handling** — All external commands checked with `if [[ $? -ne 0 ]]`; set `set -o pipefail` at top
- **JSON parsing** — Uses `jq` (fallback) for structured data extraction from `nvme id-ctrl --output-format=json`
- **XML parsing** — Uses `xmllint` to extract firmware URLs from WD device list XML

### Shell Best Practices Used

- `local` variables in functions (no leakage to global scope)
- `[[ ]]` for conditionals (not `[ ]`)
- Arrays with `mapfile -t` for safe line splitting
- Subshells with process substitution `< <()` to avoid changing directory/shell state
- `"$VARIABLE"` quoting to prevent word splitting
- `"${array[@]}"` for proper array expansion

### Important Implementation Details

- **Temporary file management** — `TEMP_FW_FILE` cleaned up via EXIT trap in `cleanup()`
- **Linux distribution detection** — Reads `/etc/os-release` with fallback to `ID_LIKE` for derived distros
- **WD API endpoint** — XML file at `https://sddashboarddownloads.sandisk.com/wdDashboard/config/devices/lista_devices.xml`
- **Firmware slots** — Devices typically support 0-3 (query via `nvme id-ctrl`)
- **Activation modes** — 0=no-activate (manual switch), 1=activate immediately, 2=after-reboot, 3=activate-with-power-loss
- **Auto-detection** — Script identifies distro and selects appropriate package manager automatically

## Testing Recommendations

When adding features or modifying firmware update logic:

1. **Device detection** — Verify with `nvme list` and `nvme id-ctrl /dev/nvmeX`
2. **Dependency checks** — Test on Arch, Debian, Ubuntu, Fedora (if possible; shell syntax is portable)
3. **Firmware URL resolution** — Validate WD XML endpoint still responds correctly
4. **Version comparison** — Ensure numeric comparison works (e.g., 070015 < 070114)
5. **Error paths** — Test missing dependencies, unavailable devices, network errors
6. **Manual mode** — Ensure `-m` flag bypasses version checks as designed
7. **Linux flavors** — Test on derivatives: Manjaro, Linux Mint, Rocky Linux, etc.

## Notes

- The script uses `sudo` for `nvme` commands (firmware operations require root)
- WD official WDDashboard was EOL as of 2025-01-23; XML endpoint availability may change
- No external frameworks — pure bash, dependencies are `nvme-cli`, `curl`, and `xmllint` (all available on major distros)
- The script is feature-complete with the Python reference implementation for core functionality
