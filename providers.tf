# Copyright © 2026 Mindclade, LLC. All Rights Reserved.
# Mindclade Proprietary and Confidential.
# SPDX-License-Identifier: LicenseRef-Mindclade-Proprietary
#
provider "google" {
  region          = var.region
  default_labels  = var.labels
  request_timeout = "120s"
}

provider "google-beta" {
  region          = var.region
  default_labels  = var.labels
  request_timeout = "120s"
}

data "google_billing_account" "this" {
  billing_account = var.billing_account
  open            = true
}
