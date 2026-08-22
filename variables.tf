# Copyright © 2026 Mindclade, LLC. All Rights Reserved.
# Mindclade Proprietary and Confidential.
# SPDX-License-Identifier: LicenseRef-Mindclade-Proprietary


variable "org_id" {
  description = "Google Cloud organization numeric ID."
  type        = string
  validation {
    condition     = can(regex("^[0-9]+$", var.org_id))
    error_message = "org_id must be numeric."
  }
}

variable "billing_account" {
  description = "Billing account ID in XXXXXX-XXXXXX-XXXXXX form."
  type        = string
  validation {
    condition     = can(regex("^[0-9A-F]{6}-[0-9A-F]{6}-[0-9A-F]{6}$", upper(var.billing_account)))
    error_message = "billing_account must use XXXXXX-XXXXXX-XXXXXX format."
  }
}

variable "bootstrap_folder_id" {
  description = "Optional existing bootstrap folder resource name (folders/NNN) for adoption. Empty creates the Ring-0 bootstrap folder."
  type        = string
  default     = ""
  validation {
    condition     = var.bootstrap_folder_id == "" || can(regex("^folders/[0-9]+$", var.bootstrap_folder_id))
    error_message = "bootstrap_folder_id must be empty or folders/<numeric-id>."
  }
}

variable "prefix" {
  description = "Short lowercase resource prefix."
  type        = string
  default     = "mc"
  validation {
    condition     = can(regex("^[a-z][a-z0-9]{1,3}$", var.prefix))
    error_message = "prefix must be 2-4 lowercase alphanumerics beginning with a letter."
  }
}

variable "region" {
  description = "Primary bootstrap region for regional control-plane resources."
  type        = string
  default     = "us-central1"

  validation {
    condition     = var.region == "us-central1"
    error_message = "The us-only-v1 residency profile requires region us-central1."
  }
}

variable "residency_profile" {
  description = "Immutable location policy selected by the enterprise blueprint."
  type        = string
  default     = "us-only-v1"

  validation {
    condition     = var.residency_profile == "us-only-v1"
    error_message = "residency_profile must be us-only-v1."
  }
}

variable "state_bucket_location" {
  description = "Primary GCS location for Terraform state buckets."
  type        = string
  default     = "US"

  validation {
    condition     = var.state_bucket_location == "US"
    error_message = "The us-only-v1 residency profile requires the US state multi-region."
  }
}

variable "state_kms_location" {
  description = "Cloud KMS location compatible with state_bucket_location (for US multi-region, use us)."
  type        = string
  default     = "us"

  validation {
    condition     = var.state_kms_location == "us"
    error_message = "The us-only-v1 residency profile requires the us KMS multi-region."
  }
}

variable "automation_secret_location" {
  description = "Single supported Secret Manager region for the Ring-0 module-reader secret and its dedicated CMEK."
  type        = string
  default     = "us-central1"

  validation {
    condition     = var.automation_secret_location == "us-central1"
    error_message = "The us-only-v1 residency profile requires automation secrets in us-central1."
  }
}

variable "state_replica_location" {
  description = "Independent U.S. GCS region for state replicas."
  type        = string
  default     = "us-east4"
  validation {
    condition     = var.state_replica_location == "us-east4"
    error_message = "The us-only-v1 residency profile requires state replicas in us-east4."
  }
}

variable "state_replica_kms_location" {
  description = "Cloud KMS location compatible with state_replica_location."
  type        = string
  default     = "us-east4"
  validation {
    condition     = var.state_replica_kms_location == "us-east4"
    error_message = "The us-only-v1 residency profile requires replica CMEK in us-east4."
  }
}

variable "state_soft_delete_days" {
  description = "GCS soft-delete retention for primary state objects."
  type        = number
  default     = 30
  validation {
    condition     = var.state_soft_delete_days >= 7 && var.state_soft_delete_days <= 90
    error_message = "state_soft_delete_days must be between 7 and 90."
  }
}

variable "noncurrent_version_days" {
  description = "Age before old noncurrent state versions become eligible for deletion."
  type        = number
  default     = 90
  validation {
    condition     = var.noncurrent_version_days >= 30
    error_message = "noncurrent_version_days must be at least 30."
  }
}

