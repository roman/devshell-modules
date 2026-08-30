{
  description = "Lightweight development shell modules";

  inputs = {
    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };
    git-hooks = {
      url = "github:cachix/git-hooks.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixpkgs.url = "github:NixOS/nixpkgs/release-25.11";
    systems.url = "github:nix-systems/default";
  };

  outputs =
    inputs:
    let
      eachSystem = inputs.nixpkgs.lib.genAttrs (import inputs.systems);
    in
    {
      flakeModule = import ./nix/flake-module.nix {
        evaluator = import ./nix/lib;
        gitHooksSource = inputs.git-hooks;
      };

      checks = eachSystem (
        system:
        let
          pkgs = inputs.nixpkgs.legacyPackages.${system};
        in
        {
          integration = import ./nix/tests/integration.nix {
            inherit pkgs;
            gitHooksSource = inputs.git-hooks;
          };
          flake-parts = import ./nix/tests/flake-parts.nix {
            inherit pkgs;
            flakeModule = inputs.self.flakeModule;
            flakeParts = inputs.flake-parts;
            gitHooksSource = inputs.git-hooks;
            projectSource = inputs.self;
          };
          nix-unit = import ./nix/tests {
            inherit pkgs;
            gitHooksSource = inputs.git-hooks;
          };
        }
      );
    };
}
