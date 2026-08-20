# Copyright © 2026 Mindclade, LLC. All Rights Reserved.
# Mindclade Proprietary and Confidential.
# SPDX-License-Identifier: LicenseRef-Mindclade-Proprietary


resource "google_project" "seed" {
  name       = "${var.prefix}-b-seed"
  project_id = local.seed_project_id
  folder_id  = local.bootstrap_folder_name

  billing_account     = var.billing_account
  auto_create_network = false
  deletion_policy     = "PREVENT"
  labels              = merge(var.labels, { purpose = "ring0-seed" })
}

locals {
  seed_services = toset([
    "cloudbilling.googleapis.com",
    "cloudkms.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "iam.googleapis.com",
    "iamcredentials.googleapis.com",
    "logging.googleapis.com",
    "monitoring.googleapis.com",
    # The seed project is the authoritative quota project for normal-plane organization-policy
    # reconciliation; bootstrap enables the API but does not own any organization policy.
    "orgpolicy.googleapis.com",
    "secretmanager.googleapis.com",
    "serviceusage.googleapis.com",
    "storage.googleapis.com",
  ])
}

resource "google_project_service" "seed" {
  for_each = local.seed_services
  project  = google_project.seed.project_id
  service  = each.value

  disable_on_destroy         = false
  disable_dependent_services = false
}

resource "google_kms_key_ring" "state_primary" {
  project  = google_project_service.seed["cloudkms.googleapis.com"].project
  name     = "${var.prefix}-bootstrap-state-primary"
  location = var.state_kms_location
}

resource "google_kms_crypto_key" "state_primary" {
  name            = "tfstate"
  key_ring        = google_kms_key_ring.state_primary.id
  purpose         = "ENCRYPT_DECRYPT"
  rotation_period = "7776000s"

  version_template {
    algorithm        = "GOOGLE_SYMMETRIC_ENCRYPTION"
    protection_level = var.kms_protection_level
  }

  lifecycle {
    prevent_destroy = true
  }
}

# A partially completed first apply may have created the original automation-secrets key in
# the `us` state key ring before the configured global Secret Manager resource rejected that
# replica location. Preserve the key in Google Cloud without retaining a dead state owner; it
# never encrypted a secret version because the secret container could not be created.
removed {
  from = google_kms_crypto_key.automation_secrets

  lifecycle {
    destroy = false
  }
}

# Ring-0 automation secrets use a dedicated regional key ring. Secret Manager requires a
# user-managed replica's CMEK to be in exactly the same supported location as the replica;
# state uses a separate multi-region key and must not be reused here.
resource "google_kms_key_ring" "automation_secrets" {
  project  = google_project_service.seed["cloudkms.googleapis.com"].project
  name     = "${var.prefix}-bootstrap-automation-secrets"
  location = var.automation_secret_location
}

resource "google_kms_crypto_key" "automation_secrets_regional" {
  name            = "automation-secrets"
  key_ring        = google_kms_key_ring.automation_secrets.id
  purpose         = "ENCRYPT_DECRYPT"
  rotation_period = "7776000s"

  version_template {
    algorithm        = "GOOGLE_SYMMETRIC_ENCRYPTION"
    protection_level = var.kms_protection_level
  }

  lifecycle {
    prevent_destroy = true
  }
}

resource "google_kms_key_ring" "state_replica" {
  project  = google_project_service.seed["cloudkms.googleapis.com"].project
  name     = "${var.prefix}-bootstrap-state-replica"
  location = var.state_replica_kms_location
}

resource "google_kms_crypto_key" "state_replica" {
  name            = "tfstate"
  key_ring        = google_kms_key_ring.state_replica.id
  purpose         = "ENCRYPT_DECRYPT"
  rotation_period = "7776000s"

  version_template {
    algorithm        = "GOOGLE_SYMMETRIC_ENCRYPTION"
    protection_level = var.kms_protection_level
  }

  lifecycle {
    prevent_destroy = true
  }
}

data "google_storage_project_service_account" "seed" {
  project = google_project.seed.project_id

  # Keep service-agent creation/readiness coupled only to the Storage API. An unrelated
  # project-service addition must not make the state-key IAM member unknown during planning.
  depends_on = [google_project_service.seed["storage.googleapis.com"]]
}
resource "google_kms_crypto_key_iam_member" "state_primary_gcs" {
  crypto_key_id = google_kms_crypto_key.state_primary.id
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  member        = "serviceAccount:${data.google_storage_project_service_account.seed.email_address}"
}

resource "google_kms_crypto_key_iam_member" "state_replica_gcs" {
  crypto_key_id = google_kms_crypto_key.state_replica.id
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  member        = "serviceAccount:${data.google_storage_project_service_account.seed.email_address}"
}

# Data Access audit logs for the Ring-0 state and token-exchange surfaces. Normal
# organization-wide sinks are owned by infrastructure-live, but the source audit policy for
# bootstrap resources must exist independently of that runtime.
resource "google_project_iam_audit_config" "ring0_data_access" {
  for_each = toset([
    "storage.googleapis.com",
    # Service Account Credentials Data Access logs are enabled through the IAM API; Google
    # Cloud does not support enabling them independently on iamcredentials.googleapis.com.
    "iam.googleapis.com",
    "secretmanager.googleapis.com",
  ])

  project = google_project.seed.project_id
  service = each.value

  # Service-account credential operations include Admin Read events. Enabling every class for
  # these Ring-0 audit surfaces also keeps administrative reads of state/secret metadata visible.
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
