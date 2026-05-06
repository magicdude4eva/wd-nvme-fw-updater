# Copilot Instructions for wd-nvme-fw-updater

## Overview

This repository contains a bash implementation of an automated NVMe firmware updater for Western Digital SSDs on Linux. The script handles dependency checking, device discovery, firmware version selection, slot management, and firmware flashing with optional activation modes.

## Project Structure

**Single-file codebase:** The entire application is in `nvme_fw_upgrade.sh` (838 lines, 25 functions).

### Architecture

The script follows a structured pipeline architecture:

1. **Logging Layer** — Three-level logging (ERROR, INFO, DEBUG) controlled by `LOG_LEVEL` global
2. **Dependency Management** — Detection and installation for Arch Linux, Debian/Ubuntu, and Fedora
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
- `install_dependencies()` — Detects OS and routes to appropriate installer

**Device & Firmware Discovery:**
- `get_devices()` — Returns list of `/dev/nvmeX` devices
- `ask_device()` — Interactive device selection (auto-selects if only one device)
- `get_model_properties()` — Extracts model info from `nvme id-ctrl` JSON output
- `print_info()` — Displays device details

**Firmware Resolution:**
- `get_fw_url()` — Fetches WD device list from XML endpoint, finds matching device model
- `ask_fw_version()` — Presents available firmware versions for user selection
- `get_upgrade_url()` — Constructs download URL for selected firmware version

**User Interaction:**
- `ask_slot()` — Prompts for firmware slot (0, 1, 2, 3)
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
- `-i, --info` — Print device information only
- `-m, --manual` — Disable version and dependency checks
- `--ignore-ssl-errors` — Ignore HTTPS/SSL errors during downloads
- `-v, --verbose` — Enable INFO-level logging
- `-vv, --very-verbose` — Enable DEBUG-level logging

## Key Conventions

### Global Variables

- `readonly` constants at top (script name, version, URLs)
- Mutable config in "Global configuration" section (`MANUAL_MODE`, `IGNORE_SSL_ERRORS`, `VERBOSE`, `LOG_LEVEL`, `TEMP_DIR`)
- Interaction state stored in globals (`DEVICE`, `DEVICE_MODEL`, `DEVICE_VENDOR`, etc.)

### Code Organization

- **Function sections marked with banners** — `## Section Name ##` with `#` separators (25 chars wide)
- **Function naming** — `verb_noun()` pattern (e.g., `get_devices`, `ask_device`, `check_missing_dependencies`)
- **Error handling** — All external commands checked with `if [[ $? -ne 0 ]]`; set `set -o pipefail` at top
- **JSON parsing** — Uses `jq` for structured data extraction from `nvme id-ctrl --output-format=json`
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
- **Linux distribution detection** — `os_release()` determines package manager and installation method
- **WD API endpoint** — XML file at `https://sddashboarddownloads.sandisk.com/wdDashboard/config/devices/lista_devices.xml`
- **Firmware slots** — Devices typically support 0-3 (query via `nvme id-ctrl`)
- **Activation modes** — 0=no-activate (manual switch), 1=activate immediately, 2=after-reboot, 3=activate-with-power-loss

## Testing Recommendations

When adding features or modifying firmware update logic:

1. **Device detection** — Verify with `nvme list` and `nvme id-ctrl /dev/nvmeX`
2. **Dependency checks** — Test on Arch, Debian, and Fedora (if possible; shell syntax is portable)
3. **Firmware URL resolution** — Validate WD XML endpoint still responds correctly
4. **Error paths** — Test missing dependencies, unavailable devices, network errors
5. **Manual mode** — Ensure `-m` flag bypasses version checks as designed

## Notes

- The script uses `sudo` for `nvme` commands (firmware operations require root)
- WD official WDDashboard was EOL as of 2025-01-23; XML endpoint availability may change
- No external frameworks — pure bash, only dependencies are `nvme-cli`, `curl`, and `xmllint` (all available on major distros)
