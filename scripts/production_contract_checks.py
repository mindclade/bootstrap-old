#!/usr/bin/env python3
# Copyright © 2026 Mindclade, LLC. All Rights Reserved.
# Mindclade Proprietary and Confidential.
# SPDX-License-Identifier: LicenseRef-Mindclade-Proprietary

# MINDCLADE CONFIDENTIAL - PROPRIETARY AND TRADE SECRET
# Copyright (c) 2026 Mindclade. All rights reserved.
"""Behavioral checks used by the bootstrap production-contract validator."""

from __future__ import annotations

import re
import shlex
import stat
from collections.abc import Iterable, Sequence
from pathlib import Path


REQUIRED_WORKFLOWS = (
    "apply.yml",
    "dr-evidence.yml",
    "dr-readiness.yml",
    "drift.yml",
    "license-headers.yml",
    "nix-flake.yml",
    "nix-qualification.yml",
    "plan.yml",
    "prepare-drill.yml",
    "production-contract.yml",
    "recovery-drill.yml",
    "validate.yml",
)

_ACTION_PIN = re.compile(
    r"(?:@[0-9a-f]{40}|@sha256:[0-9a-f]{64})$"
    r"|^mindclade/\.github/\.github/workflows/[^@]+"
    r"@v[0-9]+\.[0-9]+\.[0-9]+$"
)
_USES = re.compile(r"^\s*-?\s*uses:\s*([^#\s]+)")
_PERMISSIONS = re.compile(r"^(?P<indent> *)permissions:\s*(?P<value>[^#]*?)\s*(?:#.*)?$")
_PERMISSION_ENTRY = re.compile(
    r"^(?P<indent> +)(?P<name>[a-z-]+):\s*(?P<access>read|write|none)\s*(?:#.*)?$"
)
_PERMISSION_NAMES = frozenset(
    {
        "actions",
        "attestations",
        "checks",
        "contents",
        "deployments",
        "discussions",
        "id-token",
        "issues",
        "models",
        "packages",
        "pages",
        "pull-requests",
        "security-events",
        "statuses",
    }
)
_CONTENT_PATTERNS = (
    (
        "noncanonical GitHub organization identity",
        (
            ("Mind" + "clade/").encode(),
            ("github.com/" + "Mind" + "clade").encode(),
            ("/orgs/" + "Mind" + "clade").encode(),
        ),
    ),
    (
        "possible credential",
        (
            re.compile(br"-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----"),
            re.compile(br"AIza[0-9A-Za-z_-]{35}"),
            re.compile(br"gh[pousr]_[A-Za-z0-9]{30,}"),
        ),
    ),
)
_SCAN_CHUNK_SIZE = 1024 * 1024
_SCAN_OVERLAP = 512


def _relative(path: Path, root: Path) -> str:
    try:
        return path.relative_to(root).as_posix()
    except ValueError:
        return path.as_posix()


def _noncomment_lines(text: str) -> list[tuple[int, str]]:
    return [
        (line_number, line)
        for line_number, line in enumerate(text.splitlines(), start=1)
        if line.strip() and not line.lstrip().startswith("#")
    ]


def _validate_permissions(path: Path, root: Path, text: str) -> list[str]:
    errors: list[str] = []
    relative = _relative(path, root)
    lines = _noncomment_lines(text)
    permission_nodes: list[tuple[int, int, str]] = []

    for line_number, line in lines:
        match = _PERMISSIONS.fullmatch(line)
        if match is None:
            continue
        indent = len(match.group("indent"))
        if indent in {0, 4}:
            permission_nodes.append((line_number, indent, match.group("value")))

    top_level = [node for node in permission_nodes if node[1] == 0]
    if len(top_level) != 1:
        errors.append(
            f"workflow must declare exactly one top-level permissions mapping: {relative}"
        )

    line_lookup = {line_number: line for line_number, line in lines}
    ordered_line_numbers = [line_number for line_number, _ in lines]
    for line_number, indent, raw_value in permission_nodes:
        value = raw_value.strip()
        location = f"{relative}:{line_number}"
        if value == "{}":
            continue
        if value:
            errors.append(
                f"workflow permissions must use an explicit mapping, not a scalar: {location}"
            )
            continue

        entries = 0
        start_index = ordered_line_numbers.index(line_number) + 1
        for child_line_number in ordered_line_numbers[start_index:]:
            child_line = line_lookup[child_line_number]
            child_indent = len(child_line) - len(child_line.lstrip(" "))
            if child_indent <= indent:
                break
            entry = _PERMISSION_ENTRY.fullmatch(child_line)
            if entry is None or len(entry.group("indent")) <= indent:
                errors.append(
                    f"workflow permissions mapping contains an invalid entry: "
                    f"{relative}:{child_line_number}"
                )
                continue
            entries += 1
            if entry.group("name") not in _PERMISSION_NAMES:
                errors.append(
                    f"workflow permissions mapping contains an unknown permission: "
                    f"{relative}:{child_line_number}"
                )
        if entries == 0:
            errors.append(f"workflow permissions mapping is empty: {location}")

    return errors


