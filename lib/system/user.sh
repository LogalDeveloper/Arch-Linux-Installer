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

# Create a user account
# Arguments:
#   $1 - username
create_user() {
    local username="$1"

    chroot_run useradd -m -G wheel "$username"
}

# Set password for a user
# Arguments:
#   $1 - username
set_user_password() {
    local username="$1"

    print "Please set the password for your new account."
    chroot_run passwd "$username"
}

# Full user setup
# Sets:
#   USERNAME - the created username
setup_user() {
    prompt_username
    create_user "$USERNAME"
    set_user_password "$USERNAME"
}
