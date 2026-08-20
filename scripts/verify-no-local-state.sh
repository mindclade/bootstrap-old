#!/usr/bin/env bash
# Copyright © 2026 Mindclade, LLC. All Rights Reserved.
# Mindclade Proprietary and Confidential.
# SPDX-License-Identifier: LicenseRef-Mindclade-Proprietary

set -euo pipefail
IFS=$'\n\t'
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
state="$(find "$root" -path '*/.git' -prune -o \( -name .terraform -o -name .terragrunt-cache -o -name '*.tfstate' -o -name '*.tfstate.*' -o -name '*tfplan*' \) -print -quit)"
if [[ -n "$state" ]]; then
  echo "local Terraform/Terragrunt state or cache found: $state" >&2
  exit 1
fi
