# Copyright © 2026 Mindclade, LLC. All Rights Reserved.
# Mindclade Proprietary and Confidential.
# SPDX-License-Identifier: LicenseRef-Mindclade-Proprietary

terraform {
  # Partial configuration avoids committing the globally unique bucket name.
  # First apply: terraform init -backend=false
  # After state buckets exist: terraform init -migrate-state -backend-config="bucket=<bootstrap-bucket>"
  backend "gcs" {
    prefix = "bootstrap"
  }
}
