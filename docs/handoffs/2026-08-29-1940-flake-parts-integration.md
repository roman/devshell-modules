---
title: Flake-parts integration handoff
created: 2026-08-29
project: devshell-modules
spec: 2026-08-28-devenv-lite
---

# Flake-parts integration handoff

## Completed work

Task `6d31-flake-parts-integration` is closed. Commit `2fe0f7d` exposes the
standalone evaluator through a public flake-parts module. Consumers declare
shared modules and named shells through the existing per-system
`devenv.modules` and `devenv.shells` options. Each named shell becomes the
corresponding `devShells` output.

The bridge passes consumer inputs into shell modules and supplies the embedded
`git-hooks.nix` source. A stable module key makes repeated direct or transitive
imports safe. The production input graph adds flake-parts and contains no
devenv node.

The integration fixture covers direct consumers, shared modules, named shells,
nixDir v3 discovery, repeated imports, and a pinned upstream CUE language
module. The nixDir fixture keeps the existing directory layout and input name.

## Verification

The focused flake-parts check passes. The full `nix flake check path:.` passes
all three checks on x86_64 Linux. Nix reports the Darwin systems and aarch64
Linux as incompatible with the local builder.

Two code-critic rounds covered the implementation and the repeated-import
correction. The final round returned no findings. One meat-review round covered
the consolidated implementation commit. The review ended with `LGTM`. Review
marker `12` points to commit `2fe0f7d`. The operator closed the task without a
duplicate review of the unchanged commit.

## Next tasks

Task `c729-zoo-adoption` is now eligible. It can replace zoo.nix's `devenv`
input provider and remove the container-option workaround after confirming the
consumer lock graph contains no cachix/devenv node.
