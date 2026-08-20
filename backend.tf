# Copyright © 2026 Mindclade, LLC. All Rights Reserved.
# Mindclade Proprietary and Confidential.
# SPDX-License-Identifier: LicenseRef-Mindclade-Proprietary

terraform {
  # Partial configuration avoids committing the globally unique bucket name.
  # First apply: use scripts/prepare-first-apply.py to export an exact commit without this
  # file. `terraform init -backend=false` is validation-only and cannot prepare a plan-capable
  # local backend when a partial GCS backend is present.
  # After state buckets exist: terraform init -migrate-state -backend-config="bucket=<bootstrap-bucket>"
  backend "gcs" {
    prefix = "bootstrap"
  }
}
