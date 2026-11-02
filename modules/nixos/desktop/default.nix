{
  config,
  lib,
  pkgs,
  ...
}:
{

  config = lib.mkIf config.my.desktop.enable {

    # Default GUI programs
    programs.firefox.enable = true;

    environment.systemPackages = with pkgs; [ xterm ];

    services.displayManager.defaultSession = config.my.desktop.defaultSession;

    # Audio
    security.rtkit.enable = true;
    services.pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;
    };

    # Removable and network disks
    services = {
      udisks2.enable = true;
      gvfs.enable = true;
      devmon.enable = true;
      samba.enable = true;
    };

    # Enable CUPS to print documents.
    services.printing = {
      enable = true;
      drivers = with pkgs; [
        hplip
      ];
    };

  };

}
