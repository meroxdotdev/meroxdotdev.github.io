---
title: "Ultimate Dual Boot Guide: Windows 11 and Ubuntu 25.04"
date: 2025-04-14 10:00:00 +0200
categories: [tutorials, operating-systems, linux]
tags: [dual-boot, windows-11, ubuntu-25-04, linux, ubuntu-installation, partitioning, grub, dual-boot-tutorial, uefi, secure-boot]
description: Complete step-by-step guide for installing and configuring a dual boot system with Windows 11 and Ubuntu 25.04, perfect for beginners and advanced users alike.
image:
  path: /assets/img/posts/dual-boot-guide-banner.webp
  alt: Windows 11 and Ubuntu 25.04 Dual Boot Guide
---

![Ubuntu 25 Installer](/assets/img/posts/ubuntu25install.webp){: width="700" height="400" }
_Ubuntu Plucky Puffin installer_

**Last Updated: April 2025**

Running both Windows 11 and Ubuntu 25.04 on the same computer gives you the best of both worlds. This step-by-step guide makes dual-booting simple, even for beginners!

## What Sets This Guide Apart

Unlike typical dual-boot tutorials, this guide offers:
- **UEFI vs. Legacy BIOS** instructions for modern computers
- **Secure Boot compatibility** solutions
- **Performance optimization** tips for both operating systems
- **Advanced partition strategies** for optimal system management
- **Automated setup scripts** to speed up post-installation configuration
- **Virtualization options** when dual-boot isn't ideal
- **Real-world use case scenarios** to maximize your dual-boot experience

## What You'll Need

- A computer with Windows 11 already installed
- At least 30GB of free space (50GB+ recommended for comfortable usage)
- A USB drive (8GB or larger)
- About 30-45 minutes of your time
- Basic computer knowledge

## Part 1: Prepare Your Computer

### 1. Back Up Your Data

Always back up important files before modifying your system.
- Use Windows built-in Backup and Restore
- Consider cloud backup solutions (OneDrive, Google Drive)
- For critical data, create an external drive backup

### 2. Check Your System Type: UEFI or Legacy BIOS

1. Press **Win + R**, type `msinfo32`, and press Enter
2. Look for "BIOS Mode" under System Summary
   - If it says "UEFI", follow the UEFI instructions in this guide
   - If it says "Legacy", follow the Legacy instructions

### 3. Create Space for Ubuntu

#### Using Disk Management:
1. Press **Win + X** and select **Disk Management**
2. Right-click on your largest partition (usually C:) and select **Shrink Volume**
3. Enter the amount to shrink (minimum 30000 MB recommended for Ubuntu)
   - For a more comfortable experience: 50000 MB (50GB)
   - For developers/power users: 100000 MB (100GB)
4. Click **Shrink** to create unallocated space

![Windows Disk Management](/assets/img/posts/shrink-volume-to-partition-ssd-via-disk-management.webp){: width="700" height="400" }
_Shrink your Windows partition to make room for Ubuntu_

#### Alternative: Using Disk Cleanup First (Recommended)
Before shrinking, free up space by:
1. Press **Win + R**, type `cleanmgr` and press Enter
2. Select your C: drive and click OK
3. Click "Clean up system files"
4. Select all items, especially "Windows Update Cleanup" and "Previous Windows installations"
5. Click OK to reclaim gigabytes of space

### 4. Disable Fast Startup (Critical Step)

1. Go to **Control Panel** → **Power Options** → **Choose what the power buttons do**
2. Click **Change settings that are currently unavailable**
3. Uncheck **Turn on fast startup**
4. Click **Save changes**

![Windows Fast Startup](/assets/img/posts/fast-startup-w11.webp){: width="600" height="400" }
_Disabling Fast Startup prevents issues when dual-booting_

### 5. Disable BitLocker (If Enabled)

If you use BitLocker encryption:
1. Press **Win + X** and select **PowerShell (Admin)** or **Terminal (Admin)**
2. Type `manage-bde -status` to check BitLocker status
3. If enabled, type `manage-bde -off C:` to decrypt your drive
4. Wait for decryption to complete (may take hours)

> **Note:** You can re-enable BitLocker after Ubuntu installation, but it requires additional configuration.
{: .prompt-info }

### 6. Create Recovery Drive (Recommended)

1. Search for "Create a recovery drive" in Windows Search
2. Follow the wizard to create a Windows recovery USB
3. Store it safely in case you need to restore Windows

## Part 2: Create Ubuntu Installation Media

### 1. Download Ubuntu 25.04

