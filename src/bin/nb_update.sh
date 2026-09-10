#!/bin/bash
# ---------------------------------------------------------------------------
# Update scripts
# ---------------------------------------------------------------------------

set -euo pipefail

REPO="Nerve-box/dotfiles"
NB_DIR="$HOME/.nb"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

TAG="$(wget -qO- "https://api.github.com/repos/${REPO}/releases/latest" | grep -m1 '"tag_name"' | sed -E 's/.*"tag_name":[[:space:]]*"([^"]+)".*/\1/')"
[ -n "$TAG" ] || { echo "Error: could not determine latest release tag." >&2; exit 1; }

wget -qO "${TMP_DIR}/dotfiles.tar.gz" "https://github.com/${REPO}/archive/refs/tags/${TAG}.tar.gz"
tar -xzf "${TMP_DIR}/dotfiles.tar.gz" -C "${TMP_DIR}"

SRC_DIR="$(find "${TMP_DIR}" -mindepth 2 -maxdepth 2 -type d -name src | head -n1)"
[ -n "$SRC_DIR" ] || { echo "Error: no src/ directory found in archive." >&2; exit 1; }

[ -d "$NB_DIR" ] && { rm -rf "${NB_DIR}.bak"; mv "$NB_DIR" "${NB_DIR}.bak"; }
mkdir -p "$NB_DIR"
mv "$SRC_DIR"/* "$NB_DIR/"
