# Contributing to Pulmu

Thanks for helping improve Pulmu. Pulmu is a Codex CLI workflow skill, so changes should preserve the single-command user experience and the one-writer safety boundary described in `AGENTS.md`.

## Set up a development checkout

```bash
git clone https://github.com/KamiJeong/pulmu.git
cd pulmu
./install.sh
./tests/test.sh
```

Create a focused branch from the current default branch. Keep unrelated edits out of the change and do not force-push over another contributor's work.

## Make and verify changes

- Keep `$pulmu` as the single public command and the seven forge stages stable.
- Preserve `pulmu_smith` as the only application, source, or test writer.
- Prefer deterministic shell scripts for Git, verification, and pull-request mechanics.
- Update documentation and tests when behavior or contracts change.
- Run `./tests/test.sh` after changing Pulmu scripts or contracts.
- Test on both Linux and macOS when changing shell portability behavior.

## Open a pull request

Use a clear Conventional Commit-style title where practical, describe the user-visible outcome, and include the checks you actually ran. The pull-request template asks for:

- a concise summary and change list
- verification commands and results
- risks, compatibility concerns, or follow-up work
- a related issue when one exists

Pull requests should not contain credentials, raw environment dumps, private logs, or generated Run Context from `.git/pulmu`.

## Report security issues

Do not open a public issue for a suspected vulnerability. Follow the private reporting process in [SECURITY.md](./SECURITY.md).
