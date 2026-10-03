{ pkgs, ... }:
{

  programs.zsh.enable = true;
  users.defaultUserShell = pkgs.zsh;

  # Default programs
  programs = {

    git.enable = true;

    vim = {
      enable = true;
      defaultEditor = true;
    };

    gnupg.agent = {
      enable = true;
      enableSSHSupport = true;
    };

  };

  environment.systemPackages = with pkgs; [

    # Compilers
    clang
    gcc
    gfortran

  ];

}
