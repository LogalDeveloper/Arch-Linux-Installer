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

# drivers.sh - Graphics driver installation
#
# Prompts the user to select and install graphics drivers (Intel, NVIDIA, or skip).
# Driver package arrays are defined in config/drivers.conf.

# Prompt user for graphics driver selection and install
prompt_install_graphics() {
    local selection

    prompt_menu selection "Would you like to install graphics drivers?" "Intel" "NVIDIA" "Skip"

    case "$selection" in
        1)
            print "Installing Intel graphics drivers..."
            chroot_pacman_install "${INTEL_PACKAGES[@]}"
            ;;
        2)
            print "Installing NVIDIA graphics drivers..."
            chroot_pacman_install "${NVIDIA_PACKAGES[@]}"
            ;;
        *) print "Skipping graphics driver installation." ;;
    esac
}
