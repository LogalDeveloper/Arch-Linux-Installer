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

# logging.sh - Installation logging
#
# Captures the complete installation session for troubleshooting:
# - Redirects all stdout/stderr to both console and log file
# - Records timestamps at start and end of installation
# - Includes git commit hash for version tracking
# - Copies final log to /var/log/arch-install.log on installed system

# Temp location during installation (installed system's /var/log doesn't exist yet)
LOG_FILE_TEMP="/tmp/arch-install.log"
# Final location on the installed system
LOG_FILE="/var/log/arch-install.log"
GITEA_URL="https://git.logal.dev/LogalDeveloper/Arch-Linux-Installer"

# Print installer URL with commit if available
print_installer_url() {
    if command -v git &>/dev/null && git -C "$SCRIPT_DIR" rev-parse --git-dir &>/dev/null 2>&1; then
        local commit
        commit=$(git -C "$SCRIPT_DIR" rev-parse HEAD)
        echo "=== Installer: ${GITEA_URL}/commit/${commit} ==="
    else
        echo "=== Installer: ${GITEA_URL} ==="
    fi
}

# Initialize logging - tee all output to log file
init_logging() {
    # Create log file with secure permissions
    touch "$LOG_FILE_TEMP"
    chown root:root "$LOG_FILE_TEMP"
    chmod 640 "$LOG_FILE_TEMP"

    # Redirect stdout and stderr to both console and log
    exec > >(tee -a "$LOG_FILE_TEMP") 2>&1

    # Write log header
    echo "=== Installation started at $(date) ==="
    print_installer_url
    echo ""
}

# Copy log file to installed system
finalize_logging() {
    local final_log="${MOUNT_POINT}${LOG_FILE}"

    # Write log footer
    echo ""
    echo "=== Installation finished at $(date) ==="
    print_installer_url
    echo "=== Log saved to: ${LOG_FILE} ==="

    cp "$LOG_FILE_TEMP" "$final_log"
    chown root:root "$final_log"
    chmod 640 "$final_log"
}
