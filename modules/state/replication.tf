# Copyright © 2026 Mindclade, LLC. All Rights Reserved.
# Mindclade Proprietary and Confidential.
# SPDX-License-Identifier: LicenseRef-Mindclade-Proprietary


resource "google_project_service" "storage_transfer" {
  project = var.seed_project_id
  service = "storagetransfer.googleapis.com"

  disable_on_destroy         = false
  disable_dependent_services = false
}

resource "google_storage_bucket" "legacy_replica" {
  # checkov:skip=CKV_GCP_62:Cloud Audit Logs DATA_READ/DATA_WRITE is enabled in modules/projects/seed.tf; a second server-access-log bucket would add another Ring-0 state dependency.
  for_each = var.preserve_legacy_eu_state_replicas ? local.state_buckets : {}
  project  = var.seed_project_id
  name     = "${var.prefix}-tfstate-${each.key}-replica-${var.suffix}"
  location = "europe-west4"

  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"
  force_destroy               = false

  versioning {
    enabled = true
  }
  soft_delete_policy {
    retention_duration_seconds = min(var.state_soft_delete_days * 2, 90) * 86400
  }
  encryption {
    default_kms_key_name = var.legacy_replica_kms_key_id
  }
  lifecycle_rule {
    condition {
      days_since_noncurrent_time = var.noncurrent_version_days * 2
      num_newer_versions         = var.noncurrent_version_count
    }
    action {
      type = "Delete"
    }
  }

  labels = merge(var.labels, { purpose = "terraform-state-replica", "state-scope" = each.key })

  lifecycle {
    prevent_destroy = true
  }
}

moved {
  from = google_storage_bucket.replica
  to   = google_storage_bucket.legacy_replica
}

# The us-only-v1 recovery copy uses distinct immutable bucket names. This is deliberately
# additive so Terraform cannot propose replacing a protected legacy bucket to change location.
resource "google_storage_bucket" "replica_us" {
  # checkov:skip=CKV_GCP_62:Cloud Audit Logs DATA_READ/DATA_WRITE is enabled in modules/projects/seed.tf; a second server-access-log bucket would add another Ring-0 state dependency.
  for_each = local.state_buckets
  project  = var.seed_project_id
  name     = "${var.prefix}-tfstate-${each.key}-replica-us-${var.suffix}"
  location = var.state_replica_location

  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"
  force_destroy               = false

  versioning {
    enabled = true
  }
  soft_delete_policy {
    retention_duration_seconds = min(var.state_soft_delete_days * 2, 90) * 86400
  }
  encryption {
    default_kms_key_name = var.replica_kms_key_id
  }
  lifecycle_rule {
    condition {
      days_since_noncurrent_time = var.noncurrent_version_days * 2
      num_newer_versions         = var.noncurrent_version_count
    }
    action {
      type = "Delete"
    }
  }

  labels = merge(var.labels, {
    purpose       = "terraform-state-replica"
    "state-scope" = each.key
    residency     = "us-only-v1"
  })

  lifecycle {
    prevent_destroy = true
  }
}

data "google_storage_transfer_project_service_account" "seed" {
  project    = var.seed_project_id
  depends_on = [google_project_service.storage_transfer]
}

resource "google_storage_bucket_iam_member" "transfer_source_bucket_reader" {
  for_each = local.state_buckets
  bucket   = google_storage_bucket.state[each.key].name
  role     = "roles/storage.legacyBucketReader"
  member   = "serviceAccount:${data.google_storage_transfer_project_service_account.seed.email}"
}

resource "google_storage_bucket_iam_member" "transfer_source_object_viewer" {
  for_each = local.state_buckets
  bucket   = google_storage_bucket.state[each.key].name
  role     = "roles/storage.objectViewer"
  member   = "serviceAccount:${data.google_storage_transfer_project_service_account.seed.email}"
}

resource "google_storage_bucket_iam_member" "transfer_legacy_sink_bucket_writer" {
  for_each = var.preserve_legacy_eu_state_replicas ? local.state_buckets : {}
  bucket   = google_storage_bucket.legacy_replica[each.key].name
  role     = "roles/storage.legacyBucketWriter"
  member   = "serviceAccount:${data.google_storage_transfer_project_service_account.seed.email}"
}

