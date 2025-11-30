{ ... }:
{

  programs.git = {

    enable = true;

    settings = {

      user = {
        name = "evf";
        email = "eliseuv@pm.me";
      };

      core = {
        editor = "nvim";
        compression = 9;
        whitespace = "error";
        preloadindex = true;
      };

      url = {
        "git@github.com:".insteadOf = "gh:";
        "git@github.com:eliseuv/".insteadOf = "evf/";
      };

    };

    maintenance = {
      enable = true;
      repositories = [ "/home/evf/dotfiles" ];
    };

  };

  programs.delta = {
    enable = true;
    enableGitIntegration = true;
    options = {
      features = "decorations";
      navigate = true; # use n and N to move between diff sections
      light = false; # set to true if you're in a terminal w/ a light background color (e.g. the default macOS terminal)
      line-numbers = true;
      side-by-side = false;
      interactive = {
        keep-plus-minus-markers = false;
      };
      decorations = {
        commit-decoration-style = "blue ol";
        commit-style = "raw";
        file-style = "omit";
        hunk-header-decoration-style = "blue box";
        hunk-header-file-style = "red";
        hunk-header-line-number-style = "#067a00";
        hunk-header-style = "file line-number syntax";
      };
    };
  };

  home.shellAliases = {
    gcl = "git clone";
  };

}
