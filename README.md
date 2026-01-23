# LogalDeveloper's Arch Linux Installer

An automated Arch Linux installer which reflects my personal preferences.

## Features

### Options

- **Storage**: BTRFS, BTRFS with data duplication, BTRFS RAID1 (two disks), or ext4
- **Networking**: Optional iwd for Wi-Fi
- **Profiles**:
  - Minimal: Base system only
  - Basic Desktop: KDE Plasma with Chromium and multimedia
  - Office Workstation: KDE Plasma with full productivity suite

### Defaults

- **Full-disk encryption**: LUKS2 with modern key derivation
- **Bootloader**: systemd-boot
- **Networking**: systemd-networkd and systemd-resolved
- **Firewall**: nftables with default inbound deny (except SSH) and default outbound allow
- **SSH**: OpenSSH configured with modern algorithms only
- **USB**: USBGuard for device whitelisting
- **Users**: Root account disabled; sudo via wheel group
- **Hardware**: Automatic CPU microcode installation (Intel/AMD), SSD TRIM, fwupd for firmware updates
- **Performance**: TCP BBR congestion control
- **Maintenance**: SMART monitoring, BTRFS scrub timer (when applicable)
- **Mirror**: [My personal Arch Linux mirror](https://logal.dev/projects/arch-linux-mirror/)
- **DNS**: No fallback DNS (must be provided via DHCP or static config), LLMNR and mDNS disabled
- **CA**: LogalNet internal CA pre-installed
- **Logging**: Installation log saved to `/var/log/arch-install.log`

### KDE Defaults

- **Audio**: PipeWire audio stack
- **Browser**: Chromium with Vulkan and hardware video acceleration
- **Wallet**: KWallet with PAM integration for auto-unlock on login

## Requirements

- Arch Linux live ISO
- EFI-capable system
- Internet connectivity
- One disk for standard installation, two disks for RAID1

## Usage

Boot into the Arch Linux live ISO, then run:

```bash
pacman -Sy git
git clone https://git.logal.dev/LogalDeveloper/Arch-Linux-Installer.git
cd Arch-Linux-Installer
./install-arch-linux.sh
```

## Customization

Profiles and package lists are defined in `config/profiles.conf`. Custom CA certificates can be added to `files/certs/`.

## Disclaimer

This installer is provided as-is. It is designed around my specific use case and probably makes assumptions that don't fit all hardware or configurations.

**Use at your own risk.** Always have backups before installing any operating system.
