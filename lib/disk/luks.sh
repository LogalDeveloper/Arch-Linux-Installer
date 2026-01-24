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

# luks.sh - LUKS encryption functions
#
# Manages full-disk encryption using LUKS2:
# - Prompts for encryption passphrase with confirmation
# - Formats partitions with LUKS2 using secure defaults from luks.conf
# - Opens/unlocks encrypted containers for filesystem creation
# - Supports both single-disk and RAID1 encryption setups
# - Securely clears passwords from memory after use

# Format a partition with LUKS encryption
# Arguments:
#   $1 - partition path
#   $2 - encryption password
setup_luks_encryption() {
    local partition="$1"
    local password="$2"

    print "Setting up encryption on ${partition}..."

    run_piped_cmd "$password" cryptsetup luksFormat \
        --type "$LUKS_TYPE" \
        --cipher "$LUKS_CIPHER" \
        --hash "$LUKS_HASH" \
        --key-size "$LUKS_KEY_SIZE" \
        --pbkdf "$LUKS_PBKDF" \
        --pbkdf-force-iterations "$LUKS_PBKDF_ITERATIONS" \
        --pbkdf-memory "$LUKS_PBKDF_MEMORY" \
        --pbkdf-parallel "$LUKS_PBKDF_PARALLEL" \
        --use-urandom \
        --key-file - \
        "$partition"
}

# Open (unlock) a LUKS container
# Arguments:
#   $1 - partition path
#   $2 - encryption password
#   $3 - mapper name (e.g., cryptroot)
open_luks_container() {
    local partition="$1"
    local password="$2"
    local mapper_name="$3"

    print "Unlocking ${partition}..."

    run_piped_cmd "$password" cryptsetup open \
        --allow-discards \
        --key-file - \
        "$partition" \
        "$mapper_name"
}

# Get the UUID of a LUKS container
# Arguments:
#   $1 - partition path
# Outputs:
#   UUID to stdout
get_luks_uuid() {
    local partition="$1"

    run_cmd cryptsetup luksDump "$partition" | grep 'UUID:' | awk '{print $2}'
}

# Close a LUKS container
# Arguments:
#   $1 - mapper name
close_luks_container() {
    local mapper_name="$1"

    run_cmd_allow_fail cryptsetup close "$mapper_name"
}

# Prompt for encryption password with confirmation
# Sets:
#   ENCRYPTION_PASSWORD - the entered password
# Returns:
#   0 on success, 1 on mismatch
prompt_encryption_password() {
    if ! prompt_password "Please enter your desired encryption passphrase." ENCRYPTION_PASSWORD; then
        return 1
    fi
    return 0
}

# Setup encryption for single-disk mode
# Arguments:
#   $1 - root partition path
# Sets:
#   LUKS_UUID - UUID of the LUKS container
setup_encryption_single() {
    local root_partition="$1"

    if ! prompt_encryption_password; then
        exit 1
    fi

    setup_luks_encryption "$root_partition" "$ENCRYPTION_PASSWORD"
    open_luks_container "$root_partition" "$ENCRYPTION_PASSWORD" "cryptroot"
    LUKS_UUID=$(get_luks_uuid "$root_partition")

    # Clear password from memory
    unset ENCRYPTION_PASSWORD
}

# Setup encryption for RAID1 mode
# Arguments:
#   $1 - first root partition path
#   $2 - second root partition path
# Sets:
#   LUKS_UUID - UUID of the first LUKS container
#   LUKS_UUID_2 - UUID of the second LUKS container
setup_encryption_raid1() {
    local root_partition_1="$1"
    local root_partition_2="$2"

    if ! prompt_encryption_password; then
        exit 1
    fi

    # Setup first disk
    setup_luks_encryption "$root_partition_1" "$ENCRYPTION_PASSWORD"
    open_luks_container "$root_partition_1" "$ENCRYPTION_PASSWORD" "cryptroot-1"
    LUKS_UUID=$(get_luks_uuid "$root_partition_1")

    # Setup second disk
    setup_luks_encryption "$root_partition_2" "$ENCRYPTION_PASSWORD"
    open_luks_container "$root_partition_2" "$ENCRYPTION_PASSWORD" "cryptroot-2"
    LUKS_UUID_2=$(get_luks_uuid "$root_partition_2")

    # Clear password from memory
    unset ENCRYPTION_PASSWORD
}

# Setup encryption for RAID1 3-disk mode
# Arguments:
#   $1 - first root partition path
#   $2 - second root partition path
#   $3 - third root partition path
# Sets:
#   LUKS_UUID - UUID of the first LUKS container
#   LUKS_UUID_2 - UUID of the second LUKS container
#   LUKS_UUID_3 - UUID of the third LUKS container
setup_encryption_raid1_3disk() {
    local root_partition_1="$1"
    local root_partition_2="$2"
    local root_partition_3="$3"

    if ! prompt_encryption_password; then
        exit 1
    fi

    # Setup first disk
    setup_luks_encryption "$root_partition_1" "$ENCRYPTION_PASSWORD"
    open_luks_container "$root_partition_1" "$ENCRYPTION_PASSWORD" "cryptroot-1"
    LUKS_UUID=$(get_luks_uuid "$root_partition_1")

    # Setup second disk
    setup_luks_encryption "$root_partition_2" "$ENCRYPTION_PASSWORD"
    open_luks_container "$root_partition_2" "$ENCRYPTION_PASSWORD" "cryptroot-2"
    LUKS_UUID_2=$(get_luks_uuid "$root_partition_2")

    # Setup third disk
    setup_luks_encryption "$root_partition_3" "$ENCRYPTION_PASSWORD"
    open_luks_container "$root_partition_3" "$ENCRYPTION_PASSWORD" "cryptroot-3"
    LUKS_UUID_3=$(get_luks_uuid "$root_partition_3")

    # Clear password from memory
    unset ENCRYPTION_PASSWORD
}
