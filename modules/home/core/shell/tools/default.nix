# Small CLI tools; the ones with real configuration (bottom, yazi) have
# their own modules.
{ lib, pkgs, ... }:
{

  home.packages = with pkgs; [

    # Stream editor
    sd

    # Disk usage analyzer
    dua

    # File change monitor
    hwatch
    viddy

    # Duplicate file finder
    fdupes

    # TUI process runner
    mprocs

    # Download
    wget

    # Systemd TUI
    systemctl-tui

    # Command cheatsheets
    tldr

  ];

  programs = {

    # cd
    zoxide.enable = true;

    # find
    fd.enable = true;

    # grep
    ripgrep.enable = true;
    ripgrep-all.enable = true;

    # cat
    bat = {
      enable = true;
      config = {
        theme = "TwoDark";
      };
    };

    # ls
    eza = {
      enable = true;
      enableZshIntegration = true;
      git = true;
      colors = "auto";
      icons = "auto";
      extraOptions = [ "--group-directories-first" ];
    };

    # Fuzzy finders
    television = {
      enable = true;
      channels = { };
    };
    fzf = {
      enable = true;
      colors = {
        fg = "#f8f8f2";
        bg = "#282a36";
        hl = "#bd93f9";
        "fg+" = "#f8f8f2";
        "bg+" = "#44475a";
        "hl+" = "#bd93f9";
        info = "#ffb86c";
        prompt = "#50fa7b";
        pointer = "#ff79c6";
        marker = "#ff79c6";
        spinner = "#ffb86c";
        header = "#6272a4";
      };
      enableZshIntegration = true;
      tmux.enableShellIntegration = true;
    };

    # File manager
    broot = {
      enable = true;
      enableZshIntegration = true;
      settings = {
        modal = true;
      };
    };

    # Download manager
    aria2.enable = true;

    # Reverse engineering
    rizin.enable = true;

  };

  home.shellAliases = {
    b = "bat";
    l = "eza";
    la = "eza --all";
    ll = "eza --all --long --header";
    lt = "eza --all --tree --ignore-glob=.git";
    llt = "eza --all --long --header --tree --ignore-glob=.git";
    st = "systemctl-tui";
    w = "viddy ";
    tldrf = ''
      tldr --list | tr -d "[''']," | tr ' ' '
          ' | fzf --preview "tldr {1}" --preview-window=right,70% | xargs tldr'';
  };

  # tuiboard isn't packaged in nixpkgs; @opentui/core ships prebuilt
  # per-platform native binaries pulled in at install time, so there's
  # no real payoff in vendoring it through Nix. Reassert the global bun
  # install on every switch instead, so a fresh machine ends up with the
  # same tool without a manual `bun install -g` step. Bump the pinned
  # version below to upgrade.
  home.activation.tuiboard = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run ${pkgs.bun}/bin/bun install -g tuiboard@0.13.3
  '';

}
