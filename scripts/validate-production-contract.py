#!/usr/bin/env python3
# Copyright © 2026 Mindclade, LLC. All Rights Reserved.
# Mindclade Proprietary and Confidential.
# SPDX-License-Identifier: LicenseRef-Mindclade-Proprietary

# MINDCLADE CONFIDENTIAL - PROPRIETARY AND TRADE SECRET
# Copyright (c) 2026 Mindclade. All rights reserved.
"""Validate the Mindclade production repository contract.

This check intentionally uses only the Python standard library.
"""

from __future__ import annotations
import json
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
REPOSITORY = "bootstrap"
CONTRACT = json.loads(
    '{"authority": ["ring0-state", "automation-federation", "seed-projects", "break-glass-recovery"], "forbidden_authority": ["normal-folders", "normal-org-policy", "workload-projects", "networks", "gke", "kubernetes-desired-state"], "forbidden_paths": ["modules/folders", "modules/governance", ".terraform", ".terragrunt-cache"], "repository_class": "enterprise-control", "required_paths": ["AGENTS.md", "modules/state", "modules/identity", "modules/projects", "modules/naming", "docs/first-apply.md", "docs/break-glass.md", "docs/state-recovery.md"], "visibility": "private"}'
)
ERRORS = []


def error(msg):
    ERRORS.append(msg)


def delivery_paths() -> list[Path]:
    """Return tracked and untracked delivery paths, excluding standard ignored files."""
    if (ROOT / ".git").exists():
        result = subprocess.run(
            [
                "git",
                "-C",
                str(ROOT),
                "ls-files",
                "--cached",
                "--others",
                "--exclude-standard",
                "-z",
            ],
            check=True,
            capture_output=True,
        )
        return [
            ROOT / raw.decode("utf-8", errors="surrogateescape")
            for raw in result.stdout.split(b"\0")
            if raw
        ]
    return list(ROOT.rglob("*"))


DELIVERY_PATHS = delivery_paths()
DELIVERY_RELATIVE = {p.relative_to(ROOT).as_posix() for p in DELIVERY_PATHS}
LEGACY_GITHUB_IDENTITIES = (
    "Mind" + "clade/",
    "github.com/" + "Mind" + "clade",
    "/orgs/" + "Mind" + "clade",
)


def delivery_prefix_exists(relative: str) -> bool:
    prefix = relative.rstrip("/")
    return prefix in DELIVERY_RELATIVE or any(
        path.startswith(prefix + "/") for path in DELIVERY_RELATIVE
    )


repository_contract = (ROOT / "contracts/repository.yaml").read_text(
    "utf-8", errors="ignore"
)
if not re.search(r"(?m)^\s+merge_queue:\s+false\s*$", repository_contract):
    error(
        "enterprise-control repository contract must not require the production merge queue"
    )
for canonical_url in (
    "https://github.com/enterprises/mindclade",
    "https://github.com/mindclade",
    "https://github.com/orgs/mindclade/repositories",
    f"https://github.com/mindclade/{REPOSITORY}",
):
    if canonical_url not in repository_contract:
        error(f"repository contract omits canonical GitHub URL: {canonical_url}")

for rel in CONTRACT["required_paths"]:
    if not (ROOT / rel).exists():
        error(f"missing required path: {rel}")
for rel in CONTRACT["forbidden_paths"]:
    if delivery_prefix_exists(rel):
        error(f"forbidden delivery path present: {rel}")
for p in DELIVERY_PATHS:
    relative = p.relative_to(ROOT)
    if any(
        part in {".terraform", ".terragrunt-cache", "__MACOSX", "__pycache__"}
        for part in relative.parts
    ):
        error(f"local/cache artifact is present in delivery: {relative}")
    if (
        p.name.startswith("._")
        or ".tfstate" in p.name
        or "tfplan" in p.name
        or p.suffix == ".pyc"
    ):
        error(f"generated/sensitive artifact is present in delivery: {relative}")
    if p.is_symlink():
        error(f"symlink forbidden in delivery: {relative}")
    if p.is_file() and p.stat().st_size <= 2_000_000:
        text = p.read_text("utf-8", errors="ignore")
        if any(legacy in text for legacy in LEGACY_GITHUB_IDENTITIES):
            error(f"noncanonical GitHub organization identity in {relative}")

