---
title: Strict shell modules handoff
created: 2026-08-29
project: devshell-modules
spec: 2026-08-28-devenv-lite
---

# Strict shell modules handoff

## Completed work

Task `887e-strict-shell-modules` is closed. Commit `900a635` adds the strict
module evaluator, its declared option boundary, script packages, and ordered
shell setup. The evaluator uses one `lib.evalModules` fixpoint and appends
declared overlays to the caller's base package set.

Unsupported root options fail through module validation. Assertions and
warnings retain their module semantics. Overlay declarations that depend on
the final module `pkgs` argument receive a focused recursion diagnostic,
including dependencies deferred through nested package sets.

Named scripts become ordinary high-priority shell packages. They support
arguments, package dependencies, and environment variables without retaining
a runtime task runner. Internal setup code runs before the user's
`enterShell` code.

## Verification

The nix-unit suite passes all 14 tests. The integration check executes a
declared script, verifies package priority and setup order, and inspects both
the shell input closure and runtime closure for `devenv-tasks`. The local
Linux checks pass. Flake evaluation passes for all four declared systems. Nix
formatting and `git diff --check` pass.

Three meat-review rounds covered the implementation, its documentation fixup,
and the consolidated commit. The final review of commit `900a635` ended with
`LGTM`. Review marker `4` points to the consolidated commit.

## Next tasks

Tasks `6f37-declared-files` and `9157-generated-git-hooks` are now eligible.
They can proceed independently against the evaluator and private setup hook.
