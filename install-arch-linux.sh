#!/bin/bash

# Copyright 2025 Logan Fick
#
# Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with the License. You may obtain a copy of the License at: https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License.

# Stop the script if any command exits non-zero.
set -e

# A wrapper for "echo" which prepends a prefix so output from the script can be easily differentiated from command output.
print() {
    echo "[LogalDeveloper's Arch Linux Installer] $1"
}

## Arch Linux Installation Guide Step 1.7 - Connect to the internet
# Checks DNS and internet connectivity by making an HTTPS request. If it fails, assume no internet connection.
print "Checking internet connectivity..."
internet_check_url="https://logal.dev/"
if curl -s --head $internet_check_url | grep "200" >/dev/null; then
    print "Internet connection is available!"
else
    print "Internet connection appears not available (HTTP request to "$internet_check_url" failed). Please check network settings and re-run this script."
    exit 1
fi

## Arch Linux Installation Guide Step 1.8 - Update the system clock
# Checks systemd-timesyncd to verify the system time is synchronized.
print "Checking system time synchronization state..."
if timedatectl status | grep -q "System clock synchronized: yes"; then
    print "System time is synchronized!"
else
    print "The system time is not synchronized. Please check systemd-timesyncd and re-run this script."
    exit 1
fi

print "Setting mirrorlist to use private mirror..."
echo "Server = https://mirrors.logal.dev/archlinux/\$repo/os/\$arch" > /etc/pacman.d/mirrorlist

# Provide the tip from the Arch Linux Installation Guide regarding optimal logical sector sizes.
print "Please check the following items before proceding:"
print " - If you intend to use an Advanced Format (e.g. NVMe) drive, verify the optimal sector size is selected. (https://wiki.archlinux.org/title/Advanced_Format)"
print "If you need to go back, press Ctrl+C. Otherwise, press enter to continue."
read

print "Select storage and filesystem configuration:"
print " 1 - ext4 (Single disk)"
print " 2 - BTRFS (Single disk) [Recommended over ext4]"
print " 3 - BTRFS DUP (Single disk with duplicate data and metadata)"
print " 4 - BTRFS RAID1 (Two disks with full redundancy)"
read storage_choice

case $storage_choice in
	"1")
		storage_mode="single"
		filesystem="ext4"
		print "ext4 on single disk selected."
		;;
	"3")
		storage_mode="single"
		filesystem="btrfs-dup"
		print "BTRFS dup mode selected. Data and metadata will be duplicated on the same disk."
		;;
	"4")
		storage_mode="raid1"
		filesystem="btrfs"
		print "BTRFS RAID1 mode selected. You will need two disks of similar size."
		;;
	*)
		storage_mode="single"
		filesystem="btrfs"
		print "BTRFS on single disk selected."
		;;
esac

## Arch Linux Installation Guide Step 1.9 - Partition the disks
# Provide the user a listing of the disks and ask them which they'd like to install to.
fdisk -l

if [ "$storage_mode" = "raid1" ]; then
	print "Disk information from 'fdisk -l' is provided above. Please enter the path to the FIRST disk for RAID1 (e.g. /dev/sda)."
	read install_disk
	print "Please confirm your selection by entering the same path again."
	read disk_confirm

	if [ "$install_disk" != "$disk_confirm" ]; then
		print "The same disk was not entered both times. Exiting..."
		exit 1
	fi

	print "Now enter the path to the SECOND disk for RAID1 (e.g. /dev/sdb). This must be a DIFFERENT disk."
	read install_disk_2
	print "Please confirm your selection by entering the same path again."
	read disk_confirm_2

	if [ "$install_disk_2" != "$disk_confirm_2" ]; then
		print "The same disk was not entered both times. Exiting..."
		exit 1
	fi

	if [ "$install_disk" = "$install_disk_2" ]; then
		print "Error: Both disks must be different. You entered the same disk twice. Exiting..."
		exit 1
	fi

	# Final confirmation for RAID1
	print "Last warning: Are you sure you want to install Arch Linux in RAID1 mode to '$install_disk' and '$install_disk_2'? All data on BOTH disks will be wiped. Enter 'I am sure' exactly to confirm, or anything else to cancel."
	read final_confirmation

	if [ "$final_confirmation" != "I am sure" ]; then
		print "Confirmation failed. Exiting..."
		exit 1
	fi
