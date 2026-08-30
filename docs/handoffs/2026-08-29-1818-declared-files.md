---
title: Declared files handoff
created: 2026-08-29
project: devshell-modules
spec: 2026-08-28-devenv-lite
---

# Declared files handoff

## Completed work

Task `6f37-declared-files` is closed. Commit `97266a2` adds the v1 file
adapter and its shell-entry integration. Modules can declare text, INI, JSON,
TOML, YAML, and source paths through the existing devenv option shapes.

Each declaration resolves to an immutable source. The adapter gives that
source a stable, path-specific store name. This name identifies links created
by devshell-modules without an ownership database. Re-entry keeps the same
target when the source is unchanged and updates the target after a change.

Shell entry resolves the project root from `DEVENV_ROOT`, with `PWD` as the
fallback for direct evaluator use. It normalizes every declared path and
rejects absolute paths, escapes, duplicate targets, and ancestor conflicts.
A preflight checks every destination and parent before link creation. Regular
files, unmanaged links, and unmanaged store links remain unchanged after a
collision.

Seed mode, copy mode, orphan cleanup, ownership databases, and concurrent
entry coordination remain outside v1.

## Verification

The nix-unit suite passes all 19 tests. The integration check builds every
supported content shape and verifies stable and updated targets across
re-entry. It also checks project-root handling, option-like paths, collision
preservation, and the absence of `devenv-tasks` from both shell closures.

The local Linux checks pass. Flake evaluation passes for all four declared
systems. Nix formatting and `git diff --check` pass.

Four meat-review rounds covered implementation, documentation, corrections,
and consolidation. The final review of commit `97266a2` ended with `LGTM`.
Review marker `9` points to the consolidated commit.

## Next tasks

Task `9157-generated-git-hooks` remains eligible against the strict evaluator
and private setup hook. Task `6d31-flake-parts-integration` now waits only for
the Git-hook adapter.
