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

  # GitHub Cloud repositories created or renamed after 2026-07-15 use the immutable default
  # subject segment OWNER@OWNER-ID/REPO@REPO-ID. These control repositories were created after
  # that cutoff, so legacy name-only subjects are intentionally not accepted.
  github_immutable_subject_prefixes = {
    for repo, repository_id in local.wif_repositories : repo =>
    "repo:${var.github_org}@${var.github_org_id}/${repo}@${repository_id}"
  }

  # The monorepo provider remains the compatibility address for the signer capability. It is
  # still exact: the protected release environment, trusted-main caller, push event, and
  # immutable v4 reusable workflow must all agree.
  github_signer_repository       = "mindclade-internal-monorepo"
  github_signer_environment      = "release"
  github_signer_ref              = "refs/heads/main"
  github_release_workflow_ref    = "${var.github_org}/mindclade-internal-monorepo/.github/workflows/release.yml@refs/heads/main"
  github_signer_job_workflow_ref = "${var.github_org}/.github/.github/workflows/reusable-binauthz-sign.yml@refs/tags/v5.0.0"
  github_signer_subject          = "${local.github_immutable_subject_prefixes[local.github_signer_repository]}:environment:${local.github_signer_environment}"

  # Every non-signer release capability gets a distinct provider and principal. None can be
  # exchanged by a direct workflow, pull request, tag, manual dispatch, API dispatch, custom
  # ref, or a different released reusable workflow.
  github_artifact_authority_capabilities = {
    canary = {
      subject          = "${local.github_immutable_subject_prefixes[local.github_signer_repository]}:ref:${local.github_signer_ref}"
      job_workflow_ref = "${var.github_org}/.github/.github/workflows/reusable-arc-wif-canary.yml@refs/tags/v5.0.0"
    }
    builder = {
      subject          = "${local.github_immutable_subject_prefixes[local.github_signer_repository]}:ref:${local.github_signer_ref}"
      job_workflow_ref = "${var.github_org}/.github/.github/workflows/reusable-arc-oci-build.yml@refs/tags/v5.0.0"
    }
    qualification-reader = {
      subject          = "${local.github_immutable_subject_prefixes[local.github_signer_repository]}:ref:${local.github_signer_ref}"
      job_workflow_ref = "${var.github_org}/.github/.github/workflows/reusable-arc-oci-qualify.yml@refs/tags/v5.0.0"
    }
    qualifier = {
      subject          = "${local.github_immutable_subject_prefixes[local.github_signer_repository]}:ref:${local.github_signer_ref}"
      job_workflow_ref = "${var.github_org}/.github/.github/workflows/reusable-arc-qualification-attest.yml@refs/tags/v5.0.0"
    }
    promoter = {
      subject          = "${local.github_immutable_subject_prefixes[local.github_signer_repository]}:environment:${local.github_signer_environment}"
      job_workflow_ref = "${var.github_org}/.github/.github/workflows/reusable-gitops-promote.yml@refs/tags/v5.0.0"
    }
  }

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
      "assertion.ref == ${jsonencode(local.github_signer_ref)}",
      "assertion.event_name == \"push\"",
      "assertion.workflow_ref == ${jsonencode(local.github_release_workflow_ref)}",
      "assertion.job_workflow_ref == ${jsonencode(local.github_signer_job_workflow_ref)}",
      ] : [
      "assertion.sub.startsWith(${jsonencode("${local.github_immutable_subject_prefixes[repo]}:")})",
    ]))
  }

  # DR evidence is separate from plans, applies, and artifact release. The provider accepts
  # only standardized callers in repositories that own executable recovery procedures, only
  # from protected scratch/staging environments, and only through the immutable shared workflow.
  github_dr_evidence_repositories = {
    bootstrap           = var.github_repository_ids["bootstrap"]
    github-config       = var.github_repository_ids["github-config"]
    infrastructure-live = var.github_repository_ids["infrastructure-live"]
    gitops              = var.github_repository_ids["gitops"]
  }
  github_dr_evidence_audience         = "https://iam.googleapis.com/projects/${var.cicd_project_number}/locations/global/workloadIdentityPools/github/providers/gh-dr-evidence"
  github_dr_evidence_job_workflow_ref = "${var.github_org}/.github/.github/workflows/reusable-dr-evidence.yml@refs/tags/v5.0.0"
  github_dr_evidence_subjects = merge([
    for repo, repository_id in local.github_dr_evidence_repositories : {
      for environment in ["scratch", "staging"] : "${repo}:${environment}" => {
        repository    = "${var.github_org}/${repo}"
        repository_id = repository_id
        subject       = "${local.github_immutable_subject_prefixes[repo]}:environment:${environment}"
        workflow_ref  = "${var.github_org}/${repo}/.github/workflows/dr-evidence.yml@refs/heads/main"
      }
    }
  ]...)

  # Final production qualification is a direct GitOps workflow, isolated from DR publication
  # and ordinary GitOps render/provenance identities. All identity-bearing claims are exact.
  github_production_qualification_repository = "gitops"
  github_production_qualification_audience   = "https://iam.googleapis.com/projects/${var.cicd_project_number}/locations/global/workloadIdentityPools/github/providers/gh-production-qualification"
  github_production_qualification_subject    = "${local.github_immutable_subject_prefixes[local.github_production_qualification_repository]}:environment:production"
  github_production_qualification_workflow   = "${var.github_org}/gitops/.github/workflows/production-qualification-evidence.yml@refs/heads/main"

  github_bazel_cache_repository         = local.github_signer_repository
  github_bazel_cache_audience           = "https://iam.googleapis.com/projects/${var.cicd_project_number}/locations/global/workloadIdentityPools/github/providers/gh-bazel-cache"
  github_bazel_cache_presubmit_workflow = "${var.github_org}/${local.github_bazel_cache_repository}/.github/workflows/presubmit.yml"
  github_bazel_cache_nightly_workflow   = "${var.github_org}/${local.github_bazel_cache_repository}/.github/workflows/nightly.yml"
  github_bazel_cache_routes = {
    pull-request-read = {
      access        = "read"
      event_name    = "pull_request"
      ref_policy    = "pull-request-merge"
      workflow_path = local.github_bazel_cache_presubmit_workflow
      condition = join(" && ", [
        "assertion.event_name == \"pull_request\"",
        "assertion.sub == ${jsonencode("${local.github_immutable_subject_prefixes[local.github_bazel_cache_repository]}:pull_request")}",
        "assertion.ref.startsWith(\"refs/pull/\")",
        "assertion.ref.endsWith(\"/merge\")",
        "assertion.workflow_ref == ${jsonencode("${local.github_bazel_cache_presubmit_workflow}@")} + assertion.ref",
        "assertion.workflow_sha == assertion.sha",
      ])
    }
    trusted-main-write = {
      access        = "write"
      event_name    = "push"
      ref_policy    = "protected-main"
      workflow_path = local.github_bazel_cache_presubmit_workflow
      condition = join(" && ", [
        "assertion.event_name == \"push\"",
        "assertion.sub == ${jsonencode("${local.github_immutable_subject_prefixes[local.github_bazel_cache_repository]}:ref:refs/heads/main")}",
        "assertion.ref == \"refs/heads/main\"",
        "assertion.workflow_ref == ${jsonencode("${local.github_bazel_cache_presubmit_workflow}@refs/heads/main")}",
        "assertion.workflow_sha == assertion.sha",
      ])
    }
    merge-group-write = {
      access        = "write"
      event_name    = "merge_group"
      ref_policy    = "protected-merge-queue"
      workflow_path = local.github_bazel_cache_presubmit_workflow
      condition = join(" && ", [
        "assertion.event_name == \"merge_group\"",
        "assertion.ref.startsWith(\"refs/heads/gh-readonly-queue/main/\")",
        "assertion.sub == ${jsonencode("${local.github_immutable_subject_prefixes[local.github_bazel_cache_repository]}:ref:")} + assertion.ref",
        "assertion.workflow_ref == ${jsonencode("${local.github_bazel_cache_presubmit_workflow}@")} + assertion.ref",
        "assertion.workflow_sha == assertion.sha",
      ])
    }
    nightly-write = {
      access        = "write"
      event_name    = "schedule"
      ref_policy    = "protected-main"
      workflow_path = local.github_bazel_cache_nightly_workflow
      condition = join(" && ", [
        "assertion.event_name == \"schedule\"",
        "assertion.sub == ${jsonencode("${local.github_immutable_subject_prefixes[local.github_bazel_cache_repository]}:ref:refs/heads/main")}",
        "assertion.ref == \"refs/heads/main\"",
        "assertion.workflow_ref == ${jsonencode("${local.github_bazel_cache_nightly_workflow}@refs/heads/main")}",
        "assertion.workflow_sha == assertion.sha",
      ])
    }
  }
}

