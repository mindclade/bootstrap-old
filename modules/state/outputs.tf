# Copyright © 2026 Mindclade, LLC. All Rights Reserved.
# Mindclade Proprietary and Confidential.
# SPDX-License-Identifier: LicenseRef-Mindclade-Proprietary

output "state_buckets" {
  value = { for scope, bucket in google_storage_bucket.state : scope => bucket.name }
}
output "state_replica_buckets" {
  value = { for scope, bucket in google_storage_bucket.replica_us : scope => bucket.name }
}
output "legacy_state_replica_buckets" {
  value = { for scope, bucket in google_storage_bucket.legacy_replica : scope => bucket.name }
}
