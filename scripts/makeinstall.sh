#!/bin/ash
set -e
set -o pipefail
project_dir="$(dirname "$(realpath "$0")")"
rundate="$(date -u +%Y-%m-%d.%H%M%SZ)"

nproc=$(nproc)
projectsfile="$project_dir/projects.txt" # The order of the projects within this file is important to satisfy dependencies
if [ ! -f "$projectsfile" ]; then
	echo "File '$projectsfile' not found"
	exit 1
else
	projects=$(cat "$projectsfile")
fi

for project in $projects; do
	logfile="$project_dir/buildlog/${rundate}_${project}.log"
	mkdir -p "$project_dir/buildlog"
	cd "$project"
	echo "-> Configuring $project" >>"$logfile"
	./autogen.sh --disable-static 2>&1 | tee -a "$logfile"
	echo "-> Done configuring" >>"$logfile"
	echo "-> Building and installing $project" >>"$logfile"
	make -j"$nproc" install 2>&1 | tee -a "$logfile"
	echo "-> Done" >>"$logfile"
	cd ..
done
