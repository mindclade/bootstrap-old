# Copyright © 2026 Mindclade, LLC. All Rights Reserved.
# Mindclade Proprietary and Confidential.
# SPDX-License-Identifier: LicenseRef-Mindclade-Proprietary
#

locals {
  seed_project_id = "${var.prefix}-b-seed-${var.suffix}"
  cicd_project_id = "${var.prefix}-b-cicd-${var.suffix}"

  bootstrap_folder_name = var.bootstrap_folder_id != "" ? var.bootstrap_folder_id : google_folder.bootstrap[0].name
}
