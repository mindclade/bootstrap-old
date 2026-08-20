# Copyright © 2026 Mindclade, LLC. All Rights Reserved.
# Mindclade Proprietary and Confidential.
# SPDX-License-Identifier: LicenseRef-Mindclade-Proprietary

terraform {
  required_version = ">= 1.15.0, < 1.16.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = "~> 6.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

# Provider versions are pinned by .terraform.lock.hcl, which must be generated for BOTH
# platforms or one of CI and your laptop will fail to init:
#
#   terraform providers lock \
#     -platform=linux_amd64 \
#     -platform=darwin_arm64
