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

  };

}
