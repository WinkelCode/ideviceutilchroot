#!/bin/ash
set -e
set -o pipefail
project_dir="$(dirname "$(realpath "$0")")"
rundate="$(date -u +%Y-%m-%d.%H%M%SZ)"

depsfile="$project_dir/apkdeps.txt"
if [ ! -f "$depsfile" ]; then
	echo "File '$depsfile' not found"
	exit 1
else
	dependencies=$(cat "$depsfile")
fi

logfile="$project_dir/buildlog/${rundate}_installapkdeps.log"
mkdir -p "$project_dir/buildlog"
apk add --no-cache $dependencies 2>&1 | tee -a "$logfile"
