#!/usr/bin/env bash
# Copyright © 2026 Mindclade, LLC. All Rights Reserved.
# Mindclade Proprietary and Confidential.
# SPDX-License-Identifier: LicenseRef-Mindclade-Proprietary
#
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
python3 - "$root" <<'PY'
from pathlib import Path
import re, sys
root=Path(sys.argv[1])
wif=(root/'modules/identity/wif.tf').read_text()
sa=(root/'modules/identity/service-accounts.tf').read_text()
all_tf='\n'.join(p.read_text() for p in (root/'modules/identity').glob('*.tf'))
errors=[]

def require(token, where, label=None):
    if token not in where: errors.append(f"missing {label or token}")

for claim in (
    'assertion.repository_owner_id', 'assertion.repository_id', 'assertion.repository',
    'assertion.aud', 'assertion.workflow_ref', 'assertion.workflow_sha',
    'assertion.job_workflow_ref', 'assertion.job_workflow_sha',
): require(claim,wif)
for repo in ('bootstrap','github-config','infrastructure-live','gitops','mindclade-internal-monorepo'):
    require(f'var.github_repository_ids["{repo}"]',wif,f'immutable repository ID for {repo}')
require('attribute.workflow_ref', wif, 'mapped direct workflow_ref claim')
if 'attribute.workflow_ref/${var.github_org}/${repo}' not in wif:
    errors.append('direct workflow principal is not based on attribute.workflow_ref')

for identity in (
    'bootstrap-apply','github-config-apply','infrastructure-live-apply-foundation',
    'infrastructure-live-apply-development','infrastructure-live-apply-staging',
    'infrastructure-live-apply-production',
):
    if not re.search(rf'{re.escape(identity)}\s*=\s*"\.github/workflows/apply\.yml"',sa):
        errors.append(f'{identity} is not bound to the exact apply workflow')
for token in ('issuer_uri        = "https://agent.buildkite.com"','assertion.organization_id','assertion.pipeline_id'):
    require(token,wif)
if re.search(r'Mindclade/\*|principalSet[^\n]*/\*',all_tf): errors.append('organization-wide WIF wildcard')
if re.search(r'google_service_account_key|private_key_data|service_account.*\.json',all_tf,re.I): errors.append('static service-account key path')
if re.search(r'roles/(?:owner|editor)',all_tf,re.I): errors.append('Owner/Editor automation role')
# Basic Viewer may exist only in project_roles, never in org_roles.
for block in re.finditer(r'org_roles\s*=\s*\[(.*?)\]',sa,re.S):
    if 'roles/viewer' in block.group(1): errors.append('organization-wide basic Viewer grant')
for name in ('artifact-builder','artifact-qualifier','artifact-signer','artifact-promoter'):
    if name in all_tf: errors.append(f'non-Ring-0 supply-chain identity in bootstrap: {name}')
if 'google_secret_manager_secret_version' in all_tf: errors.append('secret payload stored in Terraform state')
if errors:
    for e in sorted(set(errors)): print(f'ERROR: {e}',file=sys.stderr)
    raise SystemExit(1)
print('bootstrap WIF and automation policy passed')
PY
