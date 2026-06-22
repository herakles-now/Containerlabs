#!/usr/bin/env bash
# shellcheck disable=SC2034  # FAULTS is consumed by the shared fault driver
#
# bgp-lab fault catalogue. Sourced by break.sh and heal.sh. Each fault_*
# function applies its change silently; the driver prints the user-facing text.

FAULTS=(
  "peer-shutdown|R1's eBGP session to R3 (192.168.13.2) is administratively down|fault_peer_shutdown"
  "as-mismatch|R1 uses the wrong remote-as for its peer R2 (192.168.12.2)|fault_as_mismatch"
  "withdraw-prefix|R7 no longer originates 10.7.0.0/16|fault_withdraw_prefix"
)

fault_peer_shutdown() {
  vtysh_on r1 "configure terminal" "router bgp 100" \
    "neighbor 192.168.13.2 shutdown" "end" >/dev/null 2>&1
}

fault_as_mismatch() {
  vtysh_on r1 "configure terminal" "router bgp 100" \
    "neighbor 192.168.12.2 remote-as 999" "end" >/dev/null 2>&1
}

fault_withdraw_prefix() {
  vtysh_on r7 "configure terminal" "router bgp 700" "address-family ipv4 unicast" \
    "no network 10.7.0.0/16" "end" >/dev/null 2>&1
}
