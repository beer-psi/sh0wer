Another Linux-based distribution for jailbreaking iOS devices on the A7-A11 chipset with the checkra1n jailbreak.

It aims to be fast and lightweight, yet easy to use.

![Sample image](https://user-images.githubusercontent.com/92439990/146394241-cd4e7ba5-db91-43f5-a826-1f5ab7c9a939.png)

-------
# Usage
Download the appropriate ISO for your PC:
- `x86_64` is for 64-bit CPUs
- `x86` is for 32-bit CPUs

If you don't know what type of CPU you have, open File Explorer, right click This PC and select Properties, look for the line "System type":
- `x64-based processor` means your CPU is 64-bit
- `x86-based processor` means your CPU is 32-bit

1. Get the latest "Release" ISO from the [Releases tab](https://github.com/extradummythicc/yacd/releases)
2. Get the ROSA Image Writer [here](http://wiki.rosalab.ru/en/images/6/62/RosaImageWriter-2.6.2-win.zip). If another USB flashing tool (like balenaEtcher) floats your boat, you can use it instead.
3. Open ROSA Image Writer and write the downloaded ISO to your USB
4. Reboot, enter your BIOS menu (you'll have to google for this) and select to boot from the USB.

After you're done using yacd, if you want to wipe your USB so you can use it normally, just use the "Clear" button inside ROSA.

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

These variables set the download link for various resources.  
They can be edited inside `build.sh`, however they are not needed:
```bash
# Leave empty to automatically grab the latest version
CHECKRA1N_AMD64=""
CHECKRA1N_I486=""
SILEO=""
```

## Advanced: Kernel modules
Inside the file `modules` is a list of kernel modules to keep. If you made a copy of the `modules` file, you can instruct the build script to read from the file you modified by editing the `KERNEL_MODULES` variable at the start of the script.

### Notes
- The file supports commenting by putting `#` at the beginning of the line (you cannot do in-line commenting). 
- Any blank lines must be totally blank (can be removed entirely with `sed '/^$/d'`)
- If you're on Windows, ensure that you are using the `LF` newline character so as not to cause any issues.



