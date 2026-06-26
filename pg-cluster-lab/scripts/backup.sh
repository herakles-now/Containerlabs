#!/usr/bin/env bash
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "${SCRIPT_DIR}/lib.sh"

require_command docker

if ! require_container "${BACKUP_NODE}"; then
  echo "Deploy the lab first: ./lab.sh pg-cluster deploy" >&2
  exit 1
fi

# Default to a differential backup (fast); pass "full" or "incr" to override.
type="${1:-diff}"

echo "Taking a ${type} backup on ${BACKUP_NODE} (data read from the standby ${IMMEDIATE_STANDBY})..."
pgbackrest_repo "--type=${type} backup"

echo
echo "===== pgBackRest repository after the backup ====="
pgbackrest_repo info
