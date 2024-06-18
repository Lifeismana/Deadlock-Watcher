#!/bin/bash
export LC_ALL=C

set -e

cd "${0%/*}"

[ -n "$GIT_NAME" ] && git config --global user.name "$GIT_NAME"
[ -n "$GIT_EMAIL" ] && git config --global user.email "$GIT_EMAIL"


FixUCS2 ()
{
	echo "> Fixing UCS-2"
	echo "$(dirname "${BASH_SOURCE[0]}")"
	find . -type f -name "*.txt" -print0 | xargs --null --max-lines=1 --max-procs=3 "/data/fix_encoding"
}

CreateCommit ()
{
	message="$1 | $(git status --porcelain | wc -l) files | $(git status --porcelain | sed '{:q;N;s/\n/, /g;t q}' | sed 's/^ *//g' | cut -c 1-1024)"
	if [ -n "$2" ]; then
		bashpls=$'\n\n'
		message="${message}${bashpls}https://steamdb.info/patchnotes/$2/"
	fi
	git add -A
	
	if ! git diff-index --quiet HEAD; then
		git commit -a -m "$message"
		git push
	fi
}

cd $GITHUB_WORKSPACE

. ./common.sh


# link .support if it doesn't exist
[ ! -d ".support" ] && ln -s /data/.support .support

# link ProtobufDumper if it doesn't exist
[ ! -L "~/ProtobufDumper" ] && ln -s /data/ProtobufDumper ~/ProtobufDumper


cd deadlock

echo "Cleaning Ddlck"

find . -type f -not \( -path './README.md' -o -path './.git*' -o -path '*.vpk' -o -path "steam.inf" -o -path "./.DepotDownloader" \) -delete 
find . -type d -empty -a -not -path './.git*' -delete

echo "Downloading Ddlck"

#if we don't have manifests, we use the latest manifest that steam provides us with
#otherwise we use the manifests that we have

if [ -z "$MANIFESTS" ]; then
	/data/DepotDownloader/DepotDownloader -username "$STEAM_USERNAME" -password "$STEAM_PASSWORD" -app 1422450 -depot 1422451 1422452 1422456 -dir . -validate
else
	#idk why i have to do this in such a weird way but it works
	depots=""
	manifests=""
	while IFS=' ' read -ra depot_manifest; do
		for dm in "${depot_manifest[@]}"; do
			IFS='_' read -ra dm_split <<< "$dm"
			depots+="${dm_split[0]} "
			manifests+="${dm_split[1]} "
		done
	done <<< "$MANIFESTS"
	
	/data/DepotDownloader/DepotDownloader -username "$STEAM_USERNAME" -password "$STEAM_PASSWORD" -app 1422450 -depot $depots -manifest $manifests -dir . -validate
fi

echo "Processing Ddlck"

ProcessDepot ".so"
ProcessDepot ".dll"
ProcessVPK

echo "> Processing VPKs"
set +e
while IFS= read -r -d '' file
do
	echo " > $file"

	/data/Decompiler/Decompiler \
			--input "$file" \
			--output "$(echo "$file" | sed -e 's/\.vpk$/\//g')" \
			--vpk_decompile \
			--vpk_extensions "txt,lua,kv3,db,gameevents,vcss_c,vjs_c,vts_c,vxml_c,vsndevts_c,vsndstck_c,vpulse_c,vdata_c"

	# https://github.com/Penguinwizzard/VPKTool
	/data/VPKTool/vpktool "$file" > "${file%.*}.txt"
done <   <(find . -type f -name "*_dir.vpk" -print0)
set -e

FixUCS2

CreateCommit "$(grep "ClientVersion=" game/citadel/steam.inf | grep -o '[0-9\.]*')" "$1"