resource "google_iam_workload_identity_pool_provider" "github_bazel_cache" {
  # checkov:skip=CKV_GCP_125:Immutable owner/repository IDs, exact event/ref/workflow/SHA routes, and a provider-specific audience are enforced below.
  project = var.cicd_project_id

  workload_identity_pool_id          = google_iam_workload_identity_pool.github.workload_identity_pool_id
  workload_identity_pool_provider_id = "gh-bazel-cache"
  display_name                       = "Bazel remote cache"

  attribute_mapping = {
    "google.subject"                = "\"bazel-cache:\" + (assertion.event_name == \"pull_request\" ? \"pull-request-read\" : assertion.event_name == \"push\" ? \"trusted-main-write\" : assertion.event_name == \"merge_group\" ? \"merge-group-write\" : \"nightly-write\")"
    "attribute.aud"                 = "assertion.aud"
    "attribute.cache_access"        = "assertion.event_name == \"pull_request\" ? \"read\" : \"write\""
    "attribute.cache_route"         = "assertion.event_name == \"pull_request\" ? \"pull-request-read\" : assertion.event_name == \"push\" ? \"trusted-main-write\" : assertion.event_name == \"merge_group\" ? \"merge-group-write\" : \"nightly-write\""
    "attribute.event_name"          = "assertion.event_name"
    "attribute.ref"                 = "assertion.ref"
    "attribute.repository"          = "assertion.repository"
    "attribute.repository_id"       = "assertion.repository_id"
    "attribute.repository_owner_id" = "assertion.repository_owner_id"
    "attribute.sha"                 = "assertion.sha"
    "attribute.workflow_ref"        = "assertion.workflow_ref"
    "attribute.workflow_sha"        = "assertion.workflow_sha"
  }

  attribute_condition = join(" && ", [
    "assertion.repository_owner_id == ${jsonencode(var.github_org_id)}",
    "assertion.repository_id == ${jsonencode(var.github_repository_ids[local.github_bazel_cache_repository])}",
    "assertion.repository == ${jsonencode("${var.github_org}/${local.github_bazel_cache_repository}")}",
    "assertion.repository_visibility in [\"internal\", \"private\"]",
    "assertion.aud == ${jsonencode(local.github_bazel_cache_audience)}",
    "(${join(" || ", [for route in values(local.github_bazel_cache_routes) : "(${route.condition})"])})",
  ])

  oidc {
    issuer_uri        = "https://token.actions.githubusercontent.com"
    allowed_audiences = [local.github_bazel_cache_audience]
  }
}

