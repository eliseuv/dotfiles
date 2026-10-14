{
  config,
  lib,
  pkgs,
  ...
}:
{

  # The account email lives in sops (the repo is public), so rbw's config is
  # rendered by sops-nix instead of programs.rbw.settings, which would put it
  # in the store
  config = lib.mkIf (config.my.desktop.enable && config.my.secrets.user.enable) {

    programs.rbw.enable = true;

    sops.secrets."bitwarden/email" = { };

    sops.templates."rbw-config.json" = {
      path = "${config.xdg.configHome}/rbw/config.json";
      content = builtins.toJSON {
        email = config.sops.placeholder."bitwarden/email";
        lock_timeout = 3600;
        pinentry = lib.getExe pkgs.pinentry-gnome3;
      };
    };

    # Search and autotype/copy, opened from the waybar widget (bitwarden.sh)
    home.packages = [ pkgs.rofi-rbw-wayland ];

    xdg.configFile."rofi-rbw.rc".text = ''
      selector = rofi
      typer = wtype
      clipboarder = wl-copy
      clear-after = 60
      prompt = Bitwarden
      selector-args = -theme ${config.xdg.configHome}/rofi/config/bitwarden.rasi
    '';

  };

}
