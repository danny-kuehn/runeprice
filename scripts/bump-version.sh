#!/usr/bin/env bash

set -euo pipefail

NEW_VERSION="$(<./VERSION.txt)"

sed -i -E 's/RUNEPRICE_VERSION="[0-9]+\.[0-9]+\.[0-9]+"/RUNEPRICE_VERSION="'"$NEW_VERSION"'"/' ./runeprice.sh

git diff ./runeprice.sh ./VERSION.txt

printf "\n"

read -rp "Commit and push? (y/N): " CHOICE

[[ "${CHOICE,,}" != "y" && "${CHOICE,,}" != "yes" ]] && {
	printf "Canceled\n" >&2
	exit 1
}

git add ./runeprice.sh ./VERSION.txt
git commit -m "$NEW_VERSION"
git tag "$NEW_VERSION"
git push --follow-tags
