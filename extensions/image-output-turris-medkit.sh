# @description Builds a medkit for the Turris Omnia: `omnia-medkit-${version}.tar.gz` and its `.sha256` in the output folder. The Turris rescue system installs the medkit from a USB flash drive to the eMMC (reset with 4 LEDs). Only for `BOARD=turris-omnia`.

#
# SPDX-License-Identifier: GPL-2.0
#
# This file is a part of the Armbian Build Framework https://github.com/armbian/build/
#
# The rescue system repartitions the eMMC and makes a btrfs file system on
# /dev/mmcblk0p1. It unpacks the medkit to the subvolume @ and links /boot.scr
# to @/boot/boot.scr. boot-turris-omnia.cmd boots from that layout. The rescue
# system takes the medkit with the greatest name, so keep only one on the
# flash drive.

function extension_prepare_config__prepare_turris_medkit() {
	[[ "${BOARD}" == "turris-omnia" ]] || exit_with_error "${EXTENSION} only supports the Turris Omnia" "${BOARD}"
	# The rescue system makes an unencrypted file system
	[[ "${CRYPTROOT_ENABLE:-no}" != "yes" ]] || exit_with_error "${EXTENSION} does not support an encrypted root" "CRYPTROOT_ENABLE=yes"
	# The root is btrfs, so add btrfs-progs like fs-btrfs-support does. Users need
	# it for example to delete @factory.
	add_packages_to_image btrfs-progs
	return 0
}

function pre_umount_final_image__900_build_turris_medkit() {
	[[ -z $version ]] && exit_with_error "version is not set"

	# The build compresses and moves only ${DESTIMG}/${version}.* to the output
	# folder. The rescue system needs the name omnia-medkit*.tar.gz, so this hook
	# moves the medkit itself. It builds the medkit in ${DESTIMG}, which the build
	# removes on failure.
	declare medkit="omnia-medkit-${version}.tar.gz" staging tarball
	staging="$(mktemp -d -p "${DESTIMG}" "turris-medkit.XXXXXX")"
	tarball="${staging}/${medkit}"
	display_alert "Building Turris medkit" "${medkit}" "info"

	# The rescue system makes the file system, so its UUID is not known here. The
	# boot script finds the root by PARTUUID. No compress option: the stock U-Boot
	# in the NOR flash cannot read files that the kernel compressed with zstd. The
	# medkit has only one file system, so drop the other UUID lines, like /boot.
	awk '$2 == "/" { print "/dev/mmcblk0p1 / btrfs defaults,commit=120,subvol=@ 0 0"; next } $1 ~ /^UUID=/ { next } { print }' "${MOUNT}/etc/fstab" > "${staging}/fstab"
	sed -e '/^rootdev=/d' -e '/^rootfstype=/d' "${MOUNT}/boot/armbianEnv.txt" > "${staging}/armbianEnv.txt"
	chmod --reference="${MOUNT}/etc/fstab" "${staging}/fstab"
	chmod --reference="${MOUNT}/boot/armbianEnv.txt" "${staging}/armbianEnv.txt"

	# GNU tar format and numeric owners like the official medkits. The image itself
	# is not changed. tar also applies the exclusions to the new fstab and
	# armbianEnv.txt, so they have other names here. --transform puts them in
	# place. Its S flag leaves symbolic link targets unchanged.
	declare -a cmd
	cmd=(tar --create --file=- --format=gnu --numeric-owner --anchored
		--exclude=./lost+found --exclude=./boot/lost+found --exclude=./etc/fstab --exclude=./boot/armbianEnv.txt
		--exclude='./dev/*' --exclude='./proc/*' --exclude='./run/*' --exclude='./sys/*' --exclude='./tmp/*'
		--transform='s,^fstab$,./etc/fstab,S' --transform='s,^armbianEnv\.txt$,./boot/armbianEnv.txt,S'
		--directory="${MOUNT}" . --directory="${staging}" fstab armbianEnv.txt)
	run_host_command_logged "${cmd[*]@Q}" "|" pigz ">" "${tarball@Q}"
	# The current rescue system compares this line with its sha256sum output. The
	# old rescue system runs sha256sum -c.
	(cd "${staging}" && sha256sum "${medkit}" > "${medkit}.sha256")

	# rsync writes each file under a temporary name and renames it when it is
	# complete. So the output folder never has a partial medkit, even when it is
	# on another file system.
	mkdir -p "${FINALDEST}"
	cmd=(rsync -av --no-owner --no-group --remove-source-files "${tarball}" "${tarball}.sha256" "${FINALDEST}/")
	run_host_command_logged "${cmd[*]@Q}"
	rm -rf "${staging}"
	display_alert "Built Turris medkit" "${FINALDEST}/${medkit}" "info"
}
