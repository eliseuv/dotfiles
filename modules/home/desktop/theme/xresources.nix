{ config, lib, ... }:
{

  config = lib.mkIf config.my.desktop.enable {

    xresources.properties = {
      "XTerm*selectToClipboard" = true;
    };

  };

}
