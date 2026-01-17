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

# xfce.sh - XFCE desktop environment installation
#
# Installs XFCE4 with LightDM and copies pre-configured user settings.

# XFCE base packages
XFCE_PACKAGES=(
    lightdm
    lightdm-gtk-greeter
    lightdm-gtk-greeter-settings
    thunar
    thunar-archive-plugin
    gvfs
    xfce4-panel
    xfce4-power-manager
    xfce4-session
    xfce4-settings
    xfce4-terminal
    xfdesktop
    xfwm4
    papirus-icon-theme
    xfce4-battery-plugin
    xfce4-notifyd
    xfce4-whiskermenu-plugin
    xfce4-screensaver
    xfce4-screenshooter
    mousepad
    noto-fonts
    noto-fonts-cjk
    noto-fonts-emoji
    noto-fonts-extra
    pipewire
    pipewire-alsa
    pipewire-pulse
    pipewire-jack
    wireplumber
    pavucontrol
    xfce4-pulseaudio-plugin
    ristretto
    webp-pixbuf-loader
    libopenraw
    xarchiver
    7zip
    xreader
)

# Install XFCE base packages
install_xfce_packages() {
    chroot_install "${XFCE_PACKAGES[@]}"
}

# Enable LightDM display manager
enable_lightdm() {
    chroot_enable lightdm.service
}

# Configure LightDM greeter
configure_lightdm() {
    chroot_run sh -c "cat > /etc/lightdm/lightdm-gtk-greeter.conf" <<EOF
[greeter]
hide-user-image = true
font-name = Noto Sans 10
clock-format = %A, %B %d, %Y,%l:%M:%S %p
theme-name = Adwaita-dark
icon-theme-name = Papirus-Dark
screensaver-timeout = 10
user-background = false
background = #77767b
indicators = ~host;~spacer;~clock;~spacer;~power
EOF
}

# Copy default XFCE configuration to user home
# Arguments:
#   $1 - username
copy_xfce_config() {
    local username="$1"
    local home_dir="${MOUNT_POINT}/home/${username}"

    cp -r "${HOME_CONFIG_DIR}" "${home_dir}/.config"

    # Disable tumblerd (thumbnail service)
    mkdir -p "${home_dir}/.config/systemd/user"
    ln -s /dev/null "${home_dir}/.config/systemd/user/tumblerd.service"

    # Set correct ownership (UID 1000 is typically first user)
    chown -R 1000:1000 "${home_dir}/.config"
}

# Full XFCE installation
# Arguments:
#   $1 - username
install_xfce() {
    local username="$1"

    install_xfce_packages
    enable_lightdm
    configure_lightdm
    copy_xfce_config "$username"
}
