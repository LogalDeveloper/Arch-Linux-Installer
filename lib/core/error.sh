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

# error.sh - Error handling framework
#
# Implements robust error handling for the installation process:
# - Sets up bash strict mode (set -e) and ERR trap
# - Provides detailed error messages with phase, line number, and failed command
# - Offers automatic cleanup on failure (unmount filesystems, close LUKS)
# - Includes retry helper for transient failures

# Enable strict error handling
set -e

# Set up error trap
trap_errors() {
    trap 'handle_error $? $LINENO "$BASH_COMMAND"' ERR
}

# Error handler function
# Arguments:
#   $1 - exit code
#   $2 - line number
#   $3 - failed command
handle_error() {
    local exit_code=$1
    local line_number=$2
    local command="$3"

    echo ""
    print_error "Installation failed!"
    print_error "Phase: ${CURRENT_PHASE:-unknown}"
    print_error "Exit code: $exit_code at line $line_number"
    print_error "Command: $command"
    echo ""

    # Offer cleanup
    print "Would you like to attempt cleanup? [y/N]: "
    read -r response

    case "$response" in
        [yY][eE][sS]|[yY])
            cleanup_on_error
            ;;
    esac

    exit 1
}

# Cleanup function for error recovery
cleanup_on_error() {
    print_warning "Cleaning up after error..."

    # Unmount filesystems (ignore errors)
    umount -R "${MOUNT_POINT}" 2>/dev/null || true

    # Close LUKS containers (ignore errors)
    cryptsetup close cryptroot 2>/dev/null || true
    cryptsetup close cryptroot-primary 2>/dev/null || true
    cryptsetup close cryptroot-secondary 2>/dev/null || true

    print "Cleanup complete. You may retry the installation."
}

# Set the current installation phase for better error messages
# Arguments:
#   $1 - phase name
set_phase() {
    CURRENT_PHASE="$1"
    print_step "$1"
}

# Run a command with error context
# Arguments:
#   $1 - description
#   $@ - command and arguments
safe_run() {
    local description="$1"
    shift

    print "  $description..."
    if ! "$@"; then
        print_error "Failed: $description"
        return 1
    fi
}

# Retry a command with exponential backoff
# Arguments:
#   $1 - max attempts
#   $2 - initial delay in seconds
#   $@ - command and arguments
retry() {
    local max_attempts="$1"
    local delay="$2"
    shift 2

    local attempt=1
    while [ $attempt -le $max_attempts ]; do
        if "$@"; then
            return 0
        fi
        print_warning "Attempt $attempt/$max_attempts failed. Retrying in ${delay}s..."
        sleep "$delay"
        ((attempt++))
        ((delay *= 2))
    done

    print_error "All $max_attempts attempts failed."
    return 1
}
