# Changelog

Notable changes to Pulmu are documented in this file. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project uses semantic versioning when releases are tagged.

## [Unreleased]

### Changed

- Added project-local installation and removal with `--local <project>`, explicit `--global`, preservation of unrelated configuration, rollback on replacement failure, and bilingual setup guidance.
- Default work branches now use `feat/<slug>`, `fix/<slug>`, and other task types without a tool namespace. An optional `git.branch_prefix` and explicit `--branch` preserve team naming, while ownership and base recovery use saved provenance rather than a prefix.
- Added a pre-Ignite necessity assessment and honest advisory/no-change completion.
- Added direct, reviewed, and delegated execution paths with one recorded writer and explicit self or independent review assurance.
- Added schema v2 routing state, strict v1 migration, explicit replan, specialist review independent of Forge depth, and routing details in delivery output.
- Added product-level design direction selection with viewable same-content alternatives and curated public-example discovery guidance.

## [0.3.0] - 2026-09-07

### Added

- Landing-page install and repository paths, project trust signals, social metadata, mobile navigation, and post-preview next steps.
- Regression coverage for stale verification, candidate integrity, workflow gates, reviewer receipts, and interrupted delivery.

### Changed

- Verification, review, staging, and delivery share run-bound candidate identity.
- Quench requires an explicit, nonempty verification plan with bounded command execution.
- Stage transitions require run identity and enforce run-wide limits of three Quench fixes and two Hone refinements.
- Hone requires complete, candidate-bound results from every required reviewer, with independent context and bounded result repair.
- Fresh task initialization is separate from guarded same-run delivery recovery.

### Fixed

- Reject hidden staged changes, changes during verification, stale evidence publication, and committed-content mismatches.
- Preserve supplied task identity, including multiline input, and prevent active runs from being silently replaced.
- Recover interrupted delivery only for the exact recorded run and reviewed commit.
- Pin GitHub operations to the origin-derived repository and validate pull-request identity.
- Preserve failed Quench command status in the test harness.

### Compatibility

- Direct helper callers must supply expected run IDs and satisfy the verification-plan, stage, and reviewer-result prerequisites.
- Seven stages, conditional Pattern, Smith-only writing, existing agents and model settings, and optional GitHub delivery remain unchanged.

## [0.2.0] - 2026-08-27

### Added

- Linux and macOS GitHub Actions coverage for the deterministic integration suite.
- GitHub setup, delivery-selection, fork limitation, and interrupted-delivery recovery guidance.
- Contribution, security-reporting, pull-request, and issue templates.

### Fixed

- Bash 3.2 compatibility when metadata or GitHub label arrays are empty.
- Cross-platform permission assertions in the Run Context test suite.
