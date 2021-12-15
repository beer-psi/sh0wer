#!/bin/sh
# YACD - Yet Another checkra1n Distribution

# Exit if user isn't root
[ "$(id -u)" -ne 0 ] && {
    echo 'Please run as root'
    exit 1
}

# Stage 0: Get download links
# * If any link is filled, the script will download from that link.
# * If empty, get the latest version from the website.
AMD64_ROOTFS=""
I486_ROOTFS=""
CHECKRA1N_AMD64=""
CHECKRA1N_I486=""
SILEO=""
[ -z "$AMD64_ROOTFS" ] && {
    AMD64_ROOTFS=$(curl -s "https://alpinelinux.org/downloads/" | sed 's/&#x2F;/\//g' | grep -Po "https://dl-cdn\.alpinelinux\.org/alpine/v[\d.]+/releases/x86_64/alpine-minirootfs-[\d.]+-x86_64\.tar\.gz" | head -1)
}
[ -z "$I486_ROOTFS" ] && {
    I486_ROOTFS=$(curl -s "https://alpinelinux.org/downloads/" | sed 's/&#x2F;/\//g' | grep -Po "https://dl-cdn\.alpinelinux\.org/alpine/v[\d.]+/releases/x86/alpine-minirootfs-[\d.]+-x86\.tar\.gz" | head -1)
}
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
    ROOTFS="$AMD64_ROOTFS"
    CHECKRA1N="$CHECKRA1N_AMD64"
}
[ "$ARCH" = "x86" ] && {
    ROOTFS="$I486_ROOTFS"
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

set -e -u -v -x

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
curl -sL "$ROOTFS" | tar -xzC work/chroot
mount --bind /proc work/chroot/proc
mount --bind /sys work/chroot/sys
mount --bind /dev work/chroot/dev
cp /etc/resolv.conf work/chroot/etc
sed -i 's/v3\.15\/community/edge\/community/g' work/chroot/etc/apk/repositories
echo "http://dl-cdn.alpinelinux.org/alpine/edge/testing" >> work/chroot/etc/apk/repositories

cat << ! | chroot work/chroot /usr/bin/env PATH=/usr/bin:/bin:/usr/sbin:/sbin /bin/sh
# Installs required packages
apk upgrade
apk add alpine-base ncurses ncurses-terminfo-base xz eudev usbmuxd libusbmuxd-progs openssh-client sshpass usbutils dialog linux-lts linux-firmware-none util-linux

# Configure services
rc-update add bootmisc
rc-update add hwdrivers
rc-update add networking
rc-update add udev
rc-update add udev-trigger
rc-update add udev-settle
rc-update add local

# Make mkinitfs use highest level of compression possible
sed -i 's/xz -C crc32 -T 0/xz -C crc32 --x86 -e9 -T0/g' /sbin/mkinitfs
!

# Strip unneeded kernel modules
cat << ! > work/chroot/etc/mkinitfs/features.d/checkn1x.modules
kernel/drivers/usb/host
kernel/drivers/hid/usbhid
kernel/drivers/hid/hid-generic.ko
kernel/drivers/hid/hid-cherry.ko
kernel/drivers/hid/hid-apple.ko
kernel/net/ipv4
!
chroot work/chroot /usr/bin/env PATH=/usr/bin:/bin:/usr/sbin:/sbin /sbin/mkinitfs -F "checkn1x" -k -t /tmp -q "$(basename "$(find work/chroot/lib/modules/* -maxdepth 0)")"
rm -rf work/chroot/lib/modules
mv work/chroot/tmp/lib/modules work/chroot/lib
find work/chroot/lib/modules/* -type f -name "*.ko" -exec strip --strip-unneeded {} +
find work/chroot/lib/modules/* -type f -name "*.ko" -exec xz --x86 -e9T0 {} +
depmod -b work/chroot "$(basename "$(find work/chroot/lib/modules/* -maxdepth 0)")"

# Remove unneeded files and folders
(
    cd work/chroot
    rm -f root/.ash_history \
        sbin/apk \
        etc/resolv.conf \
    rm -rf tmp \
        var/log \
        var/cache \
        var/lib/apk \
        usr/share/apk \
        usr/share/man \
        etc/apk \
        etc/mtab \
        etc/fstab \
        etc/mkinitfs \
        lib/apk
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
        -O https://github.com/coolstar/Odyssey-bootstrap/raw/master/org.coolstar.sileo_2.0.3_iphoneos-arm.deb \
        -O https://github.com/coolstar/Odyssey-bootstrap/raw/master/org.swift.libswift_5.0-electra2_iphoneos-arm.deb
    # Rolling everything into one xz-compressed tarball (reduces size hugely)
    gzip -dv ./*.tar.gz
    tar -vc ./* | xz --arm -zvce9T 0 > odysseyra1n_resources.tar.xz
    find ./* -not -name "odysseyra1n_resources.tar.xz" -exec rm {} +
)

# Fix ncurses
cp -r work/chroot/etc/terminfo work/chroot/usr/share/terminfo

# Configuring autologin
cat << ! | chroot work/chroot /usr/bin/env PATH=/usr/bin:/bin:/usr/sbin:/sbin /bin/sh
cd /etc/init.d

echo 'agetty_options="--autologin root --noissue"' > /etc/conf.d/agetty-autologin
ln -s agetty agetty-autologin.tty1
rc-update add agetty-autologin.tty1 default
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
linux /boot/vmlinuz-lts boot=live quiet
initrd /boot/initramfs-lts
boot
!

# Change hostname and configure .bashrc
echo 'yacd' > work/chroot/etc/hostname
echo "export VERSION='$VERSION'" > work/chroot/root/.bashrc
echo '/usr/local/bin/menu' >> work/chroot/root/.bashrc
echo 'DIALOGRC=/root/.dialogrc' >> work/chroot/root/.bashrc

# Build the ISO
umount work/chroot/proc
umount work/chroot/sys
umount work/chroot/dev
cp work/chroot/boot/vmlinuz-lts work/iso/boot
cp work/chroot/boot/initramfs-lts work/iso/boot
rm -rf work/chroot/boot
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

# Stop echoing commands
set +x
echo "Built yacd-$VERSION-$ARCH in $((elapsed_time / 60)) minutes and $((elapsed_time % 60)) seconds."