# GitHub Actions must be immutable and least privilege.
for p in (
    (ROOT / ".github/workflows").glob("*.y*ml")
    if (ROOT / ".github/workflows").exists()
    else []
):
    text = p.read_text("utf-8", errors="ignore")
    for use in re.findall(r"(?m)^\s*-?\s*uses:\s*([^#\s]+)", text):
        if use.startswith("./"):
            continue
        if not (
            re.search(r"@[0-9a-f]{40}$", use)
            or re.search(r"@sha256:[0-9a-f]{64}$", use)
            or re.fullmatch(
                r"mindclade/\.github/\.github/workflows/[^@]+@v[0-9]+\.[0-9]+\.[0-9]+",
                use,
            )
        ):
            error(
                f"workflow action is not immutable-pinned in {p.relative_to(ROOT)}: {use}"
            )
    if "permissions:" not in text:
        error(f"workflow lacks explicit permissions: {p.relative_to(ROOT)}")

# No obvious plaintext credentials. Values are intentionally conservative.
secret_patterns = [
    re.compile(r"-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----"),
    re.compile(r"AIza[0-9A-Za-z_-]{35}"),
    re.compile(r"gh[pousr]_[A-Za-z0-9]{30,}"),
]
for p in DELIVERY_PATHS:
    if not p.is_file() or p.stat().st_size > 2_000_000:
        continue
    try:
        text = p.read_text("utf-8", errors="ignore")
    except OSError:
        continue
    for pattern in secret_patterns:
        if pattern.search(text):
            error(f"possible credential in {p.relative_to(ROOT)}")

# The versioned Ring-0 output is the supported downstream interface. Keep its descriptor,
# schema, and Terraform declaration synchronized without requiring Terraform or cloud access.
try:
    output_schema = json.loads(
        (ROOT / "contracts/outputs.schema.json").read_text("utf-8")
    )
    platform_descriptor = json.loads(
        (ROOT / "contracts/platform.json").read_text("utf-8")
    )
except (OSError, json.JSONDecodeError) as exc:
    error(f"invalid bootstrap output contract metadata: {exc}")
else:
    contract_version = platform_descriptor.get("contract_version")
    if (
        output_schema.get("properties", {}).get("contract_version", {}).get("const")
        != contract_version
    ):
        error("output schema and platform descriptor contract versions differ")
    if platform_descriptor.get("terraform_output") != "platform_contract":
        error(
            "platform descriptor does not identify the platform_contract Terraform output"
        )
    outputs = (ROOT / "outputs.tf").read_text("utf-8", errors="ignore")
    if 'output "platform_contract"' not in outputs:
        error("missing versioned platform_contract Terraform output")
    if not re.search(
        rf"contract_version\s*=\s*{re.escape(json.dumps(contract_version))}", outputs
    ):
        error("platform_contract Terraform output version differs from its descriptor")
    for field in output_schema.get("required", []):
        if field not in outputs:
            error(f"platform_contract output is missing schema field: {field}")

release_manifest = json.loads((ROOT / "RELEASE_MANIFEST.json").read_text("utf-8"))
blueprint_path = release_manifest.get("blueprint", "")
if not blueprint_path or not (ROOT / blueprint_path).is_file():
    error(f"release manifest blueprint path does not exist: {blueprint_path}")

