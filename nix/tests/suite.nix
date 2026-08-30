{
  devenvSource,
  evaluator,
  pkgs,
}:

let
  evaluate = evaluator {
    inherit pkgs;
    inputs.marker = "canonical-input";
  };
  merged = evaluate {
    modules = [
      {
        env.FIRST = "one";
        packages = [ pkgs.hello ];
      }
      ({ inputs, ... }: {
        env = {
          INPUT_MARKER = inputs.marker;
          SECOND = "two";
        };
        name = "merged-shell";
        packages = [ pkgs.jq ];
      })
    ];
  };

  unsupportedOptionTest = optionName: {
    expr =
      (evaluate {
        modules = [
          (builtins.listToAttrs [
            {
              name = optionName;
              value = { };
            }
          ])
        ];
      }).config.name;
    expectedError.type = "ThrownError";
    expectedError.msg = "(.|\\n)*The option .${optionName}. does not exist(.|\\n)*";
  };
in
{
  "test reads the expected devenv version" = {
    expr = builtins.elem ''version = "2.2.3"'' (
      builtins.split "\n" (builtins.readFile "${devenvSource}/Cargo.toml")
    );
    expected = true;
  };

  "test modules merge shell values" = {
    expr = {
      inherit (merged.config) env name;
      packages = builtins.sort builtins.lessThan (map (package: package.pname) merged.config.packages);
    };
    expected = {
      env = {
        FIRST = "one";
        INPUT_MARKER = "canonical-input";
        SECOND = "two";
      };
      name = "merged-shell";
      packages = [
        "hello"
        "jq"
      ];
    };
  };

  "test evaluator returns an mkShell derivation" = {
    expr = merged.shell.drvPath != null;
    expected = true;
  };

  "test null shell name uses the mkShell default" = {
    expr =
      (evaluate {
        modules = [ { name = null; } ];
      }).shell.name;
    expected = "nix-shell";
  };

  "test rejects environment keys reserved by mkShell" = {
    expr =
      (evaluate {
        modules = [ { env.shellHook = "discarded"; } ];
      }).shell.drvPath;
    expectedError.type = "ThrownError";
    expectedError.msg = ".*environment variable `shellHook` conflicts with shell construction.*";
  };

  "test module can use a package supplied by its overlay" = {
    expr =
      let
        result = evaluate {
          modules = [
            ({ pkgs, ... }: {
              overlays = [
                (_final: previous: {
                  overlay-package = previous.hello.overrideAttrs (_old: {
                    pname = "overlay-package";
                  });
                })
              ];
              packages = [ pkgs.overlay-package ];
            })
          ];
        };
      in
      (builtins.head result.config.packages).pname;
    expected = "overlay-package";
  };

  "test shell configuration preserves inputsFrom and stdenv" = {
    expr =
      let
        inputShell = pkgs.mkShell { packages = [ pkgs.hello ]; };
        result = evaluate {
          modules = [
            {
              inputsFrom = [ inputShell ];
              name = "observed-shell";
              stdenv = pkgs.clangStdenv;
            }
          ];
        };
      in
      {
        inherit (result.shell) name;
        inputs = map (package: package.pname) result.shell.nativeBuildInputs;
        usesConfiguredStdenv = result.shell.stdenv.cc.outPath == pkgs.clangStdenv.cc.outPath;
      };
    expected = {
      inputs = [ "hello" ];
      name = "observed-shell";
      usesConfiguredStdenv = true;
    };
  };

  "test failed assertion reports its message" = {
    expr =
      (evaluate {
        modules = [
          {
            assertions = [
              {
                assertion = false;
                message = "required evaluator condition failed";
              }
            ];
          }
        ];
      }).shell.drvPath;
    expectedError.type = "ThrownError";
    expectedError.msg = ".*required evaluator condition failed.*";
  };

  "test warnings remain available to the caller" = {
    expr =
      (evaluate {
        modules = [ { warnings = [ "compatibility warning" ]; } ];
      }).config.warnings;
    expected = [ "compatibility warning" ];
  };

  "test rejects two file declarations for one normalized path" = {
    expr =
      (evaluate {
        modules = [
          {
            files = {
              "nested/../same.txt".text = "first";
              "same.txt".text = "second";
            };
          }
        ];
      }).shell.drvPath;
    expectedError.type = "ThrownError";
    expectedError.msg = ".*multiple file declarations target `same.txt`.*";
  };

  "test rejects file declarations with overlapping paths" = {
    expr =
      (evaluate {
        modules = [
          {
            files = {
              "target".text = "file";
              "target/child".text = "child";
            };
          }
        ];
      }).shell.drvPath;
    expectedError.type = "ThrownError";
    expectedError.msg = ".*file declarations overlap below `target`.*";
  };

  "test supports each declared file content shape" = {
    expr =
      let
        result = evaluate {
          modules = [
            {
              files = {
                "settings.ini".ini.section.enabled = true;
                "settings.json".json.enabled = true;
                "settings.toml".toml.section.enabled = true;
                "settings.yaml".yaml.enabled = true;
                "source.txt".source = pkgs.writeText "source-fixture" "source";
                "text.txt".text = "text";
              };
            }
          ];
        };
      in
      builtins.mapAttrs (_name: file: toString file._source != "") result.config.files;
    expected = {
      "settings.ini" = true;
      "settings.json" = true;
      "settings.toml" = true;
      "settings.yaml" = true;
      "source.txt" = true;
      "text.txt" = true;
    };
  };

  "test rejects file copy modes outside version one" = {
    expr =
      (evaluate {
        modules = [
          {
            files."generated.txt" = {
              copyMode = "copy";
              text = "generated";
            };
          }
        ];
      }).shell.drvPath;
    expectedError.type = "ThrownError";
    expectedError.msg = ".*The option .files.*copyMode. does not exist.*";
  };

  "test rejects file paths outside the project" = {
    expr =
      (evaluate {
        modules = [ { files."../outside.txt".text = "outside"; } ];
      }).shell.drvPath;
    expectedError.type = "ThrownError";
    expectedError.msg = ".*escapes the project root.*";
  };

  "test rejects tasks" = unsupportedOptionTest "tasks";
  "test rejects processes" = unsupportedOptionTest "processes";
  "test rejects services" = unsupportedOptionTest "services";
  "test rejects containers" = unsupportedOptionTest "containers";
  "test rejects profiles" = unsupportedOptionTest "profiles";
}
