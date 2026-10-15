{
  gitHooksSource,
  pkgs,
}:

let
  # This check exercises runtime behavior that evaluation-only tests cannot:
  # script execution, setup ordering, and the resulting shell closures.
  evaluate = import ../lib {
    inherit pkgs;
    inputs = {
      git-hooks = gitHooksSource;
      self = ../..;
    };
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
  failingHook = pkgs.writeShellScript "reject-forbidden-fixture" ''
    for fixture_path in "$@"; do
      if grep -q forbidden "$fixture_path"; then
        echo "forbidden fixture: $fixture_path" >&2
        exit 1
      fi
    done
  '';
  hookModule = {
    git-hooks = {
      addGcRoot = false;
      hooks.reject-forbidden = {
        enable = true;
        entry = toString failingHook;
        files = "\\.fixture$";
      };
      rootSrc = ./fixtures/git-hooks;
    };
  };
  hookResult = evaluate {
    modules = [ hookModule ];
  };
  forcedHookResult = evaluate {
    modules = [
      hookModule
      {
        git-hooks.install.force = true;
      }
    ];
  };
  worktreeHookResult = evaluate {
    modules = [
      hookModule
      {
        git-hooks.hooks.reject-forbidden.entry = pkgs.lib.mkForce (
          toString (pkgs.writeShellScript "accept-worktree-fixture" ''
            printf 'worktree hook ran\n' > worktree-hook-marker
          '')
        );
      }
    ];
  };
  derivationClosure = pkgs.closureInfo {
    rootPaths = [
      result.shell.inputDerivation
      hookResult.shell.inputDerivation
    ];
  };
  runtimeClosure = pkgs.closureInfo {
    rootPaths = [
      result.shell
      hookResult.shell
    ];
  };
in
pkgs.runCommand "strict-shell-integration"
  {
    nativeBuildInputs = [
      pkgs.git
    ]
    ++ result.shell.nativeBuildInputs
    ++ hookResult.shell.nativeBuildInputs;
    hookConfig = hookResult.config.git-hooks.configFile;
    hookFixture = ./fixtures/git-hooks/failing.fixture;
    testedHookShellHook = hookResult.shell.shellHook;
    testedForcedHookShellHook = forcedHookResult.shell.shellHook;
    testedWorktreeHookShellHook = worktreeHookResult.shell.shellHook;
    testedShellHook = result.shell.shellHook;
    testedUpdatedShellHook = updatedResult.shell.shellHook;
    unmanagedStoreTarget = pkgs.writeText "unmanaged-store-target" "unmanaged\n";
  }
  ''
    run_shell_hook() {
      eval "$testedShellHook"
    }

    run_hook_shell_hook() {
      eval "$testedHookShellHook"
    }

    run_forced_hook_shell_hook() {
      eval "$testedForcedHookShellHook"
    }

    # Verify package scripts and each supported generated-file shape.
    hello argument > script-output
    grep -E '^script-environment:argument:jq-' script-output

    export TMPDIR="$PWD/runtime"
    mkdir -p "$TMPDIR"
    export HOME="$TMPDIR/home"
    mkdir -p "$HOME"
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

    # Shell entry installs the generated hook and rejects the staged fixture.
    mkdir hook-project
    cd hook-project
    git init -q
    git config user.email fixture@example.com
    git config user.name Fixture
    cp "$hookFixture" failing.fixture
    git add failing.fixture
    run_hook_shell_hook
    if [ ! -L .pre-commit-config.yaml ]; then
      echo "generated hook configuration is not a symlink" >&2
      exit 1
    fi
    if [ ! -x .git/hooks/pre-commit ]; then
      echo "installed pre-commit hook is not executable" >&2
      exit 1
    fi
    sed -i '1c#!${pkgs.bash}/bin/bash' .git/hooks/pre-commit
    if git commit -m fixture > commit-output 2>&1; then
      echo "failing hook fixture unexpectedly committed" >&2
      exit 1
    fi
    if ! grep -F 'forbidden fixture: failing.fixture' commit-output; then
      sed -n '1,160p' commit-output >&2
      exit 1
    fi
    cd ..

    # Force installation replaces an existing config; the default preserves it.
    mkdir force-project
    cd force-project
    git init -q
    printf 'existing config\n' > .pre-commit-config.yaml
    run_hook_shell_hook 2> preserve-warning
    diff -u <(printf 'existing config\n') .pre-commit-config.yaml
    test ! -e .git/hooks/pre-commit
    grep -F 'Refusing to install because of an existing config' preserve-warning
    run_forced_hook_shell_hook
    test -L .pre-commit-config.yaml
    test -x .git/hooks/pre-commit
    printf 'stale hook\n' > .git/hooks/pre-commit
    run_forced_hook_shell_hook
    test -x .git/hooks/pre-commit
    if grep -F 'stale hook' .git/hooks/pre-commit; then
      echo "force installation preserved the stale hook" >&2
      exit 1
    fi
    cd ..

    # Linked worktrees must preserve the hooks used by the main checkout.
    mkdir worktree-project
    cd worktree-project
    git init -q
    git config user.email fixture@example.com
    git config user.name Fixture
    git commit --allow-empty -qm initial
    run_hook_shell_hook
    test -x .git/hooks/pre-commit
    sed -i '1c#!${pkgs.bash}/bin/bash' .git/hooks/pre-commit
    # Resolve shared hooks from either checkout despite the worktree's .git file.
    git config core.hooksPath "$PWD/.git/hooks"
    cp -a .git/hooks ../shared-hooks-before
    git worktree add -qb linked ../linked-project
    cd ../linked-project
    testedHookShellHook="$testedWorktreeHookShellHook" \
      run_hook_shell_hook > default-worktree-output 2>&1
    diff -ru ../shared-hooks-before ../worktree-project/.git/hooks
    cp "$hookFixture" failing.fixture
    git add failing.fixture
    if ! git commit -m 'worktree fixture' > worktree-commit-output 2>&1; then
      cat worktree-commit-output >&2
      exit 1
    fi
    diff -u <(printf 'worktree hook ran\n') worktree-hook-marker
    test -L .pre-commit-config.yaml
    diff -ru ../shared-hooks-before ../worktree-project/.git/hooks
    diff -u <(printf 'Linked worktree; skipping hook installation to preserve shared hooks.\n') \
      default-worktree-output
    rm .pre-commit-config.yaml
    printf 'worktree config\n' > .pre-commit-config.yaml
    mkdir subdirectory
    cd subdirectory
    run_forced_hook_shell_hook > ../forced-worktree-output 2>&1
    diff -ru ../../shared-hooks-before ../../worktree-project/.git/hooks
    diff -u <(printf 'worktree config\n') ../.pre-commit-config.yaml
    diff -u ../default-worktree-output ../forced-worktree-output
    cd ../..

    # The generated all-files configuration rejects the same fixture.
    mkdir all-files-project
    cd all-files-project
    git init -q
    cp "$hookFixture" failing.fixture
    git add failing.fixture
    if prek run --all-files --config "$hookConfig" > all-files-output 2>&1; then
      echo "all-files hook fixture unexpectedly passed" >&2
      exit 1
    fi
    if ! grep -F 'forbidden fixture: failing.fixture' all-files-output; then
      sed -n '1,160p' all-files-output >&2
      exit 1
    fi
    cd ..

    # Shell entry outside a Git repository reports the skipped installation.
    mkdir non-git-project
    cd non-git-project
    run_hook_shell_hook 2> hook-warning
    grep -F '.git not found; skipping installation.' hook-warning
    cd ..

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
