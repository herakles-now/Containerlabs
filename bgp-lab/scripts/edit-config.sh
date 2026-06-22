#!/usr/bin/env bash
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "${SCRIPT_DIR}/lib.sh"

require_command docker

config_src="${SCRIPT_DIR}/configure.sh"

echo "===== effective BGP running-config (r1) ====="
vtysh_on r1 "show running-config" 2>/dev/null || echo "(r1 not reachable; deploy the lab first)"
echo
echo "Run './lab.sh bgp state' to see every router."
echo "Editable source: ${config_src}"

if prompt_yes_no "Open the config source in ${EDITOR:-vi}?"; then
  "${EDITOR:-vi}" "${config_src}"
  if prompt_yes_no "Re-apply the configuration now?"; then
    "${config_src}"
  fi
fi
