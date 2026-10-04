{
  config,
  pkgs,
  lib,
  ...
}:
{

  # Nix scripts
  home.packages = [
    # ripgrep fzf
    (import ./_rgfzf.nix {
      inherit pkgs;
      inherit lib;
    })
    # ntfy
    (import ./_ntfy.nix {
      inherit pkgs;
      inherit lib;
    })
    # ntfy-done
    (import ./_ntfy-done.nix {
      inherit pkgs;
      inherit lib;
    })
    # schedule-claude
    (import ./_schedule-claude.nix {
      inherit pkgs;
      inherit lib;
    })
    # wake
    (import ./_wake.nix {
      inherit pkgs;
      inherit lib;
      inherit (config.my) wakeOnLan;
    })
  ];

  home.shellAliases = {
    # ripgrep + fzf
    f = "rgfzf";
  };

}
