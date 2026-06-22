#!/usr/bin/env bash
# shellcheck disable=SC2034  # FAULTS is consumed by the shared fault driver
#
# ipsec-lab fault catalogue. Sourced by break.sh and heal.sh. Each fault_*
# function applies its change silently; the driver prints the user-facing text.
# Packet-drop faults use iptables (the strongSwan image ships iptables, not
# nft); heal flushes the chains, which the lab does not otherwise use.

FAULTS=(
  "block-ike|R1 drops IKE (UDP/500), so the tunnel can no longer be negotiated|fault_block_ike"
  "block-esp|the transit drops ESP (IP proto 50), so tunnel data cannot pass|fault_block_esp"
  "wrong-route|R1 is missing its default route towards the transit|fault_wrong_route"
)

fault_block_ike() {
  # Tear the current SA down first (its delete still needs UDP/500), then block
  # IKE so renegotiation fails — the symptom is immediate.
  run_on r1 swanctl --terminate --ike r1-r2 >/dev/null 2>&1 || true
  run_on r1 iptables -A OUTPUT -p udp --dport 500 -j DROP >/dev/null 2>&1
}

fault_block_esp() {
  run_on transit iptables -A FORWARD -p esp -j DROP >/dev/null 2>&1
}

fault_wrong_route() {
  run_on r1 ip route del default >/dev/null 2>&1
}
