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
# - Signs systemd-boot before bootctl copies it to the ESP
# - Runs bootctl install to set up EFI boot manager
# - Relies on systemd-boot Type #2 UKI auto-discovery
# - Configures loader.conf timeout and editor settings

# Install systemd-boot bootloader
install_bootloader() {
    print "Installing bootloader..."
    run_visible_cmd_in_chroot bootctl --esp-path="$EFI_MOUNT_POINT" install
}

# Configure loader.conf
configure_loader() {
    run_cmd_in_chroot install -d -m 0755 "${EFI_MOUNT_POINT}/loader"
    run_cmd_in_chroot sh -c "cat > ${EFI_MOUNT_POINT}/loader/loader.conf" <<'EOF'
timeout menu-hidden
#console-mode keep

editor no
EOF
}

# Full bootloader setup
# Arguments:
#   $1 - storage mode
setup_bootloader() {
    local storage_mode="$1"

    sign_systemd_boot_source
    install_bootloader
    configure_loader
    chroot_systemd_enable systemd-boot-update.service
    warn_raid_esp_limitations "$storage_mode"
}
