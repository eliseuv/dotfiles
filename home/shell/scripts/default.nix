{ pkgs, lib, ... }:
{

  # Nix scripts
  home.packages = [
    # ripgrep fzf
    (import ./rgfzf.nix {
      inherit pkgs;
      inherit lib;
    })
    # ntfy
    (import ./ntfy.nix {
      inherit pkgs;
      inherit lib;
    })
    # ntfy-done
    (import ./ntfy-done.nix {
      inherit pkgs;
      inherit lib;
    })
    # schedule-claude
    (import ./schedule-claude.nix {
      inherit pkgs;
      inherit lib;
    })
  ];

  home.shellAliases = {
    # ripgrep + fzf
    f = "rgfzf";
  };

}
