{ pkgs, ... }:
{

  programs.yazi = {
    enable = true;
    enableZshIntegration = true;
    shellWrapperName = "y";
    settings = {
      mgr = {
        show_hidden = true;
      };
      plugin = {
        prepend_fetchers = [
          {
            url = "*";
            run = "git";
            group = "git";
          }
          {
            url = "*/";
            run = "git";
            group = "git";
          }
        ];
        prepend_previewers = [
          {
            mime = "text/markdown";
            run = "glow";
          }
        ];
      };
    };
    keymap = {
      mgr.prepend_keymap = [
        {
          on = [ "l" ];
          run = "plugin bypass smart-enter";
          desc = "Open the file, or enter the directory, skipping chained single-child directories";
        }
        {
          on = [ "h" ];
          run = "plugin bypass reverse";
          desc = "Leave the directory, skipping chained single-child directories";
        }
        {
          on = [
            "g"
            "i"
          ];
          run = "plugin lazygit";
          desc = "Open lazygit";
        }
        {
          on = [ "R" ];
          run = "plugin rsync";
          desc = "Copy files using rsync";
        }
        {
          on = [ "<C-e>" ];
          run = "seek 5";
          desc = "Seek down 5 units in the preview";
        }
        {
          on = [ "<C-y>" ];
          run = "seek -5";
          desc = "Seek up 5 units in the preview";
        }
      ];
    };
    plugins = {
      bypass = pkgs.yaziPlugins.bypass;
      git = {
        package = pkgs.yaziPlugins.git;
        setup = true;
      };
      glow = pkgs.yaziPlugins.glow;
      lazygit = pkgs.yaziPlugins.lazygit;
      rsync = pkgs.yaziPlugins.rsync;
    };
  };

}