variable "noncurrent_version_count" {
  description = "Minimum newer versions retained before old versions can be deleted."
  type        = number
  default     = 100
  validation {
    condition     = var.noncurrent_version_count >= 10
    error_message = "noncurrent_version_count must be at least 10."
  }
}

variable "kms_protection_level" {
  description = "SOFTWARE or HSM for bootstrap state CMEKs. HSM has cost and location implications."
  type        = string
  default     = "SOFTWARE"
  validation {
    condition     = contains(["SOFTWARE", "HSM"], var.kms_protection_level)
    error_message = "kms_protection_level must be SOFTWARE or HSM."
  }
}

variable "github_org" {
  description = "Canonical GitHub organization login: mindclade."
  type        = string
  default     = "mindclade"
}

variable "github_org_id" {
  description = "Immutable numeric GitHub organization ID."
  type        = string
  validation {
    condition     = can(regex("^[0-9]+$", var.github_org_id))
    error_message = "github_org_id must be numeric."
  }
}

variable "github_repository_ids" {
  description = "Immutable numeric GitHub repository IDs keyed by repository name."
  type        = map(string)
  validation {
    condition = alltrue([
      for name in ["bootstrap", "github-config", "infrastructure-live", "gitops"] :
      can(regex("^[0-9]+$", lookup(var.github_repository_ids, name, "")))
      ]) && can(regex(
      "^[0-9]+$",
      var.github_repository_ids["mindclade-internal-monorepo"],
    ))
    error_message = "github_repository_ids must contain numeric IDs for every control repository and the monorepo."
  }
}

variable "enable_buildkite_wif" {
  description = "Deprecated transition guard. Buildkite federation cannot be activated after the ARC authority amendment."
  type        = bool
  default     = false
  validation {
    condition     = var.enable_buildkite_wif == false
    error_message = "Buildkite WIF is retired as an authority path; keep enable_buildkite_wif false."
  }
}

variable "buildkite_organization_id" {
  description = "Immutable Buildkite organization UUID."
  type        = string
  default     = ""
  validation {
    condition = !var.enable_buildkite_wif || can(regex(
      "^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$",
      var.buildkite_organization_id,
    ))
    error_message = "buildkite_organization_id must be a UUID when Buildkite WIF is enabled."
  }
}

variable "buildkite_pipeline_ids" {
  description = "Immutable Buildkite pipeline UUIDs permitted to exchange OIDC tokens."
  type        = set(string)
  default     = []
  validation {
    condition = !var.enable_buildkite_wif || (
      length(var.buildkite_pipeline_ids) > 0 && alltrue([
        for id in var.buildkite_pipeline_ids : can(regex(
          "^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$",
          id,
        ))
      ])
    )
    error_message = "buildkite_pipeline_ids must contain at least one UUID when Buildkite WIF is enabled."
  }
}

variable "buildkite_pipeline_step_contracts" {
  description = "Immutable Buildkite pipeline UUID to the exact artifact step identities it may federate."
  type        = map(set(string))
  default     = {}

  validation {
    condition = alltrue(flatten([
      for _, steps in var.buildkite_pipeline_step_contracts : [
        for step in steps : contains(["artifact-build", "artifact-qualify", "artifact-promote"], step)
      ]
    ]))
    error_message = "Buildkite step contracts may contain only artifact-build, artifact-qualify, and artifact-promote."
  }
}

variable "break_glass_principals" {
  description = "Named human users permitted to impersonate the no-standing-permission break-glass account."
  type        = set(string)
  validation {
    condition = length(var.break_glass_principals) > 0 && alltrue([
      for p in var.break_glass_principals : can(regex("^[^@[:space:]]+@[^@[:space:]]+$", p))
    ])
    error_message = "break_glass_principals must contain at least one named human email address."
  }
}

variable "security_contact" {
  description = "Group mailbox receiving break-glass alerts."
  type        = string
  default     = "security@mindclade.com"
  validation {
    condition     = can(regex("^[^@[:space:]]+@[^@[:space:]]+$", var.security_contact))
    error_message = "security_contact must be an email address."
  }
}

variable "labels" {
  description = "Bootstrap labels."
  type        = map(string)
  default = {
    managed-by  = "terraform"
    repository  = "bootstrap"
    criticality = "critical"
  }
}
