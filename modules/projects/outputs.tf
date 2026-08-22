# Copyright © 2026 Mindclade, LLC. All Rights Reserved.
# Mindclade Proprietary and Confidential.
# SPDX-License-Identifier: LicenseRef-Mindclade-Proprietary


output "bootstrap_folder_id" { value = local.bootstrap_folder_name }
output "seed_project_id" { value = google_project.seed.project_id }
output "seed_project_number" { value = google_project.seed.number }
output "cicd_project_id" { value = google_project.cicd.project_id }
output "cicd_project_number" { value = data.google_project.cicd.number }
output "state_primary_kms_key_id" { value = google_kms_crypto_key.state_primary.id }
output "state_replica_kms_key_id" { value = google_kms_crypto_key.state_replica_us.id }
output "legacy_state_replica_kms_key_id" {
  value = one(google_kms_crypto_key.state_replica_legacy[*].id)
}
output "automation_secret_kms_key_id" { value = google_kms_crypto_key.automation_secrets_regional.id }
