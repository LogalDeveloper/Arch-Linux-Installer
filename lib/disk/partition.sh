#!/bin/bash

# Copyright 2026 Logan Fick
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# partition.sh - Disk partitioning functions
#
# Handles disk selection and GPT partitioning for both single and RAID1 modes:
# - Interactive disk selection with confirmation prompts
# - Wipes existing partition tables using wipefs
# - Creates GPT layout: 1GB EFI System Partition + LUKS root partition
# - Handles NVMe vs SATA partition naming conventions (nvme0n1p1 vs sda1)

# Detect the correct partition prefix for a disk
# NVMe drives use "p" before partition number (e.g., /dev/nvme0n1p1)
# SATA/SAS drives append number directly (e.g., /dev/sda1)
# Arguments:
#   $1 - disk path
# Outputs:
#   Partition prefix to stdout
detect_partition_prefix() {
    local disk="$1"

    if [[ "$disk" == /dev/nvme* ]]; then
        echo "${disk}p"
    else
        echo "$disk"
    fi
}

# Display disk information using fdisk
show_disk_info() {
    run_visible_cmd fdisk -l
}

# Select a disk with confirmation
# Arguments:
#   $1 - prompt message
#   $2 - variable name to store selected disk
# Returns:
#   0 on success, 1 on validation failure
select_disk() {
    local prompt_msg="$1"
    local var_name="$2"
    local selected_disk
    local disk_confirm

    print "$prompt_msg"
    read -r selected_disk

    # Validate disk exists
    if ! validate_disk_exists "$selected_disk"; then
        return 1
    fi

    # Confirm selection
    print "Please confirm your selection by entering the same path again."
    read -r disk_confirm

    if [ "$selected_disk" != "$disk_confirm" ]; then
        print_error "The same disk was not entered both times."
        return 1
    fi

    eval "$var_name='$selected_disk'"
    return 0
}

# Wipe all filesystem signatures from a disk
# Arguments:
#   $1 - disk path
wipe_disk() {
    local disk="$1"

    print "Wiping existing partition table from $disk..."
    # Discard all sectors first (useful for SSDs, may fail on HDDs)
    run_cmd_allow_fail blkdiscard -f "$disk"
    run_visible_cmd wipefs -a "$disk"
}

# Create GPT partitions for EFI + root
# Arguments:
#   $1 - disk path
# Sets:
#   EFI_PARTITION - path to EFI partition
#   ROOT_PARTITION - path to root partition
create_gpt_partitions() {
    local disk="$1"
    local prefix

    print "Partitioning $disk..."

    # Create GPT table with 1GB EFI partition
    run_visible_cmd sgdisk --new 1:0:1G "$disk"
    run_visible_cmd sgdisk --typecode 1:ef00 "$disk"

    # Create root partition using remaining space
    run_visible_cmd sgdisk --new 2:0:0 "$disk"
    run_visible_cmd sgdisk --typecode 2:8309 "$disk"

    # Set partition paths
    prefix=$(detect_partition_prefix "$disk")
    EFI_PARTITION="${prefix}1"
    ROOT_PARTITION="${prefix}2"
}

# Select and configure disks for single-disk installation
# Sets:
#   INSTALL_DISK - primary disk path
#   EFI_PARTITION - EFI partition path
#   ROOT_PARTITION - root partition path
select_single_disk() {
    show_disk_info

    if ! select_disk "Please enter the path to the disk you would like to install Arch Linux to (e.g. /dev/sda)." INSTALL_DISK; then
        return 1
    fi

    if ! require_confirmation "Last warning: Are you sure you want to install Arch Linux to '$INSTALL_DISK'? All data on this disk will be wiped."; then
        return 1
    fi

    return 0
}

# Select and configure disks for RAID1 installation
# Sets:
#   INSTALL_DISK - first disk path
#   INSTALL_DISK_2 - second disk path
#   EFI_PARTITION, EFI_PARTITION_2 - EFI partition paths
#   ROOT_PARTITION, ROOT_PARTITION_2 - root partition paths
select_raid1_disks() {
    show_disk_info

    if ! select_disk "Please enter the path to the FIRST disk for RAID1 (e.g. /dev/sda)." INSTALL_DISK; then
        return 1
    fi

    if ! select_disk "Enter the path to the SECOND disk for RAID1 (e.g. /dev/sdb). This must be a DIFFERENT disk." INSTALL_DISK_2; then
        return 1
    fi

    if ! validate_disks_different "$INSTALL_DISK" "$INSTALL_DISK_2"; then
        return 1
    fi

    if ! require_confirmation "Last warning: Are you sure you want to install Arch Linux in RAID1 mode to '$INSTALL_DISK' and '$INSTALL_DISK_2'? All data on BOTH disks will be wiped."; then
        return 1
    fi

    return 0
}

# Partition disks based on storage mode
# Arguments:
#   $1 - storage mode (single or raid1)
partition_disks() {
    local storage_mode="$1"

    if [ "$storage_mode" = "raid1" ]; then
        wipe_disk "$INSTALL_DISK"
        wipe_disk "$INSTALL_DISK_2"

        create_gpt_partitions "$INSTALL_DISK"
        local primary_efi="$EFI_PARTITION"
        local primary_root="$ROOT_PARTITION"

        create_gpt_partitions "$INSTALL_DISK_2"
        EFI_PARTITION_2="$EFI_PARTITION"
        ROOT_PARTITION_2="$ROOT_PARTITION"

        EFI_PARTITION="$primary_efi"
        ROOT_PARTITION="$primary_root"
    else
        wipe_disk "$INSTALL_DISK"
        create_gpt_partitions "$INSTALL_DISK"
    fi
}
