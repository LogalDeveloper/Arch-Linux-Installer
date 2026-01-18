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

# user.sh - User account management
#
# Creates the primary user account with wheel group membership.

# Prompt for username
# Sets:
#   USERNAME - the entered username
prompt_username() {
    while true; do
        prompt "Please enter the username you'd like to use for your account:" USERNAME

        if validate_username "$USERNAME"; then
            return 0
        fi

        print "Please try again."
    done
}

# Prompt for display name
# Sets:
#   DISPLAY_NAME - the entered display name (empty if skipped)
prompt_display_name() {
    prompt "Please enter your display name, or press Enter to skip (e.g., John Smith):" DISPLAY_NAME
}

# Copy base skeleton files to user home
# Arguments:
#   $1 - username
copy_home_skel() {
    local username="$1"
    local home_dir="${MOUNT_POINT}/home/${username}"

    run_visible_cmd cp -r "${HOME_SKEL_DIR}/." "${home_dir}/"
    run_visible_cmd rm -f "${home_dir}/.gitkeep"
    run_visible_cmd chown -R 1000:1000 "${home_dir}"
}

# Create a user account
# Arguments:
#   $1 - username
#   $2 - display name (optional)
create_user() {
    local username="$1"
    local display_name="${2:-}"

    if [[ -n "$display_name" ]]; then
        run_cmd_in_chroot useradd -m -G wheel -c "$display_name" "$username"
    else
        run_cmd_in_chroot useradd -m -G wheel "$username"
    fi
    copy_home_skel "$username"
}

# Set password for a user
# Arguments:
#   $1 - username
set_user_password() {
    local username="$1"

    print "Please set the password for your new account."
    run_visible_cmd_in_chroot passwd "$username"
}

# Full user setup
# Sets:
#   USERNAME - the created username
#   DISPLAY_NAME - the user's display name
setup_user() {
    prompt_username
    prompt_display_name
    create_user "$USERNAME" "$DISPLAY_NAME"
    set_user_password "$USERNAME"
}
