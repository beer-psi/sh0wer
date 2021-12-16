#!/bin/bash
# YACD - Yet Another checkra1n Distribution

# Exit if user isn't root
[ "$(id -u)" -ne 0 ] && {
    echo 'Please run as root'
    exit 1
}

# Stage 0: Get download links
# * If any link is filled, the script will download from that link.
# * If empty, get the latest version from the website.
KERNEL_MODULES="modules"
CHECKRA1N_AMD64=""
CHECKRA1N_I486=""
SILEO=""
[ -z "$CHECKRA1N_AMD64" ] && {
    CHECKRA1N_AMD64=$(curl -s "https://checkra.in/releases/" | grep -Po "https://assets.checkra.in/downloads/linux/cli/x86_64/[0-9a-f]*/checkra1n")
}
[ -z "$CHECKRA1N_I486" ] && {
    CHECKRA1N_I486=$(curl -s "https://checkra.in/releases/" | grep -Po "https://assets.checkra.in/downloads/linux/cli/i486/[0-9a-f]*/checkra1n")
}
[ -z "$SILEO" ] && {
    SILEO="https://github.com$(curl -s https://github.com/Sileo/Sileo/releases | grep -Po "/Sileo\/Sileo/releases/download/[\d.]+/org\.coolstar\.sileo_[\d.]+_iphoneos-arm\.deb" | head -1)"
}

# Stage 1: User input
# Ask for the version and architecture if variables are empty
while [ -z "$VERSION" ]; do
    printf 'Version: '
    read -r VERSION
done
until [ "$ARCH" = 'x86_64' ] || [ "$ARCH" = 'x86' ]; do
    echo '1 x86_64'
    echo '2 x86'
    printf 'Which architecture? x86_64 (default) or x86 '
    read -r input_arch
    [ "$input_arch" = 1 ] || [ -z "$input_arch" ] && {
        ARCH='x86_64'
    }
    [ "$input_arch" = 2 ] && {
        ARCH='x86'
    }
done

[ "$ARCH" = "x86_64" ] && {
    REPO_ARCH="amd64"
    KERNEL_ARCH="amd64"
    CHECKRA1N="$CHECKRA1N_AMD64"
}
[ "$ARCH" = "x86" ] && {
    dpkg --add-architecture i386
    apt-get update
    apt install -y --no-install-recommends libusb-1.0-0-dev:i386 gcc-multilib
    REPO_ARCH="i386"
    KERNEL_ARCH="686"
    CHECKRA1N="$CHECKRA1N_I486"
}

# Stage 2: Preparations
# * Deletes old build attempts
# * Set some shell options useful for debugging, see set(1p)
# * Starts a stopwatch for build time
{
    umount work/chroot/proc
    umount work/chroot/sys
    umount work/chroot/dev
} > /dev/null 2>&1
rm -rf work/

set -e -u -v

start_time="$(date -u +%s)"

# Stage 3: Building 
# * Creates a fresh working directory
# * Fetches the alpine minirootfs
# * Configures the base system
#   * Install required packages
#   * Configure services
#   * Stripping unneeded kernel modules
#   * Remove unneeded files and directories
mkdir -p work/chroot work/iso/live work/iso/boot/grub
debootstrap --variant=minbase --arch="$REPO_ARCH" stable work/chroot 'http://deb.debian.org/debian/'
mount --bind /proc work/chroot/proc
mount --bind /sys work/chroot/sys
mount --bind /dev work/chroot/dev
cp /etc/resolv.conf work/chroot/etc

cat << ! | chroot work/chroot /usr/bin/env PATH=/usr/bin:/bin:/usr/sbin:/sbin /bin/bash
# Set debian frontend to noninteractive
export DEBIAN_FRONTEND=noninteractive

# Install requiered packages
apt-get install -y --no-install-recommends linux-image-$KERNEL_ARCH live-boot \
  systemd systemd-sysv usbmuxd libusbmuxd-tools openssh-client sshpass xz-utils dialog

# Remove apt as it won't be usable anymore
apt purge apt -y --allow-remove-essential
!
sed -i 's/COMPRESS=gzip/COMPRESS=xz/' work/chroot/etc/initramfs-tools/initramfs.conf

# # Strip unneeded kernel modules
sed -i '/^[[:blank:]]*#/d;s/#.*//;/^$/d' $KERNEL_MODULES
modules_to_keep=()
while IFS="" read -r p || [ -n "$p" ]
do
    modules_to_keep+=("-not" "-name" "$p") 
