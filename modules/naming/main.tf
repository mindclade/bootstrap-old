# Copyright © 2026 Mindclade, LLC. All Rights Reserved.
# Mindclade Proprietary and Confidential.
# SPDX-License-Identifier: LicenseRef-Mindclade-Proprietary

# The random suffix that keeps project ids globally unique.
#
# A module of its own so that no resource is declared at the root — and because every other
# module consumes it, which makes it a shared primitive rather than something belonging to
# any one of them.
#
# Kept in state, so it is stable across applies. Regenerating it renames every project, which
# Terraform implements as delete-and-recreate; if state is ever lost, the procedure in
# docs/state-recovery.md imports the existing value rather than making a new one.
resource "random_id" "suffix" {
  byte_length = 3
}
