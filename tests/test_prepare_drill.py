# Copyright © 2026 Mindclade, LLC. All Rights Reserved.
# Mindclade Proprietary and Confidential.
# SPDX-License-Identifier: LicenseRef-Mindclade-Proprietary

from __future__ import annotations

import datetime as dt
import importlib.util
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location("prepare_drill", ROOT / "scripts/prepare-drill.py")
assert SPEC is not None and SPEC.loader is not None
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)


class PrepareDrillTest(unittest.TestCase):
    def test_packet_is_source_and_change_bound(self) -> None:
        packet = MODULE.create_packet(
            "terraform-state-recovery",
            "primary-user",
            "observer-user",
            "https://github.com/mindclade/bootstrap/issues/123",
            "a" * 40,
            dt.datetime(2026, 8, 23, tzinfo=dt.timezone.utc),
        )
        self.assertEqual(packet["reportSchema"], "mindclade/.github/schemas/drill-report-v3.schema.json")
        self.assertEqual(packet["reportSeed"]["objectives"], {"rpo_seconds": 86400, "rto_seconds": 14400})
        self.assertEqual(packet["reportSeed"]["schema_version"], 3)

    def test_same_operator_is_rejected(self) -> None:
        with self.assertRaisesRegex(ValueError, "distinct"):
            MODULE.create_packet(
                "bootstrap-clean-room",
                "same-user",
                "same-user",
                "https://github.com/mindclade/bootstrap/pull/1",
                "b" * 40,
                dt.datetime(2026, 8, 23, tzinfo=dt.timezone.utc),
            )


if __name__ == "__main__":
    unittest.main()
