{ pkgs, ... }:
{

  imports = [

    # Disks
    ../hardware/disks.nix

    # Audio
    ../hardware/audio.nix

    # Keyboard
    ../hardware/keyboard.nix

    # Printing
    ../hardware/printing.nix

  ];

  # Default GUI programs
  programs.firefox.enable = true;

  environment.systemPackages = with pkgs; [ xterm ];

}