def validate_workflows(
    root: Path,
    required_workflows: Sequence[str] = REQUIRED_WORKFLOWS,
) -> list[str]:
    errors: list[str] = []
    workflow_dir = root / ".github/workflows"
    if not workflow_dir.is_dir():
        return ["required workflow directory is missing: .github/workflows"]

    workflows = sorted(
        path
        for path in workflow_dir.iterdir()
        if path.is_file() and path.suffix in {".yml", ".yaml"}
    )
    workflow_names = {path.name for path in workflows}
    for name in sorted(set(required_workflows) - workflow_names):
        errors.append(f"required workflow is missing: .github/workflows/{name}")

    for path in workflows:
        relative = _relative(path, root)
        try:
            text = path.read_text(encoding="utf-8")
        except (OSError, UnicodeError) as exc:
            errors.append(
                f"unable to inspect workflow {relative}: {type(exc).__name__}"
            )
            continue
        for line_number, line in enumerate(text.splitlines(), start=1):
            match = _USES.match(line)
            if match is None:
                continue
            use = match.group(1)
            if use.startswith("./") or _ACTION_PIN.search(use):
                continue
            errors.append(
                f"workflow action is not immutable-pinned in {relative}:{line_number}"
            )
        errors.extend(_validate_permissions(path, root, text))

    return errors


def _scan_content(path: Path, relative: str) -> list[str]:
    violations: set[str] = set()
    try:
        with path.open("rb") as source:
            overlap = b""
            while chunk := source.read(_SCAN_CHUNK_SIZE):
                content = overlap + chunk
                for violation, patterns in _CONTENT_PATTERNS:
                    if any(
                        pattern.search(content)
                        if isinstance(pattern, re.Pattern)
                        else pattern in content
                        for pattern in patterns
                    ):
                        violations.add(violation)
                overlap = content[-_SCAN_OVERLAP:]
    except OSError as exc:
        return [f"unable to scan delivery file {relative}: {type(exc).__name__}"]
    return [f"{violation} in {relative}" for violation in sorted(violations)]


def validate_delivery_paths(paths: Iterable[Path], root: Path) -> list[str]:
    errors: list[str] = []
    for path in paths:
        relative = _relative(path, root)
        relative_path = Path(relative)
        try:
            mode = path.lstat().st_mode
        except OSError as exc:
            errors.append(
                f"unable to inspect delivery path {relative}: {type(exc).__name__}"
            )
            continue

        if any(
            part in {".terraform", ".terragrunt-cache", "__MACOSX", "__pycache__"}
            for part in relative_path.parts
        ):
            errors.append(f"local/cache artifact is present in delivery: {relative}")
        if (
            path.name.startswith("._")
            or ".tfstate" in path.name
            or "tfplan" in path.name
            or path.suffix == ".pyc"
        ):
            errors.append(f"generated/sensitive artifact is present in delivery: {relative}")
        if stat.S_ISLNK(mode):
            errors.append(f"symlink forbidden in delivery: {relative}")
            continue
        if stat.S_ISREG(mode):
            errors.extend(_scan_content(path, relative))
    return errors


def _parse_makefile(text: str) -> dict[str, tuple[set[str], list[list[str]]]]:
    targets: dict[str, tuple[set[str], list[list[str]]]] = {}
    current_targets: list[str] = []
    for raw_line in text.splitlines():
        if not raw_line.strip() or raw_line.lstrip().startswith("#"):
            continue
        if raw_line.startswith("\t"):
            if not current_targets:
                continue
            try:
                command = shlex.split(raw_line[1:], comments=True)
            except ValueError:
                command = []
            for target in current_targets:
                targets[target][1].append(command)
            continue
        current_targets = []
        if raw_line.startswith(".") and raw_line.startswith(".PHONY:"):
            continue
        match = re.fullmatch(r"([^:=\s][^:]*)\s*:\s*([^#]*?)(?:\s+#.*)?", raw_line)
        if match is None:
            continue
        names = match.group(1).split()
        prerequisites = set(match.group(2).split())
        current_targets = names
        for name in names:
            targets.setdefault(name, (set(), []))[0].update(prerequisites)
    return targets


def validate_makefile_contract(root: Path) -> list[str]:
    path = root / "Makefile"
    try:
        text = path.read_text(encoding="utf-8")
    except (OSError, UnicodeError) as exc:
        return [f"unable to inspect Makefile: {type(exc).__name__}"]

    targets = _parse_makefile(text)
    errors: list[str] = []
    required_edges = (
        ("validate", "validate-core"),
        ("validate", "validate-terraform"),
        ("validate", "validate-repository-home"),
        ("validate-core", "validate-production-contract"),
        ("validate-production-contract", "validate-production-contract-tests"),
    )
    for target, prerequisite in required_edges:
        if target not in targets or prerequisite not in targets[target][0]:
            errors.append(
                f"Makefile target {target} must depend on {prerequisite}"
            )

    expected_commands = {
        "validate-production-contract": [
            "python3",
            "scripts/validate-production-contract.py",
        ],
        "validate-production-contract-tests": [
            "python3",
            "-m",
            "unittest",
            "tests.test_production_contract",
        ],
    }
    for target, command in expected_commands.items():
        if target not in targets or command not in targets[target][1]:
            errors.append(
                f"Makefile target {target} must execute its production-contract command"
            )
    return errors
