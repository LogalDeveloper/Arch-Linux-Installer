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

# filesystem.sh - Filesystem creation and mounting functions
#
# Creates and mounts filesystems on encrypted volumes:
# - Formats EFI partition as FAT32
# - Supports ext4, BTRFS, BTRFS with DUP, and BTRFS RAID1
# - Uses xxhash checksum for BTRFS filesystems
# - Mounts root with noatime and appropriate discard options
# - Mounts EFI partition at /efi with restrictive permissions

# Format a partition as FAT32 (for EFI)
# Arguments:
#   $1 - partition path
format_efi_partition() {
    local partition="$1"

    print "Formatting ${partition} as FAT32..."
    run_visible_cmd mkfs.fat -F 32 "$partition"
}

# Format a device as ext4
# Arguments:
#   $1 - device path (e.g., /dev/mapper/cryptroot)
format_ext4() {
    local device="$1"

    print "Formatting ${device} as ext4..."
    run_visible_cmd mkfs.ext4 "$device"
}

# Format a device as BTRFS (single disk)
# Arguments:
#   $1 - device path
format_btrfs() {
    local device="$1"

    print "Formatting ${device} as btrfs..."
    run_visible_cmd mkfs.btrfs --csum xxhash "$device"
}

# Format a device as BTRFS with dup profile
# Arguments:
#   $1 - device path
format_btrfs_dup() {
    local device="$1"

    print "Formatting ${device} as btrfs with dup profile..."
    run_visible_cmd mkfs.btrfs --csum xxhash --data dup --metadata dup "$device"
}

# Format two devices as BTRFS RAID1
# Arguments:
#   $1 - first device path
#   $2 - second device path
format_btrfs_raid1() {
    local device1="$1"
    local device2="$2"

    print "Formatting ${device1} and ${device2} as btrfs RAID1..."
    run_visible_cmd mkfs.btrfs --csum xxhash --data raid1 --metadata raid1 "$device1" "$device2"
}

# Format three devices as BTRFS RAID1 with enhanced metadata redundancy
# Arguments:
#   $1 - first device path
#   $2 - second device path
#   $3 - third device path
format_btrfs_raid1_3disk() {
    local device1="$1"
    local device2="$2"
    local device3="$3"

    print "Formatting ${device1}, ${device2}, and ${device3} as btrfs RAID1..."
    run_visible_cmd mkfs.btrfs --csum xxhash --data raid1 --metadata raid1c3 "$device1" "$device2" "$device3"
}

# Format the root filesystem based on configuration
# Arguments:
#   $1 - filesystem type (ext4, btrfs, btrfs-dup)
#   $2 - storage mode (single, raid1, raid1-3disk)
format_root_filesystem() {
    local filesystem="$1"
    local storage_mode="$2"

    case "$filesystem" in
        "ext4")
            if [ "$storage_mode" = "raid1" ] || [ "$storage_mode" = "raid1-3disk" ]; then
                print_error "ext4 cannot be used with RAID1."
                exit 1
            fi
            format_ext4 /dev/mapper/cryptroot
            ;;

        "btrfs-dup")
            format_btrfs_dup /dev/mapper/cryptroot
            ;;

        "btrfs"|*)
            if [ "$storage_mode" = "raid1" ]; then
                format_btrfs_raid1 /dev/mapper/cryptroot-1 /dev/mapper/cryptroot-2
            elif [ "$storage_mode" = "raid1-3disk" ]; then
                format_btrfs_raid1_3disk /dev/mapper/cryptroot-1 /dev/mapper/cryptroot-2 /dev/mapper/cryptroot-3
            else
                format_btrfs /dev/mapper/cryptroot
            fi
            ;;
    esac
}

# Mount the root filesystem with appropriate options
# Arguments:
#   $1 - filesystem type (ext4, btrfs, btrfs-dup)
#   $2 - storage mode (single, raid1, raid1-3disk)
mount_root_filesystem() {
    local filesystem="$1"
    local storage_mode="$2"

    print "Mounting partitions..."

    case "$filesystem" in
        "ext4")
            run_visible_cmd mount -o "noatime,discard" /dev/mapper/cryptroot "${MOUNT_POINT}"
            ;;

        *)
            if [ "$storage_mode" = "raid1" ]; then
                run_visible_cmd mount -o "noatime,discard=async" /dev/mapper/cryptroot-1 "${MOUNT_POINT}"
            elif [ "$storage_mode" = "raid1-3disk" ]; then
                run_visible_cmd mount -o "noatime,discard=async" /dev/mapper/cryptroot-1 "${MOUNT_POINT}"
            else
                run_visible_cmd mount -o "noatime,discard=async" /dev/mapper/cryptroot "${MOUNT_POINT}"
            fi
            ;;
    esac
}

# Mount the EFI partition
# Arguments:
#   $1 - EFI partition path
mount_efi_partition() {
    local efi_partition="$1"
    local efi_mount_target="${MOUNT_POINT}${EFI_MOUNT_POINT}"

    run_visible_cmd install -d -m 0700 "$efi_mount_target"
    run_visible_cmd mount -o "$EFI_MOUNT_OPTIONS" "$efi_partition" "$efi_mount_target"
}

# Format and mount all filesystems
# Arguments:
#   $1 - filesystem type
#   $2 - storage mode
format_and_mount_filesystems() {
    local filesystem="$1"
    local storage_mode="$2"

    # Format EFI partition(s)
    # shellcheck disable=SC2153
    format_efi_partition "$EFI_PARTITION"
    if [ "$storage_mode" = "raid1" ]; then
        format_efi_partition "$EFI_PARTITION_2"
    elif [ "$storage_mode" = "raid1-3disk" ]; then
        format_efi_partition "$EFI_PARTITION_2"
        format_efi_partition "$EFI_PARTITION_3"
    fi

    # Format and mount root
    format_root_filesystem "$filesystem" "$storage_mode"
    mount_root_filesystem "$filesystem" "$storage_mode"

    # Mount EFI
    mount_efi_partition "$EFI_PARTITION"
}