if REPOSITORY == "bootstrap":
    for forbidden in ("modules/folders", "modules/governance"):
        if (ROOT / forbidden).exists():
            error(f"Ring-0 boundary violation: {forbidden}")
    combined = "\n".join(
        p.read_text("utf-8", errors="ignore") for p in ROOT.rglob("*.tf")
    )
    if re.search(r'module\s+"(?:folders|governance)"', combined):
        error("Ring-0 root still instantiates folders/governance")
    for identity in (
        "artifact-builder",
        "artifact-qualifier",
        "artifact-signer",
        "artifact-promoter",
    ):
        if identity in combined:
            error(f"normal-plane supply-chain identity leaked into Ring 0: {identity}")
    wif = (ROOT / "modules/identity/wif.tf").read_text("utf-8", errors="ignore")
    buildkite = wif.split(
        'resource "google_iam_workload_identity_pool_provider" "buildkite"', 1
    )[-1]
    if '"google.subject"               = "assertion.pipeline_id"' not in buildkite:
        error(
            "Buildkite WIF does not map the bounded immutable pipeline ID as its subject"
        )
    if '"google.subject"               = "assertion.sub"' in buildkite:
        error("Buildkite WIF maps the potentially overlong compound default subject")
    if 'assertion.build_source == "webhook"' not in buildkite:
        error("deprecated Buildkite WIF is not restricted to webhook builds")
    if 'assertion.build_source in ["webhook", "api"]' in buildkite:
        error("deprecated Buildkite WIF still admits API-triggered builds")
    for capability in (
        "canary",
        "builder",
        "qualification-reader",
        "qualifier",
        "promoter",
    ):
        if f"{capability} = {{" not in wif:
            error(f"ARC WIF capability is missing: {capability}")
elif REPOSITORY == "github-config":
    text = (ROOT / "catalog/repositories.yaml").read_text("utf-8", errors="ignore")
    for repo in (
        ".github",
        "bootstrap",
        "github-config",
        "infrastructure-live",
        "gitops",
        "mindclade-internal-monorepo",
    ):
        if repo not in text:
            error(f"repository catalog missing {repo}")
    if "default_branch" not in text or "main" not in text:
        error("catalog does not enforce main as the default branch")
elif REPOSITORY == "gitops":
    for p in list((ROOT / "applications").glob("*.yaml")) + list(
        (ROOT / "projects").glob("*.yaml")
    ):
        text = p.read_text("utf-8", errors="ignore")
        if re.search(
            r'(?m)^\s*(?:sourceRepos|destinations):\s*\[?\s*["\']?\*["\']?', text
        ):
            error(f"wildcard Argo authority in {p.relative_to(ROOT)}")
    for p in ROOT.rglob("*.y*ml"):
        # Negative policy fixtures intentionally contain denied examples.
        if "tests" in p.parts or "testdata" in p.parts:
            continue
        text = p.read_text("utf-8", errors="ignore")
        if re.search(
            r'(?i)(?:image|newName|newTag):?[^\n]*(?::latest|newTag:\s*["\']?latest)',
            text,
        ):
            error(f"mutable image tag in {p.relative_to(ROOT)}")
        if re.search(r"(?m)^kind:\s*Secret\s*$", text) and re.search(
            r"(?m)^\s*(?:data|stringData):\s*$", text
        ):
            error(f"plaintext Kubernetes Secret object in {p.relative_to(ROOT)}")
elif REPOSITORY == "infrastructure-live":
    for env in ("development", "staging", "production"):
        if not (ROOT / f"5-workloads/{env}").is_dir():
            error(f"missing workload environment {env}")
    for p in ROOT.rglob("*.hcl"):
        text = p.read_text("utf-8", errors="ignore")
        if "ANY_IDENTITY" in text:
            error(f"VPC-SC ANY_IDENTITY escape in {p.relative_to(ROOT)}")
        if re.search(r"(?<![0-9])0\.0\.0\.0/0(?![0-9])", text) and re.search(
            r"(?i)(master_authorized|control[_-]?plane|authorized[_-]?network)", text
        ):
            error(
                f"broad control-plane CIDR in live configuration: {p.relative_to(ROOT)}"
            )

if ERRORS:
    for msg in sorted(set(ERRORS)):
        print(f"ERROR: {msg}", file=sys.stderr)
    print(f"{len(set(ERRORS))} production contract violation(s)", file=sys.stderr)
    raise SystemExit(1)
print(f"{REPOSITORY}: production contract passed")
