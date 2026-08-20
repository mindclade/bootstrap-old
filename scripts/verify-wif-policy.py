#!/usr/bin/env python3
# Copyright © 2026 Mindclade, LLC. All Rights Reserved.
# Mindclade Proprietary and Confidential.
# SPDX-License-Identifier: LicenseRef-Mindclade-Proprietary

from pathlib import Path
import re
import sys

root = Path(__file__).resolve().parent.parent
wif = (root / "modules/identity/wif.tf").read_text()
sa = (root / "modules/identity/service-accounts.tf").read_text()
all_tf = "\n".join(p.read_text() for p in (root / "modules/identity").glob("*.tf"))
errors = []


def require(token, where, label=None):
    if token not in where:
        errors.append(f"missing {label or token}")


for claim in (
    "assertion.repository_owner_id",
    "assertion.repository_id",
    "assertion.repository",
    "assertion.sub.startsWith",
    "assertion.aud",
    "assertion.workflow_ref",
    "assertion.workflow_sha",
):
    require(claim, wif)
require(
    "allowed_audiences = [local.github_provider_audiences[each.key]]",
    wif,
    "provider-specific GitHub audience allowlist",
)
for repo in (
    "bootstrap",
    "github-config",
    "infrastructure-live",
    "gitops",
    "mindclade-internal-monorepo",
):
    require(
        f'var.github_repository_ids["{repo}"]',
        wif,
        f"immutable repository ID for {repo}",
    )
require(
    "github_immutable_subject_prefixes", wif, "immutable default GitHub subject catalog"
)
require(
    '"repo:${var.github_org}@${var.github_org_id}/${repo}@${repository_id}"',
    wif,
    "owner-ID and repository-ID subject prefix",
)
require("attribute.workflow_ref", wif, "mapped direct workflow_ref claim")
require(
    "each.key == local.github_signer_repository ? {",
    wif,
    "signer-only optional reusable-workflow claim mapping",
)
mapping_start = "attribute_mapping = merge({"
signer_mapping_start = "}, each.key == local.github_signer_repository ? {"
if mapping_start in wif and signer_mapping_start in wif:
    direct_mapping = wif.split(mapping_start, 1)[1].split(signer_mapping_start, 1)[0]
    if "attribute.job_workflow_" in direct_mapping:
        errors.append("direct-workflow provider maps optional reusable-workflow claims")
else:
    errors.append(
        "GitHub provider does not separate universal and signer-only claim mappings"
    )
for claim in (
    '"attribute.job_workflow_ref" = "assertion.job_workflow_ref"',
    '"attribute.job_workflow_sha" = "assertion.job_workflow_sha"',
):
    require(claim, wif, f"signer-only optional mapping {claim}")
if "attribute.workflow_ref/${var.github_org}/${repo}" not in wif:
    errors.append("direct workflow principal is not based on attribute.workflow_ref")
require(
    "for_each = local.wif_service_account_bindings",
    sa,
    "exhaustive WIF binding map",
)
require(
    "member             = each.value.principal", sa, "explicit per-binding principal"
)
if "apply_only" in sa:
    errors.append(
        "obsolete apply_only selector remains after exhaustive WIF binding migration"
    )
for identity, repo in (
    ("bootstrap-plan", "bootstrap"),
    ("github-config-plan", "github-config"),
    ("infrastructure-live-plan", "infrastructure-live"),
):
    require(f"{identity} ", wif, f"primary plan identity {identity}")
    require(
        f'local.github_immutable_subject_prefixes["{repo}"]}}:environment:plan',
        wif,
        f"immutable environment-scoped plan subject for {identity}",
    )
for identity, repo, workflow in (
    ("bootstrap-drift", "bootstrap", "drift.yml"),
    ("bootstrap-plan:recovery-drill", "bootstrap", "recovery-drill.yml"),
    ("github-config-plan:drift", "github-config", "drift.yml"),
    ("github-config-plan:idp-sync", "github-config", "idp-sync.yml"),
    ("infrastructure-live-plan:drift", "infrastructure-live", "drift.yml"),
):
    require(identity, wif, f"exact scheduled binding {identity}")
    require(
        f'principal_workflow_prefix["{repo}"]}}/.github/workflows/{workflow}@refs/heads/main',
        wif,
        f"protected-main workflow binding for {repo}/{workflow}",
    )
if "principal_repo" in wif or "local.principal_repo" in sa:
    errors.append("repository-wide service-account federation remains")
for token, label in (
    (
        "assertion.sub == ${jsonencode(local.github_signer_subject)}",
        "exact signer environment subject condition",
    ),
    (
        "assertion.job_workflow_ref == ${jsonencode(local.github_signer_job_workflow_ref)}",
        "exact signer reusable-workflow condition",
    ),
    (
        "${local.github_immutable_subject_prefixes[local.github_signer_repository]}:environment:${local.github_signer_environment}",
        "immutable protected release signer subject",
    ),
    (
        "${var.github_org}/.github/.github/workflows/reusable-binauthz-sign.yml@refs/tags/v3.0.0",
        "immutable v3 signer workflow",
    ),
    (
        'github_signer_principal = "principal://iam.googleapis.com/',
        "exact signer principal",
    ),
):
    require(token, wif, label)