done < $KERNEL_MODULES
find work/chroot/lib/modules/*/kernel/* -type f "${modules_to_keep[@]}" -delete
find work/chroot/lib/modules/*/kernel/* -type d -empty -delete

# Compress kernel modules
find work/chroot/lib/modules/*/kernel/* -type f -name "*.ko" -exec strip --strip-unneeded {} +
find work/chroot/lib/modules/*/kernel/* -type f -name "*.ko" -exec xz --x86 -e9T0 {} +
depmod -b work/chroot "$(basename "$(find work/chroot/lib/modules/* -maxdepth 0)")"

# Do I have to rebuild the initramfs?
chroot work/chroot update-initramfs -u

# Remove unneeded files and folders
(
    cd work/chroot
    # Empty some directories to make the system smaller
    rm -f etc/mtab \
        etc/fstab \
        etc/ssh/ssh_host* \
        root/.wget-hsts \
        root/.bash_history
    rm -rf var/log/* \
        var/cache/* \
        var/backups/* \
        var/lib/apt/* \
        var/lib/dpkg/* \
        usr/share/doc/* \
        usr/share/man/* \
        usr/share/info/* \
        usr/share/icons/* \
        usr/share/locale/* \
        usr/share/zoneinfo/* \
        usr/lib/modules/*
)

# Copying scripts & Downloading resources
mkdir -p work/chroot/opt/odysseyra1n
cp scripts/* work/chroot/usr/local/bin
(
    cd work/chroot/usr/local/bin
    curl -sLO "$CHECKRA1N"
    chmod a+x ./*
)
(
    cd work/chroot/opt/odysseyra1n
    curl -sL -O https://github.com/coolstar/Odyssey-bootstrap/raw/master/bootstrap_1500.tar.gz \
        -O https://github.com/coolstar/Odyssey-bootstrap/raw/master/bootstrap_1600.tar.gz \
        -O https://github.com/coolstar/Odyssey-bootstrap/raw/master/bootstrap_1700.tar.gz \
        -O "$SILEO" \
        -O https://github.com/coolstar/Odyssey-bootstrap/raw/master/org.swift.libswift_5.0-electra2_iphoneos-arm.deb
    # Rolling everything into one xz-compressed tarball (reduces size hugely)
    gzip -dv ./*.tar.gz
    tar -vc ./* | xz --arm -zvce9T 0 > odysseyra1n_resources.tar.xz
    find ./* -not -name "odysseyra1n_resources.tar.xz" -exec rm {} +
)


# Configuring autologin
mkdir -p work/chroot/etc/systemd/system/getty@tty1.service.d
cat << ! > work/chroot/etc/systemd/system/getty@tty1.service.d/override.conf
[Service]
ExecStart=
ExecStart=-/sbin/agetty --noissue --autologin root %I
Type=idle
!

# Configure grub
cat << ! > work/iso/boot/grub/grub.cfg
insmod all_video
echo ''
echo '                     _ '
echo ' _   _  __ _  ___ __| |'
echo '| | | |/ _  |/ __/ _  |'
echo '| |_| | (_| | (_| (_| |'
echo ' \__, |\__,_|\___\__,_|'
echo ' |___/'
echo ''
echo 'Yet Another checkra1n Distribution'
echo '      by beerpsi'
linux /boot/vmlinuz boot=live quiet
initrd /boot/initrd.img
boot
!

# * Change hostname 
# * configure .bashrc
# * configure .dialogrc
echo 'yacd' > work/chroot/etc/hostname
cat << ! > work/chroot/root/.bashrc
export VERSION='$VERSION'
export DIALOGRC=/root/.dialogrc
/usr/local/bin/menu
!

# Build the ISO
umount work/chroot/proc
umount work/chroot/sys
umount work/chroot/dev
cp work/chroot/vmlinuz work/iso/boot
cp work/chroot/initrd.img work/iso/boot
mksquashfs work/chroot work/iso/live/filesystem.squashfs -noappend -e boot -comp xz -Xbcj x86 -Xdict-size 100%

## Creates output ISO dir (easier for GitHub Actions)
mkdir -p out
grub-mkrescue -o "out/yacd-$VERSION-$ARCH.iso" work/iso \
    --compress=xz \
    --fonts='' \
    --locales='' \
    --themes=''

end_time="$(date -u +%s)"
elapsed_time="$((end_time - start_time))"

echo "Built yacd-$VERSION-$ARCH in $((elapsed_time / 60)) minutes and $((elapsed_time % 60)) seconds."
