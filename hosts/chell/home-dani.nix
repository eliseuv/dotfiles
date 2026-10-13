# dani on chell: GNOME in Portuguese (the language itself is seeded from
# users/dani.nix), with a dock, tray icons and GNOME's own viewers. Keeps
# the shared shell, terminals and assistants, with a focused dev environment.
{ lib, pkgs, ... }:
let
  papers = [ "org.gnome.Papers.desktop" ];
  loupe = [ "org.gnome.Loupe.desktop" ];
  chatgpt = pkgs.callPackage ../../pkgs/chatgpt-linux { defaultWorkspace = "/etc/dotfiles"; };
in
{

  # Only this home opts out; evf and other hosts keep the full dev setup.
  disabledModules = [
    ../../modules/home/core/development/languages/c.nix
    ../../modules/home/core/development/languages/default.nix
    ../../modules/home/core/development/languages/go.nix
    ../../modules/home/core/development/languages/haskell.nix
    ../../modules/home/core/development/languages/julia.nix
    ../../modules/home/core/development/languages/nix.nix
    ../../modules/home/core/development/languages/python.nix
    ../../modules/home/core/development/languages/rust-tools.nix
    ../../modules/home/core/development/languages/web.nix
    ../../modules/home/core/development/languages/zig.nix
    ../../modules/home/core/development/tools/default.nix
    ../../modules/home/core/development/git/default.nix
    ../../modules/home/core/editor/helix.nix
    ../../modules/home/core/editor/neovim/default.nix
    ../../modules/home/core/editor/neovim/lazyvim.nix
    ../../modules/home/apps/editor/emacs/default.nix
    ../../modules/home/apps/editor/emacs/doom.nix
    ../../modules/home/apps/editor/zed.nix
    ../../modules/home/core/containers/default.nix
    ../../modules/home/core/maintenance/kondo.nix
  ];

  # Rust (including pkg-config) remains supplied by the shared Rust module.
  programs = {
    uv.enable = true;
    lazygit.enable = true;
    delta.enable = lib.mkForce false;
    rizin.enable = lib.mkForce false;
  };
  programs.git.settings.core.editor = lib.mkForce "code --wait";
  home.sessionVariables = {
    EDITOR = "code --wait";
    VISUAL = "code --wait";
  };
  home.sessionPath = [ "$HOME/.local/bin" ];
  home.shellAliases.gg = "lazygit";

  # Hyprland is evf's session (waybar, rofi and dunst go with it); the rest
  # are evf's services and remotes
  my.desktop.hyprland.enable = lib.mkForce false;
  my.home = {
    remoteAccess.enable = lib.mkForce false;
    cloudSync.enable = lib.mkForce false;
    firefox.customUI = false;
  };
  services.syncthing.enable = lib.mkForce false;

  # GNOME's viewers over zathura, feh and sxiv. mkForce per type: the
  # option's lists would otherwise concatenate with the modules' entries.
  my.home.defaultApps = lib.mapAttrs (_: lib.mkForce) {
    "application/pdf" = papers;
    "application/epub+zip" = papers;
    "image/jpeg" = loupe;
    "image/png" = loupe;
    "image/*" = loupe;
    "video/*" = [ "org.gnome.Showtime.desktop" ];
  };

  home.packages = with pkgs; [
    # Fortran compiler and language server; uv manages Python per project.
    gfortran
    fortls

    chatgpt
    bitwarden-desktop
    libreoffice
    obs-studio
    hunspellDicts.pt_BR
  ];

  home.activation.chatgptDefaultWorkspace = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run ${chatgpt.configureWorkspace}
  '';

  programs.gnome-shell = {
    enable = true;
    extensions = with pkgs.gnomeExtensions; [
      { package = dash-to-dock; }
      { package = appindicator; }
    ];
  };

  dconf.settings = {
    "org/gnome/desktop/wm/preferences".button-layout = "appmenu:minimize,maximize,close";
    # Dates, numbers and currency; the UI language is AccountsService's
    "org/gnome/system/locale".region = "pt_BR.UTF-8";
    "org/gnome/desktop/input-sources".sources = with lib.hm.gvariant; [
      (mkTuple [
        "xkb"
        "us"
      ])
      (mkTuple [
        "xkb"
        "br"
      ])
    ];
  };

}
