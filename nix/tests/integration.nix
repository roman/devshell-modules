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
  derivationClosure = pkgs.closureInfo { rootPaths = [ result.shell.inputDerivation ]; };
  runtimeClosure = pkgs.closureInfo { rootPaths = [ result.shell ]; };
in
pkgs.runCommand "strict-shell-integration"
  {
    nativeBuildInputs = result.shell.nativeBuildInputs;
    testedShellHook = result.shell.shellHook;
  }
  ''
    hello argument > script-output
    grep -E '^script-environment:argument:jq-' script-output

    export TMPDIR="$PWD/runtime"
    mkdir -p "$TMPDIR"
    eval "$testedShellHook"
    diff -u <(printf 'setup\nentry\n') "$TMPDIR/setup-order"

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
