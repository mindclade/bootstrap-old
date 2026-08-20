# Copyright © 2026 Mindclade, LLC. All Rights Reserved.
# Mindclade Proprietary and Confidential.
# SPDX-License-Identifier: LicenseRef-Mindclade-Proprietary

locals {
  service_accounts = {
    bootstrap-plan = {
      display    = "Bootstrap speculative plan"
      repo       = "bootstrap"
      apply_only = false
      org_roles  = ["roles/resourcemanager.organizationViewer", "roles/iam.securityReviewer"]
      project_roles = {
        seed = ["roles/viewer"]
        cicd = ["roles/viewer"]
      }
    }
    bootstrap-drift = {
      display    = "Bootstrap read-only drift"
      repo       = "bootstrap"
      apply_only = false
      org_roles  = ["roles/resourcemanager.organizationViewer", "roles/iam.securityReviewer"]
      project_roles = {
        seed = ["roles/viewer"]
        cicd = ["roles/viewer"]
      }
    }
    bootstrap-apply = {
      display    = "Bootstrap protected apply"
      repo       = "bootstrap"
      apply_only = true
      org_roles = [
        "roles/resourcemanager.organizationAdmin",
        "roles/resourcemanager.projectCreator",
        "roles/resourcemanager.folderCreator",
      ]
      project_roles = {
        seed = [
          "roles/resourcemanager.projectIamAdmin",
          "roles/serviceusage.serviceUsageAdmin",
          "roles/storage.admin",
          "roles/cloudkms.admin",
          "roles/iam.serviceAccountAdmin",
          "roles/logging.configWriter",
          "roles/monitoring.admin",
        ]
        cicd = [
          "roles/resourcemanager.projectIamAdmin",
          "roles/serviceusage.serviceUsageAdmin",
          "roles/iam.workloadIdentityPoolAdmin",
        ]
      }
    }
    github-config-plan = {
      display    = "GitHub configuration speculative plan"
      repo       = "github-config"
      apply_only = false
      org_roles  = ["roles/cloudidentity.groups.readonly"]
      project_roles = {
        seed = ["roles/viewer"]
      }
    }
    github-config-apply = {
      display       = "GitHub configuration protected apply"
      repo          = "github-config"
      apply_only    = true
      org_roles     = []
      project_roles = {}
    }
    infrastructure-live-plan = {
      display    = "Infrastructure live speculative plan"
      repo       = "infrastructure-live"
      apply_only = false
      org_roles = [
        "roles/resourcemanager.organizationViewer",
        "roles/iam.securityReviewer",
        "roles/cloudasset.viewer",
      ]
      project_roles = {
        seed = ["roles/viewer"]
        cicd = ["roles/viewer"]
      }
    }
    infrastructure-live-apply-foundation = {
      display    = "Infrastructure live organization foundation apply"
      repo       = "infrastructure-live"
      apply_only = true
      org_roles = [
        "roles/resourcemanager.folderAdmin",
        "roles/resourcemanager.projectCreator",
        "roles/resourcemanager.projectIamAdmin",
        "roles/compute.xpnAdmin",
        "roles/orgpolicy.policyAdmin",
        "roles/iam.serviceAccountAdmin",
        "roles/logging.configWriter",
        "roles/securitycenter.admin",
        "roles/accesscontextmanager.policyAdmin",
      ]
      project_roles = {}
    }
    infrastructure-live-apply-development = {
      display       = "Infrastructure live development apply"
      repo          = "infrastructure-live"
      apply_only    = true
      org_roles     = []
      project_roles = {}
    }
    infrastructure-live-apply-staging = {
      display       = "Infrastructure live staging apply"
      repo          = "infrastructure-live"
      apply_only    = true
      org_roles     = []
      project_roles = {}
    }
    infrastructure-live-apply-production = {
      display       = "Infrastructure live production apply"
      repo          = "infrastructure-live"
      apply_only    = true
      org_roles     = []
      project_roles = {}
    }
  }

  apply_workflows = {
    bootstrap-apply                       = ".github/workflows/apply.yml"
    github-config-apply                   = ".github/workflows/apply.yml"
    infrastructure-live-apply-foundation  = ".github/workflows/apply.yml"
    infrastructure-live-apply-development = ".github/workflows/apply.yml"
    infrastructure-live-apply-staging     = ".github/workflows/apply.yml"
    infrastructure-live-apply-production  = ".github/workflows/apply.yml"
  }

  org_role_bindings = merge([
    for sa_key, sa in local.service_accounts : {
      for role in sa.org_roles : "${sa_key}:${role}" => { sa = sa_key, role = role }
    }
  ]...)

  project_role_bindings = merge(flatten([
    for sa_key, sa in local.service_accounts : [
      for project_key, roles in sa.project_roles : {
        for role in roles : "${sa_key}:${project_key}:${role}" => {
          sa = sa_key, project = project_key, role = role
        }
      }
    ]
  ])...)

  project_ids = {
    seed = var.seed_project_id
    cicd = var.cicd_project_id
  }
}

resource "google_service_account" "this" {
  for_each = local.service_accounts

  project      = var.seed_project_id
  account_id   = "sa-${substr(each.key, 0, 27)}"
  display_name = each.value.display
  description  = "Mindclade keyless automation identity for ${var.github_org}/${each.value.repo}."
}

resource "google_service_account_iam_member" "wif" {
  for_each = local.wif_service_account_bindings

  service_account_id = google_service_account.this[each.value.identity].name
  role               = "roles/iam.workloadIdentityUser"
  member             = each.value.principal
}

resource "google_organization_iam_member" "automation" {
  for_each = local.org_role_bindings
  org_id   = var.org_id
  role     = each.value.role
  member   = "serviceAccount:${google_service_account.this[each.value.sa].email}"
}

resource "google_project_iam_member" "automation" {
  for_each = local.project_role_bindings
  project  = local.project_ids[each.value.project]
  role     = each.value.role
  member   = "serviceAccount:${google_service_account.this[each.value.sa].email}"
}

resource "google_billing_account_iam_member" "bootstrap_apply" {
  billing_account_id = var.billing_account
  role               = "roles/billing.user"
  member             = "serviceAccount:${google_service_account.this["bootstrap-apply"].email}"
}

locals {
  infrastructure_live_billing_users = toset([
    "infrastructure-live-apply-foundation",
    "infrastructure-live-apply-development",
    "infrastructure-live-apply-staging",
    "infrastructure-live-apply-production",
  ])
}

resource "google_billing_account_iam_member" "infrastructure_live" {
  for_each = local.infrastructure_live_billing_users

  billing_account_id = var.billing_account
  role               = "roles/billing.user"
  member             = "serviceAccount:${google_service_account.this[each.key].email}"
}
