#!/usr/bin/env bash
set -euo pipefail

# Lint every tracked shell script: a bash syntax check plus shellcheck (when
# installed). Run directly or via `./lab.sh lint` from the repository root.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

mapfile -t files < <(git ls-files '*.sh')
if (( ${#files[@]} == 0 )); then
  echo "No shell scripts found." >&2
  exit 0
fi

status=0

echo "Syntax check (bash -n) over ${#files[@]} scripts..."
for f in "${files[@]}"; do
  bash -n "${f}" || status=1
done

if command -v shellcheck >/dev/null 2>&1; then
  echo "Running shellcheck..."
  shellcheck "${files[@]}" || status=1
else
  echo "shellcheck is not installed; ran 'bash -n' only." >&2
  echo "Install it (e.g. 'sudo pacman -S shellcheck') for full linting." >&2
fi

if (( status == 0 )); then
  echo "Lint OK."
fi
exit "${status}"
