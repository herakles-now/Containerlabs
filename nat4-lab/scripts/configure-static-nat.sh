#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "${SCRIPT_DIR}/lib.sh"

require_nodes static-gw
reset_nat_table static-gw

run_on_stdin static-gw nft -f - <<'EOF'
table ip nat4 {
  chain prerouting {
    type nat hook prerouting priority dstnat; policy accept;
    iifname "eth2" ip daddr 198.51.100.10 dnat to 10.10.1.10
  }

  chain postrouting {
    type nat hook postrouting priority srcnat; policy accept;
    oifname "eth2" ip saddr 10.10.1.10 snat to 198.51.100.10
  }
}
EOF

echo "Configured static one-to-one NAT: 10.10.1.10 <-> 198.51.100.10."
