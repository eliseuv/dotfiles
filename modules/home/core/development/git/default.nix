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

  # Unlock the SSH keys first: a passphrase prompt from pinentry-curses during
  # a push would otherwise fight lazygit for the tty and corrupt its input.
  # ';' not '&&' so lazygit still starts when there are no keys to unlock.
  home.shellAliases.gg = "ssh-unlock >/dev/null; lazygit";

}
