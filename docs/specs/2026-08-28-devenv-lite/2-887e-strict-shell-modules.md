---
socrates_format: 2
id: 887e-strict-shell-modules
status: closed
priority: 0
category: functional
assignee:
serves: [RC1, RC2, AC1, AC2]
deps: [be44-standalone-foundation]
---

# Evaluate strict shell modules

## Scope

This task covers the evaluator, core shell options, scripts, and private shell
entry composition from the [v1 boundary](_overview.md#ac1). Files, Git hooks,
and flake-parts integration remain in later tasks. The evaluator uses declared
Nix options instead of a freeform compatibility namespace, because unknown
options must fail during evaluation.

The evaluator follows devenv's single-fixpoint pattern. It receives a base
package set, then assigns `_module.args.pkgs` to that package set with
`config.overlays` appended. Overlay declarations must remain independent of
the final `pkgs` module argument. A two-pass evaluation is rejected because it
would merge and validate modules twice.

`lib.evalModules` owns the standard `lib`, `config`, and module metadata
arguments. Devenv-lite supplies `pkgs` and canonical `inputs`. NixDir applies
an outer flake-input function before the returned module reaches this evaluator,
so `flakeInputs` is not a second evaluator argument.

Internal setup contributions run before user `enterShell` code through one
private ordered option. A public phase system and a general task graph are
rejected because v1 needs only setup-before-entry ordering. Scripts become
ordinary shell packages rather than task definitions.

## Outcome

- Modules merge `name`, `packages`, `inputsFrom`, `env`, `enterShell`,
  `stdenv`, `overlays`, assertions, and warnings through `lib.evalModules`.
- Module functions receive the standard `lib.evalModules` arguments plus
  devenv-lite's `pkgs` and canonical `inputs` arguments.
- The evaluated configuration produces a standard `pkgs.mkShell` derivation.
- Unsupported root options stop evaluation with their option path.
- Assertions stop evaluation with their declared message, and warnings remain
  visible to the caller.
- Overlays can extend the base package set, while overlay declarations that
  depend on the final module `pkgs` argument fail with a focused diagnostic.
- Named scripts support executable text, package dependencies, and environment
  variables, and appear on the shell's `PATH`.
- Internal setup actions run before user `enterShell` code without a runtime
  runner.
- The resulting shell has no derivation or runtime reference to
  `devenv-tasks`.

## Verification

- Two modules that contribute packages and environment variables produce one
  shell containing both contributions.
- A fixture reads a marker from canonical `inputs` and observes its configured
  shell name, custom stdenv, and `inputsFrom` contribution.
- A package supplied by an overlay resolves inside the same module fixpoint.
- An overlay declaration that reads the final `pkgs` argument fails with a
  focused recursion diagnostic in its negative fixture.
- A failed assertion prevents shell evaluation and reports its message.
- A declared warning remains visible while shell evaluation succeeds.
- Fixtures defining `tasks`, `processes`, `services`, `containers`, or profiles
  each fail and identify the unsupported option.
- A declared script receives arguments and can execute a tool from its package
  dependencies.
- A sentinel fixture records internal setup before user entry code.
- The shell derivation references and runtime closure contain no
  `devenv-tasks` path.

<review></review>
