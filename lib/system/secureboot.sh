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

# secureboot.sh - UKI and Secure Boot signing configuration
#
# Builds a UKI-only boot path:
# - Creates file-backed sbctl keys in the target system
# - Configures mkinitcpio/ukify to emit a UKI
# - Signs and tracks the UKI with sbctl
# - Signs other EFI binaries that systemd-boot/fwupd need
# - Leaves firmware key enrollment to the user

readonly UKI_OUTPUT_PATH="/boot/EFI/Linux/arch-linux.efi"
readonly CMDLINE_DIR="/etc/cmdline.d"
readonly SECURITY_CMDLINE="lockdown=confidentiality intel_iommu=on amd_iommu=on iommu=force iommu.passthrough=0"

# Create sbctl keys in the target system if they do not already exist.
create_secure_boot_keys() {
    print "Creating Secure Boot signing keys..."

    run_visible_cmd_in_chroot sbctl create-keys
    run_cmd_in_chroot test -r /var/lib/sbctl/keys/db/db.key
    run_cmd_in_chroot test -r /var/lib/sbctl/keys/db/db.pem
}

# Return the storage-specific root command line for the UKI.
# Arguments:
#   $1 - storage mode (single, raid1, raid1-3disk)
get_root_cmdline() {
    local storage_mode="$1"

    if [ "$storage_mode" = "raid1" ]; then
        printf 'rd.luks.name=%s=cryptroot-1 rd.luks.name=%s=cryptroot-2 rd.luks.options=%s=discard rd.luks.options=%s=discard root=/dev/mapper/cryptroot-1\n' \
            "$LUKS_UUID" "$LUKS_UUID_2" "$LUKS_UUID" "$LUKS_UUID_2"
    elif [ "$storage_mode" = "raid1-3disk" ]; then
        printf 'rd.luks.name=%s=cryptroot-1 rd.luks.name=%s=cryptroot-2 rd.luks.name=%s=cryptroot-3 rd.luks.options=%s=discard rd.luks.options=%s=discard rd.luks.options=%s=discard root=/dev/mapper/cryptroot-1\n' \
            "$LUKS_UUID" "$LUKS_UUID_2" "$LUKS_UUID_3" "$LUKS_UUID" "$LUKS_UUID_2" "$LUKS_UUID_3"
    else
        printf 'rd.luks.name=%s=cryptroot rd.luks.options=discard root=/dev/mapper/cryptroot\n' "$LUKS_UUID"
    fi
}

# Write UKI command-line drop-ins.
# Arguments:
#   $1 - storage mode (single, raid1, raid1-3disk)
write_cmdline_dropins() {
    local storage_mode="$1"
    local root_cmdline

    root_cmdline="$(get_root_cmdline "$storage_mode")"

    print "Writing UKI command line drop-ins..."

    run_cmd_in_chroot install -d -m 0755 "$CMDLINE_DIR"

    run_cmd_in_chroot sh -c "cat > ${CMDLINE_DIR}/10-security.conf" <<EOF
${SECURITY_CMDLINE}
EOF

    run_cmd_in_chroot sh -c "cat > ${CMDLINE_DIR}/90-root.conf" <<EOF
${root_cmdline}
EOF

    run_cmd_in_chroot sh -c "test -s ${CMDLINE_DIR}/10-security.conf"
    run_cmd_in_chroot sh -c "test -s ${CMDLINE_DIR}/90-root.conf"
    run_cmd_in_chroot sh -c "find ${CMDLINE_DIR} -type f -name '*.conf' -size +0c | grep -q ."
}

# Patch the stock linux preset in place for UKI-only output.
write_uki_mkinitcpio_preset() {
    print "Configuring mkinitcpio for UKI-only output..."

    run_cmd_in_chroot test -f /etc/mkinitcpio.d/linux.preset
    run_cmd_in_chroot sed -i \
        -e '/^ALL_cmdline=/d' \
        -e '/^#ALL_cmdline=/d' \
        -e "/^ALL_kver=/a ALL_cmdline=\"${CMDLINE_DIR}\"" \
        -e 's|^default_image=|#default_image=|' \
        -e "s|^#default_uki=.*|default_uki=\"${UKI_OUTPUT_PATH}\"|" \
        -e "s|^default_uki=.*|default_uki=\"${UKI_OUTPUT_PATH}\"|" \
        /etc/mkinitcpio.d/linux.preset

    run_cmd_in_chroot grep -qx "ALL_cmdline=\"${CMDLINE_DIR}\"" /etc/mkinitcpio.d/linux.preset
    run_cmd_in_chroot grep -qx "default_uki=\"${UKI_OUTPUT_PATH}\"" /etc/mkinitcpio.d/linux.preset
    run_cmd_in_chroot sh -c "! grep -q '^default_image=' /etc/mkinitcpio.d/linux.preset"
}

# Create the UKI output directory before mkinitcpio validates the preset path.
prepare_uki_output_directory() {
    run_cmd_in_chroot install -d -m 0755 "$(dirname "$UKI_OUTPUT_PATH")"
}

