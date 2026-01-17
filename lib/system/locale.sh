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

# locale.sh - Locale and timezone configuration
#
# Configures locale (en_US.UTF-8) and runs systemd-firstboot for timezone,
# keymap, and hostname setup.

# Configure system locale (en_US.UTF-8)
configure_locale() {
    print "Setting up locale..."

    chroot_run sed -i '/^#.*en_US.UTF-8 UTF-8/s/^#//' /etc/locale.gen
    run_visible_cmd chroot_run locale-gen
    chroot_run systemd-firstboot --locale=en_US.UTF-8
}

# Run interactive firstboot setup for timezone, keymap, hostname
run_firstboot() {
    print "Entering first time setup..."
    print "Your keymap is probably 'us' and the time zone is probably 'America/New_York'."

    run_visible_cmd chroot_run systemd-firstboot --prompt
}

# Full locale and timezone setup
setup_locale() {
    configure_locale
    run_firstboot
}
