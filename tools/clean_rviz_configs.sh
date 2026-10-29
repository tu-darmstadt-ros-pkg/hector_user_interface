#!/usr/bin/env bash
# Strip volatile UI-state from rviz config files in place (see tools/rviz_normalize.py).
# Run this before committing rviz changes, then review `git diff` and stage deliberately.
# The rviz-no-volatile pre-commit hook rejects commits that still contain such entries.
#
# Usage: tools/clean_rviz_configs.sh [FILE.rviz ...]   (defaults to every tracked .rviz config)
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ "$#" -gt 0 ]; then
  files=("$@")
else
  root="$(git -C "$here" rev-parse --show-toplevel)"
  mapfile -t files < <(git -C "$root" ls-files '*.rviz')
  for i in "${!files[@]}"; do files[$i]="$root/${files[$i]}"; done
fi

if [ "${#files[@]}" -eq 0 ]; then
  echo "no rviz files to clean"
  exit 0
fi

python3 "$here/rviz_normalize.py" --write "${files[@]}"
