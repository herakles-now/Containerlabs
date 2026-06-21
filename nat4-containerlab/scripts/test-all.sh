#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

for test_script in \
  test-static-nat.sh \
  test-dynamic-nat.sh \
  test-port-forward.sh \
  test-pat.sh; do
  echo
  echo "################################################################"
  echo "Running ${test_script}"
  echo "################################################################"
  "${SCRIPT_DIR}/${test_script}"
done

echo "All NAT scenario tests completed successfully."
