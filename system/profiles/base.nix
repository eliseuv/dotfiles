{ ... }:
{

  imports = [

    # Bootloader
    ../hardware/bootloader.nix

    # Network
    ../hardware/network.nix

    # Environment
    ../environment/default.nix

  ];

  # Flakes support
  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

}
