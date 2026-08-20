# Copyright © 2026 Mindclade, LLC. All Rights Reserved.
# Mindclade Proprietary and Confidential.
# SPDX-License-Identifier: LicenseRef-Mindclade-Proprietary
#

output "service_accounts" {
  value = { for key, sa in google_service_account.this : key => sa.email }
}

output "github_wif_pool_name" { value = local.github_pool_name }

output "github_wif_providers" {
  value = {
    for repo, provider in google_iam_workload_identity_pool_provider.github :
    repo => "${local.github_pool_name}/providers/${provider.workload_identity_pool_provider_id}"
  }
}

output "github_wif_repository_identities" {
  value = {
    for repo, id in local.wif_repositories : repo => {
      repository    = "${var.github_org}/${repo}"
      repository_id = id
    }
  }
}

output "buildkite_wif_pool_name" {
  value = local.buildkite_pool_name
}

output "buildkite_wif_provider" {
  value = var.enable_buildkite_wif ? "${local.buildkite_pool_name}/providers/${google_iam_workload_identity_pool_provider.buildkite[0].workload_identity_pool_provider_id}" : null
}

output "break_glass_account" { value = google_service_account.break_glass.email }

output "automation_secret_project_id" {
  value = var.seed_project_id
}

output "github_app_terraform_secret_id" {
  value = google_secret_manager_secret.github_app_terraform_pem.secret_id
}
