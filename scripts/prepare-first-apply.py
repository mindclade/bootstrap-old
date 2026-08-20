#!/usr/bin/env python3
# Copyright © 2026 Mindclade, LLC. All Rights Reserved.
# Mindclade Proprietary and Confidential.
# SPDX-License-Identifier: LicenseRef-Mindclade-Proprietary

"""Export an exact clean bootstrap commit without its configured GCS backend.

Terraform cannot create the GCS backend while simultaneously using that backend. This helper
creates the only supported local-state working tree for a greenfield first apply. It exports
Git objects rather than copying the checkout, so untracked files, credentials, caches, and
working-tree edits cannot enter the first-apply directory.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import subprocess
import sys
from pathlib import Path, PurePosixPath


ROOT = Path(__file__).resolve().parent.parent
BACKEND_PATTERN = re.compile(r'(?m)^\s*backend\s+"[^"]+"\s*\{')


def command(*args: str, text: bool = True) -> subprocess.CompletedProcess:
    return subprocess.run(
        ["git", "-C", str(ROOT), *args],
        check=True,
        capture_output=True,
        text=text,
    )


def fail(message: str) -> int:
    print(f"error: {message}", file=sys.stderr)
    return 2


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Prepare an exact clean-commit work tree for the one-time local bootstrap apply."
    )
    parser.add_argument(
        "--commit",
        required=True,
        help="Reviewed full 40-character commit SHA; it must equal the clean checkout's HEAD.",
    )
    parser.add_argument(
        "--work-dir",
        required=True,
        type=Path,
        help="New dedicated directory on approved encrypted storage; it must not already exist.",
    )
    return parser.parse_args()


def is_within(path: Path, parent: Path) -> bool:
    try:
        path.relative_to(parent)
    except ValueError:
        return False
    return True


def tree_entries(commit: str) -> list[tuple[str, str, str]]:
    result = command("ls-tree", "-rz", "--full-tree", commit, text=False)
    entries: list[tuple[str, str, str]] = []
    for raw in result.stdout.split(b"\0"):
        if not raw:
            continue
        metadata, separator, encoded_path = raw.partition(b"\t")
        if not separator:
            raise ValueError("git ls-tree returned a malformed entry")
        mode, object_type, object_id = metadata.decode("ascii").split()
        if object_type != "blob" or mode not in {"100644", "100755"}:
            raise ValueError(
                f"unsupported Git tree entry {encoded_path!r}: {mode} {object_type}"
            )
        relative = encoded_path.decode("utf-8", errors="strict")
        path = PurePosixPath(relative)
        if path.is_absolute() or not path.parts or any(part in {"", ".", ".."} for part in path.parts):
            raise ValueError(f"unsafe Git tree path: {relative!r}")
        entries.append((mode, object_id, relative))
    return entries


def main() -> int:
    args = parse_args()
    if not re.fullmatch(r"[0-9a-f]{40}", args.commit):
        return fail("--commit must be a lowercase full 40-character Git SHA")

    try:
        head = command("rev-parse", "HEAD").stdout.strip()
        resolved = command("rev-parse", "--verify", f"{args.commit}^{{commit}}").stdout.strip()
        dirty = command("status", "--porcelain=v1", "--untracked-files=all").stdout
    except subprocess.CalledProcessError as error:
        print(error.stderr, file=sys.stderr, end="")
        return fail("cannot resolve the reviewed source commit")

    if resolved != args.commit or head != args.commit:
        return fail("--commit must resolve exactly to the checkout's current HEAD")
    if dirty:
        return fail("source checkout is not clean; commit or remove every tracked and untracked change")

    destination = args.work_dir.expanduser().resolve()
    if destination == ROOT or is_within(destination, ROOT):
        return fail("--work-dir must be outside the source repository")
    if destination.exists():
        return fail("--work-dir already exists; choose a new dedicated directory")

    try:
        entries = tree_entries(args.commit)
        if not any(relative == "backend.tf" for _, _, relative in entries):
            return fail("reviewed commit does not contain the expected root backend.tf")

        destination.mkdir(mode=0o700, parents=True, exist_ok=False)
        for mode, object_id, relative in entries:
            if relative == "backend.tf":
                continue
            target = destination.joinpath(*PurePosixPath(relative).parts)
            target.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
            blob = command("cat-file", "blob", object_id, text=False).stdout
            target.write_bytes(blob)
            target.chmod(0o755 if mode == "100755" else 0o600)

        backend_files = []
        for terraform_file in destination.rglob("*.tf"):
            if BACKEND_PATTERN.search(terraform_file.read_text("utf-8", errors="ignore")):
                backend_files.append(terraform_file.relative_to(destination).as_posix())
        if backend_files:
            raise ValueError(
                "export still contains Terraform backend blocks: " + ", ".join(backend_files)
            )

        marker = {
            "schema": "mindclade.bootstrap.first-apply/v1",
            "source_commit": args.commit,
            "backend_omitted": True,
        }
        destination.joinpath(".mindclade-first-apply.json").write_text(
            json.dumps(marker, indent=2, sort_keys=True) + "\n", encoding="utf-8"
        )
        os.chmod(destination / ".mindclade-first-apply.json", 0o600)
    except (OSError, UnicodeDecodeError, ValueError, subprocess.CalledProcessError) as error:
        # Leave an incomplete directory in place. Its existence prevents an operator from
        # accidentally reusing a partially exported tree; inspect and remove that exact path.
        return fail(f"first-apply export failed; inspect {destination}: {error}")

    print(
        f"prepared exact commit {args.commit} without backend.tf at {destination}",
        file=sys.stderr,
    )
    print(destination)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
