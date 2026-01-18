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

# kde.sh - KDE Plasma desktop environment installation
#
# Installs KDE Plasma with SDDM display manager.
# KDE_PACKAGES is defined in config/profiles.conf.

# Install KDE base packages
install_kde_packages() {
    chroot_pacman_install "${KDE_PACKAGES[@]}"
}

# Copy desktop skeleton files to user home
# Arguments:
#   $1 - username
copy_desktop_skel() {
    local username="$1"
    local home_dir="${MOUNT_POINT}/home/${username}"

    run_visible_cmd cp -r "${HOME_SKEL_DESKTOP_DIR}/." "${home_dir}/"
    run_visible_cmd rm -f "${home_dir}/.gitkeep"
    run_visible_cmd chown -R 1000:1000 "${home_dir}"
}

# Full KDE installation
# Arguments:
#   $1 - username
install_kde() {
    local username="$1"

    install_kde_packages
    chroot_systemd_enable sddm.service
    copy_desktop_skel "$username"
}
