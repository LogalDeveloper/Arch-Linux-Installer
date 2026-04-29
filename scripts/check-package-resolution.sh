#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

source "${SCRIPT_DIR}/config/defaults.conf"
source "${SCRIPT_DIR}/config/luks.conf"
source "${SCRIPT_DIR}/config/drivers.conf"
source "${SCRIPT_DIR}/config/profiles.conf"

declare -A seen=()
unique_packages=()
package_array_count=0

add_packages() {
    local package

    package_array_count=$((package_array_count + 1))

    for package in "$@"; do
        if [[ -n "$package" && -z "${seen[$package]:-}" ]]; then
            seen["$package"]=1
            unique_packages+=("$package")
        fi
    done
}

add_packages "${BASE_PACKAGES[@]}"
add_packages "${INTEL_MICROCODE_PACKAGES[@]}"
add_packages "${AMD_MICROCODE_PACKAGES[@]}"
add_packages "${WIFI_PACKAGES[@]}"
add_packages "${INTEL_PACKAGES[@]}"
add_packages "${NVIDIA_PACKAGES[@]}"
add_packages "${KDE_PACKAGES[@]}"

for profile_key in "${PROFILES[@]}"; do
    package_var="PROFILE_${profile_key}_PACKAGES[@]"
    add_packages "${!package_var}"
done

if [[ "${#unique_packages[@]}" -eq 0 ]]; then
    printf 'No package definitions were found in the sourced config files\n' >&2
    exit 1
fi

missing_packages=()

for package in "${unique_packages[@]}"; do
    if ! pacman -Si -- "$package" > /dev/null 2>&1; then
        missing_packages+=("$package")
    fi
done

if [[ "${#missing_packages[@]}" -gt 0 ]]; then
    printf 'The following packages were not found by exact name:\n' >&2
    printf '  %s\n' "${missing_packages[@]}" >&2
    exit 1
fi

printf 'Checking dependency resolution for %d packages from %d package arrays\n' "${#unique_packages[@]}" "$package_array_count"
pacman -Sp --noconfirm -- "${unique_packages[@]}" > /dev/null