else
	# Single disk mode
	print "Disk information from 'fdisk -l' is provided above. Please enter the path to the disk you would like to install Arch Linux to (e.g. /dev/sda)."
	read install_disk
	print "Please confirm your selection by entering the same path again."
	read disk_confirm

	if [ "$install_disk" != "$disk_confirm" ]; then
		print "The same disk was not entered both times. Exiting..."
		exit 1
	fi

	# Triple check the user wants to continue installing to install disk.
	print "Last warning: Are you sure you want to install Arch Linux to '$install_disk'? All data on this disk will be wiped. Enter 'I am sure' exactly to confirm, or anything else to cancel."
	read final_confirmation

	if [ "$final_confirmation" != "I am sure" ]; then
		print "Confirmation failed. Exiting..."
		exit 1
	fi
fi

# Wipe all previous file systems from the install disk(s).
if [ "$storage_mode" = "raid1" ]; then
	print "Wiping existing partition tables from $install_disk and $install_disk_2..."
	wipefs -a $install_disk
	wipefs -a $install_disk_2
else
	print "Wiping existing partition table from $install_disk..."
	wipefs -a $install_disk
fi

# Partition install disk.
print "Partitioning $install_disk..."
sgdisk --new 1:0:1G $install_disk # New GPT table, make a new partition 1G in size at the start
sgdisk --typecode 1:ef00 $install_disk # Mark it as EFI System Partition
sgdisk --new 2:0:0 $install_disk # Add a second partition taking up the rest of the remaining space.
sgdisk --type-code 2:8309 $install_disk # Mark it as Linux LUKS

# /dev/nvme has an extra charater to identify partition number.
if [[ $install_disk == /dev/nvme* ]]; then
	# Use "p" in the partition paths for NVMe drives.
	partition_prefix="${install_disk}p"
else
	# Use just numbers for other drives.
	partition_prefix="${install_disk}"
fi
efi_partition=${partition_prefix}1
root_partition=${partition_prefix}2

if [ "$storage_mode" = "raid1" ]; then
	print "Partitioning $install_disk_2..."
	sgdisk --new 1:0:1G $install_disk_2
	sgdisk --typecode 1:ef00 $install_disk_2
	sgdisk --new 2:0:0 $install_disk_2
	sgdisk --type-code 2:8309 $install_disk_2

	# Handle NVMe naming for second disk
	if [[ $install_disk_2 == /dev/nvme* ]]; then
		partition_prefix_2="${install_disk_2}p"
	else
		partition_prefix_2="${install_disk_2}"
	fi
	efi_partition_2=${partition_prefix_2}1
	root_partition_2=${partition_prefix_2}2
fi

## Arch Linux Installation Guide Step 1.10 - Format the partitions
print "Formatting ${efi_partition} as FAT32..."
mkfs.fat -F 32 ${efi_partition}

if [ "$storage_mode" = "raid1" ]; then
	print "Formatting ${efi_partition_2} as FAT32..."
	mkfs.fat -F 32 ${efi_partition_2}
fi

print "Setting up disk encryption..."
if [ "$storage_mode" = "raid1" ]; then
	print "Please enter your desired encryption passphrase. This will be used for both disks."
else
	print "Please enter your desired encryption passphrase."
fi
read -s encryption_password
echo
print "Please confirm your encryption passphrase."
read -s encryption_password_confirm
echo

if [ "$encryption_password" != "$encryption_password_confirm" ]; then
	print "Passphrases do not match. Exiting..."
	exit 1
fi

print "Setting up encryption on ${root_partition}..."
echo -n "$encryption_password" | cryptsetup luksFormat --type luks2 --cipher aes-xts-plain64 --hash sha512 --key-size 512 --pbkdf argon2id --pbkdf-force-iterations 8 --pbkdf-memory 4194304 --pbkdf-parallel 4 --use-urandom --key-file - ${root_partition}

print "Unlocking ${root_partition}..."
if [ "$storage_mode" = "raid1" ]; then
	echo -n "$encryption_password" | cryptsetup open --allow-discards --key-file - ${root_partition} cryptroot-primary
else
	echo -n "$encryption_password" | cryptsetup open --allow-discards --key-file - ${root_partition} cryptroot
fi
luks_uuid=$(cryptsetup luksDump ${root_partition} | grep 'UUID:' | awk '{print $2}')

