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

# packages.sh - Shared package group definitions
#
# Defines reusable package arrays used by installation profiles.

# Media packages (browser, video player)
PACKAGES_MEDIA=(
    chromium
    vlc
    vlc-plugin-ffmpeg
)

# Office productivity packages
PACKAGES_OFFICE=(
    hunspell-en_us
    libreoffice-fresh
    keepassxc
    qalculate-gtk
)

# General productivity packages
PACKAGES_PRODUCTIVITY=(
    ffmpeg
    gimp
    syncthing
    tenacity
)

# Development base packages
PACKAGES_DEV_BASE=(
    git
    docker
    docker-compose
)

# Python development packages
PACKAGES_DEV_PYTHON=(
    python
    python-virtualenv
    pycharm-community-edition
)

# Java development packages
PACKAGES_DEV_JAVA=(
    jdk-openjdk
    intellij-idea-community-edition
)

# Go development packages
PACKAGES_DEV_GO=(
    go
)

# Additional development tools
PACKAGES_DEV_TOOLS=(
    code
    wireshark-qt
)
