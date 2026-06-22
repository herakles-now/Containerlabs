#!/usr/bin/env bash
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "${SCRIPT_DIR}/lib.sh"

require_command docker

config_src="${SCRIPT_DIR}/configure-all.sh"

echo "===== effective nftables ruleset per gateway ====="
for gw in static-gw dynamic-gw forward-gw pat-gw; do
  echo "----- ${gw} -----"
  run_on "${gw}" nft list ruleset 2>/dev/null || echo "(not reachable)"
done
echo
echo "Editable source: ${config_src} (plus configure-*.sh for each case)"

if prompt_yes_no "Open the config source in ${EDITOR:-vi}?"; then
  "${EDITOR:-vi}" "${config_src}"
  if prompt_yes_no "Re-apply the configuration now?"; then
    "${config_src}"
  fi
fi
