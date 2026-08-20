# Copyright © 2026 Mindclade, LLC. All Rights Reserved.
# Mindclade Proprietary and Confidential.
# SPDX-License-Identifier: LicenseRef-Mindclade-Proprietary


# The infrastructure-live repository reads private Terraform modules before its
# normal common-security project exists. Ring 0 therefore owns only the empty
# Secret Manager container for that bootstrap credential. An operator adds secret
# versions out-of-band; Terraform never receives or stores the private key payload.
resource "google_project_service_identity" "secretmanager" {
  provider = google-beta
  project  = var.seed_project_id
  service  = "secretmanager.googleapis.com"
}

resource "google_kms_crypto_key_iam_member" "automation_secret_manager" {
  crypto_key_id = var.automation_secret_kms_key_id
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  member        = "serviceAccount:${google_project_service_identity.secretmanager.email}"
}

resource "google_secret_manager_secret" "github_app_terraform_pem" {
  project   = var.seed_project_id
  secret_id = "github-app-terraform-pem"

  replication {
    user_managed {
      replicas {
        location = var.automation_secret_location

        customer_managed_encryption {
          kms_key_name = var.automation_secret_kms_key_id
        }
      }
    }
  }

  labels = {
    managed-by  = "terraform"
    repository  = "bootstrap"
    purpose     = "private-module-reader"
    criticality = "critical"
  }

  lifecycle {
    prevent_destroy = true
  }

  depends_on = [google_kms_crypto_key_iam_member.automation_secret_manager]
}

locals {
  infrastructure_live_module_readers = toset([
    "infrastructure-live-plan",
    "infrastructure-live-apply-foundation",
    "infrastructure-live-apply-development",
    "infrastructure-live-apply-staging",
    "infrastructure-live-apply-production",
  ])
}

resource "google_secret_manager_secret_iam_member" "infrastructure_live_module_reader" {
  for_each = local.infrastructure_live_module_readers

  project   = var.seed_project_id
  secret_id = google_secret_manager_secret.github_app_terraform_pem.secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.this[each.key].email}"
}