# Remove standalone initramfs images created by the stock package hook before the
# installer replaces the preset. The unsigned kernel remains as mkinitcpio input.
remove_standalone_initramfs_images() {
    run_cmd_in_chroot rm -f /boot/initramfs-linux.img /boot/initramfs-linux-fallback.img
}

# Configure all files required before mkinitcpio -P creates the signed UKI.
# Arguments:
#   $1 - storage mode (single, raid1, raid1-3disk)
prepare_uki_secure_boot() {
    local storage_mode="$1"

    create_secure_boot_keys
    write_cmdline_dropins "$storage_mode"
    prepare_uki_output_directory
    write_uki_mkinitcpio_preset
}

# Sign and save the generated UKI in the sbctl file database.
sign_uki() {
    print "Signing UKI..."

    run_cmd_in_chroot test -f "$UKI_OUTPUT_PATH"
    run_visible_cmd_in_chroot sbctl sign -s "$UKI_OUTPUT_PATH"
}

# Sign the source systemd-boot binary before bootctl copies it to the ESP.
sign_systemd_boot_source() {
    print "Signing systemd-boot source binary..."

    run_cmd_in_chroot rm -f /usr/lib/systemd/boot/efi/systemd-bootx64.efi.signed
    run_visible_cmd_in_chroot sbctl sign -s \
        -o /usr/lib/systemd/boot/efi/systemd-bootx64.efi.signed \
        /usr/lib/systemd/boot/efi/systemd-bootx64.efi
}

# Configure fwupd for direct Secure Boot signing without shim.
configure_fwupd_secure_boot() {
    print "Configuring fwupd Secure Boot support..."

    run_cmd_in_chroot install -d -m 0755 /var/etc/fwupd
    run_cmd_in_chroot sh -c "cat > /var/etc/fwupd/fwupd.conf" <<'EOF'
[uefi_capsule]
DisableShimForSecureBoot=true
EOF
    run_cmd_in_chroot chmod 0640 /var/etc/fwupd/fwupd.conf

    if [ -f "${MOUNT_POINT}/usr/lib/fwupd/efi/fwupdx64.efi" ]; then
        run_cmd_in_chroot rm -f /usr/lib/fwupd/efi/fwupdx64.efi.signed
        run_visible_cmd_in_chroot sbctl sign -s \
            -o /usr/lib/fwupd/efi/fwupdx64.efi.signed \
            /usr/lib/fwupd/efi/fwupdx64.efi
    else
        print_warning "fwupd EFI helper not found; skipping fwupd EFI signing."
    fi
}

# Verify the specific signed boot artifacts.
verify_signed_artifacts_in_chroot() {
    local artifact_path

    for artifact_path in "$@"; do
        run_cmd_in_chroot sh -c '
verify_output="$(env SYSTEMD_ESP_PATH=/boot sbctl verify "$1")" || {
    printf "%s\n" "$verify_output" >&2
    exit 1
}

printf "%s\n" "$verify_output"

if ! printf "%s\n" "$verify_output" | grep -F -- "$1" | grep -Fq "is signed"; then
    printf "Expected signed Secure Boot artifact was not reported as signed: %s\n" "$1" >&2
    exit 1
fi
' sh "$artifact_path"
    done
}

verify_secure_boot_artifacts() {
    print "Verifying signed UKI and EFI boot artifacts..."

    run_cmd_in_chroot test -f "$UKI_OUTPUT_PATH"
    verify_signed_artifacts_in_chroot \
        "$UKI_OUTPUT_PATH" \
        /usr/lib/systemd/boot/efi/systemd-bootx64.efi.signed \
        /boot/EFI/systemd/systemd-bootx64.efi \
        /boot/EFI/BOOT/BOOTX64.EFI

    if [ -f "${MOUNT_POINT}/usr/lib/fwupd/efi/fwupdx64.efi.signed" ]; then
        verify_signed_artifacts_in_chroot /usr/lib/fwupd/efi/fwupdx64.efi.signed
    fi
}

# Display post-install firmware enrollment instructions.
show_secure_boot_enrollment_instructions() {
    print_warning "Secure Boot keys have not been enrolled in firmware."
    print "To enable Secure Boot after the first boot:"
    print " 1. Put firmware Secure Boot keys into Setup Mode, or otherwise prepare custom key enrollment."
    print " 2. Boot this installation with Secure Boot disabled or in Setup Mode."
    print " 3. Run: sudo sbctl enroll-keys --microsoft"
    print " 4. Enable Secure Boot in firmware."
    print "The installer does not enroll Secure Boot keys automatically."
}

# Warn when RAID installs still only have the primary mounted ESP populated.
# Arguments:
#   $1 - storage mode (single, raid1, raid1-3disk)
warn_raid_esp_limitations() {
    local storage_mode="$1"

    if [ "$storage_mode" = "raid1" ] || [ "$storage_mode" = "raid1-3disk" ]; then
        print_warning "Only the primary mounted ESP has been populated. Redundant Secure Boot bootability across secondary ESPs is not implemented yet."
    fi
}
