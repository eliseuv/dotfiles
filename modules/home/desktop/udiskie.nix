{
  config,
  lib,
  pkgs,
  ...
}:
{

  config = lib.mkIf config.my.desktop.enable {

    services.udiskie = {
      enable = true;
      automount = true;
      notify = true;
      tray = "auto";
      settings = {
        program_options = {
          # https://github.com/nix-community/home-manager/issues/632#issuecomment-2210425312
          file_manager = "${lib.getExe pkgs.nautilus}";
        };
      };
    };

  };

}
