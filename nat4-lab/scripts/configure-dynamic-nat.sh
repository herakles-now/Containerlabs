#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "${SCRIPT_DIR}/lib.sh"

require_nodes dynamic-gw
reset_nat_table dynamic-gw

run_on_stdin dynamic-gw nft -f - <<'EOF'
table ip nat4 {
  chain postrouting {
    type nat hook postrouting priority srcnat; policy accept;
    oifname "eth2" ip saddr 10.10.2.0/24 snat to 198.51.101.10-198.51.101.20
  }
}
EOF

echo "Configured dynamic NAT pool: 10.10.2.0/24 -> 198.51.101.10-198.51.101.20."
