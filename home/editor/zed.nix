{ pkgs, ... }:
{

  programs.zed-editor = {
    enable = true;
    package = pkgs.zed-editor-fhs;
    extensions = [
      "nix"
      "julia"
      "just"
    ];
    userKeymaps = [ ];
    userSettings = {
      base_keymap = "VSCode";
      telemetry = {
        diagnostics = false;
        metrics = false;
      };
      format_on_save = "on";
      # Buffer font
      buffer_font_family = "ZedMono Nerd Font";
      buffer_font_size = 12;
      # UI
      ui_font_size = 14;
      # Terminal
      terminal = {
        dock = "right";
        font_size = 12;
        font_family = "ZedMono Nerd Font";
      };
      # Vim
      vim_mode = true;
      vim = {
        use_multiline_find = true;
        use_smartcase_find = true;
        use_system_clipboard = "always";
      };
      # Inlay hints
      inlayHints = {
        maxLength = null;
        lifetimeElisionHints = {
          useParameterNames = true;
          enable = "skip_trivial";
        };
        closureReturnTypeHints = {
          "enable" = "always";
        };
      };
      # Languages
      languages = {
        Nix = {
          language_servers = [
            "!nil"
            "nixd"
          ];
          formatter.external = {
            command = "nixfmt";
          };
        };
      };
    };
    extraPackages = with pkgs; [
      # Font
      nerd-fonts.zed-mono
      # Language servers
      nixd
    ];
  };

  catppuccin.zed = {
    enable = true;
  };

}
