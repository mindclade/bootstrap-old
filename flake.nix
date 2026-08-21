# Copyright © 2026 Mindclade, LLC. All Rights Reserved.
# Mindclade Proprietary and Confidential.
# SPDX-License-Identifier: LicenseRef-Mindclade-Proprietary

{
  description = "Toolchain for the mindclade bootstrap repository";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

  outputs =
    { nixpkgs, ... }:
    let
      # Ring-0 workflows execute on Linux/amd64 and Linux/arm64, and operators use Apple
      # Silicon. Do not expose shell attributes for systems whose recovery-critical Terraform
      # binary is not pinned.
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
            config.allowUnfreePredicate = package: nixpkgs.lib.getName package == "terraform";
          };

          # Nixpkgs can lag a newly published Terraform patch even when its revision is pinned.
          # Fetch the exact CI version and verify it against HashiCorp's signed release checksum
          # inventory so local recovery never silently runs a different state engine.
          terraformVersion = "1.15.9";
          terraformSha = {
            x86_64-linux = "sha256-du3Qsi0vJ9PS4JfNeTIJZG9xnPYPAv869iawc2ETfaE=";
            aarch64-linux = "sha256-CvpsKfYcpeonDpUOQ+UOzyQYtZhQe/WA6K524eZpmxk=";
            aarch64-darwin = "sha256-BbJ1hqXX2EEFaQ7MzH7bv0i8PW1Xd0XLYfFjupkK308=";
          };
          terraformPlatform = {
            x86_64-linux = "linux_amd64";
            aarch64-linux = "linux_arm64";
            aarch64-darwin = "darwin_arm64";
          };

          terraformPinned = pkgs.stdenvNoCC.mkDerivation {
            pname = "terraform";
            version = terraformVersion;

            src = pkgs.fetchurl {
              url = "https://releases.hashicorp.com/terraform/${terraformVersion}/terraform_${terraformVersion}_${terraformPlatform.${system}}.zip";
              hash = terraformSha.${system};
            };

            dontUnpack = true;
            nativeBuildInputs = [
              pkgs.unzip
            ]
            ++ pkgs.lib.optional pkgs.stdenv.hostPlatform.isLinux pkgs.autoPatchelfHook;

            installPhase = ''
              runHook preInstall
              unzip -q "$src" -d release
              install -Dm755 release/terraform "$out/bin/terraform"
              if [ -f release/LICENSE.txt ]; then
                install -Dm644 release/LICENSE.txt "$out/share/licenses/terraform/LICENSE.txt"
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

          ciShell = pkgs.mkShell {
            packages = with pkgs; [
              actionlint
              bashInteractive
              git
              gnumake
              python3
              shellcheck
              yamllint
            ];
          };

          defaultShell = pkgs.mkShell {

            # flake.lock makes the supporting package set reproducible; Terraform itself is the
            # checksum-pinned derivation above. The shellHook verifies all repository pins agree.
            packages = with pkgs; [
              terraformPinned
              google-cloud-sdk
              jq
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
        in
        {
          inherit
            ciShell
            defaultShell
            pkgs
            terraformPinned
            ;
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
