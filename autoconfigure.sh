#!/usr/bin/env bash
set -e

project_dir="$(dirname "$(realpath "$0")")"
rootfs_location="./autoconfig-rootfs"
workdir="/root" # From the perspective of the chroot
rootfs_workdir="${rootfs_location}${workdir}" # From the perspective of the host
shell_cmd="/bin/ash --login" # --login is needed to source /etc/profile

"$project_dir/create_alpine_rootfs.sh" "$rootfs_location"

cp "$project_dir/scripts/"* "$rootfs_workdir"

script="
cd $workdir && ./installapkdeps.sh || { 
	echo 'Error: installapkdeps.sh failed'
	exit 1
} && ./clonerepos.sh || { 
	echo 'Error: clonerepos.sh failed'
	exit 1
} && ./makeinstall.sh || { 
	echo 'Error: makeinstall.sh failed'
	exit 1
} && echo 'Chroot scripts completed successfully'
"

"$project_dir/autochroot.sh" "$rootfs_location" $shell_cmd -c "$script"

echo "Autoconfigure script completed successfully, entering chroot"
"$project_dir/autochroot.sh" "$rootfs_location" $shell_cmd
