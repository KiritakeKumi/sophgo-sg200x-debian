# Debian release to build the rootfs from (trixie = Debian 13 stable, override with e.g. DEBIAN_SUITE=sid)
DEBIAN_SUITE ?= trixie
KERNELREV="3"
FSBLVERSION=1.0.0
# chip passed to the OpenSBI cvitek suspend platform (all supported boards are cv181x family)
OPENSBI_CHIP_ARCH ?= CV181X
PACKAGES="ca-certificates debian-archive-keyring dosfstools binutils file tree sudo bash-completion u-boot-menu openssh-server network-manager dnsmasq-base libpam-systemd ppp libengine-pkcs11-openssl iptables systemd-timesyncd vim usbutils parted exfatprogs systemd-sysv i2c-tools net-tools ethtool avahi-utils sudo gnupg rsync gpiod u-boot-tools libubootenv-tool"

IMAGE_ADDITIONS="usb-gadget"