{ config, pkgs, ... }:
{

  home.packages = with pkgs; [

    # Command runners
    gnumake
    cmake
    just

    # Run command on change
    watchexec

    # Linter
    ast-grep

    # Benchmarking
    hyperfine

    # Profiler
    cargo-flamegraph

    # Formatter
    prettierd

    # Reverse engineering
    ghidra-bin

  ];

  programs = {

    # JavaScript
    npm.enable = true;
    bun = {
      enable = true;
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

  home.sessionPath = [ "$HOME/.bun/bin" ];

  home.shellAliases.j = "just";

}
