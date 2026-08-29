---
socrates_format: 2
id: be44-standalone-foundation
status: approved
priority: 0
category: infrastructure
assignee:
serves: [RC2, AC1, AC2]
deps: []
---

# Provide a standalone flake foundation

## Scope

This task creates the standalone repository, flake outputs, and nix-unit test
foundation described in the [chosen approach](_overview.md#chosen-approach).
The upstream devenv source is a pinned test-local fetch instead of a flake
input, because a flake input would add production lock-file state. The task
starts from one empty initialization commit. The operator controls later
repository history during implementation. Evaluation uses an explicit `path:`
flake reference while the foundation files remain uncommitted; Git-backed
discovery is outside this task.

## Outcome

- The standalone repository evaluates on every declared system.
- The flake exposes a test check for later contract tasks.
- Tests can read a pinned devenv source tree without loading its flake inputs.
- The complete spec directory is present under the new repository's
  `docs/specs/` directory.
- The repository starts with one empty initialization commit.

## Verification

- The standalone repository exposes the expected outputs through an explicit
  `path:` flake reference on every declared system.
- The test check reads a known file from the pinned devenv revision.
- The flake lock contains no cachix/devenv node or transitive devenv inputs.
- The new repository contains the overview and all six task files under
  `docs/specs/2026-08-28-devenv-lite/`.
- The first commit has the message `chore: initialize repository` and an empty
  tree.

<review></review>
