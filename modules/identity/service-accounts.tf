# Copyright © 2026 Mindclade, LLC. All Rights Reserved.
# Mindclade Proprietary and Confidential.
# SPDX-License-Identifier: LicenseRef-Mindclade-Proprietary

locals {
  service_accounts = {
    bootstrap-plan = {
      display = "Bootstrap speculative plan"
      repo    = "bootstrap"
      # Browser supplies the hierarchy-only folders.get/list, organizations.get, and
      # projects.get/list permissions needed to refresh the bootstrap folder and projects.
      org_roles = ["roles/browser", "roles/iam.securityReviewer"]
      project_roles = {
        seed = [
          "roles/cloudkms.viewer",
          "roles/iam.serviceAccountViewer",
          "roles/logging.viewer",
          "roles/monitoring.viewer",
          "roles/secretmanager.viewer",
          "roles/serviceusage.serviceUsageViewer",
          "roles/storage.legacyBucketReader",
          "roles/storagetransfer.viewer",
        ]
        cicd = [
          "roles/iam.workloadIdentityPoolViewer",
          "roles/serviceusage.serviceUsageViewer",
        ]
      }
    }
    bootstrap-drift = {
      display   = "Bootstrap read-only drift"
      repo      = "bootstrap"
      org_roles = ["roles/browser", "roles/iam.securityReviewer"]
      project_roles = {
        seed = [
          "roles/cloudkms.viewer",
          "roles/iam.serviceAccountViewer",
          "roles/logging.viewer",
          "roles/monitoring.viewer",
          "roles/secretmanager.viewer",
          "roles/serviceusage.serviceUsageViewer",
          "roles/storage.legacyBucketReader",
          "roles/storagetransfer.viewer",
        ]
        cicd = [
          "roles/iam.workloadIdentityPoolViewer",
          "roles/serviceusage.serviceUsageViewer",
        ]
      }
    }
    bootstrap-apply = {
      display = "Bootstrap protected apply"
      repo    = "bootstrap"
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
      display = "GitHub configuration speculative plan"
      repo    = "github-config"
      # Cloud Identity Groups API authorization is administered in Google Workspace/Cloud
      # Identity, not through a Resource Manager organization IAM binding. Keep this account
      # free of unsupported organization roles; docs/cloud-identity-authorization.md defines
      # the manual fail-closed export and separately approved delegated-admin paths.
      org_roles = []
      project_roles = {
        cicd = ["roles/serviceusage.serviceUsageConsumer"]
      }
    }
    github-config-apply = {
      display       = "GitHub configuration protected apply"
      repo          = "github-config"
      org_roles     = []
      project_roles = {}
    }
    infrastructure-live-plan = {
      display = "Infrastructure live speculative plan"
      repo    = "infrastructure-live"
      org_roles = [
        "roles/resourcemanager.organizationViewer",
        "roles/iam.securityReviewer",
        "roles/cloudasset.viewer",
      ]
      project_roles = {}
    }
    infrastructure-live-apply-foundation = {
      display = "Infrastructure live organization foundation apply"
      repo    = "infrastructure-live"
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
      org_roles     = []
      project_roles = {}
    }
    infrastructure-live-apply-staging = {
      display       = "Infrastructure live staging apply"
      repo          = "infrastructure-live"
      org_roles     = []
      project_roles = {}
    }
    infrastructure-live-apply-production = {
      display       = "Infrastructure live production apply"
      repo          = "infrastructure-live"
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

# Bootstrap owns the billing-account IAM bindings below. The protected apply identity therefore
# needs only IAM-policy administration on this one billing account; Billing Account Administrator
# is deliberately not used because it also permits financial and account-lifecycle operations.
# The one-time recovery identity creates this self-hosting grant during first apply.
resource "google_billing_account_iam_member" "bootstrap_billing_iam_admin" {
  billing_account_id = var.billing_account
  role               = "roles/iam.securityAdmin"
  member             = "serviceAccount:${google_service_account.this["bootstrap-apply"].email}"
}

# Planning and drift refresh billing-backed project resources but must never link projects or
# change billing. Billing Account Viewer supplies billing.accounts.get/getIamPolicy without the
# billing.resourceAssociations.create permission held by Billing Account User.
locals {
  bootstrap_billing_viewers = toset([
    "bootstrap-plan",
    "bootstrap-drift",
  ])
}

resource "google_billing_account_iam_member" "bootstrap_read" {
  for_each = local.bootstrap_billing_viewers

  billing_account_id = var.billing_account
  role               = "roles/billing.viewer"
  member             = "serviceAccount:${google_service_account.this[each.key].email}"
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
