{ pkgs, ... }:
{

  imports = [
    ./maintenance.nix
    ./users.nix
    ./development.nix
    ./locale.nix
    ./time.nix
    ./gnupg.nix
    ./services.nix
  ];

  programs.zsh.enable = true;
  users.defaultUserShell = pkgs.zsh;

  # Default programs
  programs = {

    git.enable = true;

    vim = {
      enable = true;
      defaultEditor = true;
    };

  };

}
