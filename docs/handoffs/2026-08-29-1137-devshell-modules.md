---
title: Devshell Modules planning handoff
created: 2026-08-29
project: devshell-modules
spec: 2026-08-28-devenv-lite
---

# Devshell Modules planning handoff

## Current state

The repository exists at `/home/roman/Projects/self/devshell-modules`. Its
`master` branch contains one empty commit, `0ada942`, with the message
`chore: initialize repository`. The `docs/` directory is untracked. No flake or
implementation files exist.

The complete spec lives under `docs/specs/2026-08-28-devenv-lite/`. All six task
contracts are approved. A code-critic and grug-architect council reviewed the
plan. Fresh workers then passed the Socrates comprehension checks after two
clarifications.

## Decisions

- The project name is `devshell-modules`.
- The project is a standalone flake intended for Nix flakes and nixDir.
- Version 1 supports core shell options, scripts, safe generated-file links,
  and Git hooks.
- Version 1 excludes dedicated language, Python, treefmt, task, process,
  service, container, profile, and secret-provider adapters.
- The evaluator uses `lib.evalModules` with a strict declared root schema.
- The public interface contains `flakeModule`, `devenv.modules`, and
  `devenv.shells`. It excludes public `mkEval` and `mkShell` helpers.
- Devenv is absent from production inputs. Nix-unit fetches a pinned upstream
  source tree only for adapter-owned compatibility tests.
- Project-root discovery happens during shell entry. Pure flake evaluation does
  not read `PWD`.
- Git-hook configuration has a private lifecycle and does not depend on generic
  files.
- File support creates safe project-relative links to immutable sources. It
  excludes seed mode, copy mode, orphan cleanup, and ownership databases.

## Next step

Start the Socrates task workflow for
`be44-standalone-foundation`. Reconstruct the directive hierarchy from the
overview before planning implementation. Task 1 creates the flake foundation
and test harness. Use an explicit `path:` reference while foundation files are
uncommitted.

The operator controls repository history. Do not create another commit without
an explicit request.

## Relevant evidence

The upstream source review used cachix/devenv revision
`eeced8155ca9d573f5f3e22cbe925e7fbe4e761b`. Devenv's task module and flake
compatibility module both retain `devenv-tasks`. Its task package evaluates a
separate Nixpkgs and Rust package graph.

Zoo.nix currently imports `inputs.devenv.flakeModule`. NixDir emits discovered
configuration through `devenv.modules` and `devenv.shells`, and checks for the
input name `devenv`. The final adoption task replaces the provider under that
same input name.
