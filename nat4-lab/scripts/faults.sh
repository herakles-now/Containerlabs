#!/usr/bin/env bash
# shellcheck disable=SC2034  # FAULTS is consumed by the shared fault driver
#
# nat4-lab fault catalogue. Sourced by break.sh and heal.sh. Each fault_*
# function applies its change silently; the driver prints the user-facing text.

FAULTS=(
  "flush-nat|static-gw has no NAT table (nft table ip nat4 was deleted)|fault_flush_nat"
  "forwarding-off|pat-gw has IPv4 forwarding disabled|fault_forwarding_off"
  "rpfilter-on|dynamic-gw drops return traffic (strict rp_filter enabled)|fault_rpfilter_on"
)

fault_flush_nat() {
  run_on static-gw sh -c 'nft delete table ip nat4 2>/dev/null; conntrack -F 2>/dev/null' >/dev/null 2>&1
}

fault_forwarding_off() {
  run_on pat-gw sysctl -q -w net.ipv4.ip_forward=0 >/dev/null 2>&1
}

fault_rpfilter_on() {
  run_on dynamic-gw sh -c 'sysctl -q -w net.ipv4.conf.all.rp_filter=1; sysctl -q -w net.ipv4.conf.eth1.rp_filter=1; sysctl -q -w net.ipv4.conf.eth2.rp_filter=1' >/dev/null 2>&1
}
