{
  gitHooksSource,
  pkgs,
}:

let
  devenvSource = builtins.fetchTree {
    type = "github";
    owner = "cachix";
    repo = "devenv";
    # Keep compatibility tests aligned with the upstream revision inspected by the spec.
    rev = "eeced8155ca9d573f5f3e22cbe925e7fbe4e761b";
    narHash = "sha256-2vxVcc2CO7ihRRqg1OuqsVnOAoQ+kaRu7829hN44xLs=";
  };
  testExpression = pkgs.writeText "devshell-modules-tests.nix" ''
    import ${./suite.nix} {
      pkgs = import ${pkgs.path} {
        system = ${builtins.toJSON pkgs.stdenv.hostPlatform.system};
      };
      devenvSource = ${devenvSource};
      evaluator = import ${../.}/lib;
      gitHooksSource = ${gitHooksSource};
      projectSource = ${../..};
    }
  '';
  overlayFailureExpression = pkgs.writeText "overlay-recursion.nix" ''
    let
      pkgs = import ${pkgs.path} {
        system = ${builtins.toJSON pkgs.stdenv.hostPlatform.system};
      };
      evaluate = import ${../.}/lib {
        inherit pkgs;
        inputs.git-hooks = ${gitHooksSource};
      };
      result = evaluate {
        modules = [
          ({ pkgs, ... }: {
            overlays = builtins.seq pkgs.stdenv [ (_final: _previous: { }) ];
          })
        ];
      };
    in
    result.shell.drvPath
  '';
  delayedOverlayFailureExpression = pkgs.writeText "delayed-overlay-recursion.nix" ''
    let
      pkgs = import ${pkgs.path} {
        system = ${builtins.toJSON pkgs.stdenv.hostPlatform.system};
      };
      evaluate = import ${../.}/lib {
        inherit pkgs;
        inputs.git-hooks = ${gitHooksSource};
      };
      result = evaluate {
        modules = [
          ({ pkgs, ... }: {
            overlays = [
              (_final: _previous: { captured = pkgs.captured; })
            ];
            packages = [ pkgs.captured ];
          })
        ];
      };
    in
    result.shell.drvPath
  '';
  nestedOverlayFailureExpression = pkgs.writeText "nested-overlay-recursion.nix" ''
    let
      pkgs = import ${pkgs.path} {
        system = ${builtins.toJSON pkgs.stdenv.hostPlatform.system};
      };
      evaluate = import ${../.}/lib {
        inherit pkgs;
        inputs.git-hooks = ${gitHooksSource};
      };
      result = evaluate {
        modules = [
          ({ pkgs, ... }: {
            overlays = [
              (_final: _previous: {
                group.captured = pkgs.group.captured;
              })
            ];
            packages = [ pkgs.group.captured ];
          })
        ];
      };
    in
    result.shell.drvPath
  '';
in
pkgs.runCommand "nix-unit-check"
  {
    nativeBuildInputs = [
      pkgs.nix
      pkgs.nix-unit
    ];
  }
  ''
    export HOME="$(realpath .)"
    unset NIX_STORE
    export NIX_STORE_DIR=${builtins.storeDir}
    export NIX_REMOTE="$HOME/storedata"
    nix-unit \
      --show-trace \
      ${testExpression}

    if nix-instantiate --eval --strict --show-trace ${overlayFailureExpression} 2> overlay-error; then
      echo "overlay recursion fixture unexpectedly succeeded" >&2
      exit 1
    fi
    if ! grep -F \
      "overlay declarations cannot depend on the final module pkgs argument" \
      overlay-error; then
      sed -n '1,200p' overlay-error >&2
      exit 1
    fi

    if nix-instantiate --eval --strict --show-trace ${nestedOverlayFailureExpression} \
      2> nested-overlay-error; then
      echo "nested overlay recursion fixture unexpectedly succeeded" >&2
      exit 1
    fi
    if ! grep -F \
      "overlay declarations cannot depend on the final module pkgs argument" \
      nested-overlay-error; then
      sed -n '1,200p' nested-overlay-error >&2
      exit 1
    fi

    if nix-instantiate --eval --strict --show-trace ${delayedOverlayFailureExpression} \
      2> delayed-overlay-error; then
      echo "delayed overlay recursion fixture unexpectedly succeeded" >&2
      exit 1
    fi
    if ! grep -F \
      "overlay declarations cannot depend on the final module pkgs argument" \
      delayed-overlay-error; then
      sed -n '1,200p' delayed-overlay-error >&2
      exit 1
    fi

    touch $out
  ''
