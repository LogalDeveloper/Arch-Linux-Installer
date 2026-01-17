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

# Intel graphics packages
INTEL_PACKAGES=(
    mesa
    vulkan-intel
    intel-media-driver
    libva-intel-driver
)

# NVIDIA graphics packages
NVIDIA_PACKAGES=(
    mesa
    nvidia-open
    libva-nvidia-driver
)

# Install Intel graphics drivers
install_intel_graphics() {
    print "Installing Intel graphics drivers..."
    chroot_install "${INTEL_PACKAGES[@]}"
}

# Install NVIDIA graphics drivers
install_nvidia_graphics() {
    print "Installing NVIDIA graphics drivers..."
    chroot_install "${NVIDIA_PACKAGES[@]}"
}

# Prompt user for graphics driver selection and install
prompt_install_graphics() {
    print "Would you like to install graphics drivers? Type 'intel' exactly for Intel graphics drivers, 'nvidia' for NVIDIA graphics drivers, or anything else to skip."
    read -r driver

    case "$driver" in
        "intel")
            install_intel_graphics
            ;;
        "nvidia")
            install_nvidia_graphics
            ;;
        *)
            print "Skipping graphics driver installation."
            ;;
    esac
}
