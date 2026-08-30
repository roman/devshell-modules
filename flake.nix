{
  description = "Lightweight development shell modules";

  inputs = {
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
          nix-unit = import ./nix/tests {
            inherit pkgs;
            gitHooksSource = inputs.git-hooks;
          };
        }
      );
    };
}
