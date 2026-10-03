{ config, lib, ... }:
{

  options.my.hardware = {

    nvidia.enable = lib.mkEnableOption "the proprietary NVIDIA driver";

    bluetooth.enable = lib.mkOption {
      type = lib.types.bool;
      default = config.my.host.type == "laptop";
      defaultText = ''my.host.type == "laptop"'';
    };

  };

}
