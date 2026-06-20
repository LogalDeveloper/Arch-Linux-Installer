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

# bootloader.sh - systemd-boot configuration
#
# Installs and configures systemd-boot as the bootloader:
# - Runs bootctl install to set up EFI boot manager
# - Creates boot entry with LUKS unlock parameters
# - Supports both single-disk and RAID1 configurations
# - Configures loader.conf timeout and editor settings

# Install systemd-boot bootloader
install_bootloader() {
    print "Installing bootloader..."
    run_visible_cmd_in_chroot bootctl install
}

# Create boot entry for single-disk installation
# Arguments:
#   $1 - LUKS UUID
create_boot_entry_single() {
    local luks_uuid="$1"

    run_cmd_in_chroot sh -c "cat > /boot/loader/entries/arch.conf" <<EOF
title   Arch Linux
linux   /vmlinuz-linux
initrd  /initramfs-linux.img
options lockdown=confidentiality intel_iommu=on amd_iommu=on iommu=force iommu.passthrough=0 rd.luks.name=${luks_uuid}=cryptroot rd.luks.options=discard root=/dev/mapper/cryptroot
EOF
}

# Create boot entry for RAID1 installation
# Arguments:
#   $1 - first LUKS UUID
#   $2 - second LUKS UUID
create_boot_entry_raid1() {
    local luks_uuid_1="$1"
    local luks_uuid_2="$2"

    run_cmd_in_chroot sh -c "cat > /boot/loader/entries/arch.conf" <<EOF
title   Arch Linux
linux   /vmlinuz-linux
initrd  /initramfs-linux.img
options lockdown=confidentiality intel_iommu=on amd_iommu=on iommu=force iommu.passthrough=0 rd.luks.name=${luks_uuid_1}=cryptroot-1 rd.luks.name=${luks_uuid_2}=cryptroot-2 rd.luks.options=${luks_uuid_1}=discard rd.luks.options=${luks_uuid_2}=discard root=/dev/mapper/cryptroot-1
EOF
}

# Create boot entry for RAID1 3-disk installation
# Arguments:
#   $1 - first LUKS UUID
#   $2 - second LUKS UUID
#   $3 - third LUKS UUID
create_boot_entry_raid1_3disk() {
    local luks_uuid_1="$1"
    local luks_uuid_2="$2"
    local luks_uuid_3="$3"

    run_cmd_in_chroot sh -c "cat > /boot/loader/entries/arch.conf" <<EOF
title   Arch Linux
linux   /vmlinuz-linux
initrd  /initramfs-linux.img
options lockdown=confidentiality intel_iommu=on amd_iommu=on iommu=force iommu.passthrough=0 rd.luks.name=${luks_uuid_1}=cryptroot-1 rd.luks.name=${luks_uuid_2}=cryptroot-2 rd.luks.name=${luks_uuid_3}=cryptroot-3 rd.luks.options=${luks_uuid_1}=discard rd.luks.options=${luks_uuid_2}=discard rd.luks.options=${luks_uuid_3}=discard root=/dev/mapper/cryptroot-1
EOF
}

# Create appropriate boot entry based on storage mode
# Arguments:
#   $1 - storage mode (single, raid1, raid1-3disk)
create_boot_entry() {
    local storage_mode="$1"

    if [ "$storage_mode" = "raid1" ]; then
        # shellcheck disable=SC2153
        create_boot_entry_raid1 "$LUKS_UUID" "$LUKS_UUID_2"
    elif [ "$storage_mode" = "raid1-3disk" ]; then
        # shellcheck disable=SC2153
        create_boot_entry_raid1_3disk "$LUKS_UUID" "$LUKS_UUID_2" "$LUKS_UUID_3"
    else
        create_boot_entry_single "$LUKS_UUID"
    fi
}

# Configure loader.conf
configure_loader() {
    run_cmd_in_chroot sed -i 's/^#timeout 3/timeout menu-hidden/' /boot/loader/loader.conf
    run_cmd_in_chroot sh -c 'printf "\neditor no\n" >> /boot/loader/loader.conf'
}

# Full bootloader setup
# Arguments:
#   $1 - storage mode
setup_bootloader() {
    local storage_mode="$1"

    install_bootloader
    create_boot_entry "$storage_mode"
    configure_loader
}
