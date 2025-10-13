---
title: "Gaming on Linux"
date: 2025-11-07 09:00:00 +0300
categories: [infrastructure]
#tags: [gaming, linux, steam, proton, nvidia, lutris, egpu, homelab, quadro]
description: Real experience gaming on - Dell R720 with Quadro P2200. What works, what doesn't, and the issues you'll actually face.
image:
  path: /assets/img/posts/linux-gaming-setup.webp
  alt: Linux Gaming on Homelab Hardware
---


I've been experimenting with Linux gaming on my homelab equipment for a few years now. Here's what actually works when you're gaming on enterprise hardware instead of a dedicated gaming PC.

## My Gaming Hardware

**Current Setup (Dell R720):**
- 2× Intel Xeon E5-2697v2 (24C/48T)
- 192GB ECC RAM
- NVIDIA Quadro P2200 (5GB GDDR5)
- 2TB SSD storage
- Basic Dell Full HD monitor

**Future Gaming Rig (Beelink SEi14):**
- Intel Core Ultra 9 185H
- 64GB DDR5 RAM
- Integrated Intel Arc Graphics
- Planning: Beelink EX Pro Docking Station + RTX 4060

> The Quadro P2200 is a workstation GPU, not designed for gaming. But with Linux's overhead being lower than Windows, it handles games better than expected.
{: .prompt-info }

## What I've Actually Tested

Over the past few years, here's what I've run on this setup:

