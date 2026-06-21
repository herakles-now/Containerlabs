#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "${SCRIPT_DIR}/lib.sh"

require_nodes pat-gw
reset_nat_table pat-gw

run_on_stdin pat-gw nft -f - <<'EOF'
table ip nat4 {
  chain postrouting {
    type nat hook postrouting priority srcnat; policy accept;
    oifname "eth2" ip saddr 10.10.4.0/24 masquerade
  }
}
EOF

echo "Configured PAT: 10.10.4.0/24 shares 198.51.103.1 with port translation."
