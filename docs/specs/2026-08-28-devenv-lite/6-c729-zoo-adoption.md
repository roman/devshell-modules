---
socrates_format: 2
id: c729-zoo-adoption
status: approved
priority: 0
category: functional
assignee:
serves: [RC1, RC2, AC1, AC2]
deps: [6d31-flake-parts-integration]
---

# Adopt devenv-lite in zoo.nix

## Scope

This task changes the zoo.nix consumer after the standalone contract is stable.
It preserves the current nixDir directories and reusable module shapes. The
existing devenv input is replaced under the same input name because nixDir uses
that name as its provider boundary.

## Outcome

- Zoo.nix obtains its development shells from the standalone lite flake.
- The current package and Git-hook module evaluates without source changes.
- The obsolete container workaround and upstream devenv lock graph are absent.
- Normal development-shell entry installs the existing hooks without the Rust
  task runner.

## Verification

- The default shell contains `just`, `smart-rebuild`, `nil`, and the configured
  Git-hook packages.
- Entering the default shell installs both configured hooks in a temporary Git
  worktree.
- The default shell closure excludes `devenv-tasks` and its Rust build inputs.
- The zoo.nix build and flake checks pass after the provider swap.

<review></review>
