{ pkgs }:

let
  # This check exercises runtime behavior that evaluation-only tests cannot:
  # script execution, setup ordering, and the resulting shell closures.
  evaluate = import ../lib {
    inherit pkgs;
    inputs = { };
  };
  result = evaluate {
    modules = [
      {
        files = {
          "--help".text = "option-like path\n";
          "generated/text.txt".text = "generated text\n";
          "generated/data.json".json = {
            enabled = true;
            name = "format-generated";
          };
          "generated/data.ini".ini.section.enabled = true;
          "generated/data.toml".toml.section.enabled = true;
          "generated/data.yaml".yaml.enabled = true;
          "generated/source.txt".source = pkgs.writeText "declared-source" "source content\n";
        };
        packages = [ pkgs.hello ];
        scripts.hello = {
          exec = ''
            printf '%s:%s:%s\n' "$SCRIPT_MARKER" "$1" "$(jq --version)"
          '';
          env.SCRIPT_MARKER = "script-environment";
          packages = [ pkgs.jq ];
        };

        _internal.shellSetup = ''
          printf 'setup\n' > "$TMPDIR/setup-order"
        '';
        enterShell = ''
          test "$(cat "$TMPDIR/setup-order")" = setup
          printf 'entry\n' >> "$TMPDIR/setup-order"
        '';
      }
    ];
  };
  updatedResult = evaluate {
    modules = [
      {
        files."generated/text.txt".text = "updated text\n";
      }
    ];
  };
  derivationClosure = pkgs.closureInfo { rootPaths = [ result.shell.inputDerivation ]; };
  runtimeClosure = pkgs.closureInfo { rootPaths = [ result.shell ]; };
in
pkgs.runCommand "strict-shell-integration"
  {
    nativeBuildInputs = result.shell.nativeBuildInputs;
    testedShellHook = result.shell.shellHook;
    testedUpdatedShellHook = updatedResult.shell.shellHook;
    unmanagedStoreTarget = pkgs.writeText "unmanaged-store-target" "unmanaged\n";
  }
  ''
    run_shell_hook() {
      eval "$testedShellHook"
    }

    # Verify package scripts and each supported generated-file shape.
    hello argument > script-output
    grep -E '^script-environment:argument:jq-' script-output

    export TMPDIR="$PWD/runtime"
    mkdir -p "$TMPDIR"
    run_shell_hook
    diff -u <(printf 'setup\nentry\n') "$TMPDIR/setup-order"
    diff -u <(printf 'generated text\n') generated/text.txt
    diff -u <(printf 'option-like path\n') ./--help
    grep -F '"enabled": true' generated/data.json
    grep -F '[section]' generated/data.ini
    grep -F 'enabled=true' generated/data.ini
    grep -F '[section]' generated/data.toml
    grep -F 'enabled = true' generated/data.toml
    grep -F 'enabled: true' generated/data.yaml
    diff -u <(printf 'source content\n') generated/source.txt

    # Re-entry preserves an unchanged link and replaces a changed managed link.
    first_text_target=$(readlink generated/text.txt)
    run_shell_hook
    test "$(readlink generated/text.txt)" = "$first_text_target"
    testedShellHook="$testedUpdatedShellHook" run_shell_hook
    test "$(readlink generated/text.txt)" != "$first_text_target"
    diff -u <(printf 'updated text\n') generated/text.txt

    # One preflight reports every collision before any declared path changes.
    mkdir collision-project
    cd collision-project
    mkdir -p generated
    printf 'preserve regular file\n' > generated/text.txt
    ln -s "$PWD/unmanaged-target" generated/data.json
    ln -s "$unmanagedStoreTarget" generated/source.txt
    if run_shell_hook 2> collision-error; then
      echo "file collision fixture unexpectedly succeeded" >&2
      exit 1
    fi
    grep -F 'declared file collision: generated/text.txt' collision-error
    grep -F 'declared file collision: generated/data.json' collision-error
    grep -F 'declared file collision: generated/source.txt' collision-error
    diff -u <(printf 'preserve regular file\n') generated/text.txt
    test "$(readlink generated/data.json)" = "$PWD/unmanaged-target"
    test "$(readlink generated/source.txt)" = "$unmanagedStoreTarget"
    cd ..

    # DEVENV_ROOT anchors declarations when shell entry starts in a subdirectory.
    mkdir -p nested-project/subdirectory
    nested_project_root="$PWD/nested-project"
    cd nested-project/subdirectory
    DEVENV_ROOT="$nested_project_root/" run_shell_hook
    test -L ../generated/text.txt
    test ! -e generated/text.txt
    cd ../..

    # Neither shell closure can retain the excluded task runner.
    if grep -F devenv-tasks ${derivationClosure}/store-paths; then
      echo "the shell derivation closure contains devenv-tasks" >&2
      exit 1
    fi
    if grep -F devenv-tasks ${runtimeClosure}/store-paths; then
      echo "the shell runtime closure contains devenv-tasks" >&2
      exit 1
    fi

    touch "$out"
  ''