if [ "$storage_mode" = "raid1" ]; then
	print "Setting up encryption on ${root_partition_2}..."
	echo -n "$encryption_password" | cryptsetup luksFormat --type luks2 --cipher aes-xts-plain64 --hash sha512 --key-size 512 --pbkdf argon2id --pbkdf-force-iterations 8 --pbkdf-memory 4194304 --pbkdf-parallel 4 --use-urandom --key-file - ${root_partition_2}

	print "Unlocking ${root_partition_2}..."
	echo -n "$encryption_password" | cryptsetup open --allow-discards --key-file - ${root_partition_2} cryptroot-secondary
	luks_uuid_2=$(cryptsetup luksDump ${root_partition_2} | grep 'UUID:' | awk '{print $2}')
fi

# Clear the password from memory
unset encryption_password
unset encryption_password_confirm

case $filesystem in
	"ext4")
		if [ "$storage_mode" = "raid1" ]; then
			print "Error: ext4 cannot be used with RAID1. Exiting..."
			exit 1
		fi
		print "Formatting /dev/mapper/cryptroot as ext4..."
		mkfs.ext4 /dev/mapper/cryptroot
		;;

	"btrfs-dup")
		print "Formatting /dev/mapper/cryptroot as btrfs with dup profile..."
		mkfs.btrfs --csum xxhash --data dup --metadata dup /dev/mapper/cryptroot
		;;

	*)
		if [ "$storage_mode" = "raid1" ]; then
			print "Formatting /dev/mapper/cryptroot-primary and /dev/mapper/cryptroot-secondary as btrfs RAID1..."
			mkfs.btrfs --csum xxhash --data raid1 --metadata raid1 /dev/mapper/cryptroot-primary /dev/mapper/cryptroot-secondary
		else
			print "Formatting /dev/mapper/cryptroot as btrfs..."
			mkfs.btrfs --csum xxhash /dev/mapper/cryptroot
		fi
		;;
esac

## Arch Linux Installation Guide Step 1.11 - Mount the file systems
print "Mounting partitions..."

case $filesystem in
	"ext4")
		mount -o "noatime,discard" /dev/mapper/cryptroot /mnt
		;;

	*)
		if [ "$storage_mode" = "raid1" ]; then
			mount -o "noatime,discard=async" /dev/mapper/cryptroot-primary /mnt
		else
			mount -o "noatime,discard=async" /dev/mapper/cryptroot /mnt
		fi
		;;
esac

mount --mkdir -o "fmask=0077,dmask=0077" ${efi_partition} /mnt/boot

## Arch Linux Installation Guide Step 2.2 - Install essential packages
print "Installing Arch Linux base..."
pacstrap -K /mnt	base \
			linux \
			linux-firmware \
			bash-completion \
			btrfs-progs \
			smartmontools \
			lm_sensors \
			man-db \
			btop \
			htop \
			nano \
			less \
			tmux \
			rsync \
			sudo \
			iptables-nft \
			openssh \
			usbguard

print "Installing CPU microcode..."
cpu_vendor=$(grep -m 1 'vendor_id' /proc/cpuinfo | awk '{print $3}')
if [[ "${cpu_vendor}" == "GenuineIntel" ]]; then
   arch-chroot /mnt pacman --noconfirm -S intel-ucode
elif [[ "${cpu_vendor}" == "AuthenticAMD" ]]; then
    arch-chroot /mnt pacman --noconfirm -S amd-ucode 
else
    echo "Unknown CPU vendor: ${cpu_vendor}. Please install microcode manually after installation, if available."
fi

## Arch Linux Installation Guide Step 3.1 - Fstab
print "Generating /etc/fstab..."
genfstab -U /mnt >> /mnt/etc/fstab

## Arch Linux Installation Guide Step 3.4 - Localization
print "Setting up locale..."
arch-chroot /mnt sed -i '/^#.*en_US.UTF-8 UTF-8/s/^#//' /etc/locale.gen
arch-chroot /mnt locale-gen
arch-chroot /mnt systemd-firstboot --locale=en_US.UTF-8

## Arch Linux Installation Guide Step 3.3 - Time
## Arch Linux Installation Guide Step 3.4 - Localization
## Arch Linux Installation Guide Step 3.5 - Network configuration
print "Entering first time setup..."
print "Your keymap is probably 'us' and the time zone is probably 'America/New_York'."
arch-chroot /mnt systemd-firstboot --prompt

## Arch Linux Installation Guide Step 3.6 - Initramfs
default_mkinitcpio_line="HOOKS=(base systemd autodetect microcode modconf kms keyboard keymap sd-vconsole block filesystems fsck)"
new_mkinitcpio_line="HOOKS=(systemd autodetect microcode modconf kms keyboard sd-vconsole block sd-encrypt filesystems fsck)"
arch-chroot /mnt sed -i "s|^${default_mkinitcpio_line}|${new_mkinitcpio_line}|" /etc/mkinitcpio.conf
arch-chroot /mnt mkinitcpio -P

