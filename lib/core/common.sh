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

# common.sh - Core utility functions for messaging and user interaction
#
# Provides colored output, user prompts, and progress tracking used throughout
# the installer.

# Color codes for terminal output
readonly COLOR_RED='\033[0;31m'
readonly COLOR_GREEN='\033[0;32m'
readonly COLOR_YELLOW='\033[0;33m'
readonly COLOR_BLUE='\033[0;34m'
readonly COLOR_CYAN='\033[0;36m'
readonly COLOR_BG_GRAY='\033[48;5;236m'
readonly COLOR_RESET='\033[0m'

# Step counter for progress indicator
CURRENT_STEP=0
TOTAL_STEPS=10

# Print the installer banner (call once at start)
print_banner() {
    echo ""
    echo -e "${COLOR_BLUE}:: ${INSTALLER_NAME} ::${COLOR_RESET}"
    echo ""
}

# Print a standard message with arrow prefix
print() {
    echo -e "${COLOR_BLUE}→${COLOR_RESET} $1"
}

# Print an informational message
print_info() {
    echo -e "${COLOR_CYAN}ℹ${COLOR_RESET} $1"
}

# Run a command with gray background for its output
# Use this for commands that produce visible output (fdisk, pacstrap, pacman, etc.)
# Logs the command before execution for auditing
run_visible_cmd() {
    log_cmd "$@"
    echo -ne "${COLOR_BG_GRAY}"
    "$@"
    local exit_code=$?
    echo -e "${COLOR_RESET}"
    return $exit_code
}

# Run a command with piped input and gray background for its output
# Logs the command (without the piped input) before execution
# Arguments:
#   $1 - input to pipe to the command
#   $@ - command and arguments
run_piped_cmd() {
    local input="$1"
    shift
    log_cmd "$@"
    echo -ne "${COLOR_BG_GRAY}"
    echo -n "$input" | "$@"
    local exit_code=$?
    echo -e "${COLOR_RESET}"
    return $exit_code
}

# Run a command with logging only (no visual wrapper)
# Use for commands that need stdout preserved (pipes, redirections)
run_cmd() {
    log_cmd "$@"
    "$@"
}

# Run a command that is allowed to fail
# Logs the command, suppresses stderr, and always returns success
# Use for cleanup commands where failure is acceptable
run_cmd_allow_fail() {
    log_cmd "$@"
    "$@" 2>/dev/null || true
}

# Run a command in the chroot environment with logging
# Use for commands that don't produce visible output
run_cmd_in_chroot() {
    log_cmd arch-chroot "${MOUNT_POINT}" "$@"
    arch-chroot "${MOUNT_POINT}" "$@"
}

# Run a command in the chroot environment with gray background
# Use for commands that produce visible output (pacman, mkinitcpio, etc.)
run_visible_cmd_in_chroot() {
    log_cmd arch-chroot "${MOUNT_POINT}" "$@"
    echo -ne "${COLOR_BG_GRAY}"
    arch-chroot "${MOUNT_POINT}" "$@"
    local exit_code=$?
    echo -e "${COLOR_RESET}"
    return $exit_code
}

# Print an installation step/phase header with progress indicator
print_step() {
    local step="$1"
    CURRENT_STEP=$((CURRENT_STEP + 1))
    echo ""
    echo -e "${COLOR_BLUE}=== [${CURRENT_STEP}/${TOTAL_STEPS}] ${step} ===${COLOR_RESET}"
}

# Print a success message
print_success() {
    echo -e "${COLOR_GREEN}[OK]${COLOR_RESET} $1"
}

# Print a warning message
print_warning() {
    echo -e "${COLOR_YELLOW}[WARNING]${COLOR_RESET} $1"
}

# Print an error message
print_error() {
    echo -e "${COLOR_RED}[ERROR]${COLOR_RESET} $1" >&2
}

# Ask for yes/no confirmation
# Arguments:
#   $1 - prompt message
# Returns:
#   0 if user confirms, 1 otherwise
confirm() {
    local prompt="$1"
    local response

    print "${prompt} [y/N]: "
    read -r response

    case "$response" in
        [yY][eE][sS]|[yY])
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

# Require "I am sure" confirmation for destructive operations
# Arguments:
#   $1 - warning message
# Returns:
#   0 if user confirms, 1 otherwise
require_confirmation() {
    local warning="$1"
    local response

    print "${warning}"
    print "Enter 'I am sure' exactly to confirm, or anything else to cancel."
    read -r response

    if [ "$response" = "I am sure" ]; then
        return 0
    else
        print "Confirmation failed. Exiting..."
        return 1
    fi
}

# Prompt for user input
# Arguments:
#   $1 - prompt message
#   $2 - variable name to store result
prompt() {
    local prompt_msg="$1"
    local var_name="$2"
    local response

    print "$prompt_msg"
    read -r response
    eval "$var_name='${response//\'/\'\\\'\'}'"
}

# Prompt for secret input (no echo)
# Arguments:
#   $1 - prompt message
#   $2 - variable name to store result
prompt_secret() {
    local prompt_msg="$1"
    local var_name="$2"
    local response

    print "$prompt_msg"
    read -rs response
    echo
    eval "$var_name='${response//\'/\'\\\'\'}'"
}

# Prompt for password with confirmation
# Arguments:
#   $1 - prompt message
#   $2 - variable name to store result
# Returns:
#   0 on success, 1 if passwords don't match
prompt_password() {
    local prompt_msg="$1"
    local var_name="$2"
    local password
    local password_confirm

    print "$prompt_msg"
    read -rs password
    echo

    print "Please confirm your password."
    read -rs password_confirm
    echo

    if [ "$password" != "$password_confirm" ]; then
        print_error "Passwords do not match."
        return 1
    fi

    eval "$var_name='${password//\'/\'\\\'\'}'"
    unset password password_confirm
    return 0
}

# Display a menu and get user selection
# Arguments:
#   $1 - menu title
#   $@ - menu options (remaining arguments)
# Arguments:
#   $1 - variable name to store the selected option number
#   $2 - menu title
# Returns:
#   Selected option number in the provided variable
prompt_menu() {
    local var_name="$1"
    local title="$2"
    local selection
    shift 2
    local options=("$@")
    local i=1

    print "$title"
    for option in "${options[@]}"; do
        print " $i - $option"
        ((i++))
    done

    read -r selection
    printf -v "$var_name" '%s' "$selection"
}

# Wait for user to press enter
wait_for_enter() {
    local message="${1:-Press enter to continue.}"
    print "$message"
    read -r
}

# Get the directory containing the main script
get_script_dir() {
    echo "$SCRIPT_DIR"
}
