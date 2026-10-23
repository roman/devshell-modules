{
  config,
  lib,
  pkgs,
  ...
}:

let
  inherit (lib) mkBefore mkOption types;

  # Preserve upstream option names so compatible modules can keep their file declarations.
  formats = {
    ini = pkgs.formats.ini { };
    json = pkgs.formats.json { };
    yaml = pkgs.formats.yaml { };
    toml = pkgs.formats.toml { };
    text = {
      type = types.str;
      generate = name: contents: pkgs.writeText name contents;
    };
    source = {
      type = types.path;
      generate = _name: path: path;
    };
  };

  fileModule =
    { name, config, ... }:
    let
      formatNames = builtins.attrNames formats;
      activeFormats = builtins.filter (formatName: config.${formatName} != null) formatNames;
      activeFormatCount = builtins.length activeFormats;
      activeFormatName =
        if activeFormatCount == 1 then
          builtins.head activeFormats
        else if activeFormatCount == 0 then
          throw "no contents specified for `files.${name}`"
        else
          throw "multiple content formats specified for `files.${name}`";
      selectedFormat = formats.${activeFormatName};
      generatedSource =
        selectedFormat.generate
          (lib.strings.sanitizeDerivationName "devenv-file-${builtins.baseNameOf name}")
          config.${activeFormatName};
      managedName = managedFileName (normalizePath name);
    in
    {
      options =
        builtins.mapAttrs (
          formatName: format:
          mkOption {
            type = types.nullOr format.type;
            default = null;
            description = "${formatName} contents.";
          }
        ) formats
        // {
          _source = mkOption {
            type = types.path;
            internal = true;
          };
        };

      # A stable store name provides ownership evidence without a state database.
      config._source = pkgs.runCommandLocal managedName { } ''
        ln -s -- ${lib.escapeShellArg "${generatedSource}"} "$out"
      '';
    };

  # Canonical paths make duplicate and ancestor checks independent of spelling.
  normalizePath =
    declaredPath:
    let
      segments = lib.splitString "/" declaredPath;
      normalizedSegments = builtins.foldl' (
        currentSegments: segment:
        if segment == "" || segment == "." then
          currentSegments
        else if segment == ".." then
          if currentSegments == [ ] then
            throw "declared file path `${declaredPath}` escapes the project root"
          else
            lib.init currentSegments
        else
          currentSegments ++ [ segment ]
      ) [ ] segments;
    in
    if lib.hasPrefix "/" declaredPath || normalizedSegments == [ ] then
      throw "declared file path `${declaredPath}` is not project-relative"
    else
      lib.concatStringsSep "/" normalizedSegments;

  managedFileName =
    normalizedPath: "devshell-modules-managed-${builtins.hashString "sha256" normalizedPath}";

  declaredFiles = lib.mapAttrsToList (declaredPath: file: {
    managedName = managedFileName (normalizePath declaredPath);
    normalizedPath = normalizePath declaredPath;
    source = file._source;
  }) config.files;

  filesByNormalizedPath = builtins.groupBy (file: file.normalizedPath) declaredFiles;
  duplicatePaths = builtins.attrNames (
    lib.filterAttrs (_path: files: builtins.length files > 1) filesByNormalizedPath
  );
  normalizedPaths = map (file: file.normalizedPath) declaredFiles;
  ancestorPaths = builtins.filter (
    path:
    builtins.any (otherPath: path != otherPath && lib.hasPrefix "${path}/" otherPath) normalizedPaths
  ) normalizedPaths;
  checkedFiles =
    if duplicatePaths != [ ] then
      throw "multiple file declarations target `${builtins.head duplicatePaths}`"
    else if ancestorPaths != [ ] then
      throw "file declarations overlap below `${builtins.head ancestorPaths}`"
    else
      declaredFiles;

  # Complete the collision pass before link creation to preserve every unmanaged path.
  collisionCheck = file: ''
    declared_path=${lib.escapeShellArg file.normalizedPath}
    absolute_path="$project_root/$declared_path"
    parent_path=$(dirname -- "$absolute_path")
    while [ "$parent_path" != "$project_root" ]; do
      if [ -L "$parent_path" ] || { [ -e "$parent_path" ] && [ ! -d "$parent_path" ]; }; then
        echo "declared file collision: $declared_path" >&2
        declared_file_collision=1
        break
      fi
      parent_path=$(dirname -- "$parent_path")
    done

    if [ -L "$absolute_path" ]; then
      case $(readlink -- "$absolute_path") in
        ${builtins.storeDir}/*-${file.managedName}) ;;
        *)
          echo "declared file collision: $declared_path" >&2
          declared_file_collision=1
          ;;
      esac
    elif [ -e "$absolute_path" ]; then
      echo "declared file collision: $declared_path" >&2
      declared_file_collision=1
    fi
  '';

  createLink = file: ''
    declared_path=${lib.escapeShellArg file.normalizedPath}
    absolute_path="$project_root/$declared_path"
    mkdir -p -- "$(dirname -- "$absolute_path")" || return 1
    ln -sfn -- ${lib.escapeShellArg (toString file.source)} "$absolute_path" || return 1
  '';

  setup = ''
    _devshell_modules_materialize_files() {
      local project_root
      # DEVENV_ROOT preserves the upstream entry contract; PWD supports direct evaluation.
      project_root=$(realpath -m -- "''${DEVENV_ROOT:-$PWD}") || return 1

      local absolute_path declared_path parent_path
      local declared_file_collision=0
      ${lib.concatMapStringsSep "\n" collisionCheck checkedFiles}
      if [ "$declared_file_collision" -ne 0 ]; then
        return 1
      fi

      ${lib.concatMapStringsSep "\n" createLink checkedFiles}
    }

    if ! _devshell_modules_materialize_files; then
      unset -f _devshell_modules_materialize_files
      return 1
    fi
    unset -f _devshell_modules_materialize_files
  '';
in
{
  options.files = mkOption {
    type = types.attrsOf (types.submodule fileModule);
    default = { };
    description = "Files linked into the project root during shell entry.";
  };

  config._internal.shellSetup = mkBefore (lib.optionalString (config.files != { }) setup);
}
