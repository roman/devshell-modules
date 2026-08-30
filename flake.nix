{
  description = "Lightweight development shell modules";

  inputs = {
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
          integration = import ./nix/tests/integration.nix { inherit pkgs; };
          nix-unit = import ./nix/tests { inherit pkgs; };
        }
      );
    };
}
