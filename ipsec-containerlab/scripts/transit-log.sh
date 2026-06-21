#!/usr/bin/env bash
set -euo pipefail

LOG_DIR=/var/log/ipsec-lab
LOG_FILE="${LOG_DIR}/transit.log"
mkdir -p "${LOG_DIR}"
touch "${LOG_FILE}"

{
  echo "=== IPsec Transit Logger ==="
  echo "Start time: $(date --iso-8601=seconds)"
  echo "Transit simulates the Internet between the two IPsec gateways."
  echo "Expectation before IPsec: UDP/500 (IKE)."
  echo "Expectation after IPsec: ESP (IP protocol 50) between 100.64.1.1 and 100.64.2.2."
  echo "Optional NAT-T would use UDP/4500; NAT is not active in this lab."
  echo "Inner headers 10.1.0.10 <-> 10.2.0.10 should not be visible in tunnel mode."
  echo "--- Interfaces ---"
  ip -br addr
  echo "--- Routes ---"
  ip route
  echo "--- Packet capture ---"
} | tee -a "${LOG_FILE}"

exec tcpdump -l -i any -n -tttt -vvv \
  '(udp port 500 or udp port 4500 or proto 50 or icmp)' \
  2>&1 | tee -a "${LOG_FILE}"
