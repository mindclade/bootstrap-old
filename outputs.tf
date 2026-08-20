# Copyright © 2026 Mindclade, LLC. All Rights Reserved.
# Mindclade Proprietary and Confidential.
# SPDX-License-Identifier: LicenseRef-Mindclade-Proprietary
#

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
