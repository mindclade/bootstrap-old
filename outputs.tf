# Copyright © 2026 Mindclade, LLC. All Rights Reserved.
# Mindclade Proprietary and Confidential.
# SPDX-License-Identifier: LicenseRef-Mindclade-Proprietary


output "bootstrap_folder_id" {
  description = "Ring-0 bootstrap folder resource name."
  value       = module.projects.bootstrap_folder_id
}

output "seed_project_id" {
  description = "Ring-0 state, identity, and recovery project."
  value       = module.projects.seed_project_id
}

output "cicd_project_id" {
  description = "Project containing external workload identity federation providers."
  value       = module.projects.cicd_project_id
}

output "cicd_project_number" {
  value = module.projects.cicd_project_number
}

output "state_buckets" {
  description = "State scope to primary bucket name."
  value       = module.state.state_buckets
}

output "state_replica_buckets" {
  description = "State scope to independent replica bucket name."
  value       = module.state.state_replica_buckets
}

output "service_accounts" {
  description = "Automation identity key to service-account email."
  value       = module.identity.service_accounts
}

output "github_wif_pool_name" {
  value = module.identity.github_wif_pool_name
}

output "github_wif_providers" {
  description = "Repository name to GitHub OIDC WIF provider resource name."
  value       = module.identity.github_wif_providers
}

output "github_wif_repository_identities" {
  value = module.identity.github_wif_repository_identities
}

output "artifact_signer_wif_provider" {
  description = "Value published as WIF_PROVIDER_SIGNER for the monorepo release environment."
  value       = module.identity.artifact_signer_wif_provider
}

output "artifact_signer_principal" {
  description = "Exact WIF principal infrastructure-live binds to the artifact signer service account."
  value       = module.identity.artifact_signer_principal
}

output "artifact_signer_job_workflow_ref" {
  description = "Immutable reusable workflow reference enforced for artifact signing."
  value       = module.identity.artifact_signer_job_workflow_ref
}

output "artifact_release_identities" {
  description = "Capability-specific ARC release trust contract for infrastructure-live."
  value       = module.identity.artifact_release_identities
}

output "dr_evidence_identity" {
  description = "Protected scratch/staging WIF contract consumed by the normal-plane DR evidence writer."
  value       = module.identity.dr_evidence_identity
}

output "buildkite_wif_pool_name" {
  value = module.identity.buildkite_wif_pool_name
}

output "buildkite_wif_provider" {
  value = module.identity.buildkite_wif_provider
}

output "break_glass_account" {
  value = module.identity.break_glass_account
}

output "github_org" {
  value = var.github_org
}

output "automation_secret_project_id" {
  description = "Ring-0 project containing empty bootstrap automation-secret containers."
  value       = module.identity.automation_secret_project_id
}

output "github_app_terraform_secret_id" {
  description = "Secret Manager secret ID whose versions are injected out-of-band for private Terraform module reads."
  value       = module.identity.github_app_terraform_secret_id
}

output "org_id" {
  description = "Google Cloud organization numeric ID."
  value       = var.org_id
}

output "billing_account" {
  description = "Billing account ID used by the control-plane repositories."
  value       = var.billing_account
}

output "state_bucket_location" {
  description = "Location of the primary Terraform state buckets."
  value       = var.state_bucket_location
}

# Stable, non-secret machine interface for downstream control repositories. Consumers should
# read this value (`terraform output -json platform_contract`) instead of coupling themselves
# to module internals or reading bootstrap state directly.
output "platform_contract" {
  description = "Versioned Ring-0 identifiers consumed by other control repositories."
  value = {
    contract_version      = "1.4.0"
    organization_id       = var.org_id
    billing_account       = var.billing_account
    bootstrap_folder_id   = module.projects.bootstrap_folder_id
    state_project_id      = module.projects.seed_project_id
    federation_project_id = module.projects.cicd_project_id
    state = {
      primary_location = var.state_bucket_location
      primary_buckets  = module.state.state_buckets
      replica_buckets  = module.state.state_replica_buckets
    }
    github = {
      organization                = var.github_org
      workload_identity_pool      = module.identity.github_wif_pool_name
      workload_identity_providers = module.identity.github_wif_providers
      repository_identities       = module.identity.github_wif_repository_identities
      artifact_signer = {
        workload_identity_provider = module.identity.artifact_signer_wif_provider
        principal                  = module.identity.artifact_signer_principal
        job_workflow_ref           = module.identity.artifact_signer_job_workflow_ref
      }
      artifact_release_identities = module.identity.artifact_release_identities
      dr_evidence_identity        = module.identity.dr_evidence_identity
    }
    buildkite = {
      enabled                    = var.enable_buildkite_wif
      workload_identity_pool     = module.identity.buildkite_wif_pool_name
      workload_identity_provider = module.identity.buildkite_wif_provider
    }
    automation_identities = module.identity.service_accounts
    recovery = {
      break_glass_account = module.identity.break_glass_account
    }
    automation_secret = {
      project_id = module.identity.automation_secret_project_id
      secret_id  = module.identity.github_app_terraform_secret_id
    }
  }
}
