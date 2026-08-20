# Copyright © 2026 Mindclade, LLC. All Rights Reserved.
# Mindclade Proprietary and Confidential.
# SPDX-License-Identifier: LicenseRef-Mindclade-Proprietary
#

# Ring-0 composition only. Normal organization governance, folders, networks, workload
# projects, and runtime infrastructure are owned by infrastructure-live.
module "naming" {
  source = "./modules/naming"
}

module "projects" {
  source = "./modules/projects"

  org_id                     = var.org_id
  bootstrap_folder_id        = var.bootstrap_folder_id
  billing_account            = var.billing_account
  prefix                     = var.prefix
  suffix                     = module.naming.suffix
  state_kms_location         = var.state_kms_location
  state_replica_kms_location = var.state_replica_kms_location
  kms_protection_level       = var.kms_protection_level
  labels                     = var.labels
}

module "identity" {
  source = "./modules/identity"

  org_id              = var.org_id
  billing_account     = var.billing_account
  seed_project_id     = module.projects.seed_project_id
  cicd_project_id     = module.projects.cicd_project_id
  cicd_project_number = module.projects.cicd_project_number

  automation_secret_kms_key_id = module.projects.automation_secret_kms_key_id
  automation_secret_location   = var.state_kms_location

  github_org            = var.github_org
  github_org_id         = var.github_org_id
  github_repository_ids = var.github_repository_ids

  enable_buildkite_wif      = var.enable_buildkite_wif
  buildkite_organization_id = var.buildkite_organization_id
  buildkite_pipeline_ids    = var.buildkite_pipeline_ids

  break_glass_principals = var.break_glass_principals
  security_contact       = var.security_contact
}

module "state" {
  source = "./modules/state"

  seed_project_id           = module.projects.seed_project_id
  prefix                     = var.prefix
  suffix                     = module.naming.suffix
  primary_kms_key_id         = module.projects.state_primary_kms_key_id
  replica_kms_key_id         = module.projects.state_replica_kms_key_id
  state_bucket_location      = var.state_bucket_location
  state_replica_location     = var.state_replica_location
  state_soft_delete_days     = var.state_soft_delete_days
  noncurrent_version_days    = var.noncurrent_version_days
  noncurrent_version_count   = var.noncurrent_version_count
  service_account_emails     = module.identity.service_accounts
  labels                     = var.labels
}
