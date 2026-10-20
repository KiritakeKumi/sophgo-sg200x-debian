# Debian Images for Sophgo cv181x/sg200x based boards 
This repository builds Debian 13 (trixie) images for Sophgo cv181x/sg200x based boards such as MilkV Duo256/DuoS and Sipeed LicheeRvNano.

(Note, we don't support the MilkV Duo, as it does not have enough ram to run Debian)

The images aim to be as close to possible to debian best practices as possible

The images use the Sophgo vendor 5.10 kernel by default. There is also an experimental image with a recent mainline
Linux kernel, see [Kernels](#kernels).

## Flashing the Image

### Duo256, DuoS, and LicheeRVNano
To flash from linux, either build your own image, or download a image from the releases page, and then run the following command:
```
sudo dd if=image/(board)_sd.img of=/dev/sdX bs=4M status=progress
```

From windows, you can use tools such as balena etcher

where the (board)_sd.img is the image file you want to flash, and /dev/sdX is the device you want to flash to.
(if you build for a different board, the image file name will be different)

### DuoS with EMMC
To flash the DuoS with EMMC, you need to use the vendor tools to flash the image to the EMMC. You can follow the
instructions at https://milkv.io/docs/duo/getting-started/duos#emmc-version-firmware-burning but instead of downloading 
the  milkv-duos-emmc-v1.1.0-2024-0410.zip file, you download the duos_emmc.zip from the releases on this repository.

if you already have a image installed, but wish to upgrade, when u-boot loads up, interupt the boot process by pressing any
key and typing the following commands:
```
cvi_update
```

The flashing should then continue


## Image Info
Logins: root/rv and debian/rv

(root login is disabled via SSH, login via debian, and SU to root if needed)

On the first boot the root partition and its filesystem are grown to fill the SD card or the eMMC, and the SSH host keys are generated.

### Kernels
| | vendor (default) | mainline (experimental) |
|---|---|---|
| Kernel | Sophgo 5.10 BSP kernel | Linux 7.3 plus the Sophgo patches |
| Build with | `make BOARD=... image` | `make BOARD=... KERNEL=mainline image` |
| Compiler | the toolchain of the Sophgo SDK (x86_64 only) | Debian's `riscv64-linux-gnu` cross compiler, or the native one |
| Tested on hardware | yes | **no, not yet** |

The mainline kernel is built from the upstream kernel sources, with the patches in `configs/common/patches/linux-mainline`.
They are the Sophgo SG200x patch series of [Armbian](https://github.com/armbian/build) (which collects the work of
queenkjuul, Lukasz Sobala and others, most of it is on its way to the mainline kernel) and a few changes of our own.
The AIC8800 WiFi/Bluetooth driver is not in the mainline kernel, it is built into the kernel from
[queenkjuul/aic8800-milkv-duos](https://github.com/queenkjuul/aic8800-milkv-duos) with the build fixes from Armbian.

What works on the mainline kernel is what the patches and the device trees cover:

| | Duo S | Duo 256M | LicheeRV Nano |
|---|---|---|---|
| SD card / eMMC | yes / yes | yes / - | yes / - |
| Ethernet | yes | no hardware | yes (untested) |
| WiFi and Bluetooth | yes | no hardware | **no** |
| USB-C as a USB network adapter | yes | yes | yes |
| USB Type-A host port | no, see the note below | no hardware | no hardware |

* The USB port is a single controller that can either be a device (the board shows up as a network adapter, this is the
  default) or a host (the Type-A port of the Duo S), but not both. The mode is fixed by the device tree.
* The vendor-only features (camera, display, TPU) are not available on the mainline kernel.
* The `linux-headers` package is not built for the mainline kernel.
* The `u-boot` environment of the mainline images loads the device tree at a higher address than the vendor ones,
  because the mainline kernel is larger (`configs/common/patches/u-boot-mainline`).

### USB Gadget Support
by default, a rndis interface is started on the USB port, and the IP address is
10.42.0.1 - It also starts a DHCP Server on that interface, so your PC should automatically get an IP address in the 10.42.0.x range

To Disable the rndis interface, you can run the following command:
```
systemctl disable usb-gadget-rndis
```

There is also a option to start a serial port (ACM) interface instead of the rndis interface, to do this, you can run the following command:
```
systemctl disable usb-gadget-rndis
systemctl enable usb-gadget-acm
```

After executing these commands, you need to reboot.

### DuoS - USB Type A Port
After disabling the usb-gadgets, if you want to use the USB Type A Ports, then you need to turn them on:
```
systemctl enable usb-switch
```

and reboot afterwards. 

### Wifi on DuoS/LicheeRVNano
For the LicheeRVNano/DuoS board, Wifi is enabled (with the mainline kernel only on the DuoS, see [Kernels](#kernels)). To connect to your wifi network, execute the following command and select "Activate a connection" and select your wifi network:
```
nmtui
```

### Ethernet
For Boards with eithernet, they should automatically get a IP address if your network has a DHCP Server. You can configure the 
ethernet port in nmtui

### Camera/ISP/Panel Support
The images with the vendor 5.10 kernel exclude the following drivers:
- mipi-rx/csi drivers
- mipi-tx/dsi drivers
- TPU Drivers
- Any of the Video Encoding Drivers

(this is mainly due to compatibility reasons with the glibc version in debian and musl version used in the vendor images)

The images, by default, do not allocate any memory for the ION heap, as they are unused in this image, so you get the full memory of each device

### Ardunio/Freertos Support
The images also include the remoteproc and mailbox drivers so you can load up ardunio/freertos images on the small C906 core. 

### Additional Packages
This image also adds the debian repository for https://github.com/Fishwaldo/sophgo-sg200x-packages so you can install additional repositories. The debian repository is hosted at 
https://sophgo.my-ho.st:8443/ which pulls down the compiled debian packages from the above github repository occasionally.


## Building the Image
To build a stock image with no modifications:
```
podman run --privileged -it --rm -v ./configs/:/configs -v ./image:/output ghcr.io/fishwaldo/sophgo-sg200x-debian:master make BOARD=licheervnano image
```

Replace the licheervnano with the board you want to build for:
- duo256
- duos
- licheervnano

If you want to create a image for the DuoS with EMMC, you can add "STORAGE_TYPE=emmc" to the make command:
```
podman run --privileged -it --rm -v ./configs/:/configs -v ./image:/output ghcr.io/fishwaldo/sophgo-sg200x-debian:master make BOARD=duos STORAGE_TYPE=emmc image
```

The Docker image will build the image and place it in the image directory

To build the image with the experimental mainline kernel, add "KERNEL=mainline" to the make command:
```
podman run --privileged -it --rm -v ./configs/:/configs -v ./image:/output ghcr.io/fishwaldo/sophgo-sg200x-debian:master make BOARD=duos KERNEL=mainline image
```

addition make targets are available when building:
- image - builds the image
- clean - cleans the build directory
- linux - build a kernel debian package (of the kernel selected with KERNEL)
- linux-mainline - build the mainline kernel debian package
- fsbl - build the fsbl debain package (that includes cvitek-fsbl, opensbi and u-boot)

Some variables can be changed on the make command line:
- BOARD, STORAGE_TYPE (sd or emmc) and KERNEL (vendor or mainline), as described above
- DEBIAN_SUITE - the Debian release of the root filesystem, the default is trixie (Debian 13). The vendor kernel needs
  a systemd that still works with a 5.10 kernel: the one of Debian 13 does, but the one in sid (260 and newer) does not.
- DEBIAN_MIRROR - the mirror used to create the root filesystem, the default is http://deb.debian.org/debian/
- CROSS - the prefix of the cross compiler of the vendor kernel, u-boot, opensbi and fsbl. When building on a riscv64
  machine, "CROSS=" (empty) builds with the compiler of the system. The vendor kernel needs the toolchain of the SDK, though.

The sources of the kernel, u-boot, opensbi and fsbl are fetched from GitHub by the exact commit that is pinned at the top of
scripts/Makefile.

## Customizing the Image
The configs directory contains patches, configuration and device tree files that are used to build the image.

The configs/common directory contains the common configuration for all boards, and the configs/licheervnano and configs/duo256 directories contain the board specific configuration.

To add packages to the image, either add the package name in PACKAGES variable of configs/settings.mk or if the packae is specific to a board, add it to the configs/\<board\>/settings.mk file

Patches for the kernel, opensbi, u-boot or fsbl can be placed in configs/common/patches/ or configs/\<board\>/patches/ depending what they are for.
The patches of the mainline kernel are in the linux-mainline directories there (configs/common/patches/linux-mainline), the
kernel configuration is configs/common/linux-mainline/defconfig and local.config (the changes on top of it), the patches that are
only applied to u-boot when building with the mainline kernel are in u-boot-mainline, and the build fixes for the AIC8800
driver in aic8800-mainline. The device tree of the mainline kernel to boot is MAINLINE_DTB in the settings of the board.

To assist with developing the image, you can get a shell in the docker container by running:
```
docker run --privileged -it --rm -v ./configs/:/configs -v ./image:/output -v ./scripts/:/builder builder /bin/bash
```
inside the container, packages are build in the /builder/ directory, and the rootfs is placed at /rootfs/ directory

# TODO
- DeviceTree Overlay Support (the mainline kernel already builds the overlays of its device trees, but u-boot does not apply them yet)
- Add support for the MIPI-CSI/DSI drivers (Sample applications would be in the sophgo-sg200x-packages repository if they do not depend upon a musl libc version)
- Add support for the TPU drivers
- Test the mainline kernel on all the boards, and make it the default when it is as good as the vendor kernel
