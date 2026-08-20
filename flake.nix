# Copyright © 2026 Mindclade, LLC. All Rights Reserved.
# Mindclade Proprietary and Confidential.
# SPDX-License-Identifier: LicenseRef-Mindclade-Proprietary
#
{
  description = "Toolchain for the mindclade bootstrap repository";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          # Terraform is BUSL-licensed since 1.6.
          config.allowUnfree = true;
        };
      in
      {
        # ---------------------------------------------------------------------------------
        # CI shell
        # ---------------------------------------------------------------------------------
        # Two linters and nothing else. `default` below carries terraform, the cloud SDK and
        # the scanners — a large closure for a job that needs one binary, and `nix develop`
        # with no argument is what a laptop wants rather than what a lint job does.
        #
        # It exists because .yamllint.yaml and .github/actionlint.yaml were in this repository
        # with nothing running either of them. A config with no runner reads in review exactly
        # like a gate and reports nothing.
        devShells.ci = pkgs.mkShell {
          packages = with pkgs; [
            actionlint
            shellcheck # actionlint shells out to it for `run:` blocks
            yamllint
          ];
        };

        devShells.default = pkgs.mkShell {
          # Versions track build/toolchains/versions.yaml in the monorepo. When that file
          # moves, move this with it — two sources of truth for a toolchain version is how
          # CI and a laptop end up disagreeing about a plan.
          #
          # The channel pin above makes this shell reproducible, but it does NOT make the
          # terraform in it equal the 1.15.9 that .terraform-version and every workflow pin.
          # The shellHook checks; see the note in infrastructure-live/flake.nix for why a
          # check rather than a per-tool overlay.
          packages = with pkgs; [
            terraform
            google-cloud-sdk
            jq
            gh
            tflint
            checkov
            shellcheck
            yamllint
            actionlint

            # bash 5. macOS ships 3.2, which lacks `declare -A` and `mapfile` — used by the
            # scripts in this estate, so without this they fail locally and pass in CI.
            bashInteractive
          ];

          shellHook = ''
            want_tf="$(tr -d '[:space:]' < .terraform-version 2>/dev/null || echo unknown)"
            have_tf="$(terraform version -json 2>/dev/null | jq -r .terraform_version 2>/dev/null || echo unknown)"

            echo "bootstrap — terraform $have_tf (pinned $want_tf)"
            if [ "$have_tf" != "$want_tf" ] && [ "$want_tf" != "unknown" ]; then
              echo
              echo "  WARNING: terraform $have_tf does not match .terraform-version ($want_tf)."
              echo "           First apply is local; protected CI performs later applies. A version"
              echo "           mismatch can change plans or state serialization."
            fi
            echo
            echo "The first apply is manual; subsequent applies use the protected bootstrap environment."
            echo "Read docs/first-apply.md before running anything."
          '';
        };
      });
}
