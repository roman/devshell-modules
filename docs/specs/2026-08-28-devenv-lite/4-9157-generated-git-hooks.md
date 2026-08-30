---
socrates_format: 2
id: 9157-generated-git-hooks
status: approved
priority: 1
category: functional
assignee:
serves: [RC1, AC1]
deps: [887e-strict-shell-modules]
---

# Install generated Git hooks

## Scope

This task embeds the independent `git-hooks.nix` module and exposes the devenv
`git-hooks` option shape. The adapter owns its immutable generated configuration
and contributes installation directly to private shell setup. It remains
independent from generic files because hook configuration has its own lifecycle.
A direct adapter is used instead of porting devenv's task declarations (see
[NC2](_overview.md#nc2)).
The supported namespace is the option surface declared by the pinned
`git-hooks.nix` module, plus devenv's auto-enable behavior and an adapter-owned
force-install option. Force installation removes any file or symlink at the
configured config path before installation. Devenv task names, task ordering
fields, and test orchestration remain excluded.

## Outcome

- Modules configure Git hooks through the supported `git-hooks` namespace.
- The selected hook runner and enabled hook packages enter the shell closure.
- Shell entry makes the generated configuration available before installing
  hooks.
- Modules can force shell entry to replace any existing config path and
  reinstall the configured hooks.
- The flake exposes the generated all-files check for CI consumers.

## Verification

- A temporary Git repository receives the configured hook after shell entry.
- The installed hook runs the configured command against a staged failing
  fixture and rejects the commit.
- A project outside a Git repository reports the skipped installation and
  enters the shell successfully.
- Force installation replaces an existing configuration and reinstalls the
  configured hooks. The default preserves the existing configuration.
- The all-files check produces a failing result for the same failing fixture.
- The shell derivation references and runtime closure contain no
  `devenv-tasks` path.

<review></review>
