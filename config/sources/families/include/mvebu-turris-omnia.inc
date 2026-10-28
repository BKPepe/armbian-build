#
# SPDX-License-Identifier: GPL-2.0
#
# This file is a part of the Armbian Build Framework
# https://github.com/armbian/build/
#
# The Turris Omnia loads U-Boot from the SPI NOR flash, not from a disk.
# The U-Boot writers are in config/boards/turris-omnia.conf.
case $BRANCH in
	current | edge)
		BOOTSOURCE=$MAINLINE_UBOOT_SOURCE
		BOOTDIR=$MAINLINE_UBOOT_DIR
		BOOTBRANCH='tag:v2026.10'
		# The empty board_turris-omnia/1001-fdt_fixup_ethernet-add-logs.patch disables
		# the common patch of that name. That patch prints debug lines at each boot.
		BOOTPATCHDIR="${BOOTBRANCH#tag:}"
		BOOTSCRIPT='boot-turris-omnia.cmd:boot.cmd'
		UBOOT_TARGET_MAP=";;u-boot-with-spl.kwb:u-boot.flash"
		;;
esac
