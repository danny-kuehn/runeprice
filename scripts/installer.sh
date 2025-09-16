#!/usr/bin/env bash

set -euo pipefail

((EUID == 0)) || {
  printf "ERROR: Must be run as root.\n" >&2
  exit 1
}

APP="runeprice"
PREFIX="${PREFIX:-/usr/local}"
LICENSE_DIR="$PREFIX/share/licenses/$APP"
BIN_DIR="$PREFIX/bin"

install_files() {
  install -Dvm644 "./LICENSE.txt" "$LICENSE_DIR/LICENSE.txt"
  install -Dvm755 "./$APP.sh" "$BIN_DIR/$APP"
}

uninstall_files() {
  rm -vf "$LICENSE_DIR/LICENSE.txt"
  rm -vf "$BIN_DIR/$APP"
}

usage() {
  cat <<EOF >&2
Usage: ${BASH_SOURCE[0]##*/} <options>

Options:
  -i, --install    install files
  -u, --uninstall  uninstall files
EOF
}

case "${1:-}" in
  -i | --install) install_files ;;
  -u | --uninstall) uninstall_files ;;
  *) usage && exit 1 ;;
esac
