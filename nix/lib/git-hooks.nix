{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:

let
  inherit (lib)
    mkBefore
    mkDefault
    mkIf
    mkOption
    mkOptionDefault
    types
    ;

  gitHooksSource =
    inputs.git-hooks or (throw "the git-hooks input is required when evaluating the git-hooks adapter");
  anyHookEnabled = builtins.any (hook: hook.enable or false) (
    builtins.attrValues (config.git-hooks.hooks or { })
  );
  gitHooksType = types.submoduleWith {
    modules = [
      (gitHooksSource + "/modules/all-modules.nix")
      {
        options.install.force = mkOption {
          type = types.bool;
          default = false;
          description = "Whether shell entry removes the existing config path and reinstalls hooks.";
        };
      }
      {
        rootSrc = mkDefault (inputs.self or ../..);
        package = mkDefault pkgs.prek;
        tools = lib.mapAttrs (_name: mkOptionDefault) (
          import (gitHooksSource + "/nix/call-tools.nix") pkgs
        );
      }
    ];
    specialArgs = { inherit pkgs; };
    shorthandOnlyDefinesConfig = true;
  };
  installationScript = ''
    if ${lib.getExe config.git-hooks.gitPackage} rev-parse --git-dir &> /dev/null \
      && [ "$(${lib.getExe config.git-hooks.gitPackage} rev-parse --git-dir)" \
        != "$(${lib.getExe config.git-hooks.gitPackage} rev-parse --git-common-dir)" ]; then
      echo 'Linked worktree; skipping hook installation to preserve shared hooks.'
    else
      ${lib.optionalString config.git-hooks.install.force ''
        if ${lib.boolToString config.git-hooks.install.enable} \
          && ${lib.getExe config.git-hooks.gitPackage} rev-parse --git-dir &> /dev/null; then
          git_root=$(${lib.getExe config.git-hooks.gitPackage} rev-parse --show-toplevel) || return 1
          rm -f -- "$git_root/${config.git-hooks.configPath}" || return 1
        fi
      ''}
      ${config.git-hooks.installationScript}
    fi
  '';
in
{
  options.git-hooks = mkOption {
    type = gitHooksType;
    default = { };
    description = "Git hooks generated through git-hooks.nix.";
  };

  config = {
    git-hooks.enable = mkDefault anyHookEnabled;

    packages = mkIf config.git-hooks.enable (
      [ config.git-hooks.package ] ++ config.git-hooks.enabledPackages
    );

    _internal.checks = mkIf config.git-hooks.enable {
      git-hooks = config.git-hooks.run;
    };

    _internal.shellSetup = mkBefore (lib.optionalString config.git-hooks.enable installationScript);
  };
}
