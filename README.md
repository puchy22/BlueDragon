# BlueDragon 

## TL;DR

This is my custom Arch Linux installation. This setup is for my personal use, so it may not be suitable for everyone. However, you can use it as a reference to create your own custom Arch Linux installation. This has been tested on a Lenovo ThinkPad T490, so it is a UEFI system.

The installation uses the latest software and tools to create a modern Arch Linux setup with a focus on cybersecurity and CTFs. It could be a great alternative to the standard Kali installation. The installation is based on the [Arch Linux Installation Guide](https://wiki.archlinux.org/index.php/Installation_guide) and the [Arch Wiki](https://wiki.archlinux.org/).

The stack is: BTRFS, LUKS, systemd-boot, Wayland, and Hyprland.

### Improvements to-do

- [ ] Add periodic BTRFS snapshots
- [ ] Find a way to pipewire audio change automatically the output device to HDMI when connected (for now- I have to change the session clicking on the audio icon)

# Pre-installation

## Prerequisites

- A bootable Arch Linux USB drive
- A working internet connection (Ethernet, Wi-Fi, etc.)
- SSH access (optional, but recommended)

## SSH Access

If you want to access the installation remotely to copy and paste the commands easily, you can enable SSH by running the following command:

```bash
systemctl start sshd
```

And set a password for the root user:

```bash
passwd
```

Look for the IP address of the machine:

```bash
ip a
```

And connect to it using SSH from a second PC:

```bash
ssh root@<IP_ADDRESS>
```

Update the system clock:

```bash
timedatectl set-ntp true
```

Now list the available disks:

```bash
lsblk
```

We will use the `nvme0n1` as the only disk for this installation.

## Drive preparation for encryption (optional)

Fill the disk with random data to make it harder to recover deleted files:

```bash
cryptsetup open --type plain -d /dev/urandom /dev/nvme0n1 to_be_wiped
dd if=/dev/zero of=/dev/mapper/to_be_wiped status=progress
cryptsetup close to_be_wiped
```

## Partitioning

Check if the system is booted in UEFI mode:

```bash
ls /sys/firmware/efi/efivars
```

If the directory does not exist, reboot the system in UEFI mode.
Then partition the disk using a GPT partition table:

```bash
gdisk /dev/nvme0n1
```

Create a new partition table:

```bash
o
```

Create a new EFI system partition:

```bash
n
<Enter>
<Enter>
+512M
EF00
```

Create a new Linux filesystem partition with the rest of the disk (root partition, 8300 is the code for Linux filesystem):

```bash
n
<Enter>
<Enter>
<Enter>
8300
```

Write the changes to the disk:

```bash
w
```

## Encryption

Create an encrypted container on the root partition (you must enter a passphrase):

```bash
cryptsetup luksFormat /dev/nvme0n1p2
```

Open the encrypted container:

```bash
cryptsetup open /dev/nvme0n1p2 cryptroot
```

## Filesystem

Format the EFI system partition, and add the `esp` flag (EFI System Partition):

```bash
mkfs.fat -F32 -n esp /dev/nvme0n1p1
```

Create a BTRFS filesystem on the encrypted container for the root partition:

```bash
mkfs.btrfs -L root /dev/mapper/cryptroot
```

For both commands above labels are optional, but they are useful for identifying the partitions.

### BTRFS subvolumes

Mount the BTRFS filesystem:

```bash
mount /dev/mapper/cryptroot /mnt
```

Create the BTRFS subvolumes:

```bash
btrfs subvolume create /mnt/@
btrfs subvolume create /mnt/@swap
btrfs subvolume create /mnt/@home
btrfs subvolume create /mnt/@var
btrfs subvolume create /mnt/@snapshots
```

Unmount the BTRFS filesystem:

```bash
umount /mnt
```

Mount the BTRFS subvolumes:

```bash
mount -o noatime,nodiratime,compress=zstd,space_cache=v2,ssd,subvol=@ /dev/mapper/cryptroot /mnt
mkdir /mnt/{boot,home,var,.snapshots}
mount -o noatime,nodiratime,compress=zstd,space_cache=v2,ssd,subvol=@home /dev/mapper/cryptroot /mnt/home
mount -o noatime,nodiratime,compress=zstd,space_cache=v2,ssd,subvol=@var /dev/mapper/cryptroot /mnt/var
mount -o noatime,nodiratime,compress=zstd,space_cache=v2,ssd,subvol=@snapshots /dev/mapper/cryptroot /mnt/.snapshots
```

Mount the EFI system partition:

```bash
mount /dev/nvme0n1p1 /mnt/boot
```

### Swap

Create the swap file:

```bash
btrfs filesystem mkswapfile --size 8G /mnt/swapfile
swapon swapfile
```

Now you can check the swap file:

```bash
swapon --show
```

# Installation

## Base system

Install the base system:

```bash
pacstrap -K /mnt base base-devel linux linux-firmware btrfs-progs intel-ucode cryptsetup networkmanager neovim man-db sudo zsh openssh git
```

Generate the `fstab` file:

```bash
genfstab -U /mnt >> /mnt/etc/fstab
```

Change the root into the new system:

```bash
arch-chroot /mnt
```

## Configure the system

Set the timezone:

```bash
ln -sf /usr/share/zoneinfo/Europe/Madrid /etc/localtime
hwclock --systohc
```

Set the locale:

```bash
sed -i 's/#es_ES.UTF-8 UTF-8/es_ES.UTF-8 UTF-8/g' /etc/locale.gen
locale-gen
echo -e "LANG=es_ES.UTF-8\nLC_MESSAGES=en_US.UTF-8" > /etc/locale.conf
```

Set the keyboard layout:

```bash
echo "KEYMAP=es" > /etc/vconsole.conf
```

Set the hostname:

```bash
echo "blue-dragon" > /etc/hostname
```

Set the hosts file:

```bash
nvim /etc/hosts
```

Add the following lines:

```
# Static table lookup for hostnames.
# See hosts(5) for details.
127.0.0.1   localhost
::1         localhost
127.0.1.1   blue-dragon.localdomain blue-dragon
```

Set the root password:

```bash
passwd
```

## Initramfs

Edit the `mkinitcpio.conf` file:

```bash
nvim /etc/mkinitcpio.conf
```

Add `btrfs` and `encrypt` to the `HOOKS` array:

```bash
HOOKS=(base keyboard udev autodetect modconf block keymap consolefont encrypt btrfs filesystems resume)
```

Generate the initramfs image:

```bash
mkinitcpio -p linux
```

## Bootloader

Install the systemd-boot bootloader:

```bash
bootctl install --path=/boot
```

Edit the `loader.conf` file:

```bash
nvim /boot/loader/loader.conf
```

Add the following lines to set the default timeout (seconds that loader selection) and the default configuration file:

```bash
default arch.conf
timeout 3
console-mode max
editor no
```

Create the `arch.conf` file:

```bash
nvim /boot/loader/entries/arch.conf
```

Add the following lines:

```bash
title Arch Linux
linux /vmlinuz-linux
initrd /intel-ucode.img
initrd /initramfs-linux.img
options cryptdevice=UUID=e806a4cb-590f-4e55-9490-e3b355a4b2ce:cryptroot:allow-discards root=/dev/mapper/cryptroot rootflags=subvol=@ rd.luks.options=discard rw resume=/dev/mapper/cryptroot resume_offset=533760
```

Replace `<UUID>` with the UUID of the root partition:

```bash
blkid /dev/nvme0n1p2
```

## Network

Enable the NetworkManager service:

```bash
systemctl enable NetworkManager
```

## User

Create a new user:

```bash
useradd -m -g users -G wheel -s /bin/zsh puchy
passwd puchy
```

Edit the `sudoers` file:

```bash
EDITOR=nvim visudo
```

Uncomment the following line:

```bash
%wheel ALL=(ALL) ALL
```

## Reboot

Exit the chroot environment:

```bash
exit
```

Unmount the partitions:

```bash
umount -R /mnt
```

Reboot the system:

```bash
reboot
```

# Post-installation

Start the sshd service, to can copy and paste the commands easily:

```bash
systemctl start sshd
```

Probably you will need permit the root user to connect via SSH adding the following line to the `/etc/ssh/sshd_config` file:

```bash
PermitRootLogin yes
```

## System configuration

### Custom pacman configuration

Edit the `pacman.conf` file:

```bash
nvim /etc/pacman.conf
```

Add the following options:

```bash
[options]
ParallelDownloads = 5
Color
CheckSpace
ILoveCandy
```

### Custom repositories

Install `paru` (AUR helper):

```bash
su puchy # And press q to exit zsh configuration
cd /tmp
git clone https://aur.archlinux.org/paru.git
cd paru
makepkg -si
exit
```

Activate the multilib repository:

```bash
nvim /etc/pacman.conf
```

Uncomment the following lines:

```bash
[multilib]
Include = /etc/pacman.d/mirrorlist
```

Adding BlackArch repositories:

```bash
mkdir /tmp/blackarch
cd /tmp/blackarch
curl -O https://blackarch.org/strap.sh
chmod +x strap.sh
./strap.sh
cd $HOME
pacman -Syy
```

### Automatic mirrorlist

Install `reflector`:

```bash
pacman -S reflector
```

Create a new mirrorlist:

```bash
reflector --country "Spain,France,Germany" --age 12 --protocol https --sort rate --save /etc/pacman.d/mirrorlist
```

Add your country to the reflector configuration file:

```bash
nvim /etc/xdg/reflector/reflector.conf
```

In my case, I added the following line:

```bash
--country Spain,France,Germany
```

Enable the reflector service to update the mirrorlist on boot:

```bash
systemctl --now enable reflector.service
```

### Common packages

List of common packages:

- **Core Utilities**:
    - tar (archive tool)
    - unzip (archive tool)
    - zip (archive tool)
    - unrar (archive tool)
    - p7zip (archive tool)
    - xarchiver (archive tool)
    - findutils (find tool)
    - plocate (locate tool)
    - wget (download tool)
    - fastfetch (system information tool)
    - stow (symlink farm manager)
    - iptables-nft (Linux kernel packet control tool (using nft interface))
    - dnsmasq (lightweight, easy to configure DNS forwarder and DHCP server)
    - ufw (uncomplicated firewall)
    - brightnessctl (control bright of screen)
    - rye (multi tool for managing python)
    - jre-openjdk (latest Java for applications)
    - chrony (NTP client and server)
    - bluez (Bluetooth protocol stack)
    - bluez-utils (Bluetooth protocol stack utilities)
    - blueman (Bluetooth manager)
    - **Modern UNIX CLI tools**:
        - lsd (ls tool alternative)
        - zoxide (cd tool alternative)
        - bat (cat tool alternative)
        - fzf (fuzzy finder)
        - broot (tree tool alternative)
        - htop (system monitor)
        - thefuck (command correction tool)
        - jq (JSON command-line processor)
- **Audio**:
    - pipewire (audio server)
    - pipewire-audio (pipewire audio server)
    - pipewire-alsa (pipewire alsa compatibility)
    - wireplumber (pipewire session manager)
    - pipewire-pulse (pipewire pulseaudio compatibility)
    - easyeffects (pipewire audio effects)
- **Media**:
    - parole (media player)
    - libsixel (image converter to DEC SIXEL graphics, integrations with foot terminal)
- **Browser**:
    - chromium (browser)
- **File Managers**:
    - thunar (graphical file manager)
    - gvfs (virtual filesystem (Thunar plugins))
    - thunar-volman (Thunar volume manager)
    - thunar-archive-plugin (Thunar archive plugin)
- **Text Editors**:
    - obsidian (note-taking app)
- **Virtualization**:
    - qemu-desktop (virtualization, only x86_64)
    - libvirt (virtualization API)
    - virt-manager (virtualization manager)
    - dnsmasq (DNS and DHCP server)
    - openbsd-netcat (networking tool)
    - vde2 (virtual distributed ethernet)
    - bridge-utils (network bridge)
    - podman (container manager)
    - buildah (container builder)
    - fuse-overlayfs (overlayfs for podman)
    - netavark (network manager for podman)
    - aardvark-dns (DNS manager for podman)
    - podman-compose (compose for podman)
    - passt (default rootless network backend)
    - slirp4netns (networking tool for rootless containers)
- **Other Utilities**:
    - grim (screenshot tool)
    - hyprpicker (color picker tool)
    - okular (document viewer)
    - gimp (image editor)
    - networkmanager-openvpn (OpenVPN plugin)
    - fprintd (fingerprint manager)
    - nwg-look (GTK theme manager)
    - gnumeric (spreadsheet editor)
    - github-cli (GitHub CLI)

Install the packages:

```bash
pacman -S tar unzip zip unrar p7zip xarchiver findutils plocate bat zoxide lsd broot fzf htop wget tree fastfetch stow thefuck iptables-nft dnsmasq ufw brightnessctl jq rye jre-openjdk chrony bluez bluez-utils
pacman -S pipewire pipewire-audio pipewire-alsa wireplumber pipewire-pulse easyeffects
pacman -S parole libsixel
pacman -S chromium
pacman -S thunar gvfs thunar-volman thunar-archive-plugin
pacman -S obsidian
pacman -S qemu-desktop libvirt virt-manager dnsmasq openbsd-netcat vde2 bridge-utils podman buildah fuse-overlayfs netavark aardvark-dns podman-compose passt slirp4netns
pacman -S grim hyprpicker okular gimp networkmanager-openvpn fprintd nwg-look gnumeric github-cli
```

If want to install in the same command:

```bash
pacman -S tar unzip zip unrar p7zip xarchiver findutils plocate bat zoxide lsd broot fzf htop wget tree fastfetch stow thefuck iptables-nft dnsmasq ufw brightnessctl jq rye jre-openjdk chrony bluez bluez-utils pipewire pipewire-audio pipewire-alsa wireplumber pipewire-pulse easyeffects libsixel chromium thunar gvfs thunar-volman thunar-archive-plugin obsidian qemu-desktop libvirt virt-manager dnsmasq openbsd-netcat vde2 bridge-utils podman buildah fuse-overlayfs netavark aardvark-dns podman-compose passt slirp4netns grim hyprpicker okular gimp networkmanager-openvpn fprintd nwg-look gnumeric github-cli
```

Install the AUR packages:

- vscodium-bin (Free/Libre Open Source Software Binaries of VSCode)
- hyprshot (screenshot wrapper for Hyprland)
- librewolf-bin (browser)
- notion-app-electron (note-taking app)
- webcord-git (Discord client)
- oh-my-posh-bin (promt engine for shell)

```bash
su puchy    # paru cannot be executed by root
paru -S vscodium-bin hyprshot librewolf-bin notion-app-electron webcord-git oh-my-posh-bin
```

## Additional configuration

### Nerd Fonts

Install the Nerd Fonts, please note that the following command will download the Mononoki font. For other fonts, you can check the [Nerd Fonts](https://www.nerdfonts.com/) website.

```bash
wget https://github.com/ryanoasis/nerd-fonts/releases/download/v3.2.1/Mononoki.zip -P /tmp
unzip /tmp/Mononoki.zip -d /tmp
mkdir -p /usr/share/fonts/mononoki
cp /tmp/*.ttf /usr/share/fonts/mononoki
```

### Virtualization

#### Configure QEMY/KVM

Enable the libvirt service:

```bash
systemctl --now enable libvirtd
```

Enable the `virtlogd` service:

```bash
systemctl --now enable virtlogd
```

Add the user to the `libvirt` group:

```bash
usermod -aG libvirt puchy
```

In file `/etc/libvirt/network.conf` set `firewall_backend="nftables"` to use `nftables` as the firewall backend.


#### Configure Podman

Configure registries:

```bash
nvim /etc/containers/registries.conf.d/10-unqualified-search-registries.conf
```

Add the following lines:

```bash
unqualified-search-registries = ["docker.io"]
```

To use rootless containers, it needs to add more ranges to UIDS and GIDS for the create user:

```bash
usermod --add-subuids 10000-75535 puchy
usermod --add-subgids 10000-75535 puchy
```

### Graphical environment

DISCLAIMER: Many of this packages could be already installed as dependencies of other previous packages.

#### Display server

Install the display server:

```bash
pacman -S wayland
```

Install respective GUI libraries:

```bash
pacman -S gtk4 gtk3 qt5-wayland qt6-wayland
```

#### Window manager

The window manager used is `Hyprland`.

First install the must-have packages needed as indicated in the [Hyprland docs](https://wiki.hyprland.org/Useful-Utilities/Must-have/):

- foot (terminal emulator)
- swaync (notification daemon)
- [audio server (pipewire)](#common-packages)
- polkit-kde-agent (polkit agent)


```bash
pacman -S foot swaync polkit-kde-agent
```

Install the window manager:

```bash
pacman -S hyprland
```

### App launcher

The chosen app launcher is `wofi`.

Install the app launcher:

```bash
pacman -S wofi
```

### Status bar

The chosen status bar is `waybar`.

Install the status bar:

```bash
pacman -S waybar
```

### Wallpaper manager

The chosen wallpaper manager is `hyprpaper`.

Install the wallpaper manager:

```bash
pacman -S hyprpaper
```

#### Display manager

Install the display manager:

```bash
pacman -S sddm
```

Now change the default SDDM display manager, to do this add the following file with the following content:

```bash
nvim /etc/sddm.conf.d/10-wayland.conf
```

Add the following lines:

```
[General]
DisplayServer=wayland
GreeterEnvironment=QT_WAYLAND_SHELL_INTEGRATION=layer-shell
```

Enable the display manager:

```bash
systemctl --now enable sddm
```

Configure the fingerprint reader:

```bash
nvim /etc/pam.d/sddm
```

If you want to use fingerprint to log in follow the next tutorial to configure the fingerprint reader: [Fingerprint reader configuration](https://wiki.archlinux.org/title/Fprint#Create_fingerprint_signature).

Add the following line:

```
auth 			[success=1 new_authtok_reqd=1 default=ignore]  	pam_unix.so try_first_pass likeauth nullok
auth 			sufficient  	pam_fprintd.so
```

The last thing that I have configure is to change the default theme because I don't like the default one. To do this, I have installed the `sddm-eucalyptus-drop` theme, that you can install following his guide: [sddm-eucalyptus-drop](https://gitlab.com/Matt.Jolly/sddm-eucalyptus-drop/) and adding as background this [wallpaper](https://images-wixmp-ed30a86b8c4ca887773594c2.wixmp.com/i/63ae2adb-98d7-47f9-8df6-3f569ed8ba46/d979ppg-aac967f3-68f4-454e-ab2c-bb23468ea028.png).

#### ZSH

The regular user is configured to use `zsh` as the default shell. In order to configure I use as plugin manager `zinit`, to install it I follow the [documentation manual installation](https://github.com/JanDeDobbeleer/oh-my-posh/blob/main/themes/kushal.omp.json) adding the snippet provided to my `.zshrc`. And the theme `oh-my-posh` (installed previously with `paru`), to customize the prompt follow the next tutorial: [oh-my-posh](https://ohmyposh.dev/docs/installation/customize), in my case I use a modified version of `kushal` [theme](https://github.com/JanDeDobbeleer/oh-my-posh/blob/main/themes/kushal.omp.json).

In relation of the plugins and other configurations, I followed this [video from Dreams of Autonomy](https://www.youtube.com/watch?v=ud7YxC33Z3wO).

# Security

## Secrity software and pentesting tools

If you do not want to install the pentesting tools, you can only install `ufw` and `clamav` that are the security software needed for a regular user.

The following list of packages are the security software and pentesting tools that I have installed:

- **Security Software**:
    - ufw (uncomplicated firewall)
    - clamav (antivirus)
- **Pentesting Tools**:
    - nmap (network scanner)
    - sqlmap (SQL injection scanner)
    - john (password cracker)
    - hashcat (password cracker)
    - wireshark-qt (network protocol analyzer)
    - gobuster (directory and file brute-forcer)
    - exploitdb (exploit database, searchsploit command)
    - zaproxy (web application scanner)

Install the packages:

```bash
pacman -S ufw clamav
pacman -S nmap sqlmap john hashcat wireshark-qt gobuster exploitdb zaproxy
```

Packages from AUR:

- **Pentesting Tools**:
    - whatweb (web scanner)
    - wordlists (wordlists for password cracking stored in `/usr/share/wordlists`)
    - burpsuite (security testing of web applications)

```bash
paru -S whatweb wordlists burpsuite
```

## Firewall

Enable the UFW service:

```bash
systemctl --now enable ufw
```

For desktop environments, I will use the following rules, only allowing outgoing traffic:

```bash
ufw default deny incoming
ufw default allow outgoing
```

Now enable the firewall (if you are connected via SSH, wait until ending the configuration):

```bash
ufw enable
```

## Antivirus

To update the ClamAV database:

```bash
freshclam
```

Enable the ClamAV service:

```bash
systemctl --now enable clamav-freshclam
systemctl --now enable clamav-daemon
```

## Locking root account

Now that sudo is configured, it is a good idea to lock the root account:

```bash
passwd -l root
```
