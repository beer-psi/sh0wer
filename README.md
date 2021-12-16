Another Linux-based distribution for jailbreaking iOS devices on the A7-A11 chipset with the checkra1n jailbreak.

It aims to be fast, easy to use, yet lightweight. 

-------

# Building yacd
## Installing build dependencies
### Debian and its derivatives
```
sudo apt-get update
sudo apt-get install -y --no-install-recommends wget debootstrap grub-pc-bin \
    grub-efi-amd64-bin mtools squashfs-tools xorriso ca-certificates curl \
    libusb-1.0-0-dev gcc make gzip xz-utils unzip libc6-dev
```
## Environment variables
These environment variables can be set prior to executing the script
```bash
VERSION="YOUR_VERSION"
ARCH="ARCHITECTURE_TO_BUILD" # Available architectures: x86_64 and x86
```

These variables can be edited inside `build.sh`, however they are not needed:
```bash
# Leave empty to automatically grab the latest version
CHECKRA1N_AMD64=""
CHECKRA1N_I486=""
SILEO=""
```

## Advanced: Kernel modules
Inside the file `modules` is a list of kernel modules to keep. If you made a copy of the `modules` file, you can instruct the build script to read from the file you modified by editing the `KERNEL_MODULES` variable at the start of the script.

The file supports commenting by putting `#` at the beginning of the line (you cannot do in-line commenting). 

Any blank lines must be totally blank (can be removed entirely with `sed '/^$/d'`)




