{ lib, pkgs, ... }:

let
  inherit (lib) mkOption types;
in
{
  options = {
    name = mkOption {
      type = types.nullOr types.str;
      default = "devenv-shell";
      description = "Name of the development shell.";
    };

    packages = mkOption {
      type = types.listOf types.package;
      default = [ ];
      description = "Packages available in the development shell.";
    };

    inputsFrom = mkOption {
      type = types.listOf types.package;
      default = [ ];
      description = "Derivations whose build inputs are added to the shell.";
    };

    env = mkOption {
      type = types.lazyAttrsOf types.anything;
      default = { };
      description = "Environment variables exposed inside the shell.";
    };

    enterShell = mkOption {
      type = types.lines;
      default = "";
      description = "Shell code run when the shell starts.";
    };

    stdenv = mkOption {
      type = types.package;
      default = pkgs.stdenv;
      defaultText = lib.literalExpression "pkgs.stdenv";
      description = "Standard environment used to construct the shell.";
    };

    overlays = mkOption {
      type = types.listOf (types.functionTo (types.functionTo types.attrs));
      default = [ ];
      description = "Overlays appended to the base package set.";
    };

    assertions = mkOption {
      type = types.listOf types.unspecified;
      default = [ ];
      internal = true;
      description = "Conditions that must hold before shell evaluation succeeds.";
    };

    warnings = mkOption {
      type = types.listOf types.str;
      default = [ ];
      internal = true;
      description = "Warnings reported during shell evaluation.";
    };

    _internal.shellSetup = mkOption {
      type = types.lines;
      default = "";
      internal = true;
      description = "Internal setup code run before user shell entry code.";
    };

    _internal.checks = mkOption {
      type = types.attrsOf types.package;
      default = { };
      internal = true;
      description = "Checks exposed to flake consumers.";
    };
  };
}
