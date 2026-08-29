{ devenvSource }:

{
  "test reads the expected devenv version" = {
    expr = builtins.elem ''version = "2.2.3"'' (
      builtins.split "\n" (builtins.readFile "${devenvSource}/Cargo.toml")
    );
    expected = true;
  };
}
