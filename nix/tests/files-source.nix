{
  pkgs,
  gitHooksSource,
}:

let
  evaluate = import ../lib {
    inherit pkgs;
    inputs.git-hooks = gitHooksSource;
  };
  # Model raw paths into a flake input without adding that input to the check.
  sourceTree =
    /.
    + builtins.unsafeDiscardStringContext (builtins.path {
      path = ./fixtures/files-source;
      name = "files-source-input";
    });
  result = evaluate {
    modules = [
      {
        files = {
          "file.txt".source = sourceTree + "/file.txt";
          "directory".source = sourceTree + "/directory";
        };
      }
    ];
  };
in
pkgs.runCommand "files-source-check"
  {
    testedShellHook = result.shell.shellHook;
  }
  ''
    eval "$testedShellHook"
    test -L file.txt
    cmp file.txt <(printf 'raw source content\n')
    test -L directory
    cmp directory/nested.txt <(printf 'directory source content\n')
    touch "$out"
  ''
