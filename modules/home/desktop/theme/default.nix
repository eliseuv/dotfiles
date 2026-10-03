# Dark GTK/Qt/X resources; Catppuccin for the programs it themes is in
# catppuccin.nix.
{ config, lib, ... }:
{

  config = lib.mkIf config.my.desktop.enable {

    dconf.settings = {
      "org/gnome/desktop/interface" = {
        color-scheme = "prefer-dark";
      };
      "org/gnome/desktop/peripherals/keyboard" = {
        numlock-state = true;
        remember-numlock-state = true;
      };
    };

    gtk = {
      enable = true;
      gtk3.extraConfig = {
        gtk-application-prefer-dark-theme = 1;
      };
      gtk4 = {
        theme = config.gtk.theme;
        extraConfig = {
          gtk-application-prefer-dark-theme = 1;
        };
      };
    };

    qt = {
      enable = true;
      style.name = "adwaita-dark";
    };

    xresources.properties = {
      "XTerm*selectToClipboard" = true;
    };

  };

}
