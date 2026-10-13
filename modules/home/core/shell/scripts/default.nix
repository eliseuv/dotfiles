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
      editor =
        if config.programs.neovim.enable then "nvim {1} +{2}" else "code --wait --goto {1}:{2}:{3}";
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
    # ssh-unlock
    (import ./_ssh-unlock.nix {
      inherit pkgs;
      inherit lib;
      cacheTtl = config.services.gpg-agent.maxCacheTtlSsh;
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
