#!/usr/bin/env bash

set -euo pipefail

REPO_URL="https://github.com/danny-kuehn/runeprice"
PKGBUILD_DIR="$HOME/git/pkgbuilds/runeprice"
VERSION="$(<./VERSION.txt)"

cd "$PKGBUILD_DIR"

trap 'rm -f *.tar.gz *.tar.lz4' EXIT INT TERM

sed -i "s/^pkgver=.*/pkgver=$VERSION/" ./PKGBUILD
sed -i "s/^pkgrel=.*/pkgrel=1/" ./PKGBUILD

updpkgsums || {
	printf "ERROR: updpkgsums failed\n" >&2
	exit 1
}

rm -f ./*.tar.gz

makepkg --clean || {
	printf "ERROR: makepkg --clean failed\n" >&2
	exit 1
}

printf "\n"

git diff ./PKGBUILD

printf "\n"

read -rp "Commit and push? (y/N): " CHOICE

[[ "${CHOICE,,}" != "y" && "${CHOICE,,}" != "yes" ]] && {
	printf "Canceled\n" >&2
	exit 1
}

makepkg --printsrcinfo >./.SRCINFO

git add ./PKGBUILD ./.SRCINFO
git commit -m "$VERSION" -m "$REPO_URL/releases/tag/$VERSION"
git push
