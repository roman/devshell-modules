{
  evaluator,
  gitHooksSource,
}:

{
  flake-parts-lib,
  inputs,
  ...
}:

{
  _file = __curPos.file;
  key = __curPos.file;

  options.perSystem = flake-parts-lib.mkPerSystemOption (
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      inherit (lib) mkOption types;
    in
    {
      options.devenv = {
        modules = mkOption {
          type = types.listOf types.deferredModule;
          default = [ ];
          description = "Modules shared by every development shell.";
        };

        shells = mkOption {
          type = types.lazyAttrsOf types.deferredModule;
          default = { };
          description = "Named development shell modules.";
        };
      };

      config.devShells = lib.mapAttrs (
        _name: shellModule:
        (evaluator
          {
            inherit pkgs;
            inputs = inputs // {
              git-hooks = gitHooksSource;
            };
          }
          {
            modules = config.devenv.modules ++ [ shellModule ];
          }
        ).shell
      ) config.devenv.shells;
    }
  );
}
