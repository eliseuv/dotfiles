{ ... }:
{

  programs.eza = {
    enable = true;
    enableZshIntegration = true;
    git = true;
    colors = "auto";
    icons = "auto";
    extraOptions = [ "--group-directories-first" ];
  };
  home.shellAliases = {
    l = "eza";
    la = "eza --all";
    ll = "eza --all --long --header";
    lt = "eza --all --tree --ignore-glob=.git";
    llt = "eza --all --long --header --tree --ignore-glob=.git";
  };

}