Download the Ubuntu 25.04 ISO file from [ubuntu.com/download/desktop](https://releases.ubuntu.com/plucky/)

![Ubuntu Download Page](/assets/img/posts/ubuntu25.webp){: width="700" height="400" }
_Download the latest Ubuntu 25.04 ISO file_

### 2. Verify the ISO (For Extra Security)

1. Download the SHA256SUMS and SHA256SUMS.gpg files from the Ubuntu download page
2. On Windows, open PowerShell and run:
   ```powershell
   Get-FileHash -Algorithm SHA256 -Path path\to\ubuntu-25.04-desktop-amd64.iso
   ```
3. Compare the output hash with the one in the SHA256SUMS file

### 3. Create Bootable USB

#### Using Rufus:
1. Download and install [Rufus](https://rufus.ie)
2. Insert your USB drive
3. Open Rufus and select your USB drive
4. Click **SELECT** and choose the Ubuntu ISO file
5. For UEFI systems: Make sure "GPT" is selected in the partition scheme
6. Click **START** and select **Write in ISO Image mode**

![Rufus USB Creator](/assets/img/posts/rufus.webp){: width="600" height="400" }
_Rufus will create a bootable Ubuntu USB drive_

#### Alternative: Using Ventoy (Multi-Boot Solution)
1. Download [Ventoy](https://www.ventoy.net)
2. Install it to your USB drive
3. Copy the Ubuntu ISO directly to the USB
4. You can add multiple ISOs to create a multi-boot USB

## Part 3: Install Ubuntu Alongside Windows

### 1. Adjust UEFI/BIOS Settings

1. Restart your computer
2. Enter BIOS/UEFI (usually by pressing F2, F12, Del, or Esc during startup)
3. Make these critical changes:
   - Disable "Secure Boot" (temporarily)
   - Set "SATA Operation" to "AHCI" mode if using SSD
   - Disable "Intel Rapid Storage Technology" if present
   - Change boot order to prioritize USB
4. Save and exit

### 2. Boot from USB

1. Restart your computer
2. Press the boot menu key during startup (F12, F2, or Del - varies by computer)
3. Select your USB drive from the boot menu
4. On UEFI systems, select the "UEFI" entry for your USB

### 3. Start Ubuntu Installation

1. Select **Try or Install Ubuntu**
2. Choose your language and click **Install Ubuntu**
3. Select keyboard layout and click **Continue**
4. For wireless connection, connect to your WiFi network

### 4. Choose Optimal Installation Type

#### For Beginners (Automatic Partitioning):
1. Select **Install Ubuntu alongside Windows Boot Manager**
2. Click **Install Now**

#### For Advanced Users (Manual Partitioning):
1. Select **Something else** for manual partitioning
2. Create the following partitions in the unallocated space:
   - EFI partition (if not already present): 512 MB, use as "EFI System Partition"
   - Root partition (/): 20-30 GB, use as "Ext4", mount point "/"
   - Swap partition: Equal to your RAM (for hibernation support), use as "swap"
   - Home partition (/home): Remaining space, use as "Ext4", mount point "/home"

### 5. Confirm Partition Changes

Review the changes and click **Continue**

### 6. Choose Your Location

Select your time zone on the map

### 7. Create Your User Account

Enter your name, computer name, username, and password

> **Security Tip:** Use a different password than your Windows account
{: .prompt-tip }

### 8. Installation Process

Wait for the installation to complete (usually 10-15 minutes)

### 9. Restart Your Computer

When prompted, remove the USB drive and click **Restart Now**

## Part 4: Post-Installation Configuration

### 1. Re-enable Secure Boot (Optional)

If you want to use Secure Boot with Ubuntu:
1. Boot into UEFI settings
2. Find Secure Boot settings
3. Enter "Setup Mode" if available
4. Enable Secure Boot
5. Save and exit

Ubuntu 25.04 supports Secure Boot, but you may need to manage keys if you encounter boot issues.

### 2. First Boot and Updates

1. At the GRUB menu, select Ubuntu
2. Log in with your credentials
3. Run system updates:
   ```bash
   sudo apt update && sudo apt upgrade -y
   ```

### 3. Install Ubuntu Restricted Extras

For media codecs, fonts, and other proprietary software:
```bash
sudo apt install ubuntu-restricted-extras
```

### 4. Install Hardware-Specific Drivers

#### For NVIDIA Graphics:
```bash
sudo ubuntu-drivers autoinstall
```

#### For AMD Graphics:
The open-source drivers are usually included, but you can install the proprietary ones if needed:
```bash
sudo add-apt-repository ppa:kisak/kisak-mesa
sudo apt update && sudo apt upgrade
```

### 5. Fix Time Synchronization Issues

To prevent time conflicts between Windows and Ubuntu:

In Ubuntu Terminal:
```bash
timedatectl set-local-rtc 1 --adjust-system-clock
```

### 6. Post-Installation Script (Exclusive to This Guide)

Save time with our automated setup script that configures:
- Optimal power settings
- Improved performance tweaks
- Common software installations
- Proper dual-boot time synchronization

Create a file named `dual-boot-setup.sh`:

```bash
#!/bin/bash

# Update system
sudo apt update && sudo apt upgrade -y

# Install essential software
sudo apt install -y ubuntu-restricted-extras vlc gimp libreoffice timeshift gnome-tweaks

# Fix time synchronization
timedatectl set-local-rtc 1 --adjust-system-clock

# Optimize SSD if present
if [ -d "/sys/block/nvme0n1" ] || [ -d "/sys/block/sda" ]; then
  sudo apt install -y util-linux
  sudo systemctl enable fstrim.timer
fi

# Improve battery life
sudo apt install -y tlp tlp-rdw
sudo systemctl enable tlp

# Set up auto-cleaning
echo 'APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Download-Upgradeable-Packages "1";
APT::Periodic::AutocleanInterval "7";' | sudo tee /etc/apt/apt.conf.d/20auto-upgrades

# Performance improvements
echo 'vm.swappiness=10' | sudo tee -a /etc/sysctl.conf

# Check and repair GRUB if needed
sudo update-grub

echo "Setup complete! Reboot for changes to take effect."
```

Make it executable and run:
```bash
chmod +x dual-boot-setup.sh
./dual-boot-setup.sh
```

## Part 5: Using Your Dual-Boot System

### 1. The GRUB Boot Menu

After restart, you'll see the GRUB menu where you can select:
- Ubuntu 25.04
- Windows 11

![Dual Boot Screen](/assets/img/posts/dual-boot-windows-11-and-ubuntu-create-ubuntu.webp){: width="700" height="400" }
_The GRUB boot menu lets you choose which operating system to use_

### 2. Accessing Windows Files from Ubuntu

Ubuntu can read your Windows files:
1. Open **Files** in Ubuntu
2. Look for your Windows drive in the sidebar

> **Warning:** Writing to NTFS partitions from Ubuntu may require additional setup:
> ```bash
> sudo apt install ntfs-3g
> ```
{: .prompt-warning }

### 3. Accessing Ubuntu Files from Windows

To access Linux files from Windows 11:
1. Install WSL2 in Windows
2. Install the WSL Ubuntu extension
3. Use `\\wsl$\Ubuntu\home\yourusername` in File Explorer

Alternatively, install [Paragon Linux File Systems for Windows](https://www.paragon-software.com/home/linuxfs-windows/)

### 4. Changing Default Operating System

To change which system boots by default:

#### Graphical Method:
1. Install GRUB Customizer:
   ```bash
   sudo apt install grub-customizer
   ```
2. Launch GRUB Customizer
3. Go to "General Settings" tab
4. Change "Default entry" to your preference
5. Click Save

#### Terminal Method:
1. In Ubuntu, open Terminal
2. Type `sudo nano /etc/default/grub`
3. Change `GRUB_DEFAULT=0` to your preference (0 is usually Ubuntu)
4. Set `GRUB_TIMEOUT=10` for a longer selection time
5. Press Ctrl+X, then Y to save
6. Run `sudo update-grub`

### 5. Optimizing Performance in Dual-Boot Configuration

#### For Windows:
1. Disable indexing on drives shared with Linux
2. Use Storage Sense to automatically free up space
3. Disable unnecessary startup programs

#### For Ubuntu:
1. Reduce swappiness for better performance:
   ```bash
   sudo echo 'vm.swappiness=10' | sudo tee -a /etc/sysctl.conf
   ```
2. Enable zRAM for better memory management:
   ```bash
   sudo apt install zram-config
   ```

## Part 6: Advanced Techniques and Alternatives

### 1. Using Separate Hard Drives (Ideal Setup)

If your computer supports multiple drives:
1. Install Windows on first drive
2. Install Ubuntu on second drive
3. Configure BIOS/UEFI boot order or use boot menu to select OS

Benefits:
- No partition resizing needed
- Each OS gets a full drive
- Eliminates most dual-boot conflicts

### 2. Virtualization as Alternative

#### Windows as Host:
1. Enable virtualization in BIOS/UEFI
2. Install WSL2 for Linux command-line:
   ```powershell
   wsl --install
   ```
3. Or install VirtualBox/VMware for full Ubuntu desktop

#### Ubuntu as Host:
1. Install VirtualBox or GNOME Boxes:
   ```bash
   sudo apt install virtualbox
   ```
2. Create Windows 11 VM (requires valid license)

### 3. Timeshift for System Backup

Create system snapshots before major changes:
```bash
sudo apt install timeshift
sudo timeshift --create --comments "Fresh Ubuntu installation"
```

### 4. Custom GRUB Theme (Make Your Dual-Boot Stylish)

1. Download a theme from [GRUB Themes](https://www.gnome-look.org/browse/cat/109/)
2. Extract the theme to `/boot/grub/themes/`
3. Edit GRUB configuration:
   ```bash
   sudo nano /etc/default/grub
   ```
4. Add/modify: `GRUB_THEME="/boot/grub/themes/theme-name/theme.txt"`
5. Update GRUB:
   ```bash
   sudo update-grub
   ```

## Part 7: Real-World Use Cases

### 1. Developer Workstation

Optimal configuration:
- Windows for Adobe Suite, Microsoft Office, and gaming
- Ubuntu for development (Docker, VS Code, programming languages)
- Shared data partition in exFAT format
- Git repositories on the Linux partition

### 2. Data Science Setup

- Windows for Power BI and Excel analysis
- Ubuntu for Python, R, and machine learning frameworks
- Large data storage on separate drive accessible to both OSs
- Jupyter notebooks in shared folder

### 3. Gaming and Multimedia

- Windows for AAA gaming titles
- Ubuntu for day-to-day browsing and work
- Steam installed on both systems with shared library folder
- Proton configured for Windows games on Linux

## Part 8: Troubleshooting Common Issues

### Windows Not Showing in GRUB Menu

If Windows doesn't appear in the boot menu:
1. Boot into Ubuntu
2. Open Terminal
3. Type `sudo os-prober`
4. Then `sudo update-grub`

### Ubuntu Won't Boot After Windows Update

Windows updates may overwrite GRUB. To fix:
1. Boot from Ubuntu USB in "Try Ubuntu" mode
2. Open Terminal
3. Run Boot Repair:
   ```bash
   sudo add-apt-repository ppa:yannubuntu/boot-repair
   sudo apt update
   sudo apt install boot-repair
   boot-repair
   ```
4. Select "Recommended repair"

### Fixing Secure Boot Issues

If Ubuntu won't boot with Secure Boot enabled:
1. Boot into UEFI settings
2. Disable Secure Boot temporarily
3. Boot into Ubuntu
4. Run:
   ```bash
   sudo apt install sbsigntool
   sudo update-secureboot-policy
   ```

### Recovering Windows Bootloader

If you need to restore Windows boot without Ubuntu:
1. Boot from Windows installation media
2. Select "Repair your computer"
3. Go to Troubleshoot > Advanced Options > Command Prompt
4. Run:
   ```
   bootrec /fixmbr
   bootrec /fixboot
   bootrec /rebuildbcd
   ```

## Part 9: Uninstalling Either OS (If Needed)

### Removing Ubuntu while keeping Windows:
1. Boot into Windows
2. Open Disk Management
3. Delete the Ubuntu partitions
4. Expand Windows partition
5. Repair Windows boot using installation media

### Removing Windows while keeping Ubuntu:
1. Boot into Ubuntu
2. Use GParted to delete Windows partitions:
   ```bash
   sudo apt install gparted
   sudo gparted
   ```
3. Expand Ubuntu partitions as needed
4. Update GRUB:
   ```bash
   sudo update-grub
   ```

## Conclusion

Congratulations! You now have a dual-boot system with Windows 11 and Ubuntu 25.04. Enjoy the flexibility of choosing between two powerful operating systems depending on your needs.

Remember that Ubuntu offers amazing performance with lower system requirements than Windows, making it perfect for:
- Programming
- Web development
- Office work
- Multimedia
- Gaming (with Steam's Proton compatibility layer)

This dual-boot setup gives you the freedom to use the best tool for each job, while our performance optimizations ensure both systems run at their best.

### Recommended Next Steps

1. Set up cloud synchronization across both OSs (Dropbox, OneDrive, etc.)
2. Configure SSH keys and development environments in Ubuntu
3. Create your ideal productivity workflow between the two systems
4. Explore Linux gaming with Proton and Steam

If you have any questions, need help with your specific hardware, or want to share your dual-boot experience, leave a comment below!