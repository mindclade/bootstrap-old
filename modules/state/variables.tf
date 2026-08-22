# Copyright © 2026 Mindclade, LLC. All Rights Reserved.
# Mindclade Proprietary and Confidential.
# SPDX-License-Identifier: LicenseRef-Mindclade-Proprietary


variable "seed_project_id" { type = string }
variable "prefix" { type = string }
variable "suffix" { type = string }
variable "primary_kms_key_id" { type = string }
variable "replica_kms_key_id" { type = string }
variable "legacy_replica_kms_key_id" {
  type     = string
  nullable = true
}
variable "preserve_legacy_eu_state_replicas" { type = bool }
variable "state_bucket_location" { type = string }
variable "state_replica_location" { type = string }
variable "state_soft_delete_days" { type = number }
variable "noncurrent_version_days" { type = number }
variable "noncurrent_version_count" { type = number }
variable "service_account_emails" { type = map(string) }
variable "labels" { type = map(string) }
