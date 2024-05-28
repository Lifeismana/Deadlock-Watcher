#!/bin/bash
export LC_ALL=C

set -e

cd "${0%/*}"

# if the env MANIFEST is not set we return an error
[ -z "$GIT_URL" ] && echo "GIT_URL is missing" && exit 2

# if SSH_KEY is set to a non empty string save it in id_ed25519 if it doesn't exist
[ -n "$SSH_KEY" ] && [ ! -f ~/.ssh/id_ed25519 ] && echo "$SSH_KEY" > ~/.ssh/id_ed25519
[ -n "$GIT_NAME" ] && git config --global user.name "$GIT_NAME"
[ -n "$GIT_EMAIL" ] && git config --global user.email "$GIT_EMAIL"
[ -n "$GPG_KEY" ] && gpg --batch --import <( echo "$GPG_KEY")
[ -n "$GPG_KEY_ID" ] && git config --global user.signingkey "$GPG_KEY_ID"
[ -f ~/.ssh/id_ed25519 ] && chmod 600 ~/.ssh/id_ed25519
[ -n "$KNOWN_HOSTS" ] && echo "$KNOWN_HOSTS" > ~/.ssh/known_hosts

ProcessVPK ()
{
	echo "> Processing VPKs"
	set +e
	while IFS= read -r -d '' file
	do
		echo " > $file"

		for ext in "vmat_c" "vtex_c" "gif"
		do
			~/Decompiler/Decompiler \
				--input "$file" \
				--output "$(echo "$file" | sed -e 's/\.vpk$/\//g')" \
				--vpk_decompile
		done
	done <   <(find . -type f -name "*_dir.vpk" -print0)
	wait
	set -e
}

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
		git commit -S -a -m "$message"
		git push
	fi
}

cd git_folder

if [ ! -d "ddlckvpktracking" ]; then
	git clone $GIT_URL ddlckvpktracking
	cd ddlckvpktracking
else
	cd ddlckvpktracking
	git fetch
	git reset --hard origin/master
fi

echo "Cleaning Ddlck"

find . -type f -not \( -path './README.md' -o -path './.git*' -o -path '*.vpk' -o -path "steam.inf" -o -path "./.DepotDownloader" \) -delete 
find . -type d -empty -a -not -path './.git*' -delete

echo "Downloading Ddlck"

#if we don't have manifests, we use the latest manifest that steam provides us with
#otherwise we use the manifests that we have

if [ -z "$MANIFESTS" ]; then
	~/DepotDownloader/DepotDownloader -username "$STEAM_USERNAME" -password "$STEAM_PASSWORD" -app 1422450 -dir . -validate
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
	
	~/DepotDownloader/DepotDownloader -username "$STEAM_USERNAME" -password "$STEAM_PASSWORD" -app 1422450 -depot $depots -manifest $manifests -dir . -validate
fi

echo "Processing Ddlck"

ProcessVPK

FixUCS2

CreateCommit "$(grep "ClientVersion=" game/citadel/steam.inf | grep -o '[0-9\.]*')" "$1"