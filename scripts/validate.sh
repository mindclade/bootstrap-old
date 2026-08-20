#!/usr/bin/env bash
# Copyright © 2026 Mindclade, LLC. All Rights Reserved.
# Mindclade Proprietary and Confidential.
# SPDX-License-Identifier: LicenseRef-Mindclade-Proprietary

set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root"

bash scripts/verify-no-local-state.sh
python3 scripts/verify-wif-policy.py
python3 scripts/verify-state-policy.py
python3 scripts/license-header-check.py --check

test -f .github/CODEOWNERS
test ! -e CODEOWNERS
test ! -d modules/folders
test ! -d modules/governance
test ! -e modules/projects/audit.tf
test ! -e modules/identity/secrets.tf
test -f modules/identity/automation-secrets.tf
test -f docs/automation-secret-bootstrap.md
test -f contracts/outputs.schema.json

metadata="$(find . -path './.git' -prune -o -type f \( -name '._*' -o -name '.DS_Store' \) -print -quit)"
if [[ -n "$metadata" ]]; then
  echo "forbidden platform metadata: $metadata" >&2
  exit 1
fi
echo 'bootstrap repository invariants passed'
