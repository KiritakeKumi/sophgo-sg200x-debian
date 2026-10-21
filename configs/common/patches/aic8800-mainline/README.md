# Build fixes for the AIC8800 driver on mainline kernels

The AIC8800 WiFi/Bluetooth driver is not in the mainline kernel. For the mainline kernel variant it is taken from
[queenkjuul/aic8800-milkv-duos](https://github.com/queenkjuul/aic8800-milkv-duos) (the commit AIC8800_COMMIT in
scripts/Makefile), a clean up of the Milk-V vendor driver for the Milk-V Duo S, copied into the kernel tree and built
as in-tree modules by `scripts/mainline-aic8800.sh`.

The driver does not build on recent kernels by itself. These patches come from the
[Armbian build framework](https://github.com/armbian/build) (`patch/misc/aic8800`, commit `c2d4d22b685c`, by Lukasz
Sobala), licensed under GPL-2.0 like the driver:

- `aic8800-Fix-building-on-7.1-kernel.patch`, `...7.2-kernel.patch` and `...7.3-kernel.patch`: the changes in the
  cfg80211 interface of those kernel versions
- `aic8800-Derive-the-fallback-MAC-from-the-SoC-efuse.patch`: a stable MAC address when the chip has none

They are applied in the order of their names. When moving to another kernel version, add the patch for it.

The driver reads its firmware from the directory AIC8800_FW_DIR (scripts/Makefile), which is where the
`aic8800-firmware` addon installs it. This is a build time setting, `modprobe aic8800_bsp aic_fw_path=...`
overrides it.

Boards: the power-up of the chip in the driver uses the fixed GPIOs of the Milk-V Duo S (XGPIOA15 and
XGPIOE7 of the RTC bank). `aic8800-Support-the-LicheeRV-Nano-power-flow.patch` adds a board selection to
that: with `WLAN_BOARD=licheervnano` (set via AIC8800_BOARD in scripts/Makefile) no GPIO is touched,
because the vendor u-boot of the LicheeRV Nano has already powered the chip (a GPIOA26 pulse, held high)
and muxed the SD1 pads before the kernel starts. Claiming XGPIOA15 there would switch off the SD card,
it is the card power enable on that board.
