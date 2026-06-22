#!/usr/bin/env bash
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "${SCRIPT_DIR}/lib.sh"

require_command docker

r1_conf="${PROJECT_DIR}/strongswan/r1-swanctl.conf"
r2_conf="${PROJECT_DIR}/strongswan/r2-swanctl.conf"

echo "===== loaded IPsec connections (r1) ====="
run_on r1 swanctl --list-conns 2>/dev/null || echo "(r1 not reachable; deploy the lab first)"
echo
echo "Editable sources (mounted into the gateways at /etc/swanctl/swanctl.conf):"
echo "  ${r1_conf}"
echo "  ${r2_conf}"

if prompt_yes_no "Open r1's swanctl config in ${EDITOR:-vi}?"; then
  "${EDITOR:-vi}" "${r1_conf}"
  if prompt_yes_no "Reload swanctl on r1 now (swanctl --load-all)?"; then
    run_on r1 swanctl --load-all || true
    run_on r1 swanctl --terminate --ike r1-r2 >/dev/null 2>&1 || true
    run_on r1 swanctl --initiate --child lan-to-lan >/dev/null 2>&1 || true
  fi
fi
