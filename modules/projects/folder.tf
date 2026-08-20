# Copyright © 2026 Mindclade, LLC. All Rights Reserved.
# Mindclade Proprietary and Confidential.
# SPDX-License-Identifier: LicenseRef-Mindclade-Proprietary
#

# Ring 0 owns exactly one bootstrap folder. Supplying bootstrap_folder_id adopts an existing
# folder without creating a second hierarchy.
resource "google_folder" "bootstrap" {
  count        = var.bootstrap_folder_id == "" ? 1 : 0
  display_name = "Mindclade Bootstrap"
  parent       = "organizations/${var.org_id}"

  lifecycle {
    prevent_destroy = true
  }
}
