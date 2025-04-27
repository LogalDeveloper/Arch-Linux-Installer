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

## Arch Linux Installation Guide Step 1.9 - Partition the disks
# Provide the user a listing of the disks and ask them which they'd like to install to.
fdisk -l
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

# Wipe all previous file systems from the install disk.
print "Wiping existing partition table from $install_disk..."
wipefs -a $install_disk

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

## Arch Linux Installation Guide Step 1.10 - Format the partitions
print "Formatting ${efi_partition} as FAT32..."
mkfs.fat -F 32 ${efi_partition}

print "Setting up encryption on ${root_partition}..."
print "Please follow the cryptsetup prompts to enter your desired encryption passphrase."
cryptsetup luksFormat --type luks2 --cipher aes-xts-plain64 --hash sha512 --key-size 512 --pbkdf argon2id --pbkdf-force-iterations 8 --pbkdf-memory 4194304 --pbkdf-parallel 4 --use-urandom ${root_partition}

print "Unlocking ${root_partition}..."
print "Please enter the passphrase you just used to unlock the newly encrypted partition."
cryptsetup open ${root_partition} cryptroot
luks_uuid=$(cryptsetup luksDump ${root_partition} | grep 'UUID:' | awk '{print $2}')

print "Formatting /dev/mapper/cryptroot..."
mkfs.btrfs --csum xxhash /dev/mapper/cryptroot

## Arch Linux Installation Guide Step 1.11 - Mount the file systems
print "Mounting partitions..."
mount -o noatime /dev/mapper/cryptroot /mnt
mount --mkdir ${efi_partition} /mnt/boot

## Arch Linux Installation Guide Step 2.2 - Install essential packages
print "Installing Arch Linux base..."
pacstrap -K /mnt	base \
			linux \
			linux-firmware \
			bash-completion \
			btrfs-progs \
			htop \
			nano \
			sudo \
			ufw \
			openssh \
			usbguard

print "Installing CPU microcode..."
cpu_vendor=$(grep -m 1 'vendor_id' /proc/cpuinfo | awk '{print $3}')
if [[ "${cpu_vendor}" == "GenuineIntel" ]]; then
   arch-chroot /mnt pacman --noconfirm -S intel-ucode
elif [[ "{$cpu_vendor}" == "AuthenticAMD" ]]; then
    arch-chroot /mnt pacman --noconfirm -S amd-ucode 
else
    echo "Unknown CPU vendor: {$cpu_vendor}. Please install microcode manually after installation, if available."
fi

## Arch Linux Installation Guide Step 3.1 - Fstab
print "Generating /etc/fstab..."
genfstab -U /mnt >>/mnt/etc/fstab

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
default_mkinitcpio_line="HOOKS=(base udev autodetect microcode modconf kms keyboard keymap consolefont block filesystems fsck)"
new_mkinitcpio_line="HOOKS=(systemd autodetect microcode modconf kms keyboard sd-vconsole block sd-encrypt filesystems fsck)"
arch-chroot /mnt sed -i "s|^${default_mkinitcpio_line}|${new_mkinitcpio_line}|" /etc/mkinitcpio.conf
arch-chroot /mnt mkinitcpio -P

## Arch Linux Installation Guide Step 3.8 - Boot loader
print "Installing bootloader..."
arch-chroot /mnt bootctl install
arch-chroot /mnt sh -c "cat > /boot/loader/entries/arch.conf" <<EOF
title   Arch Linux
linux   /vmlinuz-linux
initrd  /initramfs-linux.img
options rd.luks.name=${luks_uuid}=cryptroot root=/dev/mapper/cryptroot rootfstype=btrfs
EOF
arch-chroot /mnt sh -c "cat > /boot/loader/entries/arch-fallback.conf" <<EOF
title   Arch Linux (fallback)
linux   /vmlinuz-linux
initrd  /initramfs-linux-fallback.img
options rd.luks.name=${luks_uuid}=cryptroot root=/dev/mapper/cryptroot rootfstype=btrfs
EOF

