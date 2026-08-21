# Copyright © 2026 Mindclade, LLC. All Rights Reserved.
# Mindclade Proprietary and Confidential.
# SPDX-License-Identifier: LicenseRef-Mindclade-Proprietary

{
  description = "Toolchain for the mindclade bootstrap repository";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

  outputs =
    { nixpkgs, ... }:
    let
      # Ring-0 recovery must enumerate only platforms backed by reviewed Terraform artifacts.
      # Do not inherit flake-utils' x86_64-darwin default: Mindclade's operator fleet is Apple
      # Silicon and Nixpkgs drops Intel Darwin after 26.05.
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "aarch64-darwin"
      ];
      forAllSystems = nixpkgs.lib.genAttrs systems;
      perSystem =
        system:
        let
          pkgs = import nixpkgs {
            inherit system;
            # Terraform is BUSL-licensed since 1.6.
            config.allowUnfreePredicate = package: nixpkgs.lib.getName package == "terraform";
          };

          # Nixpkgs can lag a newly published Terraform patch even when its revision is pinned.
          # Fetch the exact CI version and verify it against HashiCorp's signed release checksum
          # inventory so local recovery never silently runs a different state engine.
          terraformVersion = "1.15.9";
          terraformRelease =
            {
              aarch64-darwin = {
                os = "darwin";
                arch = "arm64";
                hash = "sha256-BbJ1hqXX2EEFaQ7MzH7bv0i8PW1Xd0XLYfFjupkK308=";
              };
              aarch64-linux = {
                os = "linux";
                arch = "arm64";
                hash = "sha256-CvpsKfYcpeonDpUOQ+UOzyQYtZhQe/WA6K524eZpmxk=";
              };
              x86_64-linux = {
                os = "linux";
                arch = "amd64";
                hash = "sha256-du3Qsi0vJ9PS4JfNeTIJZG9xnPYPAv869iawc2ETfaE=";
              };
            }
            .${system};
          terraformPinned = pkgs.stdenvNoCC.mkDerivation {
            pname = "terraform";
            version = terraformVersion;
            src = pkgs.fetchurl {
              url = "https://releases.hashicorp.com/terraform/${terraformVersion}/terraform_${terraformVersion}_${terraformRelease.os}_${terraformRelease.arch}.zip";
              inherit (terraformRelease) hash;
            };
            nativeBuildInputs = [ pkgs.unzip ];
            dontUnpack = true;
            installPhase = ''
              runHook preInstall
              mkdir -p "$out/bin" "$out/share/licenses/terraform"
              unzip -q "$src" -d release
              install -m755 release/terraform "$out/bin/terraform"
              if [ -f release/LICENSE.txt ]; then
                install -m644 release/LICENSE.txt "$out/share/licenses/terraform/LICENSE.txt"
              fi
              runHook postInstall
            '';
            meta = with pkgs.lib; {
              description = "Terraform infrastructure-as-code CLI";
              homepage = "https://www.terraform.io/";
              license = licenses.bsl11;
              mainProgram = "terraform";
              platforms = [ system ];
            };
          };
        in
        {
          inherit pkgs terraformPinned;

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
          ciShell = pkgs.mkShell {
            packages = with pkgs; [
              actionlint
              git
              gnumake
              python3
              shellcheck # actionlint shells out to it for `run:` blocks
              yamllint
            ];
          };

          defaultShell = pkgs.mkShell {
            # Versions track build/toolchains/versions.yaml in the monorepo. When that file
            # moves, move this with it — two sources of truth for a toolchain version is how
            # CI and a laptop end up disagreeing about a plan.
            #
            # flake.lock makes the supporting package set reproducible; Terraform itself is the
            # checksum-pinned derivation above. The shellHook verifies all repository pins agree.
            packages = with pkgs; [
              terraformPinned
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
        };
    in
    {
      packages = forAllSystems (system: {
        terraform = (perSystem system).terraformPinned;
      });
      devShells = forAllSystems (system: {
        ci = (perSystem system).ciShell;
        default = (perSystem system).defaultShell;
      });
      checks = forAllSystems (system: {
        ci-shell = (perSystem system).ciShell;
        terraform = (perSystem system).terraformPinned;
      });
      formatter = forAllSystems (system: (perSystem system).pkgs.nixfmt);
    };
}
