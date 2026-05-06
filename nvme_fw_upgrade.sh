#!/bin/bash

##############################################################################
# WD NVME Firmware Updater - Bash Implementation
# 
# This script is a bash implementation of the Python wd_fw_update tool
# Compatible with Arch Linux and other Linux distributions
# 
# Usage: ./nvme_fw_upgrade.sh [OPTIONS]
# Options:
#   -h, --help              Show this help message
#   --version               Show version information
#   -i, --info              Print information about available drives
#   -m, --manual            Disable version and dependency checks
#   --ignore-ssl-errors     Ignore HTTPS/SSL errors
#   -v, --verbose           Enable verbose output
#   -vv, --very-verbose     Enable debug output
#
##############################################################################

set -o pipefail

# Constants
readonly SCRIPT_NAME="$(basename "$0")"
readonly SCRIPT_VERSION="1.0.0"
readonly BASE_WD_DOMAIN="https://sddashboarddownloads.sandisk.com/wdDashboard"
readonly DEVICE_LIST_URL="${BASE_WD_DOMAIN}/config/devices/lista_devices.xml"

# Global configuration
MANUAL_MODE=false
IGNORE_SSL_ERRORS=false
VERBOSE=0
TEMP_DIR=""

# Logging setup
LOG_LEVEL=0  # 0=ERROR, 1=INFO, 2=DEBUG

##############################################################################
# Logging Functions
##############################################################################

log_error() {
    echo "[ERROR] $*" >&2
}

log_info() {
    if [[ $LOG_LEVEL -ge 1 ]]; then
        echo "[INFO] $*"
    fi
}

log_debug() {
    if [[ $LOG_LEVEL -ge 2 ]]; then
        echo "[DEBUG] $*"
    fi
}

##############################################################################
# Dependency Checking and Installation
##############################################################################

command_exists() {
    command -v "$1" &>/dev/null
}

check_missing_dependencies() {
    local missing=0
    local dependencies=("sudo" "nvme" "curl" "xmllint")
    
    for cmd in "${dependencies[@]}"; do
        if ! command_exists "$cmd"; then
            log_error "Missing dependency: $cmd"
            missing=1
        fi
    done
    
    return $missing
}

install_dependencies_arch() {
    echo "Installing dependencies for Arch Linux..."
    
    # Install nvme-cli and other dependencies
    local packages=("nvme-cli" "curl" "libxml2")
    
    for pkg in "${packages[@]}"; do
        if ! pacman -Q "$pkg" &>/dev/null; then
            echo "Installing $pkg..."
            sudo pacman -S --noconfirm "$pkg" || {
                log_error "Failed to install $pkg"
                return 1
            }
        fi
    done
    
    return 0
}

install_dependencies_debian() {
    echo "Installing dependencies for Debian/Ubuntu..."
    
    sudo apt-get update
    local packages=("nvme-cli" "curl" "libxml2-utils" "jq")
    
    for pkg in "${packages[@]}"; do
        if ! dpkg -l | grep -q "^ii  $pkg"; then
            echo "Installing $pkg..."
            sudo apt-get install -y "$pkg" || {
                log_error "Failed to install $pkg"
                return 1
            }
        fi
    done
    
    return 0
}

install_dependencies_fedora() {
    echo "Installing dependencies for Fedora/RHEL..."
    
    local packages=("nvme-cli" "curl" "libxml2" "jq")
    
    for pkg in "${packages[@]}"; do
        if ! rpm -q "$pkg" &>/dev/null; then
            echo "Installing $pkg..."
            sudo dnf install -y "$pkg" || {
                log_error "Failed to install $pkg"
                return 1
            }
        fi
    done
    
    return 0
}

install_dependencies() {
    echo "Checking for missing dependencies..."
    
    if ! check_missing_dependencies; then
        echo ""
        echo "Attempting to install missing dependencies..."
        echo ""
        
        if [[ -f /etc/os-release ]]; then
            . /etc/os-release
            # Use ID_LIKE for better compatibility with derived distros
            local distro_id="${ID_LIKE:-$ID}"
            
            case "$distro_id" in
                *arch*)
                    install_dependencies_arch || return 1
                    ;;
                *debian*|*ubuntu*|*mint*)
                    install_dependencies_debian || return 1
                    ;;
                *fedora*|*rhel*|*centos*)
                    install_dependencies_fedora || return 1
                    ;;
                *)
                    log_error "Unsupported distribution: $ID"
                    log_error "Please manually install: sudo, nvme-cli, curl, xmllint"
                    return 1
                    ;;
            esac
        else
            log_error "Cannot determine Linux distribution"
            log_error "Please manually install: sudo, nvme-cli, curl, xmllint"
            return 1
        fi
    else
        echo "All dependencies are installed."
    fi
    
    return 0
}

