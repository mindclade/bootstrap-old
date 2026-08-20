# Copyright © 2026 Mindclade, LLC. All Rights Reserved.
# Mindclade Proprietary and Confidential.
# SPDX-License-Identifier: LicenseRef-Mindclade-Proprietary


locals {
  state_buckets = {
    bootstrap                       = "Ring-0 bootstrap state"
    github-config                   = "GitHub Enterprise governance state"
    infrastructure-live-development = "Development live infrastructure state"
    infrastructure-live-staging     = "Staging live infrastructure state"
    infrastructure-live-production  = "Organization, shared, and production live infrastructure state"
  }

  readers = {
    bootstrap                       = ["bootstrap-plan", "bootstrap-drift"]
    github-config                   = ["github-config-plan"]
    infrastructure-live-development = ["infrastructure-live-plan"]
    infrastructure-live-staging     = ["infrastructure-live-plan"]
    infrastructure-live-production  = ["infrastructure-live-plan"]
  }
  writers = {
    bootstrap     = ["bootstrap-apply"]
    github-config = ["github-config-apply"]
    infrastructure-live-development = [
      "infrastructure-live-apply-foundation",
      "infrastructure-live-apply-development",
    ]
    infrastructure-live-staging = [
      "infrastructure-live-apply-foundation",
      "infrastructure-live-apply-staging",
    ]
    infrastructure-live-production = [
      "infrastructure-live-apply-foundation",
      "infrastructure-live-apply-production",
    ]
  }
  reader_bindings = merge([
    for scope, accounts in local.readers : {
      for account in accounts : "${scope}:${account}" => { scope = scope, account = account }
    }
  ]...)
  writer_bindings = merge([
    for scope, accounts in local.writers : {
      for account in accounts : "${scope}:${account}" => { scope = scope, account = account }
    }
  ]...)
}

resource "google_storage_bucket" "state" {
  # checkov:skip=CKV_GCP_62:Cloud Audit Logs DATA_READ/DATA_WRITE is enabled in modules/projects/seed.tf; a second server-access-log bucket would add another Ring-0 state dependency.
  for_each = local.state_buckets
  project  = var.seed_project_id
  name     = "${var.prefix}-tfstate-${each.key}-${var.suffix}"
  location = var.state_bucket_location

  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"
  force_destroy               = false

  versioning {
    enabled = true
  }
  soft_delete_policy {
    retention_duration_seconds = var.state_soft_delete_days * 86400
  }
  encryption {
    default_kms_key_name = var.primary_kms_key_id
  }

  lifecycle_rule {
    condition {
      days_since_noncurrent_time = var.noncurrent_version_days
      num_newer_versions         = var.noncurrent_version_count
    }
    action {
      type = "Delete"
    }
  }

  labels = merge(var.labels, { purpose = "terraform-state", "state-scope" = each.key })

  lifecycle {
    prevent_destroy = true
  }
}

resource "google_storage_bucket_iam_member" "reader" {
  for_each = local.reader_bindings
  bucket   = google_storage_bucket.state[each.value.scope].name
  role     = "roles/storage.objectViewer"
  member   = "serviceAccount:${var.service_account_emails[each.value.account]}"
}

resource "google_storage_bucket_iam_member" "writer" {
  for_each = local.writer_bindings
  bucket   = google_storage_bucket.state[each.value.scope].name
  role     = "roles/storage.objectAdmin"
  member   = "serviceAccount:${var.service_account_emails[each.value.account]}"
}
