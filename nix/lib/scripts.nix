{
  config,
  lib,
  pkgs,
  ...
}:

let
  # Scripts become ordinary shell packages so mkShell can put them on PATH
  # without retaining devenv's task runner or runtime coordination model.
  scriptType = lib.types.submodule (
    { config, name, ... }:
    {
      options = {
        exec = lib.mkOption {
          type = lib.types.oneOf [
            lib.types.str
            lib.types.path
          ];
          description = "Shell code or a file executed by the named script.";
        };

        package = lib.mkOption {
          type = lib.types.package;
          default = pkgs.bash;
          defaultText = lib.literalExpression "pkgs.bash";
          description = "Package used to run the script.";
        };

        binary = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = "Program from the runner package used to execute the script.";
        };

        packages = lib.mkOption {
          type = lib.types.listOf lib.types.package;
          default = [ ];
          description = "Packages added to PATH while the script runs.";
        };

        env = lib.mkOption {
          type = lib.types.attrsOf lib.types.str;
          default = { };
          description = "Environment variables set while the script runs.";
        };

        scriptPackage = lib.mkOption {
          type = lib.types.package;
          internal = true;
          readOnly = true;
        };
      };

      config.scriptPackage =
        let
          runner =
            if config.binary == null then
              lib.getExe config.package
            else
              "${lib.getBin config.package}/bin/${config.binary}";
          scriptFile =
            if builtins.isPath config.exec then config.exec else pkgs.writeText "${name}-script" config.exec;
          environment = lib.concatStringsSep "\n" (
            lib.mapAttrsToList (
              variableName: value: "export ${variableName}=${lib.escapeShellArg value}"
            ) config.env
          );
        in
        lib.hiPrio (
          pkgs.writeShellScriptBin name ''
            ${lib.optionalString (config.packages != [ ]) ''
              export PATH=${lib.escapeShellArg (lib.makeBinPath config.packages)}:"$PATH"
            ''}
            ${environment}
            exec ${runner} ${lib.escapeShellArg scriptFile} "$@"
          ''
        );
    }
  );
in
{
  options.scripts = lib.mkOption {
    type = lib.types.attrsOf scriptType;
    default = { };
    description = "Named scripts available in the development shell.";
  };

  config.packages = lib.mapAttrsToList (_name: script: script.scriptPackage) config.scripts;
}
