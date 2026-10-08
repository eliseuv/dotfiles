{
  config,
  lib,
  pkgs,
  ...
}:
let
  development = config.my.home.development.enable;
in
{

  home.packages =
    with pkgs;
    [

      # Command runner
      just

      # Run command on change
      watchexec

      # Linter
      ast-grep

      # Benchmarking
      hyperfine

    ]
    ++ lib.optionals development [

      # Build systems
      gnumake
      cmake

      # Profiler
      cargo-flamegraph

      # Formatter
      prettierd

      # Reverse engineering
      ghidra-bin

    ];

  programs = {

    # JavaScript
    npm.enable = development;
    bun = {
      enable = development;
      enableGitIntegration = true;
    };

    # JSON
    jq.enable = true;
    jqp = {
      enable = true;
      settings = {
        theme.name = "catppuccin-${config.my.theme.flavor}";
      };
    };

    # Tabular data and databases
    visidata.enable = true;
    lazysql.enable = true;

  };

  home.sessionPath = lib.optional development "$HOME/.bun/bin";

  home.shellAliases.j = "just";

}
