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
# Provides functions to list, select, and install profiles.
# Profile definitions are loaded from config/profiles.conf.
# Adding a new profile requires only adding entries to the config file.

# Get profile key by menu number (1-based)
# Arguments:
#   $1 - menu selection number
# Outputs:
#   Profile key to stdout
get_profile_key() {
    local index=$(($1 - 1))
    echo "${PROFILES[$index]}"
}

# Display available profiles (auto-generated from PROFILES array)
list_profiles() {
    print "Base install complete. Select profile to install for this system:"

    local i=1
    for profile in "${PROFILES[@]}"; do
        local name_var="PROFILE_${profile}_NAME"
        local desc_var="PROFILE_${profile}_DESC"
        print " $i - ${!name_var}"
        print "         ${!desc_var}"
        ((i++))
    done
}

# Get packages for a profile
# Arguments:
#   $1 - profile key
# Outputs:
#   Package list to stdout
get_profile_packages() {
    local profile_key="$1"
    local pkg_var="PROFILE_${profile_key}_PACKAGES[@]"
    echo "${!pkg_var}"
}

# Get services for a profile
# Arguments:
#   $1 - profile key
# Outputs:
#   Service list to stdout
get_profile_services() {
    local profile_key="$1"
    local svc_var="PROFILE_${profile_key}_SERVICES[@]"
    echo "${!svc_var}"
}

# Check if profile requires KDE
# Arguments:
#   $1 - profile key
# Returns:
#   0 if requires KDE, 1 otherwise
profile_requires_kde() {
    local profile_key="$1"
    local kde_var="PROFILE_${profile_key}_KDE"
    [ "${!kde_var}" = "true" ]
}

# Validate profile selection
# Arguments:
#   $1 - user selection
# Returns:
#   0 if valid, 1 otherwise
validate_profile_selection() {
    local selection="$1"
    local max="${#PROFILES[@]}"
    [[ "$selection" =~ ^[1-9][0-9]*$ ]] && [ "$selection" -le "$max" ]
}

# Install a profile
# Arguments:
#   $1 - profile key
#   $2 - username
install_profile() {
    local profile_key="$1"
    local username="$2"
    local packages
    local services

    # Install KDE if required
    if profile_requires_kde "$profile_key"; then
        install_kde "$username"
        prompt_install_graphics
    fi

    # Get and install profile packages
    packages=$(get_profile_packages "$profile_key")
    if [ -n "$packages" ]; then
        # shellcheck disable=SC2086
        chroot_pacman_install $packages
    fi

    # Enable profile services
    services=$(get_profile_services "$profile_key")
    for service in $services; do
        chroot_systemd_enable "$service"
    done
}

# Prompt user for profile selection and install
# Arguments:
#   $1 - username
select_and_install_profile() {
    local username="$1"
    local selection
    local profile_key

    list_profiles
    read -r selection

    # Validate selection
    if ! validate_profile_selection "$selection"; then
        print_warning "Unknown profile, defaulting to minimal install."
        selection="1"
    fi

    profile_key=$(get_profile_key "$selection")
    install_profile "$profile_key" "$username"
}