moved {
  from = google_storage_bucket_iam_member.transfer_sink_bucket_writer
  to   = google_storage_bucket_iam_member.transfer_legacy_sink_bucket_writer
}

resource "google_storage_bucket_iam_member" "transfer_us_sink_bucket_writer" {
  for_each = local.state_buckets
  bucket   = google_storage_bucket.replica_us[each.key].name
  role     = "roles/storage.legacyBucketWriter"
  member   = "serviceAccount:${data.google_storage_transfer_project_service_account.seed.email}"
}

# The protected recovery workflow uses the read-only bootstrap plan identity. It already has
# access to authoritative bootstrap state, so replica read access does not widen its data class;
# it makes the documented independent recovery path testable without an apply identity.
resource "google_storage_bucket_iam_member" "bootstrap_legacy_replica_recovery_reader" {
  count = var.preserve_legacy_eu_state_replicas ? 1 : 0

  bucket = google_storage_bucket.legacy_replica["bootstrap"].name
  role   = "roles/storage.objectViewer"
  member = "serviceAccount:${var.service_account_emails["bootstrap-plan"]}"
}

moved {
  from = google_storage_bucket_iam_member.bootstrap_replica_recovery_reader
  to   = google_storage_bucket_iam_member.bootstrap_legacy_replica_recovery_reader[0]
}

resource "google_storage_bucket_iam_member" "bootstrap_us_replica_recovery_reader" {
  bucket = google_storage_bucket.replica_us["bootstrap"].name
  role   = "roles/storage.objectViewer"
  member = "serviceAccount:${var.service_account_emails["bootstrap-plan"]}"
}

resource "google_storage_transfer_job" "state_legacy" {
  for_each    = var.preserve_legacy_eu_state_replicas ? local.state_buckets : {}
  project     = var.seed_project_id
  description = "Replicate ${each.key} Terraform state to the legacy recovery estate"

  transfer_spec {
    gcs_data_source {
      bucket_name = google_storage_bucket.state[each.key].name
    }
    gcs_data_sink {
      bucket_name = google_storage_bucket.legacy_replica[each.key].name
    }
    transfer_options {
      delete_objects_from_source_after_transfer  = false
      delete_objects_unique_in_sink              = false
      overwrite_objects_already_existing_in_sink = true
    }
  }

  schedule {
    schedule_start_date {
      year  = 2026
      month = 1
      day   = 1
    }
    start_time_of_day {
      hours   = 3
      minutes = 17
      seconds = 0
      nanos   = 0
    }
    # Hourly bounds source-to-recovery state lag while retaining deletion independence.
    repeat_interval = "3600s"
  }

  logging_config {
    log_actions       = ["FIND", "COPY"]
    log_action_states = ["SUCCEEDED", "FAILED"]
  }

  depends_on = [
    google_storage_bucket_iam_member.transfer_source_bucket_reader,
    google_storage_bucket_iam_member.transfer_source_object_viewer,
    google_storage_bucket_iam_member.transfer_legacy_sink_bucket_writer,
  ]
}

moved {
  from = google_storage_transfer_job.state
  to   = google_storage_transfer_job.state_legacy
}

resource "google_storage_transfer_job" "state_us" {
  for_each    = local.state_buckets
  project     = var.seed_project_id
  description = "Replicate ${each.key} Terraform state to us-east4"

  transfer_spec {
    gcs_data_source {
      bucket_name = google_storage_bucket.state[each.key].name
    }
    gcs_data_sink {
      bucket_name = google_storage_bucket.replica_us[each.key].name
    }
    transfer_options {
      delete_objects_from_source_after_transfer  = false
      delete_objects_unique_in_sink              = false
      overwrite_objects_already_existing_in_sink = true
    }
  }

  schedule {
    schedule_start_date {
      year  = 2026
      month = 1
      day   = 1
    }
    start_time_of_day {
      hours   = 3
      minutes = 47
      seconds = 0
      nanos   = 0
    }
    repeat_interval = "3600s"
  }

  logging_config {
    log_actions       = ["FIND", "COPY"]
    log_action_states = ["SUCCEEDED", "FAILED"]
  }

  depends_on = [
    google_storage_bucket_iam_member.transfer_source_bucket_reader,
    google_storage_bucket_iam_member.transfer_source_object_viewer,
    google_storage_bucket_iam_member.transfer_us_sink_bucket_writer,
  ]
}
