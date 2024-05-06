#!/bin/ash
set -e
set -o pipefail
project_dir="$(dirname "$(realpath "$0")")"
rundate="$(date -u +%Y-%m-%d.%H%M%SZ)"
baseurl="https://github.com/libimobiledevice"

projectsfile="$project_dir/projects.txt"
if [ ! -f "$projectsfile" ]; then
	echo "File '$projectsfile' not found"
	exit 1
else
	projects=$(cat "$projectsfile")
fi

logfile="$project_dir/buildlog/${rundate}_clonerepos.log"
mkdir -p "$project_dir/buildlog"
for project in $projects; do
	repourl="$baseurl/$project"
	echo "-> Cloning $repourl" >>"$logfile"
	git clone --depth=1 "$repourl" 2>&1 | tee -a "$logfile"
	echo "-> Done" >>"$logfile"
done