resource "google_iam_workload_identity_pool_provider" "github_dr_evidence" {
  # checkov:skip=CKV_GCP_125:Owner/repository IDs, environment subjects, caller and reusable workflows, event, and audience are exact.
  project = var.cicd_project_id

  workload_identity_pool_id          = google_iam_workload_identity_pool.github.workload_identity_pool_id
  workload_identity_pool_provider_id = "gh-dr-evidence"
  display_name                       = "DR evidence publisher"

  attribute_mapping = {
    "google.subject"                = "\"dr-evidence:\" + assertion.sub"
    "attribute.aud"                 = "assertion.aud"
    "attribute.repository"          = "assertion.repository"
    "attribute.repository_id"       = "assertion.repository_id"
    "attribute.repository_owner_id" = "assertion.repository_owner_id"
    "attribute.workflow_ref"        = "assertion.workflow_ref"
    "attribute.event_name"          = "assertion.event_name"
    "attribute.job_workflow_ref"    = "assertion.job_workflow_ref"
  }

  attribute_condition = join(" && ", [
    "assertion.repository_owner_id == ${jsonencode(var.github_org_id)}",
    "assertion.aud == ${jsonencode(local.github_dr_evidence_audience)}",
    "assertion.event_name == \"workflow_dispatch\"",
    "assertion.job_workflow_ref == ${jsonencode(local.github_dr_evidence_job_workflow_ref)}",
    "(${join(" || ", [for contract in values(local.github_dr_evidence_subjects) : "(assertion.repository_id == ${jsonencode(contract.repository_id)} && assertion.repository == ${jsonencode(contract.repository)} && assertion.sub == ${jsonencode(contract.subject)} && assertion.workflow_ref == ${jsonencode(contract.workflow_ref)})"])})",
  ])

  oidc {
    issuer_uri        = "https://token.actions.githubusercontent.com"
    allowed_audiences = [local.github_dr_evidence_audience]
  }
}

