---
socrates_format: 2
id: 6d31-flake-parts-integration
status: approved
priority: 0
category: functional
assignee:
serves: [RC1, RC2, AC1, AC2]
deps: [6f37-declared-files, 9157-generated-git-hooks]
---

# Expose flake-parts shell integration

## Scope

This task provides the public flake interface used by nixDir and existing
consumers. It preserves `devenv.modules`, `devenv.shells`, and `flakeModule`.
A renamed top-level namespace is rejected because nixDir already emits the
devenv namespace and checks for that input name. Public `mkEval` and `mkShell`
helpers remain outside v1 because repository research found no consumer.

## Outcome

- Consumers import one flake-parts module and define named shells through the
  existing devenv-shaped namespace.
- Shared modules apply to every declared shell.
- Each shell becomes the corresponding per-system `devShells` output.
- The standalone flake can replace a consumer's `devenv` input URL.
- Representative upstream modules evaluate when their complete option use fits
  the v1 boundary.
- Production consumers carry no cachix/devenv input or lock node.

## Verification

- A flake-parts fixture defines default and named shells and observes both
  `devShells` outputs.
- A shared module contributes one package to every shell.
- A nixDir fixture discovers a shell and reusable module without changing its
  directory layout.
- A representative pinned upstream module that uses only v1 options evaluates
  through the public integration.
- The production lock and input graph contain no cachix/devenv node.

<review></review>