outputs = (root / "outputs.tf").read_text()
module_outputs = (root / "modules/identity/outputs.tf").read_text()
output_schema = (root / "contracts/outputs.schema.json").read_text()
for name in (
    "artifact_signer_wif_provider",
    "artifact_signer_principal",
    "artifact_signer_job_workflow_ref",
):
    require(f'output "{name}"', outputs, f"root signer contract output {name}")
    require(
        f'output "{name}"', module_outputs, f"identity signer contract output {name}"
    )
require(
    "repository_owner_id = var.github_org_id",
    module_outputs,
    "exported immutable GitHub owner ID",
)
require(
    "repo:mindclade@[0-9]+/mindclade-internal-monorepo@[0-9]+:environment:release",
    output_schema,
    "immutable signer principal contract pattern",
)
if "@refs/heads/main" not in wif:
    errors.append(
        "apply workflow identity catalog is not restricted to the protected main ref"
    )

for identity in (
    "bootstrap-apply",
    "github-config-apply",
    "infrastructure-live-apply-foundation",
    "infrastructure-live-apply-development",
    "infrastructure-live-apply-staging",
    "infrastructure-live-apply-production",
):
    if not re.search(
        rf'{re.escape(identity)}\s*=\s*"\.github/workflows/apply\.yml"', sa
    ):
        errors.append(f"{identity} is not bound to the exact apply workflow")
for token in (
    'issuer_uri        = "https://agent.buildkite.com"',
    "assertion.organization_id",
    "assertion.pipeline_id",
):
    require(token, wif)
require(
    "allowed_audiences = [local.buildkite_provider_audience]",
    wif,
    "provider-specific Buildkite audience allowlist",
)
require(
    '"google.subject"               = "assertion.pipeline_id"',
    wif,
    "bounded immutable Buildkite subject mapping",
)
buildkite_block = wif.split(
    'resource "google_iam_workload_identity_pool_provider" "buildkite"', 1
)[-1]
if '"google.subject"               = "assertion.sub"' in buildkite_block:
    errors.append(
        "Buildkite provider maps the potentially overlong default compound subject"
    )
if re.search(r"mindclade/\*|principalSet[^\n]*/\*", all_tf):
    errors.append("organization-wide WIF wildcard")
if re.search(
    r"google_service_account_key|private_key_data|service_account.*\.json", all_tf, re.I
):
    errors.append("static service-account key path")
if re.search(r"roles/(?:owner|editor)", all_tf, re.I):
    errors.append("Owner/Editor automation role")
# Basic Viewer may exist only in project_roles, never in org_roles.
for block in re.finditer(r"org_roles\s*=\s*\[(.*?)\]", sa, re.S):
    if "roles/viewer" in block.group(1):
        errors.append("organization-wide basic Viewer grant")
for name in (
    "artifact-builder",
    "artifact-qualifier",
    "artifact-signer",
    "artifact-promoter",
):
    if name in all_tf:
        errors.append(f"non-Ring-0 supply-chain identity in bootstrap: {name}")
if 'repo       = "mindclade-internal-monorepo"' in sa:
    errors.append("monorepo principal is bound to a Ring-0 service account")
if (
    "repo:${var.github_org}/${repo}" in wif
    or "repo:${var.github_org}/${local.github_signer_repository}" in wif
):
    errors.append("legacy name-only GitHub subject remains")
if "google_secret_manager_secret_version" in all_tf:
    errors.append("secret payload stored in Terraform state")

plan_workflow = (root / ".github/workflows/plan.yml").read_text()
apply_workflow = (root / ".github/workflows/apply.yml").read_text()
drift_workflow = (root / ".github/workflows/drift.yml").read_text()
recovery_workflow = (root / ".github/workflows/recovery-drill.yml").read_text()
for name, workflow in (("plan", plan_workflow), ("apply-plan", apply_workflow)):
    require("environment: plan", workflow, f"{name} protected plan environment")
require(
    "environment: bootstrap-recovery-read",
    recovery_workflow,
    "dedicated governed read-only recovery environment",
)
for name, workflow in (
    ("drift", drift_workflow),
    ("recovery inspection", recovery_workflow),
):
    guard = '[[ "${GITHUB_REF}" == "refs/heads/main" ]]'
    require(guard, workflow, f"{name} protected-main pre-authentication guard")
    if guard in workflow and "google-github-actions/auth@" in workflow:
        if workflow.index(guard) > workflow.index("google-github-actions/auth@"):
            errors.append(f"{name} main-ref guard runs after cloud authentication")
for name, workflow in (
    ("plan", plan_workflow),
    ("apply-plan", apply_workflow),
    ("drift", drift_workflow),
):
    require("-lock-timeout=20m", workflow, f"{name} state locking")
for path in list((root / ".github/workflows").glob("*.yml")) + [
    root / "Makefile",
    root / "test/clean-room-recovery.md",
]:
    if "-lock=false" in path.read_text():
        errors.append(f"state locking disabled in {path.relative_to(root)}")
if errors:
    for e in sorted(set(errors)):
        print(f"ERROR: {e}", file=sys.stderr)
    raise SystemExit(1)
print("bootstrap WIF and automation policy passed")
