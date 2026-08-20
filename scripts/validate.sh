#!/usr/bin/env bash
# Copyright © 2026 Mindclade, LLC. All Rights Reserved.
# Mindclade Proprietary and Confidential.
# SPDX-License-Identifier: LicenseRef-Mindclade-Proprietary

set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root"

bash scripts/verify-no-local-state.sh
bash scripts/verify-wif-policy.sh
bash scripts/verify-state-policy.sh
bash scripts/license-header-check.sh --check

test -f .github/CODEOWNERS
test ! -e CODEOWNERS
test ! -d modules/folders
test ! -d modules/governance
test ! -e modules/projects/audit.tf
test ! -e modules/identity/secrets.tf
test -f modules/identity/automation-secrets.tf
test -f docs/automation-secret-bootstrap.md
test -f contracts/outputs.schema.json

python3 - <<'PY_INNER'
from pathlib import Path
for path in Path('.').rglob('*'):
    if '.git' in path.parts:
        continue
    if path.is_file() and (path.name.startswith('._') or path.name == '.DS_Store'):
        raise SystemExit(f'forbidden platform metadata: {path}')
print('bootstrap repository invariants passed')
PY_INNER
