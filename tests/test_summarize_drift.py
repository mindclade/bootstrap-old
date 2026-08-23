# Copyright © 2026 Mindclade, LLC. All Rights Reserved.
# Mindclade Proprietary and Confidential.
# SPDX-License-Identifier: LicenseRef-Mindclade-Proprietary

from __future__ import annotations

import importlib.util
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location("summarize_drift", ROOT / "scripts/summarize-drift.py")
assert SPEC is not None and SPEC.loader is not None
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)


class SummarizeDriftTest(unittest.TestCase):
    def test_addresses_are_not_exposed(self) -> None:
        result = MODULE.summarize(
            {"resource_changes": [{"address": "secret.path", "type": "google_storage_bucket", "change": {"actions": ["delete", "create"]}}]},
            "a" * 40,
        )
        self.assertEqual(result["actions"]["replace"], 1)
        self.assertTrue(result["risk"]["destructive"])
        self.assertNotIn("secret.path", str(result))


if __name__ == "__main__":
    unittest.main()
