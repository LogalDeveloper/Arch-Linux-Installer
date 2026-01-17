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

# base.sh - Base system installation functions
#
# Installs and configures the core Arch Linux system:
# - Runs pacstrap with base packages defined in defaults.conf
# - Detects CPU vendor and installs appropriate microcode (Intel/AMD)
# - Generates /etc/fstab with UUIDs
# - Provides chroot helper functions for running commands in new system
# - Copies configuration files from installer to target system

# Run a command in the chroot environment
# Arguments:
#   $@ - command and arguments
chroot_run() {
    arch-chroot "${MOUNT_POINT}" "$@"
}

# Install packages in the chroot environment
# Arguments:
#   $@ - package names
chroot_install() {
    run_visible_cmd chroot_run pacman --noconfirm -S "$@"
}

# Enable a systemd service in the chroot environment
# Arguments:
#   $@ - service names
chroot_enable() {
    run_visible_cmd chroot_run systemctl enable "$@"
}

# Install base Arch Linux packages
install_base_packages() {
    print "Installing Arch Linux base..."

    run_visible_cmd pacstrap -K "${MOUNT_POINT}" "${BASE_PACKAGES[@]}"
}

# Detect CPU vendor
# Outputs:
#   "intel", "amd", or "unknown"
detect_cpu_vendor() {
    local vendor
    vendor=$(grep -m 1 'vendor_id' /proc/cpuinfo | awk '{print $3}')

    case "$vendor" in
        "GenuineIntel")
            echo "intel"
            ;;
        "AuthenticAMD")
            echo "amd"
            ;;
        *)
            echo "unknown"
            ;;
    esac
}

# Install CPU microcode based on detected vendor
install_microcode() {
    local vendor
    vendor=$(detect_cpu_vendor)

    print "Installing CPU microcode..."

    case "$vendor" in
        "intel")
            chroot_install intel-ucode
            ;;
        "amd")
            chroot_install amd-ucode
            ;;
        *)
            print_warning "Unknown CPU vendor: ${vendor}. Please install microcode manually after installation, if available."
            ;;
    esac
}

# Generate /etc/fstab
generate_fstab() {
    print "Generating /etc/fstab..."
    genfstab -U "${MOUNT_POINT}" >> "${MOUNT_POINT}/etc/fstab"
}

# Copy configuration files from installer to target system
copy_config_files() {
    print "Installing default configuration files..."
    cp -r "${CONFIG_SRC_DIR}" "${MOUNT_POINT}"
}
