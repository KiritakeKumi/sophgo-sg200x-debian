#!/bin/sh
# Add the AIC8800 SDIO WiFi/Bluetooth driver to a mainline kernel tree, as in-tree modules.
#
# usage: mainline-aic8800.sh <kernel tree> <driver checkout> <patch dir> <firmware dir>
#
# The driver is the queenkjuul/aic8800-milkv-duos fork of the Milk-V vendor driver. It does not build on
# recent kernels by itself, the patches in <patch dir> (from Armbian) fix that. Copying it into the
# kernel tree is cheaper than DKMS under emulation and needs no headers package on the board.
set -e

KERNEL=$1
DRIVER=$2
PATCHES=$3
FWDIR=$4

WIRELESS=$KERNEL/drivers/net/wireless
DEST=$WIRELESS/aicsemi

rm -rf "$DEST"
cp -a "$DRIVER/aicsemi" "$DEST"

# the vendor sources are not maintained against new kernels, the patches keep them building
for p in $(ls "$PATCHES"/*.patch | sort); do
	echo "applying $(basename "$p")"
	(cd "$KERNEL" && git apply --ignore-whitespace "$p")
done

# aic8800_bsp/Makefile assigns the firmware path itself (with '=', so it wins over the Kconfig value), and
# aic8800_fdrv takes the value from the kernel config, set both
sed -i "s|^CONFIG_AIC_FW_PATH = .*|CONFIG_AIC_FW_PATH = \"$FWDIR\"|" "$DEST/aic8800/aic8800_bsp/Makefile"
grep -qF "CONFIG_AIC_FW_PATH = \"$FWDIR\"" "$DEST/aic8800/aic8800_bsp/Makefile" || {
	echo "could not set the firmware path in the AIC8800 Makefile" >&2
	exit 1
}

# hook the driver into the wireless Kconfig and Makefile
if ! grep -q 'aicsemi/Kconfig' "$WIRELESS/Kconfig"; then
	sed -i 's|^source "drivers/net/wireless/admtek/Kconfig"|source "drivers/net/wireless/aicsemi/Kconfig"\n&|' "$WIRELESS/Kconfig"
	grep -q 'aicsemi/Kconfig' "$WIRELESS/Kconfig" || {
		echo "could not add the AIC8800 Kconfig to drivers/net/wireless/Kconfig" >&2
		exit 1
	}
fi
if ! grep -q 'aicsemi/' "$WIRELESS/Makefile"; then
	echo 'obj-$(CONFIG_WLAN_VENDOR_AICSEMI)	+= aicsemi/' >> "$WIRELESS/Makefile"
fi
