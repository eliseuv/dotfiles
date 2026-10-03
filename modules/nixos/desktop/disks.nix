{ config, lib, ... }:
{

  config = lib.mkIf config.my.desktop.enable {

    services = {
      udisks2.enable = true;
      gvfs.enable = true;
      devmon.enable = true;
      samba.enable = true;
    };

  };

}
