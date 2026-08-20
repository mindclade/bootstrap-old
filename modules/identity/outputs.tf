# Copyright © 2026 Mindclade, LLC. All Rights Reserved.
# Mindclade Proprietary and Confidential.
# SPDX-License-Identifier: LicenseRef-Mindclade-Proprietary


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
      repository          = "${var.github_org}/${repo}"
      repository_owner_id = var.github_org_id
      repository_id       = id
    }
  }
}

output "artifact_signer_wif_provider" {
  description = "Signer-only GitHub WIF provider for the internal monorepo release workflow."
  value = "${local.github_pool_name}/providers/${
    google_iam_workload_identity_pool_provider.github[local.github_signer_repository].workload_identity_pool_provider_id
  }"
}

output "artifact_signer_principal" {
  description = "Exact protected-release subject to bind to the normal-plane signer service account."
  value       = local.github_signer_principal
}

output "artifact_signer_job_workflow_ref" {
  description = "Exact released reusable workflow enforced by the signer-only WIF provider."
  value       = local.github_signer_job_workflow_ref
}

output "artifact_release_identities" {
  description = "Capability-specific GitHub WIF providers and exact principals for normal-plane release identities."
  value = merge(
    {
      for capability, provider in google_iam_workload_identity_pool_provider.github_artifact_authority :
      capability => {
        workload_identity_provider = "${local.github_pool_name}/providers/${provider.workload_identity_pool_provider_id}"
        principal                  = "principal://iam.googleapis.com/${local.github_pool_name}/subject/arc-${capability}:${local.github_artifact_authority_capabilities[capability].subject}"
        subject                    = local.github_artifact_authority_capabilities[capability].subject
        workflow_ref               = local.github_release_workflow_ref
        job_workflow_ref           = local.github_artifact_authority_capabilities[capability].job_workflow_ref
      }
    },
    {
      signer = {
        workload_identity_provider = "${local.github_pool_name}/providers/${google_iam_workload_identity_pool_provider.github[local.github_signer_repository].workload_identity_pool_provider_id}"
        principal                  = local.github_signer_principal
        subject                    = local.github_signer_subject
        workflow_ref               = local.github_release_workflow_ref
        job_workflow_ref           = local.github_signer_job_workflow_ref
      }
    },
  )
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
