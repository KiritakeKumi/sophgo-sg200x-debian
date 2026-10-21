$(BUILDDIR)/aic8800-firmware-stamp:
	@echo "$(COLOUR_GREEN)Installing aic8800-firmware for $(BOARD)$(END_COLOUR)"
	@rm -rf $(BUILDDIR)/aic8800-firmware
	@git clone --depth 1 https://github.com/armbian/firmware.git $(BUILDDIR)/aic8800-firmware
	@mkdir -p /rootfs/lib/firmware/aic8800_sdio/aic8800/
	@cp -a $(BUILDDIR)/aic8800-firmware/aic8800/SDIO/aic8800/ /rootfs/lib/firmware/aic8800_sdio/
#	The D80 (DuoS) chip needs its own firmware set, which replaces the generic one.
#	Installing it on the other boards bricks their wifi: the driver of the plain
#	AIC8800 (e.g. the U03 revision of the LicheeRV Nano) loads the D80 fmacfw.bin
#	and times out starting the firmware.
ifeq ($(BOARD),duos)
	@cp -a $(BUILDDIR)/aic8800-firmware/aic8800/SDIO/aic8800D80/* /rootfs/lib/firmware/aic8800_sdio/aic8800/
endif
	@touch $@
