#!/usr/bin/env bash
set -e

# Check if a custom target directory was specified
if [ -z "$1" ]; then
	target_dir="./alpine-minirootfs"
	echo "No custom target directory specified; using '$target_dir'"
else
	target_dir="$1"
fi

# Setup architecture and repository URL
arch="$(uname -m)"
flavor="edge"  # Currently only supports 'edge' version
repo_url="https://dl-cdn.alpinelinux.org/alpine/${flavor}/releases/${arch}"

# Fetch repository data
repo_data=$(curl -fsSL "$repo_url")
tarball_versions=$(echo "$repo_data" | grep -oP 'alpine-minirootfs-\K\d{8}' | sort -ur)
latest_tarball_date=$(echo "$tarball_versions" | head -n 1)
next_4_tarball_dates=$(echo "$tarball_versions" | head -n 5 | tail -n +2 | tr '\n' ',' | head -c -1)

# Construct download URLs
rootfs_file_pattern="alpine-minirootfs-${latest_tarball_date}-${arch}.tar.gz"
rootfs_url="${repo_url}/${rootfs_file_pattern}"
rootfs_sha512_url="${repo_url}/${rootfs_file_pattern}.sha512"

# Display version information
echo -n "Latest detected Alpine version: $latest_tarball_date"
echo " (next older 4: $next_4_tarball_dates)"
echo "Rootfs URL: $rootfs_url"
echo "Rootfs SHA512 URL: $rootfs_sha512_url"
echo -n "Target directory: $target_dir"

# Check if target directory exists
if [ -e "$target_dir" ]; then
	echo -e "\x1B[31m (!!! Path exists and will be removed !!!)\x1B[0m"
else
	echo -e "\x1B[32m (Path does not exist and will be created)\x1B[0m"
fi

# Prompt user to proceed
read -p "Press enter to continue or Ctrl+C to cancel"

# Prepare target directory
rm -rf "$target_dir"
mkdir "$target_dir"

# Download and verify the rootfs tarball
echo "Downloading rootfs from '$rootfs_url'"
curl -fL "$rootfs_url" -o $target_dir/$rootfs_file_pattern

# Get checksums
echo "Getting checksum from $rootfs_sha512_url"
checksum_target=$(curl -fsSL "$rootfs_sha512_url" | cut -d' ' -f1)
checksum_actual=$(sha512sum $target_dir/$rootfs_file_pattern | cut -d' ' -f1)

# Compare checksums
echo "Comparing checksums"
if [ "$checksum_target" != "$checksum_actual" ]; then
	echo -e "\x1B[31m!!! Checksum mismatch !!!\x1B[0m"
	echo -e "Expected: \t $checksum_target"
	echo -e "Actual: \t $checksum_actual"
	exit 1
else
	echo -e "\x1B[32mChecksums match\x1B[0m"
	echo -e "Expected: \t $checksum_target"
	echo -e "Actual: \t $checksum_actual"
fi

# Extract the rootfs
echo "Extracting rootfs to '$target_dir'"
tar -xf $target_dir/$rootfs_file_pattern -C "$target_dir"
echo "Done"
