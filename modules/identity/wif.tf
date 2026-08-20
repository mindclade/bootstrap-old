# Copyright © 2026 Mindclade, LLC. All Rights Reserved.
# Mindclade Proprietary and Confidential.
# SPDX-License-Identifier: LicenseRef-Mindclade-Proprietary

locals {
  wif_repositories = {
    bootstrap                   = var.github_repository_ids["bootstrap"]
    github-config               = var.github_repository_ids["github-config"]
    infrastructure-live         = var.github_repository_ids["infrastructure-live"]
    gitops                      = var.github_repository_ids["gitops"]
    mindclade-internal-monorepo = var.github_repository_ids["mindclade-internal-monorepo"]
  }

  # The monorepo GitHub provider is intentionally a signer-only trust path. Heavy builds and
  # qualification use Buildkite federation; only the protected release environment executing
  # this versioned reusable workflow may exchange a GitHub token through this provider.
  github_signer_repository       = "mindclade-internal-monorepo"
  github_signer_environment      = "release"
  github_signer_job_workflow_ref = "${var.github_org}/.github/.github/workflows/reusable-binauthz-sign.yml@refs/tags/v3.0.0"
  github_signer_subject          = "repo:${var.github_org}/${local.github_signer_repository}:environment:${local.github_signer_environment}"

  github_provider_audiences = {
    for repo, _ in local.wif_repositories : repo =>
    "https://iam.googleapis.com/projects/${var.cicd_project_number}/locations/global/workloadIdentityPools/github/providers/gh-${substr(replace(repo, "_", "-"), 0, 28)}"
  }

  github_provider_conditions = {
    for repo, repository_id in local.wif_repositories : repo => join(" && ", concat([
      "assertion.repository_owner_id == ${jsonencode(var.github_org_id)}",
      "assertion.repository_id == ${jsonencode(repository_id)}",
      "assertion.repository == ${jsonencode("${var.github_org}/${repo}")}",
      "assertion.aud == ${jsonencode(local.github_provider_audiences[repo])}",
      ], repo == local.github_signer_repository ? [
      "assertion.sub == ${jsonencode(local.github_signer_subject)}",
      "assertion.job_workflow_ref == ${jsonencode(local.github_signer_job_workflow_ref)}",
      ] : [
      "assertion.sub.startsWith(${jsonencode("repo:${var.github_org}/${repo}:")})",
    ]))
  }
}

resource "google_iam_workload_identity_pool" "github" {
  project                   = var.cicd_project_id
  workload_identity_pool_id = "github"
  display_name              = "Mindclade GitHub Actions"
  description               = "Repository-isolated keyless federation for Mindclade."
}

resource "google_iam_workload_identity_pool_provider" "github" {
  # checkov:skip=CKV_GCP_125:Immutable owner/repository IDs, a repo-shaped subject, and an exact provider audience are enforced below; apply/plan authorization is narrower at the service-account binding.
  for_each = local.wif_repositories
  project  = var.cicd_project_id

  workload_identity_pool_id          = google_iam_workload_identity_pool.github.workload_identity_pool_id
  workload_identity_pool_provider_id = "gh-${substr(replace(each.key, "_", "-"), 0, 28)}"
  display_name                       = each.key

  attribute_mapping = merge({
    "google.subject"                = "assertion.sub"
    "attribute.aud"                 = "assertion.aud"
    "attribute.repository"          = "assertion.repository"
    "attribute.repository_id"       = "assertion.repository_id"
    "attribute.repository_owner_id" = "assertion.repository_owner_id"
    "attribute.ref"                 = "assertion.ref"
    "attribute.workflow_ref"        = "assertion.workflow_ref"
    "attribute.workflow_sha"        = "assertion.workflow_sha"
    "attribute.event_name"          = "assertion.event_name"
    }, each.key == local.github_signer_repository ? {
    # These claims exist only while a job executes a called reusable workflow. Mapping them
    # on direct-workflow providers would make otherwise valid tokens fail attribute mapping.
    "attribute.job_workflow_ref" = "assertion.job_workflow_ref"
    "attribute.job_workflow_sha" = "assertion.job_workflow_sha"
  } : {})

  attribute_condition = local.github_provider_conditions[each.key]

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
  # Direct repository workflows expose workflow_ref. job_workflow_ref is only populated
  # when a job is executing inside a called reusable workflow, so it cannot be used to
  # authorize these repository-local apply workflows.
  principal_workflow_prefix = {
    for repo, _ in local.wif_repositories :
    repo => "principalSet://iam.googleapis.com/${local.github_pool_name}/attribute.workflow_ref/${var.github_org}/${repo}"
  }
  # Plans read sensitive state. Bind each plan identity to its repository's environment-shaped
  # OIDC subject rather than every workflow in the repository.
  principal_environment = {
    bootstrap-plan           = "principal://iam.googleapis.com/${local.github_pool_name}/subject/repo:${var.github_org}/bootstrap:environment:plan"
    github-config-plan       = "principal://iam.googleapis.com/${local.github_pool_name}/subject/repo:${var.github_org}/github-config:environment:plan"
    infrastructure-live-plan = "principal://iam.googleapis.com/${local.github_pool_name}/subject/repo:${var.github_org}/infrastructure-live:environment:plan"
  }

  # Primary bindings are exhaustive: adding a service account without an explicit trust path
  # fails during configuration evaluation instead of falling back to repository-wide trust.
  primary_federated_principals = merge(
    {
      for identity, workflow in local.apply_workflows : identity =>
      "${local.principal_workflow_prefix[local.service_accounts[identity].repo]}/${workflow}@refs/heads/main"
    },
    local.principal_environment,
    {
      bootstrap-drift = "${local.principal_workflow_prefix["bootstrap"]}/.github/workflows/drift.yml@refs/heads/main"
    },
  )

  # Scheduled read-only consumers cannot wait for environment approval. Each receives only
  # its exact protected-main workflow_ref, never a repository or branch wildcard.
  additional_federated_principals = {
    "bootstrap-plan:recovery-drill" = {
      identity  = "bootstrap-plan"
      principal = "${local.principal_workflow_prefix["bootstrap"]}/.github/workflows/recovery-drill.yml@refs/heads/main"
    }
    "github-config-plan:drift" = {
      identity  = "github-config-plan"
      principal = "${local.principal_workflow_prefix["github-config"]}/.github/workflows/drift.yml@refs/heads/main"
    }
    "github-config-plan:idp-sync" = {
      identity  = "github-config-plan"
      principal = "${local.principal_workflow_prefix["github-config"]}/.github/workflows/idp-sync.yml@refs/heads/main"
    }
    "infrastructure-live-plan:drift" = {
      identity  = "infrastructure-live-plan"
      principal = "${local.principal_workflow_prefix["infrastructure-live"]}/.github/workflows/drift.yml@refs/heads/main"
    }
    "infrastructure-live-plan:cost" = {
      identity  = "infrastructure-live-plan"
      principal = "${local.principal_workflow_prefix["infrastructure-live"]}/.github/workflows/cost.yml@refs/heads/main"
    }
  }

  wif_service_account_bindings = merge(
    {
      for identity, principal in local.primary_federated_principals : identity => {
        identity  = identity
        principal = principal
      }
    },
    local.additional_federated_principals,
  )
  github_signer_principal = "principal://iam.googleapis.com/${local.github_pool_name}/subject/${local.github_signer_subject}"

  buildkite_pool_name = var.enable_buildkite_wif ? "projects/${var.cicd_project_number}/locations/global/workloadIdentityPools/buildkite" : null
}
