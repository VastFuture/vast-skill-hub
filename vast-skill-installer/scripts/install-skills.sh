#!/usr/bin/env bash
set -euo pipefail

TARGET_DIR=".agents/skills"
REPO_URLS=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --target|-t)
      TARGET_DIR="$2"
      shift 2
      ;;
    *)
      REPO_URLS+=("$1")
      shift
      ;;
  esac
done

if [[ ${#REPO_URLS[@]} -eq 0 ]]; then
  echo "Usage: $0 [--target <dir>] <repo_url1> [<repo_url2> ...]"
  exit 1
fi

mkdir -p "$TARGET_DIR"
TEMP_BASE=$(mktemp -d 2>/dev/null || mktemp -d -t 'vast-skills')

trap 'rm -rf "$TEMP_BASE"' EXIT

for URL in "${REPO_URLS[@]}"; do
  REPO_NAME=$(basename "$URL" .git)
  echo "==> Downloading $REPO_NAME from $URL..."
  
  TEMP_CLONE="$TEMP_BASE/$REPO_NAME"
  git clone --depth 1 "$URL" "$TEMP_CLONE"
  
  rm -rf "$TEMP_CLONE/.git"
  
  DEST="$TARGET_DIR/$REPO_NAME"
  mkdir -p "$DEST"
  cp -a "$TEMP_CLONE/." "$DEST/"
  
  echo "[OK] Installed $REPO_NAME to $DEST"
done

echo "All requested skills have been installed cleanly."