arch-chroot /mnt sed -i '/^#timeout 3/s/^#//' /boot/loader/loader.conf

print "Enabling sudo access for wheel group..."
arch-chroot /mnt sed -i "s|^# %wheel ALL=(ALL:ALL) ALL|%wheel ALL=(ALL:ALL) ALL|" /etc/sudoers

print "Disabling root account..."
arch-chroot /mnt passwd -l root

print "Please enter the username you'd like to use for your account"
read username
arch-chroot /mnt useradd -m -G wheel $username
print "Please set the password for your new account."
arch-chroot /mnt passwd $username

print "Setting up systemd-resolved..."
arch-chroot /mnt sed -i "s|^#MulticastDNS=yes|MulticastDNS=no|" /etc/systemd/resolved.conf
arch-chroot /mnt sed -i "s|^#LLMNR=yes|LLMNR=no|" /etc/systemd/resolved.conf
arch-chroot /mnt systemctl enable systemd-resolved.service
ln -sf ../run/systemd/resolve/stub-resolv.conf /mnt/etc/resolv.conf

print "Setting up systemd-networkd..."
arch-chroot /mnt sh -c "cat > /etc/systemd/network/00-default.network" <<EOF
[Match]
Name=*

[Link]
RequiredForOnline=routable

[Network]
DHCP=yes
IPv6AcceptRA=yes
EOF
arch-chroot /mnt systemctl enable systemd-networkd.service

print "Would you like to install iwd for Wi-Fi support? Enter 'y' exactly for yes, otherwise anything else to skip."
read install_iwd

if [ "$install_iwd" == "y" ]; then
	print "Installing iwd..."
    arch-chroot /mnt pacman --noconfirm -S iwd
	arch-chroot /mnt systemctl enable iwd.service
fi

print "Enabling systemd-timesyncd..."
arch-chroot /mnt systemctl enable systemd-timesyncd.service

print "Setting up and enabling OpenSSH server..."
arch-chroot /mnt sh -c "cat > /etc/ssh/sshd_config" <<EOF
AllowUsers $username
AuthenticationMethods publickey,password
Ciphers aes256-gcm@openssh.com
Compression no
HostKey /etc/ssh/ssh_host_ed25519_key
HostKeyAlgorithms ssh-ed25519
KexAlgorithms mlkem768x25519-sha256
MACs umac-128-etm@openssh.com
PermitRootLogin no
PubkeyAcceptedAlgorithms ssh-ed25519
Subsystem sftp internal-sftp
EOF
arch-chroot /mnt ssh-keygen -t ed25519 -C "" -N "" -f /etc/ssh/ssh_host_ed25519_key
arch-chroot /mnt systemctl enable sshd.service

# https://wiki.archlinux.org/index.php?title=Sysctl#Enable_BBR
print "Setting up BBR congestion control..."
arch-chroot /mnt sh -c "cat > /etc/sysctl.d/10-bbr.conf" <<EOF
net.core.default_qdisc = cake
net.ipv4.tcp_congestion_control = bbr
EOF

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
						xarchiver \
						unzip \
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
print " 4 - Basic Desktop"
print "         XFCE 4 with Firefox as only included desktop application."
print " 5 - Full Desktop"
print "         XFCE 4 with a suite of recommended desktop applications."
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
		arch-chroot /mnt pacman --noconfirm  -S firefox \
							firefox-ublock-origin
		;;

	"5")
		install_base_xfce
		arch-chroot /mnt pacman --noconfirm  -S	audacious \
							audacity \
							element-desktop \
							ffmpeg \
							firefox \
							firefox-ublock-origin \
							gimp \
							git \
							gnucash \
							hunspell-en_us \
							keepassxc \
							libreoffice-fresh \
							liferea \
							mumble \
							mpv \
							obs-studio \
							qalculate-gtk \
							syncthing \
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
