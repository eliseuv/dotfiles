{ ... }:
{
  programs.bun = {
    enable = true;
    enableGitIntegration = true;
  };

  home.sessionPath = [ "$HOME/.bun/bin" ];
}
