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

# security.sh - Security hardening functions
#
# Applies security hardening to the installed system:
# - Configures mkinitcpio with sd-encrypt hook for LUKS
# - Enables sudo access for wheel group
# - Disables root account login
# - Enables nftables firewall, smartd, and fstrim timer
# - Configures OpenSSH with restricted settings
# - Installs custom CA certificates from certs directory to system trust store
# - Sets up USBGuard to whitelist connected devices

# Configure mkinitcpio hooks for encrypted root
configure_initramfs() {
    print "Configuring initramfs..."

    run_visible_cmd_in_chroot mkinitcpio -P
}

# Enable BTRFS scrub timer if using BTRFS filesystem
# Arguments:
#   $1 - filesystem type
enable_btrfs_scrub() {
    local filesystem="$1"

    if [ "$filesystem" = "btrfs" ] || [ "$filesystem" = "btrfs-dup" ]; then
        chroot_systemd_enable btrfs-scrub@-.timer
    fi
}

# Configure sudo access for wheel group
configure_sudo() {
    print "Enabling sudo access for wheel group..."
    run_cmd_in_chroot sed -i "s|^# %wheel ALL=(ALL:ALL) ALL|%wheel ALL=(ALL:ALL) ALL|" /etc/sudoers
}

# Disable root account login
disable_root() {
    print "Disabling root account..."
    run_cmd_in_chroot passwd -l root
}

# Configure SSH server
# Arguments:
#   $1 - username to allow SSH access
configure_ssh() {
    local username="$1"

    print "Setting up and enabling OpenSSH server..."

    run_cmd_in_chroot sed -i "s|PLACEHOLDER|${username}|" /etc/ssh/sshd_config
    run_visible_cmd_in_chroot ssh-keygen -t ed25519 -C "" -N "" -f /etc/ssh/ssh_host_ed25519_key
    chroot_systemd_enable sshd.service
}

# Display SSH host key fingerprint
show_ssh_fingerprint() {
    print "Public SSH key fingerprint of this host:"
    run_visible_cmd_in_chroot ssh-keygen -lvf /etc/ssh/ssh_host_ed25519_key.pub
}

# Install custom CA certificates from certs directory
install_ca_certificates() {
    local certs=("${CA_CERTS_DIR}"/*.crt)

    if [ ! -e "${certs[0]}" ]; then
        print "No CA certificates found to install."
        return
    fi

    for cert in "${certs[@]}"; do
        local cert_name
        cert_name=$(basename "$cert")
        print "Adding ${cert_name} to system CA store..."

        run_visible_cmd cp "$cert" "${MOUNT_POINT}/${cert_name}"
        run_cmd_in_chroot trust anchor --store "/${cert_name}"
        run_cmd_in_chroot rm "/${cert_name}"
    done
}

# Configure USBGuard
configure_usbguard() {
    print "Please add or remove any USB devices, including the installer drive, to form the standard configuration for this system. USBGuard will be configured to only allow the USB devices connected at the time you press enter to be used; everything else will be blocked."
    print "When ready to proceed, press enter."
    read -r

    run_cmd_in_chroot sh -c "usbguard generate-policy > /etc/usbguard/rules.conf"
    chroot_systemd_enable usbguard.service
}

# Full security setup
# Arguments:
#   $1 - filesystem type
setup_security() {
    local filesystem="$1"

    configure_sudo
    disable_root
    chroot_systemd_enable nftables.service
    chroot_systemd_enable smartd.service
    chroot_systemd_enable fstrim.timer
    enable_btrfs_scrub "$filesystem"
}
