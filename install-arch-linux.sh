#!/bin/bash

# Copyright 2025 Logan Fick
#
# Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with the License. You may obtain a copy of the License at: https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License.

#===============================================================================
# INITIALIZATION
#===============================================================================

# Determine script directory for sourcing modules
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source configuration
source "${SCRIPT_DIR}/config/defaults.conf"
source "${SCRIPT_DIR}/config/luks.conf"
source "${SCRIPT_DIR}/config/drivers.conf"
source "${SCRIPT_DIR}/config/profiles.conf"

# Source core libraries
source "${SCRIPT_DIR}/lib/core/common.sh"
source "${SCRIPT_DIR}/lib/core/validation.sh"
source "${SCRIPT_DIR}/lib/core/error.sh"
source "${SCRIPT_DIR}/lib/core/logging.sh"

# Source disk operation modules
source "${SCRIPT_DIR}/lib/disk/partition.sh"
source "${SCRIPT_DIR}/lib/disk/luks.sh"
source "${SCRIPT_DIR}/lib/disk/filesystem.sh"

# Source system configuration modules
source "${SCRIPT_DIR}/lib/system/base.sh"
source "${SCRIPT_DIR}/lib/system/bootloader.sh"
source "${SCRIPT_DIR}/lib/system/locale.sh"
source "${SCRIPT_DIR}/lib/system/network.sh"
source "${SCRIPT_DIR}/lib/system/security.sh"
source "${SCRIPT_DIR}/lib/system/user.sh"

# Source desktop modules
source "${SCRIPT_DIR}/lib/desktop/kde.sh"
source "${SCRIPT_DIR}/lib/desktop/drivers.sh"

# Source profile system
source "${SCRIPT_DIR}/lib/system/profiles.sh"

# Enable error handling
trap_errors

#===============================================================================
# STORAGE CONFIGURATION
#===============================================================================

# Prompt user for storage mode selection
# Sets:
#   STORAGE_MODE - "single" or "raid1"
#   FILESYSTEM - "ext4", "btrfs", or "btrfs-dup"
select_storage_mode() {
    print "Select storage and filesystem configuration:"
    print " 1 - BTRFS (Single disk)"
    print " 2 - BTRFS DUP (Single disk with duplicate data and metadata)"
    print " 3 - BTRFS RAID1 (Two disks with full redundancy)"
    print " 4 - ext4 (Single disk)"
    read -r storage_choice

    case "$storage_choice" in
        "2")
            STORAGE_MODE="single"
            FILESYSTEM="btrfs-dup"
            print "BTRFS dup mode selected. Data and metadata will be duplicated on the same disk."
            ;;
        "3")
            STORAGE_MODE="raid1"
            FILESYSTEM="btrfs"
            print "BTRFS RAID1 mode selected. You will need two disks of similar size."
            ;;
        "4")
            STORAGE_MODE="single"
            FILESYSTEM="ext4"
            print "ext4 on single disk selected."
            ;;
        *)
            STORAGE_MODE="single"
            FILESYSTEM="btrfs"
            print "BTRFS on single disk selected."
            ;;
    esac
}

#===============================================================================
# PRE-INSTALLATION NOTES
#===============================================================================

show_pre_install_notes() {
    print "Please check the following items before proceeding:"
    print " - If you intend to use an Advanced Format (e.g. NVMe) drive, verify the optimal sector size is selected. (https://wiki.archlinux.org/title/Advanced_Format)"
    print "If you need to go back, press Ctrl+C. Otherwise, press enter to continue."
    read -r
}

#===============================================================================
# MAIN INSTALLATION FLOW
#===============================================================================

main() {
    # Initialize logging
    init_logging

    # Show banner
    print_banner

    #---------------------------------------------------------------------------
    # Phase 1: Pre-flight Checks
    #---------------------------------------------------------------------------
    set_phase "Pre-flight Checks"

    if ! check_internet; then
        exit 1
    fi

    if ! check_time_sync; then
        exit 1
    fi

    configure_mirrorlist
    show_pre_install_notes

    #---------------------------------------------------------------------------
    # Phase 2: Storage Configuration
    #---------------------------------------------------------------------------
    set_phase "Storage Configuration"

    select_storage_mode

    if [ "$STORAGE_MODE" = "raid1" ]; then
        if ! select_raid1_disks; then
            exit 1
        fi
    else
        if ! select_single_disk; then
            exit 1
        fi
    fi

    #---------------------------------------------------------------------------
    # Phase 3: Disk Preparation
    #---------------------------------------------------------------------------
    set_phase "Disk Preparation"

    partition_disks "$STORAGE_MODE"

    # Setup encryption
    if [ "$STORAGE_MODE" = "raid1" ]; then
        setup_encryption_raid1 "$ROOT_PARTITION" "$ROOT_PARTITION_2"
    else
        setup_encryption_single "$ROOT_PARTITION"
    fi

    # Format and mount filesystems
    format_and_mount_filesystems "$FILESYSTEM" "$STORAGE_MODE"

    #---------------------------------------------------------------------------
    # Phase 4: Base System Installation
    #---------------------------------------------------------------------------
    set_phase "Base System Installation"

    install_base_packages
    install_microcode
    generate_fstab

    #---------------------------------------------------------------------------
    # Phase 5: System Configuration
    #---------------------------------------------------------------------------
    set_phase "System Configuration"

    setup_locale
    configure_initramfs
    setup_bootloader "$STORAGE_MODE"

    #---------------------------------------------------------------------------
    # Phase 6: User Account Setup
    #---------------------------------------------------------------------------
    set_phase "User Account Setup"

    setup_user
    copy_config_files

    #---------------------------------------------------------------------------
    # Phase 7: Network Configuration
    #---------------------------------------------------------------------------
    set_phase "Network Configuration"

    setup_network
    prompt_install_wifi

    #---------------------------------------------------------------------------
    # Phase 8: Security Configuration
    #---------------------------------------------------------------------------
    set_phase "Security Configuration"

    setup_security "$FILESYSTEM"
    configure_ssh "$USERNAME"
    install_ca_certificates

    #---------------------------------------------------------------------------
    # Phase 9: Profile Installation
    #---------------------------------------------------------------------------
    set_phase "Profile Installation"

    select_and_install_profile "$USERNAME"

    #---------------------------------------------------------------------------
    # Phase 10: Finalization
    #---------------------------------------------------------------------------
    set_phase "Finalization"

    configure_usbguard

    #---------------------------------------------------------------------------
    # Finish
    #---------------------------------------------------------------------------
    finalize_logging

    echo -e "\n\n\n\n\n"
    print_success "Installation complete!"

    show_ssh_fingerprint
}

# Run main function
main "$@"
