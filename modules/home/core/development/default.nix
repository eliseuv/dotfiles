{
  config,
  lib,
  pkgs,
  ...
}:
{
  home.packages = with pkgs; [
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

  ];

  programs.nushell.extraConfig = ''
    def "nu-complete dj" [] { ^dj --summary | complete | get stdout | split row --regex '\s+' | compact --empty }
    extern dj [recipe?: string@"nu-complete dj", ...args: any]
  '';

  home.shellAliases = {
    j = "just";
    ns = "nix-shell --command zsh --packages";
  };
}
