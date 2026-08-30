{
  flakeModule,
  flakeParts,
  gitHooksSource,
  pkgs,
  projectSource,
}:

let
  devenvSource = builtins.fetchTree {
    type = "github";
    owner = "cachix";
    repo = "devenv";
    rev = "eeced8155ca9d573f5f3e22cbe925e7fbe4e761b";
    narHash = "sha256-2vxVcc2CO7ihRRqg1OuqsVnOAoQ+kaRu7829hN44xLs=";
  };
  nixDirSource = builtins.fetchTree {
    type = "github";
    owner = "roman";
    repo = "nixDir";
    rev = "374c01219df47f70da75edab64854da1ae6b41e4";
    narHash = "sha256-yVHFDbf2mUhrtnhF9BX7KKm70PqJ3P5oHsInbkhhOK8=";
  };
  nixDirModule = import "${nixDirSource}/default.nix" nixDirSource;
  fixture =
    flakeParts.lib.mkFlake
      {
        inputs = {
          git-hooks = gitHooksSource;
          self = projectSource;
        };
      }
      {
        imports = [ flakeModule ];
        systems = [ pkgs.stdenv.hostPlatform.system ];

        perSystem =
          { pkgs, ... }:
          {
            devenv = {
              modules = [ { packages = [ pkgs.hello ]; } ];
              shells = {
                default = {
                  packages = [ pkgs.jq ];
                };
                upstream = {
                  imports = [ "${devenvSource}/src/modules/languages/cue.nix" ];
                  languages.cue = {
                    enable = true;
                    lsp.enable = false;
                  };
                };
                worker = {
                  packages = [ pkgs.git ];
                };
              };
            };
          };
      };
  nixDirFixture =
    flakeParts.lib.mkFlake
      {
        inputs = {
          devenv = projectSource;
          self = projectSource;
        };
      }
      {
        imports = [
          flakeModule
          flakeModule
          nixDirModule
        ];
        systems = [ pkgs.stdenv.hostPlatform.system ];
        nixDir = {
          enable = true;
          root = ./fixtures/nixdir;
          installDevenvModules = modules: [ modules.shared ];
        };
      };

  system = pkgs.stdenv.hostPlatform.system;
  packageNames =
    shell: builtins.sort builtins.lessThan (map (package: package.pname) shell.nativeBuildInputs);
  defaultPackageNames = packageNames fixture.devShells.${system}.default;
  nixDirPackageNames = packageNames nixDirFixture.devShells.${system}.default;
  upstreamPackageNames = packageNames fixture.devShells.${system}.upstream;
  workerPackageNames = packageNames fixture.devShells.${system}.worker;
in
assert
  defaultPackageNames == [
    "hello"
    "jq"
  ];
assert
  workerPackageNames == [
    "git"
    "hello"
  ];
assert
  nixDirPackageNames == [
    "hello"
    "jq"
  ];
assert
  upstreamPackageNames == [
    "cue"
    "hello"
  ];
assert builtins.match ".*\"devenv\".*" (builtins.readFile ../../flake.lock) == null;
pkgs.runCommand "flake-parts-integration-test" { } ''
  test -n ${fixture.devShells.${system}.default.drvPath}
  test -n ${fixture.devShells.${system}.upstream.drvPath}
  test -n ${fixture.devShells.${system}.worker.drvPath}
  test -n ${nixDirFixture.devShells.${system}.default.drvPath}

  touch "$out"
''
