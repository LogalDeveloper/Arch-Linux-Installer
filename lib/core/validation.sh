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

# validation.sh - Input validation functions
#
# Validates user input (disks, usernames, menu selections) to prevent errors
# during installation.

# Validate that a disk exists
# Arguments:
#   $1 - disk path (e.g., /dev/sda)
# Returns:
#   0 if disk exists, 1 otherwise
validate_disk_exists() {
    local disk="$1"

    if [ ! -b "$disk" ]; then
        print_error "Disk '$disk' does not exist or is not a block device."
        return 1
    fi
    return 0
}

# Validate that a disk is not mounted
# Arguments:
#   $1 - disk path
# Returns:
#   0 if not mounted, 1 if mounted
validate_disk_not_mounted() {
    local disk="$1"

    if mount | grep -q "^${disk}"; then
        print_error "Disk '$disk' appears to be mounted. Please unmount it first."
        return 1
    fi
    return 0
}

# Validate that two disks are different (for RAID1)
# Arguments:
#   $1 - first disk path
#   $2 - second disk path
# Returns:
#   0 if different, 1 if same
validate_disks_different() {
    local disk1="$1"
    local disk2="$2"

    if [ "$disk1" = "$disk2" ]; then
        print_error "Both disks must be different. You entered the same disk twice."
        return 1
    fi
    return 0
}

# Validate username format
# Arguments:
#   $1 - username
# Returns:
#   0 if valid, 1 otherwise
validate_username() {
    local username="$1"

    # Check if empty
    if [ -z "$username" ]; then
        print_error "Username cannot be empty."
        return 1
    fi

    # Check length (max 32 chars)
    if [ ${#username} -gt 32 ]; then
        print_error "Username must be 32 characters or less."
        return 1
    fi

    # Check format (lowercase letters, digits, underscore, hyphen; must start with letter)
    if ! [[ "$username" =~ ^[a-z][a-z0-9_-]*$ ]]; then
        print_error "Username must start with a lowercase letter and contain only lowercase letters, digits, underscores, and hyphens."
        return 1
    fi

    return 0
}

# Validate menu selection is in range
# Arguments:
#   $1 - selection
#   $2 - minimum value
#   $3 - maximum value
# Returns:
#   0 if valid, 1 otherwise
validate_menu_selection() {
    local selection="$1"
    local min="$2"
    local max="$3"

    # Check if it's a number
    if ! [[ "$selection" =~ ^[0-9]+$ ]]; then
        print_error "Please enter a number between $min and $max."
        return 1
    fi

    # Check range
    if [ "$selection" -lt "$min" ] || [ "$selection" -gt "$max" ]; then
        print_error "Please enter a number between $min and $max."
        return 1
    fi

    return 0
}

# Validate password is not empty
# Arguments:
#   $1 - password
# Returns:
#   0 if valid, 1 otherwise
validate_password_not_empty() {
    local password="$1"

    if [ -z "$password" ]; then
        print_error "Password cannot be empty."
        return 1
    fi
    return 0
}
