<!-- mindclade-doc: changelog@1 -->

# Mindclade changelog · Ring-0 foundation

This file records material repository changes from the adoption of the
estate-wide changelog contract. Earlier history remains available in Git and is
not reconstructed or relabeled here.

## Unreleased

### Added

- Added the exact estate-wide `LEGAL.md` reliance policy and made it part of
  the repository contract.
- Added CI/CD-project Cloud Identity API enablement as the explicit quota-consumer
  prerequisite for the reviewed, named-administrator IdP export.

### Changed

- Made connected pull-request planning path-aware and added the stable `plan / verdict` check.
  Documentation-only changes skip protected credentials, while Terraform, lockfile, toolchain,
  and plan-control changes still fail closed to the connected plan. Pull-request close events
  cancel stale waiting runs without entering a protected environment. Pull requests execute
  the immutable base-branch classifier, classifier and workflow changes force connected
  qualification, and a cancelled connected plan remains a failing verdict.
- Synchronized policy bundle `2026.08.21.3` and pinned repository-home validation to canonical
  commit `8467615f12868d4b78718b8ddf7f05797c44a507`.
- Updated the proprietary license with the protected-disclosure notice and
  recorded the Contributor Covenant 2.1 attribution and modifications.
- Moved the reusable SPDX source-header template under `.github/` so `LICENSE`
  is the sole root license surface.

### Fixed

### Security

- Clarified that security response times are non-contractual operational
  targets and that safe harbor cannot authorize third-party systems or
  unlawful conduct.

### Removed

## 2026-08-21 — Common-document governance baseline

### Added

- established local, versioned contribution, security, support, conduct,
  governance, license, notice, and changelog documents;
- added machine-enforced presence and content requirements for those documents.

### Changed

- aligned the root documentation with the Mindclade MONO brand and repository
  authority contract;
- standardized proprietary rights, contributor authorization, third-party
  precedence, and support routing across the governed repository estate.

### Security

- made private vulnerability reporting and the absence of a published PGP key
  explicit;
- prohibited secrets, sensitive evidence, customer data, model material, and
  restricted biological content in public or general-purpose channels.
