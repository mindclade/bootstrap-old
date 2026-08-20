#!/usr/bin/env bash
# Copyright © 2026 Mindclade, LLC. All Rights Reserved.
# Mindclade Proprietary and Confidential.
# SPDX-License-Identifier: LicenseRef-Mindclade-Proprietary

set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
if find "$root" -path '*/.git' -prune -o \( -name .terraform -o -name .terragrunt-cache -o -name '*.tfstate' -o -name '*.tfstate.*' -o -name '*tfplan*' \) -print | grep -q .; then
  echo "local Terraform/Terragrunt state or cache found" >&2; exit 1
fi
