# Forges and TUIs around git; git itself is configured in git.nix.
{ pkgs, ... }:
{

  # GitLab CLI
  home.packages = [ pkgs.glab ];

  programs = {

    # GitHub CLI
    gh = {
      enable = true;
      settings = {
        git_protocol = "ssh";
        prompt = "enabled";
        pager = "bat";
        aliases = {
          co = "pr checkout";
          pv = "pr view";
        };
      };
    };

    # TUIs
    gitui.enable = true;
    lazygit = {
      enable = true;
      settings = {
        git = {
          diffRenderers = [
            {
              command = "delta --dark --paging=never";
            }
          ];
        };
      };
    };

  };

  home.shellAliases.gg = "lazygit";

}
