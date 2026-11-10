{
  config,
  inputs,
  lib,
  ...
}:
{

  imports = [ inputs.bootvine.nixosModules.default ];

  config = lib.mkIf config.my.desktop.bootvine.enable {

    # Plymouth owns the same console and the LUKS prompt; the splash would
    # hide the tree.
    assertions = [
      {
        assertion = !config.my.desktop.bootSplash.enable;
        message = "my.desktop.bootvine and my.desktop.bootSplash both draw on the boot console; enable only one.";
      }
    ];

    services.bootvine.enable = true;

  };

}