## Arch Linux Installation Guide Step 3.8 - Boot loader
print "Installing bootloader..."
arch-chroot /mnt bootctl install

if [ "$storage_mode" = "raid1" ]; then
	# RAID1 mode: Must unlock both LUKS devices at boot
	arch-chroot /mnt sh -c "cat > /boot/loader/entries/arch.conf" <<EOF
title   Arch Linux
linux   /vmlinuz-linux
initrd  /initramfs-linux.img
options rd.luks.name=${luks_uuid}=cryptroot-primary rd.luks.name=${luks_uuid_2}=cryptroot-secondary rd.luks.options=${luks_uuid}=discard rd.luks.options=${luks_uuid_2}=discard root=/dev/mapper/cryptroot-primary
EOF
else
	# Single disk mode (original)
	arch-chroot /mnt sh -c "cat > /boot/loader/entries/arch.conf" <<EOF
title   Arch Linux
linux   /vmlinuz-linux
initrd  /initramfs-linux.img
options rd.luks.name=${luks_uuid}=cryptroot rd.luks.options=discard root=/dev/mapper/cryptroot
EOF
fi

arch-chroot /mnt sed -i '/^#timeout 3/s/^#//' /boot/loader/loader.conf

print "Enabling fstrim timer..."
arch-chroot /mnt systemctl enable fstrim.timer

if [ "$filesystem" = "btrfs" ] || [ "$filesystem" = "btrfs-dup" ]; then
	print "Enabling scrub timer..."
	arch-chroot /mnt systemctl enable btrfs-scrub@-.timer
fi

print "Enabling sudo access for wheel group..."
arch-chroot /mnt sed -i "s|^# %wheel ALL=(ALL:ALL) ALL|%wheel ALL=(ALL:ALL) ALL|" /etc/sudoers

print "Disabling root account..."
arch-chroot /mnt passwd -l root

print "Please enter the username you'd like to use for your account"
read username
arch-chroot /mnt useradd -m -G wheel $username
print "Please set the password for your new account."
arch-chroot /mnt passwd $username

print "Installing default configuration files..."
cp -r ./etc /mnt

print "Enabling systemd-resolved..."
arch-chroot /mnt systemctl enable systemd-resolved.service
ln -sf ../run/systemd/resolve/stub-resolv.conf /mnt/etc/resolv.conf

print "Enabling systemd-networkd..."
arch-chroot /mnt systemctl enable systemd-networkd.service

print "Enabling systemd-timesyncd..."
arch-chroot /mnt systemctl enable systemd-timesyncd.service

print "Enabling nftables firewall..."
arch-chroot /mnt systemctl enable nftables.service

print "Enabling smartd..."
arch-chroot /mnt systemctl enable smartd.service

print "Would you like to install iwd for Wi-Fi support? Enter 'y' exactly for yes, otherwise anything else to skip."
read install_iwd

if [ "$install_iwd" == "y" ]; then
	print "Installing iwd..."
	arch-chroot /mnt pacman --noconfirm -S iwd
	arch-chroot /mnt systemctl enable iwd.service
fi

print "Setting up and enabling OpenSSH server..."
arch-chroot /mnt sed -i "s|PLACEHOLDER|${username}|" /etc/ssh/sshd_config
arch-chroot /mnt ssh-keygen -t ed25519 -C "" -N "" -f /etc/ssh/ssh_host_ed25519_key
arch-chroot /mnt systemctl enable sshd.service

print "Adding LogalNet Internal Certification Authority to system CA store..."
cp ./logalnet-internal-ca.crt /mnt
arch-chroot /mnt trust anchor --store /logalnet-internal-ca.crt
arch-chroot /mnt rm /logalnet-internal-ca.crt

