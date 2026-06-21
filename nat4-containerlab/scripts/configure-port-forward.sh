#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "${SCRIPT_DIR}/lib.sh"

require_nodes forward-gw
reset_nat_table forward-gw

run_on_stdin forward-gw nft -f - <<'EOF'
table ip nat4 {
  chain prerouting {
    type nat hook prerouting priority dstnat; policy accept;
    iifname "eth2" ip daddr 198.51.102.1 tcp dport 8080 dnat to 10.10.3.10:80
  }
}
EOF

echo "Configured port forward: 198.51.102.1:8080 -> 10.10.3.10:80."
