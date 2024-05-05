#!/bin/sh
# Script designed for both ash and bash

set -e

# Initialize variables
chroot_dir="$1"
shift
efivars_mounted=0
resolvconf_created=0
exit_code=0
resolv_conf_dummy_id="# __TEMPORARY_BIND_MOUNT_TARGET__"

# Define mountpoints
mountpoints="proc sys dev dev/pts dev/shm run tmp"
unmountpoints="$(echo $mountpoints | tr ' ' '\n' | tac | tr '\n' ' ')"
num_mountpoints=$(echo $mountpoints | wc -w)

# Cleanup mode
if [ "$*" = "--clean" ]; then
	if [ ! -d "$chroot_dir" ]; then
		echo "Error: Specified chroot directory '$chroot_dir' not found."
		exit 1
	fi
	echo "Initiating cleanup of mounts in '$chroot_dir'."
	echo "Note: Ignore 'No such file or directory' and 'Invalid argument' errors."
	for mountpoint in sys/firmware/efi/efivars etc/resolv.conf $unmountpoints; do
		umount "$chroot_dir/$mountpoint" 2>/dev/null && echo "Unmounted $chroot_dir/$mountpoint" || true
	done
	if [ -f "$chroot_dir/etc/resolv.conf" ] && [ "$(cat "$chroot_dir/etc/resolv.conf")" = "$resolv_conf_dummy_id" ]; then
		echo "Cleaning temporary resolv.conf in chroot."
		rm "$chroot_dir/etc/resolv.conf"
	fi
	echo "Cleanup complete."
	exit 0
fi

# Check for existing mounts
mountpoints_found=0
for mountpoint in $mountpoints; do
	if mountpoint -q "$chroot_dir/$mountpoint"; then
		mountpoints_found=$((mountpoints_found + 1))
	fi
done

# Handle partial or full mounts
if [ $mountpoints_found -gt 0 ] && [ $mountpoints_found -lt $num_mountpoints ]; then
	echo "Error: Not all expected mounts are active in '$chroot_dir'. Consider '--clean'."
	exit 1
elif [ $mountpoints_found -eq $num_mountpoints ]; then
	echo "Operating in guest mode with existing mounts."
	chroot "$chroot_dir" "$@" || exit_code=$?
	echo "Chroot in guest mode exited. No cleanup performed."
	exit $exit_code
fi

# Mount all necessary filesystems
for mountpoint in $mountpoints; do
	case $mountpoint in
		proc)
			mount "/$mountpoint" "$chroot_dir/proc" -t proc -o nosuid,noexec,nodev ;;
		sys)
			mount "/$mountpoint" "$chroot_dir/sys" -t sysfs -o nosuid,noexec,nodev,ro ;;
		dev)
			mount "/$mountpoint" "$chroot_dir/dev" -t devtmpfs -o mode=0755,nosuid ;;
		dev/pts)
			mount "/$mountpoint" "$chroot_dir/dev/pts" -t devpts -o mode=0620,gid=5,nosuid,noexec ;;
		dev/shm)
			mount "/$mountpoint" "$chroot_dir/dev/shm" -t tmpfs -o mode=1777,nosuid,nodev ;;
		run)
			mount "/$mountpoint" "$chroot_dir/run"  --bind --make-private ;;
		tmp)
			mount "/$mountpoint" "$chroot_dir/tmp" -t tmpfs -o mode=1777,strictatime,nodev,nosuid ;;
		*)
			echo "Error: Unknown mountpoint '$mountpoint'."
			exit 1
			;;
	esac
done

# Optionally mount efivarfs for EFI variables
efivars_mount="sys/firmware/efi/efivars"
if [ -d "/$efivars_mount" ]; then
	echo "EFI vars found on host. Mounting efivarfs in chroot."
	mount "/$efivars_mount" "$chroot_dir/$efivars_mount" -t efivarfs -o nosuid,noexec,nodev
	efivars_mounted=1
fi

# Handle resolv.conf for network resolution
if [ ! -f "$chroot_dir/etc/resolv.conf" ]; then
	echo "Creating a temporary /etc/resolv.conf."
	echo "$resolv_conf_dummy_id" >"$chroot_dir/etc/resolv.conf"
	resolvconf_created=1
fi
mount --bind /etc/resolv.conf "$chroot_dir/etc/resolv.conf"

# Enter chroot and handle exit
chroot "$chroot_dir" "$@" || exit_code=$?

# Cleanup operations
umount "$chroot_dir/etc/resolv.conf"
[ $resolvconf_created -eq 1 ] && echo "Removing temporary resolv.conf." && rm "$chroot_dir/etc/resolv.conf"
[ $efivars_mounted -eq 1 ] && umount "$chroot_dir/$efivars_mount" && echo "Unmounted efivarfs."
for mountpoint in $unmountpoints; do
	umount "$chroot_dir/$mountpoint"
done
echo "Exited chroot and cleaned up mounts."

exit $exit_code
