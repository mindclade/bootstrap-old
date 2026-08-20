# Copyright © 2026 Mindclade, LLC. All Rights Reserved.
# Mindclade Proprietary and Confidential.
# SPDX-License-Identifier: LicenseRef-Mindclade-Proprietary

output "state_buckets" {
  value = { for scope, bucket in google_storage_bucket.state : scope => bucket.name }
}
output "state_replica_buckets" {
  value = { for scope, bucket in google_storage_bucket.replica : scope => bucket.name }
}
