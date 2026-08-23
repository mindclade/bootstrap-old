# Copyright © 2026 Mindclade, LLC. All Rights Reserved.
# Mindclade Proprietary and Confidential.
# SPDX-License-Identifier: LicenseRef-Mindclade-Proprietary

from __future__ import annotations

import datetime as dt
import importlib.util
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location("dr_readiness", ROOT / "scripts/dr-readiness.py")
assert SPEC is not None and SPEC.loader is not None
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)


class DrReadinessTest(unittest.TestCase):
    def test_current_source_is_not_falsely_qualified(self) -> None:
        result = MODULE.derive(dt.date(2026, 8, 23))
        self.assertEqual(result["summary"]["productionReady"], 0)
        self.assertEqual(result["summary"]["notRun"], 10)
        self.assertEqual(result["summary"]["critical"], 0)
        self.assertEqual(result["summary"]["warning"], 3)

    def test_overdue_status_is_derived(self) -> None:
        result = MODULE.derive(dt.date(2026, 10, 14))
        self.assertGreater(result["summary"]["overdue"], 0)


if __name__ == "__main__":
    unittest.main()