##############################################################################
# NVME Device Functions
##############################################################################

get_devices() {
    # Returns list of NVME devices
    local devices=()
    
    log_debug "Getting device list..."
    
    # Parse nvme list output, skipping header lines
    while IFS= read -r line; do
        local device=$(echo "$line" | awk '{print $1}')
        if [[ -n "$device" && "$device" != "Node" ]]; then
            devices+=("$device")
        fi
    done < <(sudo nvme list 2>/dev/null | tail -n +2)
    
    log_debug "Device list: ${devices[@]}"
    
    if [[ ${#devices[@]} -eq 0 ]]; then
        log_error "No NVME devices found!"
        return 1
    fi
    
    printf '%s\n' "${devices[@]}"
}

ask_device() {
    local devices=()
    local device
    
    log_debug "Asking for device selection..."
    
    mapfile -t devices < <(get_devices)
    
    if [[ ${#devices[@]} -eq 0 ]]; then
        log_error "No NVME devices found!"
        return 1
    fi
    
    if [[ ${#devices[@]} -eq 1 ]]; then
        device="${devices[0]}"
        echo "Found single device: $device"
    else
        echo "Select the NVME drive you want to update:"
        for i in "${!devices[@]}"; do
            echo "$((i + 1))) ${devices[$i]}"
        done
        
        local choice
        while true; do
            read -p "Enter selection (1-${#devices[@]}): " choice
            if [[ "$choice" =~ ^[0-9]+$ ]] && ((choice >= 1 && choice <= ${#devices[@]})); then
                device="${devices[$((choice - 1))]}"
                break
            fi
            echo "Invalid selection. Please try again."
        done
    fi
    
    DEVICE="$device"
    log_info "Selected device: $DEVICE"
}

get_model_properties() {
    local device="$1"
    
    log_info "Getting device properties of $device..."
    
    # Get device info in JSON format
    local output
    output=$(sudo nvme id-ctrl "$device" --output-format=json 2>/dev/null)
    
    if [[ $? -ne 0 ]]; then
        log_error "Failed to get device properties for $device"
        return 1
    fi
    
    # Parse JSON output
    MODEL=$(echo "$output" | grep -o '"mn":"[^"]*' | sed 's/"mn":"//' | xargs)
    CURRENT_FW=$(echo "$output" | grep -o '"fr":"[^"]*' | sed 's/"fr":"//' | xargs)
    
    log_debug "Model: $MODEL"
    log_debug "Current FW: $CURRENT_FW"
    
    # Parse FRMW field for slot information (binary flags)
    local frmw_hex
    frmw_hex=$(echo "$output" | grep -o '"frmw":[0-9]*' | sed 's/"frmw"://')
    
    if [[ -z "$frmw_hex" ]]; then
        log_error "Could not parse FRMW information"
        return 1
    fi
    
    # Convert hex to binary and extract flags
    local frmw_bin=$(printf '%08b' "$frmw_hex")
    
    SLOT_1_READONLY=$((2#${frmw_bin: -1}))
    SLOT_COUNT=$((2#${frmw_bin: -4:3}))
    ACTIVATION_WITHOUT_RESET=$((2#${frmw_bin: -5:1}))
    
    log_debug "Slot 1 readonly: $SLOT_1_READONLY"
    log_debug "Slot count: $SLOT_COUNT"
    log_debug "Activation without reset: $ACTIVATION_WITHOUT_RESET"
    
    # Get current active slot
    output=$(sudo nvme fw-log "$device" --output-format=json 2>/dev/null)
    
    if [[ $? -ne 0 ]]; then
        log_error "Failed to get firmware log"
        return 1
    fi
    
    # Extract active firmware slot (bits 2:0)
    local afi_val
    afi_val=$(echo "$output" | grep -o '"afi":[0-9]*' | sed 's/"afi"://')
    
    if [[ -z "$afi_val" ]]; then
        # Try alternative parsing for firmware slot info
        afi_val=$(echo "$output" | grep -oP '"Active Firmware Slot \(afi\)":\K[0-9]+')
    fi
    
    if [[ -n "$afi_val" ]]; then
        local afi_bin=$(printf '%08b' "$afi_val")
        CURRENT_SLOT=$((2#${afi_bin: -2}))
    else
        CURRENT_SLOT=-1
    fi
    
    log_info "Current Active Firmware Slot: $CURRENT_SLOT"
    
    # Parse slots with firmware
    SLOTS_WITH_FW=""
    while IFS= read -r line; do
        if [[ $line =~ \"Firmware\ Rev\ Slot\ ([0-9]+)\" ]]; then
            local slot_num="${BASH_REMATCH[1]}"
            local fw_ver=$(echo "$line" | grep -o '"value":"[^"]*' | sed 's/"value":"//')
            if [[ -n "$fw_ver" ]]; then
                SLOTS_WITH_FW="$SLOTS_WITH_FW $slot_num:$fw_ver"
            fi
        fi
    done < <(echo "$output" | grep -i "Firmware Rev Slot")
    
    log_debug "Slots with firmware:$SLOTS_WITH_FW"
}

print_info() {
    local device="$1"
    
    DEVICE="$device"
    get_model_properties "$device" || return 1
    
    echo "========== Device Info =========="
    echo "Device: $DEVICE"
    echo "Model: $MODEL"
    echo "Current FW version: $CURRENT_FW"
    echo "Slot 1 readonly: $SLOT_1_READONLY"
    echo "Slot count: $SLOT_COUNT"
    echo "Current slot: $CURRENT_SLOT"
    echo "Activation without reset: $ACTIVATION_WITHOUT_RESET"
    echo "Slots with firmware:$SLOTS_WITH_FW"
    echo ""
}

##############################################################################
# Firmware URL Functions
##############################################################################

get_curl_opts() {
    local opts="-s -L"
    
    if [[ "$IGNORE_SSL_ERRORS" == "true" ]]; then
        opts="$opts -k"
    fi
    
    echo "$opts"
}

get_fw_url() {
    log_debug "Getting firmware URL..."
    
    local model="$MODEL"
    local curl_opts=$(get_curl_opts)
    
    local response
    response=$(curl $curl_opts "$DEVICE_LIST_URL" 2>/dev/null)
    
    if [[ $? -ne 0 ]]; then
        log_error "Failed to fetch device list"
        return 1
    fi
    
    # Parse XML to find firmware URLs for this model
    FIRMWARE_URLS=()
    
    # Extract device URLs using xmllint or basic parsing
    if command_exists xmllint; then
        while IFS= read -r url; do
            if [[ -n "$url" ]]; then
                FIRMWARE_URLS+=("$url")
            fi
        done < <(echo "$response" | xmllint --xpath "//lista_device[@model='$model']/url/text()" - 2>/dev/null)
    else
        # Fallback to grep-based parsing if xmllint is not available
        while IFS= read -r line; do
            if [[ $line =~ \<url\>(.*)\</url\> ]]; then
                FIRMWARE_URLS+=("${BASH_REMATCH[1]}")
            fi
        done < <(echo "$response" | grep -A 100 "model=\"$model\"" | grep "<url>")
    fi
    
    if [[ ${#FIRMWARE_URLS[@]} -eq 0 ]]; then
        log_error "No firmware found for model: $model"
        return 1
    fi
    
    log_debug "Found ${#FIRMWARE_URLS[@]} firmware URLs"
}

ask_fw_version() {
    local fw_versions=()
    local current_fw_int
    
    if [[ ${#FIRMWARE_URLS[@]} -eq 0 ]]; then
        log_error "No firmware versions available"
        return 1
    fi
    
    # Extract version number from current firmware by removing "WD" suffix
    current_fw_int="${CURRENT_FW%WD}"
    
    log_debug "Current FW version (int): $current_fw_int"
    
    # Parse available versions from URLs
    # Python does: url.split("/")[3] which gets the 4th path component
    # Example: https://sddashboarddownloads.sandisk.com/wdDashboard/firmware/WD_Black_SN850X/070015WD/device_properties.xml
    # Split by / and get element [6] (0-indexed): 070015WD
    for url in "${FIRMWARE_URLS[@]}"; do
        # Split URL by / and extract the version (4th path component after domain)
        local version
        version=$(echo "$url" | awk -F'/' '{print $(NF-1)}')
        
        if [[ -z "$version" ]]; then
            log_debug "Failed to extract version from URL: $url"
            continue
        fi
        
        # Convert version to int by removing "WD" suffix for comparison
        local version_int="${version%WD}"
        
        # Add only newer versions or all in manual mode
        if [[ "$MANUAL_MODE" == "true" ]]; then
            # Manual mode: add all versions
            if ! [[ " ${fw_versions[@]} " =~ " $version " ]]; then
                fw_versions+=("$version")
            fi
        elif [[ -z "$current_fw_int" ]]; then
            # No current version: add all
            if ! [[ " ${fw_versions[@]} " =~ " $version " ]]; then
                fw_versions+=("$version")
            fi
        else
            # Normal mode: only add newer versions (numeric comparison)
            if [[ "$version_int" =~ ^[0-9]+$ ]] && [[ "$current_fw_int" =~ ^[0-9]+$ ]]; then
                if ((version_int > current_fw_int)); then
                    if ! [[ " ${fw_versions[@]} " =~ " $version " ]]; then
                        fw_versions+=("$version")
                    fi
                fi
            fi
        fi
    done
    
    if [[ ${#fw_versions[@]} -eq 0 ]]; then
        print_info "$DEVICE"
        echo "No different/newer firmware version found."
        echo "You are probably already on the latest version."
        if [[ "$MANUAL_MODE" == "false" ]]; then
            echo "If you believe this is a mistake, run with -m flag to enable manual mode."
        fi
        exit 0
    fi
    
    log_debug "Available firmware versions: ${fw_versions[@]}"
    
    echo "Select the Firmware Version for $MODEL:"
    for i in "${!fw_versions[@]}"; do
        echo "$((i + 1))) ${fw_versions[$i]}"
    done
    
    local choice
    while true; do
        read -p "Enter selection (1-${#fw_versions[@]}): " choice
        if [[ "$choice" =~ ^[0-9]+$ ]] && ((choice >= 1 && choice <= ${#fw_versions[@]})); then
            SELECTED_VERSION="${fw_versions[$((choice - 1))]}"
            break
        fi
        echo "Invalid selection. Please try again."
    done
    
    log_info "Selected firmware version: $SELECTED_VERSION"
}

ask_slot() {
    local slots=()
    local i
    
    # Create list of available slots
    for ((i = 1; i <= SLOT_COUNT; i++)); do
        # Skip slot 1 if it's read-only
        if [[ $i -eq 1 && $SLOT_1_READONLY -eq 1 ]]; then
            continue
        fi
        slots+=("$i")
    done
    
    if [[ ${#slots[@]} -eq 0 ]]; then
        log_error "No writable slots available"
        return 1
    fi
    
    log_debug "Available slots: ${slots[@]}"
    
    echo "Select the slot to which the firmware should be installed."
    echo "Slot ID: Current Firmware Version"
    
    for slot in "${slots[@]}"; do
        # Check if this slot has firmware
        local fw_label="No firmware."
        if [[ "$SLOTS_WITH_FW" =~ $slot: ]]; then
            fw_label=$(echo "$SLOTS_WITH_FW" | grep -o "$slot:[^ ]*" | sed 's/.*://')
        fi
        echo "$slot: $fw_label"
    done
    
    local choice
    while true; do
        read -p "Enter slot number: " choice
        if [[ "$choice" =~ ^[0-9]+$ ]] && [[ " ${slots[@]} " =~ " $choice " ]]; then
            SELECTED_SLOT="$choice"
            break
        fi
        echo "Invalid selection. Please try again."
    done
    
    log_info "Selected slot: $SELECTED_SLOT"
}

ask_mode() {
    local modes=()
    local mode_descriptions=(
        "0: Downloaded image replaces the image indicated by the Firmware Slot field. This image is not activated."
        "1: Downloaded image replaces the image indicated by the Firmware Slot field. This image is activated at the next reset."
        "2: The image indicated by the Firmware Slot field is activated at the next reset."
        "3: The image specified by the Firmware Slot field is requested to be activated immediately without reset."
    )
    
    modes=(0 1 2)
    if [[ $ACTIVATION_WITHOUT_RESET -eq 1 ]]; then
        modes+=(3)
    fi
    
    echo "Select update action (Mode 2 is recommended):"
    for mode in "${modes[@]}"; do
        echo "${mode_descriptions[$mode]}"
    done
    
    local choice
    while true; do
        read -p "Enter mode number (${modes[0]}-${modes[-1]}): " choice
        if [[ "$choice" =~ ^[0-9]$ ]] && [[ " ${modes[@]} " =~ " $choice " ]]; then
            ACTIVATION_MODE="$choice"
            break
        fi
        echo "Invalid selection. Please try again."
    done
    
    log_info "Selected activation mode: $ACTIVATION_MODE"
}

##############################################################################
# Firmware Download and Update
##############################################################################

get_upgrade_url() {
    log_debug "Getting upgrade URL..."
    
    local model="${MODEL// /_}"
    local base_url="${BASE_WD_DOMAIN}/firmware/${model}/${SELECTED_VERSION}"
    local prop_url="${base_url}/device_properties.xml"
    
    log_debug "Firmware properties URL: $prop_url"
    
    local curl_opts=$(get_curl_opts)
    local response
    response=$(curl $curl_opts "$prop_url" 2>/dev/null)
    
    if [[ $? -ne 0 ]]; then
        log_error "Failed to fetch firmware properties"
        return 1
    fi
    
    # Extract dependencies from XML
    local dependencies=()
    if command_exists xmllint; then
        while IFS= read -r dep; do
            if [[ -n "$dep" ]]; then
                dependencies+=("$dep")
            fi
        done < <(echo "$response" | xmllint --xpath "//dependency/text()" - 2>/dev/null)
    else
        while IFS= read -r line; do
            if [[ $line =~ \<dependency\>(.*)\</dependency\> ]]; then
                dependencies+=("${BASH_REMATCH[1]}")
            fi
        done < <(echo "$response" | grep "<dependency>")
    fi
    
    log_debug "Firmware dependencies: ${dependencies[@]}"
    
    # Check if current firmware is in dependencies
    if [[ "$MANUAL_MODE" == "false" ]]; then
        local found=0
        for dep in "${dependencies[@]}"; do
            if [[ "$dep" == "$CURRENT_FW" ]]; then
                found=1
                break
            fi
        done
        
        if [[ $found -eq 0 ]]; then
            echo "The current firmware version $CURRENT_FW is not in the dependency list"
            echo "of the new firmware. In order to upgrade to $SELECTED_VERSION, please"
            echo "upgrade to one of these versions first: ${dependencies[@]}"
            echo "If you believe this is a mistake, run with -m flag to enable manual mode."
            exit 1
        fi
    fi
    
    # Extract firmware file name from XML
    local fwfile
    if command_exists xmllint; then
        fwfile=$(echo "$response" | xmllint --xpath "//fwfile/text()" - 2>/dev/null)
    else
        fwfile=$(echo "$response" | grep -o '<fwfile>[^<]*' | sed 's/<fwfile>//')
    fi
    
    if [[ -z "$fwfile" ]]; then
        log_error "Could not find firmware file name"
        return 1
    fi
    
    FIRMWARE_URL="${base_url}/${fwfile}"
    log_debug "Firmware file URL: $FIRMWARE_URL"
}

update_fw() {
    log_info "Downloading firmware..."
    
    # Create temporary file for firmware
    local fw_file
    fw_file=$(mktemp --tmpdir "wd_fw_update.XXXXXX.fluf")
    TEMP_FW_FILE="$fw_file"
    
    log_debug "Temporary firmware file: $fw_file"
    
    # Download firmware
    local curl_opts=$(get_curl_opts)
    
    if ! curl $curl_opts "$FIRMWARE_URL" -o "$fw_file" 2>/dev/null; then
        log_error "Failed to download firmware from $FIRMWARE_URL"
        rm -f "$fw_file"
        return 1
    fi
    
    # Check if file was downloaded
    if [[ ! -f "$fw_file" ]] || [[ ! -s "$fw_file" ]]; then
        log_error "Firmware file is empty or not created"
        rm -f "$fw_file"
        return 1
    fi
    
    log_info "Firmware downloaded successfully"
    
    # Print summary
    echo ""
    echo "========== Summary =========="
    echo "NVME location:     $DEVICE"
    echo "Model:             $MODEL"
    echo "Firmware Version:  $CURRENT_FW --> $SELECTED_VERSION"
    echo "Installation Slot: $SELECTED_SLOT"
    echo "Active Slot:       $CURRENT_SLOT --> $SELECTED_SLOT"
    echo "Activation Mode:   $ACTIVATION_MODE"
    echo "Temporary File:    $fw_file"
    echo ""
    
    # Ask for confirmation
    read -p "The summary is correct. Continue? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Aborted."
        rm -f "$fw_file"
        exit 0
    fi
    
    log_info "Loading the firmware file..."
    
    # Download firmware to device
    if ! sudo nvme fw-download "$DEVICE" --fw="$fw_file" &>/dev/null; then
        log_error "Failed to download firmware to device"
        rm -f "$fw_file"
        return 1
    fi
    
    log_info "Firmware loaded successfully"
    
    log_info "Committing/Switching to the firmware file..."
    
    # Commit firmware and set activation mode
    if ! sudo nvme fw-commit "$DEVICE" -s "$SELECTED_SLOT" -a "$ACTIVATION_MODE" &>/dev/null; then
        log_error "Failed to commit firmware"
        rm -f "$fw_file"
        return 1
    fi
    
    log_info "Firmware committed successfully"
    rm -f "$fw_file"
    
    return 0
}

##############################################################################
# Main Workflow
##############################################################################

print_help() {
    cat << EOF
$SCRIPT_NAME v$SCRIPT_VERSION

Updates the firmware of Western Digital SSDs.

Usage: $SCRIPT_NAME [OPTIONS]

Options:
  -h, --help              Show this help message
  --version               Show version information
  -i, --info              Print information about available drives
  -m, --manual            Disable version and dependency checks
  --ignore-ssl-errors     Ignore HTTPS/SSL errors (e.g. expired certificate)
  -v, --verbose           Enable verbose output
  -vv, --very-verbose     Enable debug output

Examples:
  $SCRIPT_NAME              # Interactive firmware update
  $SCRIPT_NAME -i           # Show drive information
  $SCRIPT_NAME -m -vv       # Update with manual mode and debug output

EOF
}

main_interactive() {
    echo "Western Digital SSD Firmware Update Tool"
    echo ""
    echo "WARNING: The official WDDashboard is EOL since 23.01.2025 and was transferred to SanDisk."
    echo "This may impact the functionality of this non-official tool."
    echo ""
    
    # Step 1: Ask for device
    ask_device || return 1
    
    # Step 2: Get model properties
    get_model_properties "$DEVICE" || return 1
    
    # Step 3: Fetch device list and find firmware URLs
    get_fw_url || return 1
    
    # Step 4: Ask for firmware version
    ask_fw_version || return 1
    
    # Step 5: Get upgrade URL
    get_upgrade_url || return 1
    
    # Step 6: Ask for slot
    ask_slot || return 1
    
    # Step 7: Ask for mode
    ask_mode || return 1
    
    # Step 8: Download and install firmware
    if update_fw; then
        case "$ACTIVATION_MODE" in
            0)
                echo "Update complete. Don't forget to switch to the new slot."
                ;;
            1|2)
                echo "Update complete. Please reboot."
                ;;
            3)
                echo "Update complete. Switched to the new version."
                ;;
        esac
    else
        log_error "An error happened during the update process."
        return 1
    fi
    
    log_info "Firmware update process completed."
}

main_info() {
    local devices=()
    
    mapfile -t devices < <(get_devices)
    
    if [[ ${#devices[@]} -eq 0 ]]; then
        log_error "No NVME devices found!"
        return 1
    fi
    
    for device in "${devices[@]}"; do
        print_info "$device"
    done
}

main() {
    local show_info=false
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                print_help
                exit 0
                ;;
            --version)
                echo "$SCRIPT_NAME $SCRIPT_VERSION"
                exit 0
                ;;
            -i|--info)
                show_info=true
                shift
                ;;
            -m|--manual)
                MANUAL_MODE=true
                shift
                ;;
            --ignore-ssl-errors)
                IGNORE_SSL_ERRORS=true
                shift
                ;;
            -v|--verbose)
                LOG_LEVEL=1
                shift
                ;;
            -vv|--very-verbose)
                LOG_LEVEL=2
                shift
                ;;
            *)
                log_error "Unknown option: $1"
                print_help
                exit 1
                ;;
        esac
    done
    
    # Install dependencies if needed
    if ! install_dependencies; then
        log_error "Dependency installation failed"
        exit 1
    fi
    
    # Run info mode or interactive mode
    if [[ "$show_info" == "true" ]]; then
        main_info
    else
        main_interactive
    fi
}

##############################################################################
# Script Entry Point
##############################################################################

# Trap to clean up temporary files on exit
cleanup() {
    if [[ -n "$TEMP_FW_FILE" && -f "$TEMP_FW_FILE" ]]; then
        rm -f "$TEMP_FW_FILE"
        log_debug "Cleaned up temporary firmware file"
    fi
}

trap cleanup EXIT

# Run main function with all arguments
main "$@"
