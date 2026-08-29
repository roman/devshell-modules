{ pkgs }:

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
    import ${./suite.nix} { devenvSource = ${devenvSource}; }
  '';
in
pkgs.runCommand "nix-unit-check" { nativeBuildInputs = [ pkgs.nix-unit ]; } ''
  export HOME="$(realpath .)"
  unset NIX_STORE
  export NIX_STORE_DIR=${builtins.storeDir}
  export NIX_REMOTE="$HOME/storedata"
  nix-unit \
    --show-trace \
    ${testExpression}
  touch $out
''