resource "google_iam_workload_identity_pool_provider" "github_production_qualification" {
  # checkov:skip=CKV_GCP_125:Owner/repository IDs, production subject, main ref, direct workflow, event, and audience are exact.
  project = var.cicd_project_id

  workload_identity_pool_id          = google_iam_workload_identity_pool.github.workload_identity_pool_id
  workload_identity_pool_provider_id = "gh-production-qualification"
  display_name                       = "Production qualification"

  attribute_mapping = {
    "google.subject"                = "\"production-qualification:\" + assertion.sub"
    "attribute.aud"                 = "assertion.aud"
    "attribute.repository"          = "assertion.repository"
    "attribute.repository_id"       = "assertion.repository_id"
    "attribute.repository_owner_id" = "assertion.repository_owner_id"
    "attribute.ref"                 = "assertion.ref"
    "attribute.workflow_ref"        = "assertion.workflow_ref"
    "attribute.event_name"          = "assertion.event_name"
  }

  attribute_condition = join(" && ", [
    "assertion.repository_owner_id == ${jsonencode(var.github_org_id)}",
    "assertion.repository_id == ${jsonencode(var.github_repository_ids[local.github_production_qualification_repository])}",
    "assertion.repository == ${jsonencode("${var.github_org}/${local.github_production_qualification_repository}")}",
    "assertion.aud == ${jsonencode(local.github_production_qualification_audience)}",
    "assertion.sub == ${jsonencode(local.github_production_qualification_subject)}",
    "assertion.ref == \"refs/heads/main\"",
    "assertion.event_name == \"workflow_dispatch\"",
    "assertion.workflow_ref == ${jsonencode(local.github_production_qualification_workflow)}",
  ])

  oidc {
    issuer_uri        = "https://token.actions.githubusercontent.com"
    allowed_audiences = [local.github_production_qualification_audience]
  }
}

resource "google_iam_workload_identity_pool_provider" "github_artifact_authority" {
  # checkov:skip=CKV_GCP_125:Every immutable identity and execution claim is matched exactly.
  for_each = local.github_artifact_authority_capabilities
  project  = var.cicd_project_id

  workload_identity_pool_id          = google_iam_workload_identity_pool.github.workload_identity_pool_id
  workload_identity_pool_provider_id = "gh-arc-${each.key}"
  display_name                       = "ARC ${each.key}"

  attribute_mapping = {
    # A workload-identity pool principal is keyed by google.subject, not by provider.
    # Prefixing the immutable GitHub subject prevents a token accepted by one ARC provider
    # from inheriting a different capability's service-account binding.
    "google.subject"                = "\"arc-${each.key}:\" + assertion.sub"
    "attribute.aud"                 = "assertion.aud"
    "attribute.repository"          = "assertion.repository"
    "attribute.repository_id"       = "assertion.repository_id"
    "attribute.repository_owner_id" = "assertion.repository_owner_id"
    "attribute.ref"                 = "assertion.ref"
    "attribute.workflow_ref"        = "assertion.workflow_ref"
    "attribute.event_name"          = "assertion.event_name"
    "attribute.job_workflow_ref"    = "assertion.job_workflow_ref"
  }

  attribute_condition = join(" && ", [
    "assertion.repository_owner_id == ${jsonencode(var.github_org_id)}",
    "assertion.repository_id == ${jsonencode(var.github_repository_ids[local.github_signer_repository])}",
    "assertion.repository == ${jsonencode("${var.github_org}/${local.github_signer_repository}")}",
    "assertion.aud == ${jsonencode("https://iam.googleapis.com/projects/${var.cicd_project_number}/locations/global/workloadIdentityPools/github/providers/gh-arc-${each.key}")}",
    "assertion.sub == ${jsonencode(each.value.subject)}",
    "assertion.ref == ${jsonencode(local.github_signer_ref)}",
    "assertion.event_name == \"push\"",
    "assertion.workflow_ref == ${jsonencode(local.github_release_workflow_ref)}",
    "assertion.job_workflow_ref == ${jsonencode(each.value.job_workflow_ref)}",
  ])

  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
    allowed_audiences = [
      "https://iam.googleapis.com/projects/${var.cicd_project_number}/locations/global/workloadIdentityPools/github/providers/gh-arc-${each.key}"
    ]
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
  buildkite_pipeline_step_condition = join(" || ", [
    for pipeline_id, step_keys in var.buildkite_pipeline_step_contracts :
    "(assertion.pipeline_id == ${jsonencode(pipeline_id)} && assertion.step_key in ${jsonencode(sort(tolist(step_keys)))})"
  ])
}

