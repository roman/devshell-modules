{
  inputs ? { },
  pkgs,
}:

{
  modules,
}:

let
  inherit (pkgs) lib;

  # The final package set depends on module-defined overlays. Recursively add
  # context because an overlay can defer its dependency through nested sets.
  overlayDiagnostic = ''
    while applying overlays; overlay declarations cannot depend on the final module pkgs argument
  '';
  addOverlayDiagnostic =
    value:
    builtins.addErrorContext overlayDiagnostic (
      if builtins.isAttrs value && !lib.isDerivation value then
        lib.mapAttrs (_name: addOverlayDiagnostic) value
      else
        value
    );

  # One module fixpoint merges the declarations and supplies its overlaid
  # package set back to module functions through the standard module argument.
  evaluation = lib.evalModules {
    specialArgs = { inherit inputs; };
    modules = [
      ./options.nix
      ./scripts.nix
      ./files.nix
      {
        _module.args.pkgs = pkgsWithOverlays;
      }
    ]
    ++ modules;
  };

  rawPkgsWithOverlays = pkgs.appendOverlays evaluation.config.overlays;
  pkgsWithOverlays = addOverlayDiagnostic rawPkgsWithOverlays;

  # mkShell uses these names for structure, so accepting them as environment
  # variables would silently discard the caller's declared values.
  reservedEnvironmentNames = [
    "inputsFrom"
    "name"
    "packages"
    "shellHook"
  ];
  environmentAssertions = map (variableName: {
    assertion = !builtins.hasAttr variableName evaluation.config.env;
    message = "environment variable `${variableName}` conflicts with shell construction";
  }) reservedEnvironmentNames;
  failedAssertions = builtins.filter (item: !item.assertion) (
    evaluation.config.assertions ++ environmentAssertions
  );
  assertionMessages = map (item: item.message) failedAssertions;

  # Force assertion and warning handling before any shell field is consumed.
  checkedConfig =
    if failedAssertions == [ ] then
      lib.showWarnings evaluation.config.warnings evaluation.config
    else
      throw ''
        Failed assertions:
        ${lib.concatMapStringsSep "\n" (message: "- ${message}") assertionMessages}
      '';

  # Preserve package priority when mkShell builds PATH. Script packages use a
  # high priority so a declared script wins over a package with the same name.
  makeShell = pkgsWithOverlays.mkShell.override { stdenv = checkedConfig.stdenv; };
  sortedPackages = lib.sortOn (
    package: package.meta.priority or lib.meta.defaultPriority
  ) checkedConfig.packages;

  # Internal adapters contribute setup before the user's entry hook without a
  # runtime phase runner.
  shellHook = ''
    ${checkedConfig._internal.shellSetup}
    ${checkedConfig.enterShell}
  '';

  shell = makeShell (
    checkedConfig.env
    // lib.optionalAttrs (checkedConfig.name != null) { inherit (checkedConfig) name; }
    // {
      inherit (checkedConfig) inputsFrom;
      packages = sortedPackages;
      inherit shellHook;
    }
  );
in
evaluation
// {
  config = checkedConfig;
  inherit shell shellHook;
}
