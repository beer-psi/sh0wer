#!/bin/bash
# sh0wer

# Exit if user isn't root
[ "$(id -u)" -ne 0 ] && {
    echo 'Please run as root'
    exit 1
}

# Stage 0: Get download links
# * If any link is filled, the script will download from that link.
# * If empty, get the latest version from the website.
source ./.env
[ -z "$CHECKRA1N_AMD64" ] && {
    CHECKRA1N_AMD64=$(curl -s "https://checkra.in/releases/" | grep -Po "https://assets.checkra.in/downloads/linux/cli/x86_64/[0-9a-f]*/checkra1n")
}
[ -z "$CHECKRA1N_I486" ] && {
    CHECKRA1N_I486=$(curl -s "https://checkra.in/releases/" | grep -Po "https://assets.checkra.in/downloads/linux/cli/i486/[0-9a-f]*/checkra1n")
}
[ -z "$SILEO" ] && {
    SILEO="https://github.com$(curl -s https://github.com/Sileo/Sileo/releases | grep -Po "/Sileo\/Sileo/releases/download/[\d.]+/org\.coolstar\.sileo_[\d.]+_iphoneos-arm\.deb" | head -1)"
}
[ -z "$ZSTD" ] && {
    ZSTD="https://github.com$(curl -s https://github.com/facebook/zstd/releases | grep -Po "/facebook\/zstd/releases/download/v[\d.]+/zstd-[\d.]+\.tar\.gz" | head -1)"
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
rm -rf work

set -e -u -x

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
debootstrap --variant=minbase --arch="$REPO_ARCH" sid work/chroot 'http://deb.debian.org/debian/'
mount --bind /proc work/chroot/proc
mount --bind /sys work/chroot/sys
mount --bind /dev work/chroot/dev
cp /etc/resolv.conf work/chroot/etc

cat << ! | chroot work/chroot /usr/bin/env PATH=/usr/bin:/bin:/usr/sbin:/sbin /bin/bash
# Set debian frontend to noninteractive
export DEBIAN_FRONTEND=noninteractive

# Install required packages
apt-get update
apt-get install -y --no-install-recommends busybox linux-image-$KERNEL_ARCH live-boot \
    systemd systemd-sysv usbmuxd libusbmuxd-tools openssh-client sshpass dialog \
    build-essential curl ca-certificates

curl -LO $ZSTD
tar xf zstd*.tar.gz -C /opt
(
    cd /opt/zstd*
    make
    make install
)
rm -rf zstd*.tar.gz /opt/zstd*
ln -sf /usr/local/bin/zstd /usr/bin/zstd
!

# Switch compression to zstd 22 for space savings
sed -i 's/COMPRESS=gzip/COMPRESS=zstd/' work/chroot/etc/initramfs-tools/initramfs.conf
sed -i 's/zstd -q -19 -T0/zstd -q --ultra -22 -T0/g' work/chroot/sbin/mkinitramfs

# Debloating Debian
# * Compress kernel modules
find work/chroot/lib/modules/*/kernel/* -type f -name "*.ko" -exec strip --strip-unneeded {} +
find work/chroot/lib/modules/*/kernel/* -type f -name "*.ko" -exec xz --x86 -e9T0 {} +
depmod -b work/chroot "$(basename "$(find work/chroot/lib/modules/* -maxdepth 0)")"
chroot work/chroot update-initramfs -u

# * Purge a bunch of packages that won't be used anyway
cat << ! | chroot work/chroot /usr/bin/env PATH=/usr/bin:/bin:/usr/sbin:/sbin /bin/bash
export DEBIAN_FRONTEND=noninteractive
apt-get -y purge make dpkg-dev g++ gcc libc-dev make build-essential curl ca-certificates \
    perl-modules-5.32 perl libdpkg-perl libffi8 libk5crypto3 libkeyutils1 libkrb5-3 \
    libkrb5support0
apt-get -y autoremove
dpkg -P --force-all apt cpio gzip libgpm2
dpkg -P --force-all initramfs-tools initramfs-tools-core linux-image-$KERNEL_ARCH 
dpkg -P --force-all debconf libdebconfclient0
dpkg -P --force-all init-system-helpers
dpkg -P --force-all dpkg perl-base
!

# * Replacing coreutils with their Debian equivalents (123MB size reduction)
cat << "!" | chroot work/chroot /bin/bash
ln -sfv "$(command -v busybox)" /usr/bin/which
busybox --list | egrep -v "(busybox)|(init)|(sh)" | while read -r line; do
    if which $line &> /dev/null; then                               # If command exists
        if [ "$(stat -c%s $(which $line))" -gt 16 ]; then           # And we can gain storage space from making a symlink (symlinks are 16 bytes)
            ln -sfv "$(which busybox)" "$(which $line)"             # Then make one (ignore nonexistent commands /shrug)
        fi
    fi
done 
!

# * Empty unused directories
(
    cd work/chroot
    rm -f etc/mtab \
        etc/fstab \
        etc/ssh/ssh_host* \
        root/.wget-hsts \
        root/.bash_history \
        lib/xtables/libip6t_*
    rm -rf var/log/* \
        var/cache/* \
        var/backups/* \
        var/lib/apt/* \
        var/lib/dpkg/* \
        usr/share/doc/* \
        usr/share/man/* \
        usr/share/fonts/* \
        usr/share/info/* \
        usr/share/icons/* \
        usr/share/locale/* \
        usr/share/zoneinfo/* \
        usr/share/perl*/* \
        usr/lib/modules/*
)

# Copying scripts & Downloading resources
mkdir -p work/chroot/opt/odysseyra1n work/chroot/opt/a9x
cp scripts/* work/chroot/usr/local/bin
cp assets/.dialogrc work/chroot/root/.dialogrc
cp assets/PongoConsolidated.bin work/chroot/opt/a9x
(
    cd work/chroot/usr/local/bin
    curl -sLO "$CHECKRA1N"
    chmod a+x ./*
)
if [ "$GITHUB_ACTIONS" = true ]; then
    cp assets/odysseyra1n/odysseyra1n_resources.tar.zst work/chroot/opt/odysseyra1n
else
    (
        cd work/chroot/opt/odysseyra1n
        curl -sL -O https://github.com/coolstar/Odyssey-bootstrap/raw/master/bootstrap_1500.tar.gz \
            -O https://github.com/coolstar/Odyssey-bootstrap/raw/master/bootstrap_1600.tar.gz \
            -O https://github.com/coolstar/Odyssey-bootstrap/raw/master/bootstrap_1700.tar.gz \
            -O "$SILEO" \
            -O https://github.com/coolstar/Odyssey-bootstrap/raw/master/org.swift.libswift_5.0-electra2_iphoneos-arm.deb
        # Rolling everything into one zstd-compressed tarball (reduces size hugely)
        gzip -dv ./*.tar.gz
        tar -vc ./* | zstd -zcT0 --ultra -22 > odysseyra1n_resources.tar.zst
        find ./* -not -name "odysseyra1n_resources.tar.zst" -exec rm {} +
    )
fi


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
echo '     .-.     '
echo '    (   ).   '
echo '   (___(__)  '
echo "    ' ' ' '  "
echo "   ' ' ' '   "
echo ''
echo '    sh0wer   '
echo '  by beerpsi '
linux /boot/vmlinuz boot=live quiet
initrd /boot/initrd.img
boot
!

# * Change hostname 
# * configure .bashrc
# * configure .dialogrc
echo "$NAME" > work/chroot/etc/hostname
cat << ! > work/chroot/root/.bashrc
export VERSION='$VERSION'
export DIALOGRC=/root/.dialogrc
/usr/local/bin/menu
!

# Stage 4: Build the ISO
# * Make an zstd-compressed squashfs
umount work/chroot/proc
umount work/chroot/sys
umount work/chroot/dev
cp work/chroot/vmlinuz work/iso/boot
cp work/chroot/initrd.img work/iso/boot
mksquashfs work/chroot work/iso/live/filesystem.squashfs -noappend -e boot -comp xz -Xbcj x86 -Xdict-size 100%

## Creates output ISO dir (easier for GitHub Actions)
mkdir -p out
grub-mkrescue -o "out/$NAME-$VERSION-$ARCH.iso" work/iso \
    --compress=xz \
    --fonts='' \
    --locales='' \
    --themes=''

end_time="$(date -u +%s)"
elapsed_time="$((end_time - start_time))"

echo "Built $NAME-$VERSION-$ARCH in $((elapsed_time / 60)) minutes and $((elapsed_time % 60)) seconds."
