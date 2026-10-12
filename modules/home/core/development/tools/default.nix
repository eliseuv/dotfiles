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

      # The dotfiles' Justfile from anywhere. A binary rather than an alias
      # so it also works over `ssh host -- dj ...` and from scripts; just
      # runs the recipes from the Justfile's directory. Completes recipes
      # itself: just's dynamic completion only looks in the current directory.
      (symlinkJoin {
        name = "dj";
        paths = [
          (writeShellScriptBin "dj" ''
            exec ${lib.getExe just} --justfile ${config.my.dotfiles.path}/Justfile "$@"
          '')
          (writeTextDir "share/zsh/site-functions/_dj" ''
            #compdef dj
            local -a recipes
            recipes=(''${(z)"$(dj --summary 2>/dev/null)"})
            _arguments "1:recipe:(''${recipes})" '*::argument:_default'
          '')
        ];
      })

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
