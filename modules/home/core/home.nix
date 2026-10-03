{ config, ... }:
{

  programs.home-manager.enable = true;
  home.stateVersion = config.my.host.stateVersion;

}
