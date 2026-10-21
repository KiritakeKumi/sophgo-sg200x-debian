# Patches for the mainline kernel

These patches are applied, in the order of their names, on top of Linux v7.3 (see MAINLINE_COMMIT in scripts/Makefile)
when building with `KERNEL=mainline`. A patch that does not apply stops the build.

## Origin

`0007` to `0068` are the Sophgo SG200x patch series of the [Armbian build framework](https://github.com/armbian/build),
`patch/kernel/archive/sophgo-sg200x-7.3` at commit `c2d4d22b685c` (2026-10-19). Armbian collects them from the Linux
kernel mailing lists, from [queenkjuul](https://github.com/queenkjuul/milkv-duo-ubuntu) and from Lukasz Sobala, the
authors are in the headers of the patches. They are licensed under GPL-2.0 like the kernel they patch.

Left out on purpose:
- the arm64 variants of the patches (these boards run the C906, which is RISC-V)
- the TPU driver, the camera (media) patches and the CMA pool, because nothing in these images uses them yet
- a change for the build with the test suite of the fortify code

`0100` to `0102` are our own, they have to come after the Armbian patches that change the same device trees:
- `0100` puts the USB port of the Duo 256M in device mode (it only has a Type-C port)
- `0101` does the same for the LicheeRV Nano B and enables its ethernet
- `0102` enables the second SDHCI slot of the LicheeRV Nano B, which is where its AIC8800 WiFi chip sits
  (powered and muxed by the vendor u-boot already, so no pwrseq node and no pin config in it)

The Duo S gets its device mode from the `sg2000-milkv-duo-s-usb-device.dtb` variant that the Armbian patches build.

## Updating

To move to a newer kernel, take the series of Armbian for that version, check that the patches apply, and adapt
MAINLINE_COMMIT and MAINLINE_VERSION in scripts/Makefile. The AIC8800 build fixes are version specific as well
(`../aic8800-mainline`).
