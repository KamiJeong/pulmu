# Changelog

Notable changes to Pulmu are documented in this file. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project uses semantic versioning when releases are tagged.

## [Unreleased]

## [0.4.0] - 2026-09-08

### Added

- Project-local installation and removal with `--local <project>`, explicit `--global`, preservation of unrelated configuration, and rollback on replacement failure.
- Pre-Ignite necessity assessment and advisory/no-change completion without creating development state or empty commits.
- Direct, reviewed, and delegated execution paths with one recorded writer and explicit self or independent review assurance.
- Product-level design direction proposals with viewable same-content alternatives and named design-system candidates.
- Complete Korean usage documentation alongside the primary English README, plus download, installation, update, and removal guidance on Pages.

### Changed

- Run Context schema v2 records execution routing and supports strict v1 migration and explicit replanning that invalidates stale evidence.
- Medium/high-risk work requires independent review, and explicit security or compatibility risk requires specialist review regardless of Forge depth.
- Default work branches use task types such as `feat/<slug>` and `fix/<slug>`. Optional `git.branch_prefix` and explicit `--branch` support team conventions; base recovery uses saved provenance instead of a prefix.
- Demo packaging reuses the project-local installer.

### Fixed

- Local installation tests compare canonical paths and exercise symlinked project paths, including macOS temporary-directory aliases.

### Compatibility

- `$pulmu` remains the single public command. All development paths preserve the seven stages and conditional Pattern; advisory/no-change requests finish before Ignite.
- A run can designate the main Orchestrator or `pulmu_smith` as its sole writer. Low-risk direct work can use self-checks, which are reported separately from independent review.
- Existing branches are not renamed. Supported v1 Run Context migrates through strict validation.
- No-argument installation remains current-user-wide. Local installation neither removes a global copy nor changes project `config.toml` or Git ignore rules. Commit or locally exclude newly installed files before starting a development run.
- Reinstallation replaces Pulmu-managed copies; keep customizations in the maintained source checkout.

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
