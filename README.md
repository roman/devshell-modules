# devshell-modules

Devenv's flake integration includes its Rust task runner even when a project
defines no tasks. A cache miss can therefore make development shell setup
evaluate another Nixpkgs instance and build the task runner from source.

`devshell-modules` builds lightweight Nix development shells from a focused
subset of the [devenv](https://devenv.sh/) module interface. It keeps common
shell features without adding devenv's task runner to the shell closure.

## Features

- Composable Nix modules for development shells
- Packages, environment variables, overlays, and shell entry code
- Executable scripts with their own packages and environment variables
- Generated JSON, INI, TOML, YAML, text, and source-linked files
- Git hooks powered by [`git-hooks.nix`](https://github.com/cachix/git-hooks.nix)
- A flake-parts module with shared and named shell modules
- Strict evaluation that rejects unsupported devenv options

This project intentionally excludes tasks, processes, services, containers,
profiles, runtime coordination, and secret providers.

## Usage with flake-parts

Add the project as a flake input and import its module:

```nix
{
  inputs = {
    devshell-modules.url = "github:roman/devshell-modules";
    flake-parts.url = "github:hercules-ci/flake-parts";
    nixpkgs.url = "github:NixOS/nixpkgs/release-25.11";
  };

  outputs = inputs@{ flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      imports = [ inputs.devshell-modules.flakeModule ];
      systems = [ "x86_64-linux" "aarch64-linux" ];

      perSystem = { pkgs, ... }: {
        devenv = {
          modules = [
            {
              packages = [ pkgs.git ];
              env.PROJECT_ENV = "development";
            }
          ];

          shells.default = {
            packages = [ pkgs.jq ];

            scripts.hello.exec = ''
              echo "Hello from the development shell"
            '';

            files."generated/settings.json".json = {
              enabled = true;
            };

            enterShell = ''
              echo "Development shell ready"
            '';
          };
        };
      };
    };
}
```

Enter the default shell with:

```console
nix develop
```

Each attribute under `devenv.shells` becomes an attribute under `devShells`.
For example, enter `devenv.shells.worker` with `nix develop .#worker`.
Modules in `devenv.modules` apply to every named shell.

## Development

Run the full test suite with:

```console
nix flake check
```

The checks cover module evaluation, shell behavior, declared files, generated
Git hooks, and flake-parts integration.

## License

This project is available under the [MIT License](LICENSE).