install_base_xfce() {
	arch-chroot /mnt pacman --noconfirm -S	lightdm \
						lightdm-gtk-greeter \
						lightdm-gtk-greeter-settings \
						thunar \
						thunar-archive-plugin \
						gvfs \
						xfce4-panel \
						xfce4-power-manager \
						xfce4-session \
						xfce4-settings \
						xfce4-terminal \
						xfdesktop \
						xfwm4 \
						papirus-icon-theme \
						xfce4-battery-plugin \
						xfce4-notifyd \
						xfce4-whiskermenu-plugin \
						xfce4-screensaver \
						xfce4-screenshooter \
						mousepad \
						noto-fonts \
						noto-fonts-cjk \
						noto-fonts-emoji \
						noto-fonts-extra \
						pipewire \
						pipewire-alsa \
						pipewire-pulse \
						pipewire-jack \
						wireplumber \
						pavucontrol \
						xfce4-pulseaudio-plugin \
						ristretto \
						webp-pixbuf-loader \
						libopenraw \
						xarchiver \
						7zip \
						xreader
    arch-chroot /mnt systemctl enable lightdm.service

    cp -r ./default-home-directory-config /mnt/home/$username/.config

arch-chroot /mnt sh -c "cat > /etc/lightdm/lightdm-gtk-greeter.conf" <<EOF
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

    mkdir -p /mnt/home/$username/.config/systemd/user
    ln -s /dev/null /mnt/home/$username/.config/systemd/user/tumblerd.service

    chown -R 1000:1000 /mnt/home/$username/.config

    print "Would you like to install graphics drivers? Type 'intel' exactly for Intel graphics drivers, 'nvidia' for NVIDIA graphics drivers, or anything else to skip"
    read driver

    case $driver in
        "intel")
            arch-chroot /mnt pacman --noconfirm -S 	mesa \
							vulkan-intel \
							intel-media-driver \
							libva-intel-driver
            ;;
        "nvidia")
            arch-chroot /mnt pacman --noconfirm -S	mesa \
							nvidia-open \
							libva-nvidia-driver
            ;;
        *)
            print "Skipping graphics driver installation."
    esac
}

print "Base install complete. Select profile to install for this system:"
print " 1 - Minimal"
print "         Base Arch Linux system, no additional packages."
print " 2 - Server"
print "         Adds Restic, Docker, and Docker Compose."
print " 3 - Minimal Desktop"
print "         XFCE 4 with no additional applications."
print " 4 - Home Theater PC"
print "         XFCE 4 with Chromium and VLC media player."
print " 5 - Home Theater PC with Gaming"
print "         XFCE 4 with Chromium, VLC media player, and Dolphin."
print " 6 - Office Workstation"
print "         XFCE 4 with a full suite of desktop applications aimed at general office work."
print " 7 - Software Development Workstation"
print "         XFCE 4 with a suite of software development applications."
read profile

case $profile in
	"1")
		# Do nothing...
		;;

	"2")
		arch-chroot /mnt pacman --noconfirm  -S restic \
							docker \
							docker-compose
		arch-chroot /mnt systemctl enable docker.service
		;;

	"3")
		install_base_xfce
		;;

	"4")
		install_base_xfce
		arch-chroot /mnt pacman --noconfirm  -S chromium \
							vlc \
							vlc-plugin-ffmpeg
		;;

        "5")
                install_base_xfce
                arch-chroot /mnt pacman --noconfirm  -S dolphin-emu \
							chromium \
							vlc \
							vlc-plugin-ffmpeg
                ;;

	"6")
		install_base_xfce
		arch-chroot /mnt pacman --noconfirm  -S	ffmpeg \
							chromium \
							gimp \
							git \
							gnucash \
							hunspell-en_us \
							keepassxc \
							libreoffice-fresh \
							qalculate-gtk \
							syncthing \
							tenacity \
							vlc \
							vlc-plugin-ffmpeg
		;;

        "7")
                install_base_xfce
                arch-chroot /mnt pacman --noconfirm  -S code \
							docker \
							docker-compose \
							ffmpeg \
							chromium \
							gimp \
							git \
							go \
							hunspell-en_us \
							intellij-idea-community-edition \
							jdk-openjdk \
							keepassxc \
							libreoffice-fresh \
							pycharm-community-edition \
							python \
							python-virtualenv \
							qalculate-gtk \
							syncthing \
							tenacity \
							vlc \
							vlc-plugin-ffmpeg \
							wireshark-qt
                ;;

	*)
		echo -n "Unknown profile, defaulting to minimal install."
		;;
esac

print "Please add or remove any USB devices, including the installer drive, to form the standard configuration for this system. USBGuard will be configured to only allow the USB devices connected at the time you press enter to be used; everything else will be blocked."
print "When ready to proceed, press enter."
read
arch-chroot /mnt sh -c "usbguard generate-policy > /etc/usbguard/rules.conf"
arch-chroot /mnt systemctl enable usbguard.service

echo "\n\n\n\n\n"
print "Installation complete!"

print "Public SSH key fingerprint of this host:"
arch-chroot /mnt ssh-keygen -lvf /etc/ssh/ssh_host_ed25519_key.pub
