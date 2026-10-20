# Debian release to build the rootfs from (trixie = Debian 13 stable, override with e.g. DEBIAN_SUITE=sid)
DEBIAN_SUITE ?= trixie
# mirror used to bootstrap the rootfs (the sources.list of the final image always points to deb.debian.org)
DEBIAN_MIRROR ?= http://deb.debian.org/debian/
KERNELREV="3"
# vendor: the Sophgo 5.10 BSP kernel (default), mainline: upstream Linux with the Sophgo patches (experimental)
KERNEL ?= vendor
# the mainline device tree to boot (relative to the dtb directory of the kernel package) and whether the board
# has the AIC8800 WiFi/Bluetooth chip, whose driver is then built into the mainline kernel
MAINLINE_AIC8800 ?= no
FSBLVERSION=1.0.0
# chip passed to the OpenSBI cvitek suspend platform (all supported boards are cv181x family)
OPENSBI_CHIP_ARCH ?= CV181X
PACKAGES="ca-certificates debian-archive-keyring dosfstools binutils file tree sudo bash-completion u-boot-menu openssh-server network-manager dnsmasq-base libpam-systemd ppp libengine-pkcs11-openssl iptables systemd-timesyncd vim usbutils parted exfatprogs systemd-sysv i2c-tools net-tools ethtool avahi-utils sudo gnupg rsync gpiod u-boot-tools libubootenv-tool"

IMAGE_ADDITIONS="usb-gadget"