# Copyright © 2026 Mindclade, LLC. All Rights Reserved.
# Mindclade Proprietary and Confidential.
# SPDX-License-Identifier: LicenseRef-Mindclade-Proprietary
#
locals {
  wif_repositories = {
    bootstrap                   = var.github_repository_ids["bootstrap"]
    github-config               = var.github_repository_ids["github-config"]
    infrastructure-live         = var.github_repository_ids["infrastructure-live"]
    gitops                      = var.github_repository_ids["gitops"]
    mindclade-internal-monorepo = var.github_repository_ids["mindclade-internal-monorepo"]
  }

  github_provider_audiences = {
    for repo, _ in local.wif_repositories : repo =>
    "https://iam.googleapis.com/projects/${var.cicd_project_number}/locations/global/workloadIdentityPools/github/providers/gh-${substr(replace(repo, "_", "-"), 0, 28)}"
  }
}

resource "google_iam_workload_identity_pool" "github" {
  project                   = var.cicd_project_id
  workload_identity_pool_id = "github"
  display_name              = "Mindclade GitHub Actions"
  description               = "Repository-isolated keyless federation for Mindclade."
}

resource "google_iam_workload_identity_pool_provider" "github" {
  for_each = local.wif_repositories
  project  = var.cicd_project_id

  workload_identity_pool_id          = google_iam_workload_identity_pool.github.workload_identity_pool_id
  workload_identity_pool_provider_id = "gh-${substr(replace(each.key, "_", "-"), 0, 28)}"
  display_name                       = each.key

  attribute_mapping = {
    "google.subject"                = "assertion.sub"
    "attribute.aud"                 = "assertion.aud"
    "attribute.repository"          = "assertion.repository"
    "attribute.repository_id"       = "assertion.repository_id"
    "attribute.repository_owner_id" = "assertion.repository_owner_id"
    "attribute.ref"                 = "assertion.ref"
    "attribute.workflow_ref"        = "assertion.workflow_ref"
    "attribute.workflow_sha"        = "assertion.workflow_sha"
    "attribute.job_workflow_ref"    = "assertion.job_workflow_ref"
    "attribute.job_workflow_sha"    = "assertion.job_workflow_sha"
    "attribute.event_name"          = "assertion.event_name"
  }

  attribute_condition = <<-EOT
    assertion.repository_owner_id == "${var.github_org_id}" &&
    assertion.repository_id == "${each.value}" &&
    assertion.repository == "${var.github_org}/${each.key}" &&
    assertion.aud == "${local.github_provider_audiences[each.key]}"
  EOT

  oidc {
    issuer_uri        = "https://token.actions.githubusercontent.com"
    allowed_audiences = [local.github_provider_audiences[each.key]]
  }
}

resource "google_iam_workload_identity_pool" "buildkite" {
  count = var.enable_buildkite_wif ? 1 : 0

  project                   = var.cicd_project_id
  workload_identity_pool_id = "buildkite"
  display_name              = "Mindclade Buildkite"
  description               = "Pipeline-isolated keyless federation for Mindclade Buildkite agents."
}

locals {
  buildkite_provider_audience = "https://iam.googleapis.com/projects/${var.cicd_project_number}/locations/global/workloadIdentityPools/buildkite/providers/buildkite"
}

resource "google_iam_workload_identity_pool_provider" "buildkite" {
  count = var.enable_buildkite_wif ? 1 : 0

  project                            = var.cicd_project_id
  workload_identity_pool_id          = google_iam_workload_identity_pool.buildkite[0].workload_identity_pool_id
  workload_identity_pool_provider_id = "buildkite"
  display_name                       = "Mindclade Buildkite"

  attribute_mapping = {
    "google.subject"               = "assertion.sub"
    "attribute.aud"                = "assertion.aud"
    "attribute.organization_id"    = "assertion.organization_id"
    "attribute.organization_slug"  = "assertion.organization_slug"
    "attribute.pipeline_id"        = "assertion.pipeline_id"
    "attribute.pipeline_slug"      = "assertion.pipeline_slug"
    "attribute.build_branch"       = "assertion.build_branch"
    "attribute.step_key"           = "assertion.step_key"
    "attribute.runner_environment" = "assertion.runner_environment"
    "attribute.build_source"       = "assertion.build_source"
  }

  attribute_condition = <<-EOT
    assertion.organization_id == "${var.buildkite_organization_id}" &&
    assertion.pipeline_id in ${jsonencode(sort(tolist(var.buildkite_pipeline_ids)))} &&
    assertion.aud == "${local.buildkite_provider_audience}"
  EOT

  oidc {
    issuer_uri        = "https://agent.buildkite.com"
    allowed_audiences = [local.buildkite_provider_audience]
  }
}

locals {
  github_pool_name = "projects/${var.cicd_project_number}/locations/global/workloadIdentityPools/github"
  principal_repo = {
    for repo, _ in local.wif_repositories :
    repo => "principalSet://iam.googleapis.com/${local.github_pool_name}/attribute.repository/${var.github_org}/${repo}"
  }
  # Direct repository workflows expose workflow_ref. job_workflow_ref is only populated
  # when a job is executing inside a called reusable workflow, so it cannot be used to
  # authorize these repository-local apply workflows.
  principal_workflow_prefix = {
    for repo, _ in local.wif_repositories :
    repo => "principalSet://iam.googleapis.com/${local.github_pool_name}/attribute.workflow_ref/${var.github_org}/${repo}"
  }

  buildkite_pool_name = var.enable_buildkite_wif ? "projects/${var.cicd_project_number}/locations/global/workloadIdentityPools/buildkite" : null
}
