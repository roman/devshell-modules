---
title: Standalone flake foundation handoff
created: 2026-08-29
project: devshell-modules
spec: 2026-08-28-devenv-lite
---

# Standalone flake foundation handoff

## Completed work

Task `be44-standalone-foundation` is closed. Commit `2a48149` adds a standalone
flake with checks for every system from `nix-systems/default`. The lock graph
contains only Nixpkgs and the systems list. Test-only dependencies do not appear
as flake inputs.

The nix-unit runner lives under `nix/tests/`. It uses the nix-unit package from
the primary Nixpkgs input and gives nix-unit an isolated local store. The
devenv fixture uses `builtins.fetchTree` during flake evaluation, outside the
lock graph. Its commit matches the upstream revision inspected by the spec.
The fixture test asserts devenv version `2.2.3` from the workspace
`Cargo.toml`.

## Verification

`nix flake check path:/home/roman/Projects/self/devshell-modules --all-systems`
evaluated the check on all four declared systems and passed the local Linux
build. Nix formatting and `git diff --check` passed.

Two meat-review rounds covered the implementation and its fixup. The second
round ended with `LGTM`. The commits were consolidated and the newest review
marker was moved to `2a48149`. The operator declined the optional final review
of the consolidated commit.

## Next task

Task `887e-strict-shell-modules` is now eligible. It adds the strict module
schema and shell evaluation that later file and Git-hook adapters extend.
