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

# registry.sh - Profile registry and management
#
# Defines installation profiles that customize the system for different use cases.
# Each profile specifies which packages to install and services to enable.

# Source shared package definitions
source "${SCRIPT_DIR}/profiles/packages.sh"

# Profile definitions
declare -A PROFILE_NAMES=(
    [1]="Minimal"
    [2]="Server"
    [3]="Minimal Desktop"
    [4]="Home Theater PC"
    [5]="Home Theater PC with Gaming"
    [6]="Office Workstation"
    [7]="Software Development Workstation"
)

declare -A PROFILE_DESCRIPTIONS=(
    [1]="Base Arch Linux system, no additional packages."
    [2]="Adds Restic, Docker, and Docker Compose."
    [3]="XFCE 4 with no additional applications."
    [4]="XFCE 4 with Chromium and VLC media player."
    [5]="XFCE 4 with Chromium, VLC media player, and Dolphin."
    [6]="XFCE 4 with a full suite of desktop applications aimed at general office work."
    [7]="XFCE 4 with a suite of software development applications."
)

declare -A PROFILE_REQUIRES_XFCE=(
    [1]=false
    [2]=false
    [3]=true
    [4]=true
    [5]=true
    [6]=true
    [7]=true
)

# Display available profiles
list_profiles() {
    print "Base install complete. Select profile to install for this system:"

    for i in {1..7}; do
        print " $i - ${PROFILE_NAMES[$i]}"
        print "         ${PROFILE_DESCRIPTIONS[$i]}"
    done
}

# Get packages for a profile
# Arguments:
#   $1 - profile number
# Outputs:
#   Package list to stdout
get_profile_packages() {
    local profile="$1"

    case "$profile" in
        "1")
            # Minimal - no additional packages
            ;;
        "2")
            # Server
            echo "restic docker docker-compose"
            ;;
        "3")
            # Minimal Desktop - XFCE only, no additional packages
            ;;
        "4")
            # Home Theater PC
            echo "${PACKAGES_MEDIA[*]}"
            ;;
        "5")
            # Home Theater PC with Gaming
            echo "dolphin-emu ${PACKAGES_MEDIA[*]}"
            ;;
        "6")
            # Office Workstation
            echo "${PACKAGES_MEDIA[*]} ${PACKAGES_OFFICE[*]} ${PACKAGES_PRODUCTIVITY[*]} git gnucash"
            ;;
        "7")
            # Software Development Workstation
            echo "${PACKAGES_MEDIA[*]} ${PACKAGES_OFFICE[*]} ${PACKAGES_PRODUCTIVITY[*]}"
            echo "${PACKAGES_DEV_BASE[*]} ${PACKAGES_DEV_PYTHON[*]} ${PACKAGES_DEV_JAVA[*]}"
            echo "${PACKAGES_DEV_GO[*]} ${PACKAGES_DEV_TOOLS[*]}"
            ;;
    esac
}

# Get services to enable for a profile
# Arguments:
#   $1 - profile number
# Outputs:
#   Service list to stdout
get_profile_services() {
    local profile="$1"

    case "$profile" in
        "2"|"7")
            echo "docker.service"
            ;;
    esac
}

# Check if profile requires XFCE
# Arguments:
#   $1 - profile number
# Returns:
#   0 if requires XFCE, 1 otherwise
profile_requires_xfce() {
    local profile="$1"

    if [ "${PROFILE_REQUIRES_XFCE[$profile]}" = "true" ]; then
        return 0
    else
        return 1
    fi
}

# Install a profile
# Arguments:
#   $1 - profile number
#   $2 - username
install_profile() {
    local profile="$1"
    local username="$2"
    local packages
    local services

    # Install XFCE if required
    if profile_requires_xfce "$profile"; then
        install_xfce "$username"
        prompt_install_graphics
    fi

    # Get and install profile packages
    packages=$(get_profile_packages "$profile")
    if [ -n "$packages" ]; then
        # shellcheck disable=SC2086
        chroot_pacman_install $packages
    fi

    # Enable profile services
    services=$(get_profile_services "$profile")
    if [ -n "$services" ]; then
        # shellcheck disable=SC2086
        chroot_systemd_enable $services
    fi
}

# Prompt user for profile selection and install
# Arguments:
#   $1 - username
select_and_install_profile() {
    local username="$1"
    local profile

    list_profiles
    read -r profile

    # Validate selection
    if ! [[ "$profile" =~ ^[1-7]$ ]]; then
        print_warning "Unknown profile, defaulting to minimal install."
        profile="1"
    fi

    install_profile "$profile" "$username"
}
