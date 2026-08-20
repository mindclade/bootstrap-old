# Copyright © 2026 Mindclade, LLC. All Rights Reserved.
# Mindclade Proprietary and Confidential.
# SPDX-License-Identifier: LicenseRef-Mindclade-Proprietary
#

variable "org_id" { type = string }
variable "billing_account" { type = string }
variable "seed_project_id" { type = string }
variable "cicd_project_id" { type = string }
variable "cicd_project_number" { type = string }
variable "automation_secret_kms_key_id" { type = string }
variable "automation_secret_location" { type = string }
variable "github_org" { type = string }
variable "github_org_id" { type = string }
variable "github_repository_ids" { type = map(string) }
variable "enable_buildkite_wif" { type = bool }
variable "buildkite_organization_id" { type = string }
variable "buildkite_pipeline_ids" { type = set(string) }
variable "break_glass_principals" { type = set(string) }
variable "security_contact" { type = string }
