```
     .-.     
    (   ).   
   (___(__)  
    ' ' ' '  
   ' ' ' '   
```

Another Linux-based distribution for jailbreaking iOS devices on the A7-A11 chipset with the checkra1n jailbreak.

It aims to be fast and lightweight, yet easy to use.

<p align="center">
    <img src="https://user-images.githubusercontent.com/92439990/146394241-cd4e7ba5-db91-43f5-a826-1f5ab7c9a939.png"
</p>
     
<p align="center">
    <a href="#usage">Usage</a>
    &#8226;
    <a href="#building-sh0wer">Building</a>
</p>

-------
# Usage
You'll need a USB storage device with at least 128MB of storage.

Download the appropriate ISO for your PC:
- `x86_64` is for 64-bit CPUs
- `x86` is for 32-bit CPUs

If you don't know what type of CPU you have:
<details>
    <summary>Windows</summary>
    
Open File Explorer, right click This PC and select Properties, look for the line "System type":
- `x64-based processor` means your CPU is 64-bit
- `x86-based processor` means your CPU is 32-bit
  
</details>

**I will only support Ventoy, use other tools at your own risk**

1. Get the latest Ventoy for Windows here: https://github.com/ventoy/Ventoy/releases
2. After downloading and extracting the Ventoy .zip file, connect your USB flash drive then open the Ventoy2Disk.exe program. Back up any files on the USB now, you can copy them back later.
3. Select your USB flash drive at the top then press Install. You will be prompted twice to confirm that you are okay with deleting all data on the drive.
4. Copy the Odysseyn1x .iso file to the newly-flashed "Ventoy" USB.

# Building sh0wer
## Installing build dependencies
### Debian and its derivatives
```
sudo apt-get update
sudo apt-get install -y --no-install-recommends wget debootstrap grub-pc-bin \
    grub-efi-amd64-bin mtools squashfs-tools xorriso ca-certificates curl \
    libusb-1.0-0-dev gcc make gzip xz-utils unzip libc6-dev zstd rename
```
## Environment variables
All build variables are inside the `.env` file.
```bash
VERSION="YOUR_VERSION"
ARCH="ARCHITECTURE_TO_BUILD" # Available architectures: x86_64 and x86

# Leave empty to automatically grab the latest version
CHECKRA1N_AMD64=""
CHECKRA1N_I486=""
SILEO=""
ZSTD="" # gz-compressed archive of release from https://github.com/facebook/zstd
```

## Advanced: Kernel modules
Inside the file `modules` is a list of kernel modules to keep. If you made a copy of the `modules` file, you can instruct the build script to read from the file you modified by editing the `KERNEL_MODULES` variable at the start of the script.

### Notes
- The file supports commenting by putting `#` at the beginning of the line (you cannot do in-line commenting). 
- Any blank lines must be totally blank (can be removed entirely with `sed '/^$/d'`)
- If you're on Windows, ensure that you are using the `LF` newline character so as not to cause any issues.