check "buildkite_pipeline_step_contract_is_exact" {
  assert {
    condition = !var.enable_buildkite_wif || (
      toset(keys(var.buildkite_pipeline_step_contracts)) == var.buildkite_pipeline_ids &&
      toset(flatten([for _, steps in var.buildkite_pipeline_step_contracts : tolist(steps)])) == toset([
        "artifact-build",
        "artifact-qualify",
        "artifact-promote",
      ]) &&
      length(flatten([for _, steps in var.buildkite_pipeline_step_contracts : tolist(steps)])) == 3
    )
    error_message = "Buildkite WIF requires every pipeline UUID to have a contract and each artifact-build, artifact-qualify, and artifact-promote identity exactly once."
  }
}

resource "google_iam_workload_identity_pool_provider" "buildkite" {
  count = var.enable_buildkite_wif ? 1 : 0

  project                            = var.cicd_project_id
  workload_identity_pool_id          = google_iam_workload_identity_pool.buildkite[0].workload_identity_pool_id
  workload_identity_pool_provider_id = "buildkite"
  display_name                       = "Mindclade Buildkite"

  attribute_mapping = {
    # Buildkite's default compound `sub` includes organization/pipeline/ref/commit/step and
    # can exceed Google's 127-byte mapped-subject limit. Production pipelines must request
    # `--subject-claim pipeline_id --claim organization_id`; the immutable pipeline UUID is
    # both short enough for Google and already restricted by the provider condition below.
    "google.subject"               = "assertion.pipeline_id"
    "attribute.aud"                = "assertion.aud"
    "attribute.organization_id"    = "assertion.organization_id"
    "attribute.organization_slug"  = "assertion.organization_slug"
    "attribute.pipeline_id"        = "assertion.pipeline_id"
    "attribute.pipeline_slug"      = "assertion.pipeline_slug"
    "attribute.build_branch"       = "assertion.build_branch"
    "attribute.build_commit"       = "assertion.build_commit"
    "attribute.step_key"           = "assertion.step_key"
    "attribute.runner_environment" = "assertion.runner_environment"
    "attribute.build_source"       = "assertion.build_source"
  }

  attribute_condition = <<-EOT
    assertion.organization_id == "${var.buildkite_organization_id}" &&
    assertion.pipeline_id in ${jsonencode(sort(tolist(var.buildkite_pipeline_ids)))} &&
    assertion.runner_environment == "self-hosted" &&
    assertion.build_branch == "main" &&
    assertion.build_source == "webhook" &&
    (${local.buildkite_pipeline_step_condition}) &&
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
    bootstrap-plan           = "principal://iam.googleapis.com/${local.github_pool_name}/subject/${local.github_immutable_subject_prefixes["bootstrap"]}:environment:plan"
    github-config-plan       = "principal://iam.googleapis.com/${local.github_pool_name}/subject/${local.github_immutable_subject_prefixes["github-config"]}:environment:plan"
    infrastructure-live-plan = "principal://iam.googleapis.com/${local.github_pool_name}/subject/${local.github_immutable_subject_prefixes["infrastructure-live"]}:environment:plan"
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