**Games That Worked:**
- **CS:GO** - Ran perfectly on Ubuntu
- **StarCraft II** - Through Battle.net with Lutris ([video guide](https://www.youtube.com/watch?v=HqOEKSR_Eow))
- **League of Legends** - Worked well back then, but **no longer playable** due to Vanguard anti-cheat ([details here](https://leagueoflinux.org/post_vanguard/))

**Problematic Games:**
- **GTA V Single Player** - Font rendering issues, missing text
- **GTA Online** - [Completely blocked on Linux since September 2024](https://steamcommunity.com/games/271590/announcements/detail/6356356787200715685) due to BattlEye anti-cheat

## Ubuntu vs Arch for Gaming

I've tested both Ubuntu and Arch Linux. Here's my take:

**Ubuntu (My Preference):**
- More stable, less likely to break
- Better for beginners who don't want troubleshooting marathons
- Easier to recover when things go wrong
- Works out of the box for most gaming needs

**Arch Linux:**
- Latest drivers and packages
- More control over everything
- Higher chance of random breakage
- Not worth the hassle for casual gaming

> For gaming, Ubuntu is the safe bet. Save Arch for when you enjoy debugging more than playing.
{: .prompt-tip }

## Essential Setup

### 1. NVIDIA Drivers (The Official Way)

The recommended approach from [Ubuntu documentation](https://ubuntu.com/server/docs/nvidia-drivers-installation):

```bash
# Check available drivers for your hardware
sudo ubuntu-drivers list

# Install recommended driver (automatic detection)
sudo ubuntu-drivers install

# Or specify version manually
sudo ubuntu-drivers install nvidia:535

# Verify installation
nvidia-smi
```

**Alternative method (if you need specific PPA):**

```bash
# Add graphics drivers PPA
sudo add-apt-repository ppa:graphics-drivers/ppa
sudo apt update

# Install specific version
sudo apt install nvidia-driver-535
```

**For servers/compute workloads:**

```bash
# List available drivers for compute
sudo ubuntu-drivers list --gpgpu

# Install server driver
sudo ubuntu-drivers install --gpgpu nvidia:535-server

# Install additional utilities
sudo apt install nvidia-utils-535-server
```

> Using `ubuntu-drivers` tool is recommended as it automatically handles Secure Boot signing.
{: .prompt-warning }

### 2. Steam + Proton

```bash
# Install Steam
sudo apt install steam-installer

# Enable 32-bit architecture
sudo dpkg --add-architecture i386
sudo apt update
sudo apt install mesa-vulkan-drivers:i386
```

**Enable Proton in Steam:**
1. Settings → Steam Play
2. Check "Enable Steam Play for all other titles"
3. Select "Proton Experimental"

### 3. Lutris for Non-Steam Games

```bash
# Add Lutris PPA
sudo add-apt-repository ppa:lutris-team/lutris
sudo apt update
sudo apt install lutris

# Install Wine dependencies
sudo apt install wine64 wine32 winetricks
```

### 4. Performance Tools

```bash
# GameMode for CPU governor management
sudo apt install gamemode

# MangoHud for performance overlay
sudo apt install mangohud
```

## Quadro P2200 Gaming Performance

The Quadro P2200 is roughly equivalent to a GTX 1650 in gaming performance. Here's what it can handle based on real-world testing and benchmarks:

| Game | Resolution | Settings | Expected FPS |
|:-----|:-----------|:---------|:-------------|
| **CS:GO/CS2** | 1080p | High | 100-140 |
| **Dota 2** | 1080p | High | 80-120 |
| **Rocket League** | 1080p | High | 110-144 |
| **Valorant** | 1080p | Medium | ❌ Anti-cheat blocks Linux |
| **Overwatch 2** | 1080p | Medium | 60-80 |
| **Apex Legends** | 1080p | Medium | ❌ Anti-cheat issues |
| **Elden Ring** | 1080p | Medium | 45-60 |
| **Cyberpunk 2077** | 1080p | Low | 35-45 |
| **The Witcher 3** | 1080p | High | 55-70 |
| **Satisfactory** | 1080p | Medium | 50-65 |

> Performance data compiled from ProtonDB, r/linux_gaming, and Quadro P2200 gaming benchmarks.
{: .prompt-info }

## Real Issues I Encountered

### 1. Font Issues (GTA V and Others)

**The Problem:**
Missing text, scrambled characters, or unreadable UI in older games. This was common 3-4 years ago with GTA V.

**Modern Solution (2025):**

Proton has significantly improved font handling. Most font issues are now resolved automatically. However, if you still encounter problems:

```bash
# Install MS core fonts system-wide
sudo apt install ttf-mscorefonts-installer
```

This makes fonts available to all Wine/Proton prefixes automatically - **no need for winetricks corefonts anymore** in most cases.

> **Important:** Modern Proton versions can access system fonts. The old winetricks corefonts method is rarely needed in 2025.
{: .prompt-tip }

**For Persistent Font Issues (Rare):**

If a specific game still has font problems after installing system fonts:

```bash
# Install Protontricks for per-game fixes
sudo apt install protontricks

# List your Steam games
protontricks -l

# Install fonts for specific game (if really needed)
protontricks GAME_ID corefonts
```

### 2. NVIDIA Driver Issues

**Problem:** Crashes, black screens, GPU not detected

**Solution:** Use official ubuntu-drivers tool (already covered in setup)

```bash
# If still having issues, verify driver is loaded
lsmod | grep nvidia

# Check for errors in system logs
dmesg | grep -i nvidia

# Reinstall if needed
sudo ubuntu-drivers install
```

### 3. Battle.net Games (StarCraft II)

**Setup with Lutris:**
1. Install Lutris (already covered above)
2. Visit [lutris.net](https://lutris.net) and search "Battle.net"
3. Click the Install button on the Battle.net installer page
4. Follow the automated installation
5. Login to Battle.net and install StarCraft II

**Video guides I used:**
- [StarCraft II Linux Setup](https://www.youtube.com/watch?v=HqOEKSR_Eow)
- [Battle.net Configuration Guide](https://www.youtube.com/watch?v=R9in9yeY4Jw&t=68s)

### 4. League of Legends - No Longer Works

**Reality Check:** As of 2024, League of Legends is **completely unplayable** on Linux due to Riot's Vanguard anti-cheat.

Source: [League of Linux - Vanguard Update](https://leagueoflinux.org/post_vanguard/)

There's no workaround. If you want to play League, you need Windows.

### 5. GTA V Issues

**Single Player:**
- Works with Proton, but had font issues 3-4 years ago
- Modern Proton versions (2024+) mostly fixed these
- Use system fonts (ttf-mscorefonts-installer) if issues persist

**GTA Online:**
- **Blocked since September 2024** due to BattlEye anti-cheat
- [Official announcement from Rockstar](https://steamcommunity.com/games/271590/announcements/detail/6356356787200715685)
- No workaround available - requires Windows

> BattlEye on GTA Online does not support Linux, even though BattlEye technically works on other games.
{: .prompt-warning }

## Launch Options That Help

Add these to Steam game properties:

```bash
# Basic performance setup
gamemoderun mangohud %command%

# Force Vulkan renderer (better performance)
VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/nvidia_icd.json %command%

# Enable FSR upscaling (AMD's FidelityFX)
WINE_FULLSCREEN_FSR=1 %command%

# For problematic games, try Proton-GE
# Install via ProtonUp-Qt first
```

## Proton-GE for Stubborn Games

Some games need custom Proton builds. **Video guide I recommend:** [Chris Titus Tech - Proton GE Installation](https://www.youtube.com/watch?v=BYIDoD8VdAw)

**Quick method:**

```bash
# Install ProtonUp-Qt (GUI manager for Proton-GE)
flatpak install flathub net.davidotek.pupgui2
```

> **Flatpak Note:** If you encounter "Unable to allocate instance id" errors with flatpak, this is a [known issue in Ubuntu 25.04](https://discourse.ubuntu.com/t/ubuntu-25-04-flatpak-unable-to-allocate-instance-id/50704). Usually fixed with: `flatpak repair` or reinstalling the flatpak.
{: .prompt-info }

Launch ProtonUp-Qt → Install latest GE-Proton → Restart Steam

**Manual installation:**

```bash
cd ~/.steam/steam/compatibilitytools.d/
wget https://github.com/GloriousEggroll/proton-ge-custom/releases/latest/download/GE-Proton.tar.gz
tar -xf GE-Proton.tar.gz
```

Restart Steam → Right-click game → Properties → Compatibility → Select GE-Proton

## Future: eGPU Setup with Beelink

Planning to use the Beelink SEi14 with an external RTX 4060 via Beelink EX Pro Docking Station.

### Why eGPU Instead of Dell R720?

- **Power consumption** - R720 pulls ~200W idle
- **Noise levels** - Server fans are loud
- **Portability** - Beelink is a compact mini PC
- **Dual use** - Gaming + AI workloads with RTX 4060

### eGPU Setup Preview

```bash
# Check Thunderbolt support
sudo apt install bolt
boltctl list

# Install eGPU utilities
sudo apt install egpu-switcher

# NVIDIA eGPU configuration
sudo nano /etc/X11/xorg.conf.d/10-nvidia-egpu.conf
```

```
Section "Device"
    Identifier "nvidia-egpu"
    Driver "nvidia"
    BusID "PCI:XX:XX:X"  # Find with: lspci | grep NVIDIA
    Option "AllowExternalGpus" "True"
EndSection
```

> I'll update this section with real benchmarks once I get the hardware.
{: .prompt-warning }

## Gaming Workflow

**My typical gaming session:**

1. Boot Ubuntu
2. Run gaming-mode script (sets CPU governor)
3. Launch Steam/Lutris
4. Check ProtonDB if game issues occur
5. Monitor performance with MangoHud

### Gaming Mode Script

```bash
#!/bin/bash
# ~/scripts/gaming-mode.sh

# Set CPU to performance mode
echo "performance" | sudo tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor > /dev/null

# NVIDIA max performance
nvidia-settings -a "[gpu:0]/GpuPowerMizerMode=1" > /dev/null 2>&1

echo "🎮 Gaming mode enabled!"
```

```bash
chmod +x ~/scripts/gaming-mode.sh
```

### MangoHud Configuration

```bash
# ~/.config/MangoHud/MangoHud.conf
fps
frame_timing=1
cpu_stats
cpu_temp
gpu_stats
gpu_temp
ram
vram
position=top-right
background_alpha=0.5
```

## Quick Troubleshooting

### Game Won't Launch

```bash
# Check Proton logs
PROTON_LOG=1 %command%

# View log file
cat $HOME/steam-*.log
```

### Performance Issues

```bash
# Check if GameMode is running
gamemoded -t

# Verify GPU is being used
nvidia-smi

# Monitor in real-time
watch -n 1 nvidia-smi
```

### Audio Problems

```bash
# Install PipeWire (better than PulseAudio for gaming)
sudo apt install pipewire pipewire-pulse
systemctl --user enable pipewire pipewire-pulse
systemctl --user start pipewire pipewire-pulse
```

## Anti-Cheat Reality Check

**Games That Work:**
- Easy Anti-Cheat (Elden Ring, some games)
- BattlEye (limited - game-dependent)
- VAC (Valve Anti-Cheat - works perfectly)

**Games That Don't Work:**
- **Riot Vanguard** (League of Legends, Valorant)
- **RICOCHET** (Call of Duty)
- **BattlEye on GTA Online** (blocked by Rockstar)

Check compatibility: [AreWeAntiCheatYet.com](https://areweanticheatyet.com/)

## Dual-Boot Game Library Sharing

If you dual-boot Windows and Linux, share your Steam library:

```bash
# Create mount point
sudo mkdir /mnt/games

# Edit fstab for auto-mount
sudo nano /etc/fstab
```

Add:
```
UUID=YOUR-DRIVE-UUID /mnt/games ntfs-3g defaults,uid=1000,gid=1000,umask=0022 0 0
```

```bash
# Find UUID
sudo blkid
```

**In Steam:**
Settings → Storage → Add Drive → Select `/mnt/games/SteamLibrary`

## Automated Setup Script

```bash
#!/bin/bash
# linux-gaming-setup.sh

set -e

echo "🎮 Setting up Linux gaming environment..."

# Add repositories
sudo add-apt-repository multiverse -y
sudo add-apt-repository ppa:lutris-team/lutris -y
sudo dpkg --add-architecture i386

# Update system
sudo apt update && sudo apt upgrade -y

# Install gaming essentials
sudo apt install -y \
    steam-installer \
    lutris \
    gamemode \
    mangohud \
    wine64 wine32 \
    winetricks \
    vulkan-tools \
    mesa-vulkan-drivers:i386 \
    ttf-mscorefonts-installer

# Install NVIDIA drivers using ubuntu-drivers
sudo ubuntu-drivers install

# Install ProtonUp-Qt via flatpak
flatpak install -y flathub net.davidotek.pupgui2

# Create scripts directory
mkdir -p ~/scripts

# Create gaming mode script
cat > ~/scripts/gaming-mode.sh << 'EOF'
#!/bin/bash
echo "performance" | sudo tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor > /dev/null
nvidia-settings -a "[gpu:0]/GpuPowerMizerMode=1" > /dev/null 2>&1
echo "🎮 Gaming mode enabled!"
EOF

chmod +x ~/scripts/gaming-mode.sh

# Create MangoHud config
mkdir -p ~/.config/MangoHud
cat > ~/.config/MangoHud/MangoHud.conf << 'EOF'
fps
frame_timing=1
cpu_stats
cpu_temp
gpu_stats
gpu_temp
ram
vram
position=top-right
background_alpha=0.5
EOF

echo "✅ Setup complete!"
echo "Reboot your system, then run ~/scripts/gaming-mode.sh before gaming."
```

Run it:
```bash
chmod +x linux-gaming-setup.sh
./linux-gaming-setup.sh
```

## Useful Resources

**Compatibility Databases:**
- [ProtonDB](https://www.protondb.com/) - Steam game compatibility
- [Lutris](https://lutris.net/) - Game installers and scripts
- [AreWeAntiCheatYet](https://areweanticheatyet.com/) - Anti-cheat status

**Communities:**
- r/linux_gaming - Reddit community
- [GamingOnLinux](https://www.gamingonlinux.com/) - News and guides
- r/eGPU - eGPU setups and troubleshooting

**Tools:**
- [ProtonUp-Qt](https://davidotek.github.io/protonup-qt/) - Proton-GE manager
- [Heroic Games Launcher](https://heroicgameslauncher.com/) - Epic/GOG alternative

**Video Guides:**
- [Chris Titus Tech - Proton GE](https://www.youtube.com/watch?v=BYIDoD8VdAw)
- [StarCraft II Setup](https://www.youtube.com/watch?v=HqOEKSR_Eow)

## The Honest Reality

**What Works Well:**
- Single-player games (90%+ compatibility)
- Valve games (native or perfect Proton)
- Indie titles (most are native Linux)
- Older AAA games (proven Proton compatibility)

**What's Problematic:**
- Competitive multiplayer (anti-cheat issues)
- Brand new AAA releases (wait 1-2 weeks for Proton updates)
- VR gaming (limited support)
- Games with aggressive DRM

**My Experience:**
I game on Linux about 20% of the time. For competitive shooters or games with kernel-level anti-cheat (League, Valorant, GTA Online), I still dual-boot to Windows. But for everything else, Linux works surprisingly well - especially on enterprise hardware that's overkill for gaming.

## Conclusion

Gaming on Linux with homelab hardware isn't conventional, but it works better than expected. The Quadro P2200 handles 1080p gaming at medium/high settings, and once I add the RTX 4060 eGPU to the Beelink, I'll have a proper gaming setup.

The biggest hurdle isn't performance - it's anti-cheat compatibility. If you play mostly single-player games or older multiplayer titles, Linux gaming is viable. If you're into competitive esports titles, keep Windows around.
