{ config, lib, ... }:
{

  config = lib.mkIf config.my.desktop.gnome.enable {

    services.desktopManager.gnome = {
      enable = true;
    };

    # The GNOME module defaults to IBus, whose XDG autostart entry fires in
    # every non-GNOME session (Hyprland) and warns about the IM env vars on
    # Wayland. All input sources are plain xkb, which mutter switches itself.
    i18n.inputMethod.enable = false;

  };

}
