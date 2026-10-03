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

  };

}
