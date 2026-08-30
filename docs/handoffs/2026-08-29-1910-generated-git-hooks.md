---
title: Generated Git hooks handoff
created: 2026-08-29
project: devshell-modules
spec: 2026-08-28-devenv-lite
---

# Generated Git hooks handoff

## Completed work

Task `9157-generated-git-hooks` is closed. Commit `933d7e5` adds the
`git-hooks.nix` adapter and locks the upstream input to the project Nixpkgs.
Modules retain the upstream `git-hooks` option shape and devenv's auto-enable
behavior. The selected runner and enabled hook packages enter the shell.

The adapter contributes installation to private shell setup and exposes the
generated all-files derivation through the evaluator's checks. Projects outside
a Git repository receive the upstream skip warning and enter the shell without
an error. Both shell closures remain free of `devenv-tasks`.

The adapter adds `git-hooks.install.force`. Its default preserves an existing
configuration. When enabled, shell entry removes any file or symlink at the
configured config path before reinstalling the hooks. This policy supports
projects that need to replace a stale regular configuration or rebuild an
installed hook on every entry.

## Verification

The nix-unit suite passes all 22 tests. The integration check installs a hook,
rejects a staged failing fixture, rejects the same fixture through the
all-files configuration, and reports skipped installation outside Git. It also
verifies the default config-preservation policy and forced replacement of a
stale hook.

The full local `nix flake check` passes on x86_64 Linux. Nix formatting and
`git diff --check` pass. Two meat-review rounds covered the implementation and
the force-install correction. The second review ended with `LGTM`. Review
marker `11` points to consolidated commit `933d7e5`. The operator waived the
final review of the consolidated commit.

## Next tasks

Task `6d31-flake-parts-integration` is now eligible. Re-check its assumptions
about evaluator checks and the new force-install option before implementation.
