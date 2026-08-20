# Copyright © 2026 Mindclade, LLC. All Rights Reserved.
# Mindclade Proprietary and Confidential.
# SPDX-License-Identifier: LicenseRef-Mindclade-Proprietary


resource "google_project" "cicd" {
  name       = "${var.prefix}-b-cicd"
  project_id = local.cicd_project_id
  folder_id  = local.bootstrap_folder_name

  billing_account     = var.billing_account
  auto_create_network = false
  deletion_policy     = "PREVENT"
  labels              = merge(var.labels, { purpose = "ring0-federation" })
}

resource "google_project_service" "cicd" {
  for_each = toset([
    "cloudidentity.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "iam.googleapis.com",
    "iamcredentials.googleapis.com",
    "logging.googleapis.com",
    "serviceusage.googleapis.com",
    "sts.googleapis.com",
  ])
  project = google_project.cicd.project_id
  service = each.value

  disable_on_destroy         = false
  disable_dependent_services = false
}

data "google_project" "cicd" {
  project_id = google_project.cicd.project_id
  depends_on = [google_project.cicd]
}

# Workload Identity Federation token exchange is anchored in the project containing the pool.
# Google Cloud records the complete exchange only when Admin Read logging is enabled for both
# IAM and STS in that project. Normal organization-wide sinks remain infrastructure-live owned.
resource "google_project_iam_audit_config" "cicd_token_exchange" {
  for_each = toset([
    "iam.googleapis.com",
    "sts.googleapis.com",
  ])

  project = google_project.cicd.project_id
  service = each.value

  audit_log_config {
    log_type = "ADMIN_READ"
  }

  audit_log_config {
    log_type = "DATA_READ"
  }

  audit_log_config {
    log_type = "DATA_WRITE"
  }
}
