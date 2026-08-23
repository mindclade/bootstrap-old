#!/usr/bin/env python3
# Copyright © 2026 Mindclade, LLC. All Rights Reserved.
# Mindclade Proprietary and Confidential.
# SPDX-License-Identifier: LicenseRef-Mindclade-Proprietary

from __future__ import annotations

import json
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock


ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "scripts"))

from production_contract_checks import (  # noqa: E402
    validate_delivery_paths,
    validate_makefile_contract,
    validate_workflows,
)


class OutputContractTests(unittest.TestCase):
    def test_retired_buildkite_outputs_are_always_null(self) -> None:
        schema = json.loads((ROOT / "contracts/outputs.schema.json").read_text())
        buildkite = schema["properties"]["buildkite"]

        self.assertEqual(buildkite["properties"]["enabled"], {"const": False})
        self.assertEqual(
            buildkite["properties"]["workload_identity_pool"], {"type": "null"}
        )
        self.assertEqual(
            buildkite["properties"]["workload_identity_provider"], {"type": "null"}
        )


class WorkflowContractTests(unittest.TestCase):
    def test_missing_workflow_directory_fails_closed(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            errors = validate_workflows(Path(directory), ("validate.yml",))

        self.assertEqual(
            errors,
            ["required workflow directory is missing: .github/workflows"],
        )

    def test_missing_required_workflow_fails_closed(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / ".github/workflows").mkdir(parents=True)

            errors = validate_workflows(root, ("validate.yml",))

        self.assertEqual(
            errors,
            ["required workflow is missing: .github/workflows/validate.yml"],
        )

    def test_comment_cannot_satisfy_permissions_contract(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            workflow = root / ".github/workflows/validate.yml"
            workflow.parent.mkdir(parents=True)
            workflow.write_text(
                "name: validate\n"
                "on: pull_request\n"
                "# permissions:\n"
                "jobs:\n"
                "  validate:\n"
                "    runs-on: ubuntu-24.04\n"
                "    steps: []\n",
                encoding="utf-8",
            )

            errors = validate_workflows(root, ("validate.yml",))

        self.assertIn(
            "workflow must declare exactly one top-level permissions mapping: "
            ".github/workflows/validate.yml",
            errors,
        )

    def test_explicit_permissions_mapping_and_sha_pin_pass(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            workflow = root / ".github/workflows/validate.yml"
            workflow.parent.mkdir(parents=True)
            workflow.write_text(
                "name: validate\n"
                "on: pull_request\n"
                "permissions:\n"
                "  contents: read\n"
                "jobs:\n"
                "  validate:\n"
                "    runs-on: ubuntu-24.04\n"
                "    steps:\n"
                "      - uses: actions/checkout@"
                + "a" * 40
                + "\n",
                encoding="utf-8",
            )

            errors = validate_workflows(root, ("validate.yml",))

        self.assertEqual(errors, [])


class DeliveryScanTests(unittest.TestCase):
    def test_large_delivery_file_is_scanned_for_credentials(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            candidate = root / "large.bin"
            marker = b"gh" + b"p_" + (b"A" * 30)
            candidate.write_bytes((b"x" * 2_100_000) + marker)

            errors = validate_delivery_paths([candidate], root)

        self.assertEqual(errors, ["possible credential in large.bin"])

    def test_read_error_fails_closed_without_exception_details(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            candidate = root / "unreadable.txt"
            candidate.write_text("safe", encoding="utf-8")

            with mock.patch.object(
                Path,
                "open",
                side_effect=PermissionError("sensitive operating-system detail"),
            ):
                errors = validate_delivery_paths([candidate], root)

        self.assertEqual(
            errors,
            ["unable to scan delivery file unreadable.txt: PermissionError"],
        )
        self.assertNotIn("sensitive operating-system detail", errors[0])

    def test_stat_error_fails_closed_without_exception_details(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            candidate = root / "uninspectable.txt"

            with mock.patch.object(
                Path,
                "lstat",
                side_effect=OSError("sensitive operating-system detail"),
            ):
                errors = validate_delivery_paths([candidate], root)

        self.assertEqual(
            errors,
            ["unable to inspect delivery path uninspectable.txt: OSError"],
        )
        self.assertNotIn("sensitive operating-system detail", errors[0])


class MakefileContractTests(unittest.TestCase):
    def test_comments_cannot_satisfy_validation_wiring(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "Makefile").write_text(
                "# validate: validate-core\n"
                "# validate-core: validate-production-contract\n"
                "# python3 scripts/validate-production-contract.py\n",
                encoding="utf-8",
            )

            errors = validate_makefile_contract(root)

        self.assertIn("Makefile target validate must depend on validate-core", errors)
        self.assertIn(
            "Makefile target validate-production-contract must execute its "
            "production-contract command",
            errors,
        )

    def test_validation_targets_are_parsed_structurally(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "Makefile").write_text(
                "validate: validate-core validate-terraform validate-repository-home\n"
                "validate-core: validate-production-contract\n"
                "validate-terraform:\n"
                "validate-repository-home:\n"
                "validate-production-contract: validate-production-contract-tests\n"
                "\tpython3 scripts/validate-production-contract.py\n"
                "validate-production-contract-tests:\n"
                "\tpython3 -m unittest tests.test_production_contract\n",
                encoding="utf-8",
            )

            errors = validate_makefile_contract(root)

        self.assertEqual(errors, [])


if __name__ == "__main__":
    unittest.main()
