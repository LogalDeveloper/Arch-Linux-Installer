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

# network.sh - Network configuration
#
# Handles network setup for both installation and target system:
# - Verifies internet connectivity before installation begins
# - Checks system time synchronization via systemd-timesyncd
# - Configures pacman mirrorlist to use private mirror
# - Enables systemd-resolved, systemd-networkd, and systemd-timesyncd
# - Optionally installs iwd for Wi-Fi support

# Check internet connectivity
check_internet() {
    print "Checking internet connectivity..."

    if curl -s --head "$INTERNET_CHECK_URL" | grep "200" >/dev/null; then
        print_success "Internet connection is available!"
        return 0
    else
        print_error "Internet connection appears not available (HTTP request to \"$INTERNET_CHECK_URL\" failed). Please check network settings and re-run this script."
        return 1
    fi
}

# Check system time synchronization
check_time_sync() {
    print "Checking system time synchronization state..."

    if timedatectl status | grep -q "System clock synchronized: yes"; then
        print_success "System time is synchronized!"
        return 0
    else
        print_error "The system time is not synchronized. Please check systemd-timesyncd and re-run this script."
        return 1
    fi
}

# Configure pacman mirrorlist
configure_mirrorlist() {
    print "Setting mirrorlist to use private mirror..."
    echo "Server = ${MIRROR_URL}" > /etc/pacman.d/mirrorlist
}

# Enable systemd-resolved
enable_resolved() {
    print "Enabling systemd-resolved..."

    chroot_enable systemd-resolved.service
    ln -sf ../run/systemd/resolve/stub-resolv.conf "${MOUNT_POINT}/etc/resolv.conf"
}

# Enable systemd-networkd
enable_networkd() {
    print "Enabling systemd-networkd..."
    chroot_enable systemd-networkd.service
}

# Enable systemd-timesyncd
enable_timesyncd() {
    print "Enabling systemd-timesyncd..."
    chroot_enable systemd-timesyncd.service
}

# Prompt and install iwd for Wi-Fi support
prompt_install_wifi() {
    print "Would you like to install iwd for Wi-Fi support? Enter 'y' exactly for yes, otherwise anything else to skip."
    read -r install_iwd

    if [ "$install_iwd" = "y" ]; then
        print "Installing iwd..."
        chroot_install iwd
        chroot_enable iwd.service
    fi
}

# Full network setup
setup_network() {
    enable_resolved
    enable_networkd
    enable_timesyncd
}
