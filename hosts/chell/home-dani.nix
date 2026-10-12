# dani on chell: GNOME in Portuguese (the language itself is seeded from
# users/dani.nix), with a dock, tray icons and GNOME's own viewers. Keeps
# evf's shell, editors and dev toolchains; drops what is evf's alone.
{ lib, pkgs, ... }:
let
  papers = [ "org.gnome.Papers.desktop" ];
  loupe = [ "org.gnome.Loupe.desktop" ];
  chatgpt = pkgs.callPackage ../../pkgs/chatgpt-linux { defaultWorkspace = "/etc/dotfiles"; };
in
{

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
