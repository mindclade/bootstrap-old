# Copyright © 2026 Mindclade, LLC. All Rights Reserved.
# Mindclade Proprietary and Confidential.
# SPDX-License-Identifier: LicenseRef-Mindclade-Proprietary

output "suffix" {
  description = "Six hex characters. Appended to every project id."
  value       = random_id.suffix.hex
}
