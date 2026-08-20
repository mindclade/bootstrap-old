# Copyright © 2026 Mindclade, LLC. All Rights Reserved.
# Mindclade Proprietary and Confidential.
# SPDX-License-Identifier: LicenseRef-Mindclade-Proprietary
#

variable "org_id" { type = string }
variable "bootstrap_folder_id" { type = string }
variable "billing_account" { type = string }
variable "prefix" { type = string }
variable "suffix" { type = string }
variable "state_kms_location" { type = string }
variable "state_replica_kms_location" { type = string }
variable "kms_protection_level" { type = string }
variable "labels" { type = map(string) }
