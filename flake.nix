# Copyright © 2026 Mindclade, LLC. All Rights Reserved.
# Mindclade Proprietary and Confidential.
# SPDX-License-Identifier: LicenseRef-Mindclade-Proprietary

{
  description = "Toolchain for the mindclade bootstrap repository";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
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

        # Nixpkgs can lag a newly published Terraform patch even when its revision is pinned.
        # Fetch the exact CI version and verify it against HashiCorp's signed release checksum
        # inventory so local recovery never silently runs a different state engine.
        terraformVersion = "1.15.9";
        terraformSha = {
          x86_64-linux = "76edd0b22d2f27d3d2e097cd793209646f719cf60f02ff3af626b07361137da1";
          aarch64-darwin = "05b27586a5d7d84105690ecccc7edbbf48bc3d6d577745cb61f163ba990adf4f";
        };
        terraformPlatform = {
          x86_64-linux = "linux_amd64";
          aarch64-darwin = "darwin_arm64";
        };

        terraform-pinned =
          if !(terraformSha ? ${system}) then
            throw "terraform ${terraformVersion} is not pinned for ${system}; add its SHA256 from the release SHA256SUMS to flake.nix"
          else
            pkgs.runCommand "terraform-${terraformVersion}"
              {
                src = pkgs.fetchurl {
                  url = "https://releases.hashicorp.com/terraform/${terraformVersion}/terraform_${terraformVersion}_${terraformPlatform.${system}}.zip";
                  sha256 = terraformSha.${system};
                };
                nativeBuildInputs = [ pkgs.unzip ]
                  ++ pkgs.lib.optional pkgs.stdenv.hostPlatform.isLinux pkgs.autoPatchelfHook;
                meta.mainProgram = "terraform";
              } ''
              unzip -q "$src"
              install -Dm755 terraform "$out/bin/terraform"
            '';
      in
      {
        packages.terraform = terraform-pinned;

        # ---------------------------------------------------------------------------------
        # CI shell
        # ---------------------------------------------------------------------------------
        # CI-focused linters only. `default` below carries Terraform, the cloud SDK and
        # infrastructure tooling — a large closure for a job that needs one binary, and `nix develop`
        # with no argument is what a laptop wants rather than what a lint job does.
        #
        # It exists because .yamllint.yaml and .github/actionlint.yaml were in this repository
        # with nothing running either of them. A config with no runner reads in review exactly
        # like a gate and reports nothing.
        devShells.ci = pkgs.mkShell {
          packages = with pkgs; [
            actionlint
            git
            shellcheck # actionlint shells out to it for `run:` blocks
            yamllint
          ];
        };

        devShells.default = pkgs.mkShell {
          # Versions track build/toolchains/versions.yaml in the monorepo. When that file
          # moves, move this with it — two sources of truth for a toolchain version is how
          # CI and a laptop end up disagreeing about a plan.
          #
          # flake.lock makes the supporting package set reproducible; Terraform itself is the
          # checksum-pinned derivation above. The shellHook verifies all repository pins agree.
          packages = with pkgs; [
            terraform-pinned
            google-cloud-sdk
            jq
            git
            gh
            tflint
            shellcheck
            yamllint
            actionlint
            check-jsonschema
            python3

            # bash 5. macOS ships 3.2, which lacks `declare -A` and `mapfile` — used by the
            # scripts in this estate, so without this they fail locally and pass in CI.
            bashInteractive
          ];

          shellHook = ''
            want_tf="$(tr -d '[:space:]' < .terraform-version 2>/dev/null || echo unknown)"
            have_tf="$(terraform version -json 2>/dev/null | jq -r .terraform_version 2>/dev/null || echo unknown)"

            echo "bootstrap — terraform $have_tf (pinned $want_tf)" >&2
            if [ "$have_tf" != "$want_tf" ] && [ "$want_tf" != "unknown" ]; then
              echo >&2
              echo "  ERROR: terraform $have_tf does not match .terraform-version ($want_tf)." >&2
              echo "         First apply is local; a version mismatch can change plans or state" >&2
              echo "         serialization. Update flake.lock and the repository pin together." >&2
              exit 1
            fi
            echo >&2
            echo "The first apply is manual; subsequent applies use the protected bootstrap environment." >&2
            echo "Read docs/first-apply.md before running anything." >&2
          '';
        };
      });
}
