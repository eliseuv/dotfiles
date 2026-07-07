{ pkgs, lib, ... }:
let
  inline = lib.generators.mkLuaInline;
in
{

  home.packages = with pkgs; [

    # Audio mixer
    wiremix

  ];

  # Catppuccin theme
  catppuccin.hyprland = {
    enable = true;
  };

  # Hyprland config
  # Monitors are set per-host in monitors-<host>.nix, imported from each host's
  # top-level home file.
  wayland.windowManager.hyprland = {
    enable = true;
    package = null; # installed by the NixOS module (programs.hyprland.enable)
    configType = "lua";
    systemd.enable = false; # UWSM (withUWSM = true) owns session integration

    settings = {

      ###################
      ### MY PROGRAMS ###
      ###################

      mainMod = {
        _var = "SUPER";
      };
      terminal = {
        _var = "ghostty";
      };
      terminalCommand = {
        _var = "ghostty -e";
      };
      menu = {
        _var = "~/.config/rofi/bin/launcher";
      };
      powermenu = {
        _var = "~/.config/rofi/bin/powermenu";
      };
      browser = {
        _var = "firefox";
      };
      emacs = {
        _var = "emacsclient -nc -a 'emacs'";
      };
      vim = {
        _var = "neovide";
      };
      fileManager = {
        _var = "nautilus";
      };

      #################
      ### AUTOSTART ###
      #################

      on = {
        _args = [
          "hyprland.start"
          (inline ''
            function()
              hl.exec_cmd("waybar")
              hl.exec_cmd("dbus-update-activation-environment --systemd --all")
            end
          '')
        ];
      };

      #############################
      ### ENVIRONMENT VARIABLES ###
      #############################

      env = [
        { _args = [ "XDG_CURRENT_DESKTOP" "Hyprland" ]; }
        { _args = [ "XCURSOR_THEME" "Adwaita" ]; }
        { _args = [ "XCURSOR_SIZE" "10" ]; }
      ];

      #####################
      ### LOOK AND FEEL ###
      #####################

      config = {
        general = {
          layout = "dwindle";

          gaps_in = 2;
          gaps_out = 2;

          border_size = 2;

          col = {
            active_border = {
              colors = [
                "rgba(33ccffee)"
                "rgba(8948aaee)"
              ];
              angle = 45;
            };
            inactive_border = {
              colors = [
                "rgba(707070aa)"
                "rgba(303030aa)"
              ];
              angle = 45;
            };
          };

          allow_tearing = true;
        };

        decoration = {
          rounding = 6;
          rounding_power = 3;

          active_opacity = 1.0;
          inactive_opacity = 0.9;

          shadow = {
            enabled = false;
            range = 4;
            render_power = 3;
            color = "rgba(1a1a1aee)";
          };

          blur = {
            enabled = true;
            size = 3;
            passes = 3;
          };
        };

        animations = {
          enabled = true;
        };

        dwindle = {
          preserve_split = true;
        };

        master = {
          new_status = "master";
        };

        misc = {
          disable_hyprland_logo = true;
        };

        input = {
          numlock_by_default = true;

          kb_layout = "us,br";
          kb_options = "grp:alt_shift_toggle";

          touchpad = {
            disable_while_typing = true;
            natural_scroll = true;
            drag_lock = true;
          };
        };

        cursor = {
          # Hide cursor when idle
          inactive_timeout = 3;
        };
      };

      curve = [
        {
          _args = [
            "easeOutQuint"
            {
              type = "bezier";
              points = [
                [
                  0.23
                  1
                ]
                [
                  0.32
                  1
                ]
              ];
            }
          ];
        }
        {
          _args = [
            "easeInOutCubic"
            {
              type = "bezier";
              points = [
                [
                  0.65
                  0.05
                ]
                [
                  0.36
                  1
                ]
              ];
            }
          ];
        }
        {
          _args = [
            "linear"
            {
              type = "bezier";
              points = [
                [
                  0
                  0
                ]
                [
                  1
                  1
                ]
              ];
            }
          ];
        }
        {
          _args = [
            "almostLinear"
            {
              type = "bezier";
              points = [
                [
                  0.5
                  0.5
                ]
                [
                  0.75
                  1
                ]
              ];
            }
          ];
        }
        {
          _args = [
            "quick"
            {
              type = "bezier";
              points = [
                [
                  0.15
                  0
                ]
                [
                  0.1
                  1
                ]
              ];
            }
          ];
        }
      ];

      animation = [
        {
          leaf = "global";
          enabled = true;
          speed = 10;
          bezier = "default";
        }
        {
          leaf = "border";
          enabled = true;
          speed = 5.39;
          bezier = "easeOutQuint";
        }
        {
          leaf = "windows";
          enabled = true;
          speed = 4.79;
          bezier = "easeOutQuint";
        }
        {
          leaf = "windowsIn";
          enabled = true;
          speed = 4.1;
          bezier = "easeOutQuint";
          style = "popin 87%";
        }
        {
          leaf = "windowsOut";
          enabled = true;
          speed = 1.49;
          bezier = "linear";
          style = "popin 87%";
        }
        {
          leaf = "fadeIn";
          enabled = true;
          speed = 1.73;
          bezier = "almostLinear";
        }
        {
          leaf = "fadeOut";
          enabled = true;
          speed = 1.46;
          bezier = "almostLinear";
        }
        {
          leaf = "fade";
          enabled = true;
          speed = 3.03;
          bezier = "quick";
        }
        {
          leaf = "layers";
          enabled = true;
          speed = 3.81;
          bezier = "easeOutQuint";
        }
        {
          leaf = "layersIn";
          enabled = true;
          speed = 4;
          bezier = "easeOutQuint";
          style = "fade";
        }
        {
          leaf = "layersOut";
          enabled = true;
          speed = 1.5;
          bezier = "linear";
          style = "fade";
        }
        {
          leaf = "fadeLayersIn";
          enabled = true;
          speed = 1.79;
          bezier = "almostLinear";
        }
        {
          leaf = "fadeLayersOut";
          enabled = true;
          speed = 1.39;
          bezier = "almostLinear";
        }
        {
          leaf = "workspaces";
          enabled = true;
          speed = 1.94;
          bezier = "almostLinear";
          style = "fade";
        }
        {
          leaf = "workspacesIn";
          enabled = true;
          speed = 1.21;
          bezier = "almostLinear";
          style = "fade";
        }
        {
          leaf = "workspacesOut";
          enabled = true;
          speed = 1.94;
          bezier = "almostLinear";
          style = "fade";
        }
      ];

      ###################
      ### KEYBINDINGS ###
      ###################

      bind = [
        # Exit
        {
          _args = [
            (inline ''mainMod .. " + SHIFT + backspace"'')
            (inline "hl.dsp.exec_cmd(powermenu)")
          ];
        }
        {
          _args = [
            (inline ''mainMod .. " + SHIFT + R"'')
            (inline ''
              hl.dsp.exec_cmd("hyprctl reload; systemctl --user restart hyprpaper.service; systemctl --user restart hypridle.service; systemctl --user restart hyprpolkitagent")'')
          ];
        }

        # Menu
        {
          _args = [
            (inline ''mainMod .. " + SHIFT + return"'')
            (inline "hl.dsp.exec_cmd(menu)")
          ];
        }

        # Terminal
        {
          _args = [
            (inline ''mainMod .. " + return"'')
            (inline "hl.dsp.exec_cmd(terminal)")
          ];
        }

        # Programs
        {
          _args = [
            (inline ''mainMod .. " + SHIFT + B"'')
            (inline "hl.dsp.exec_cmd(browser)")
          ];
        }
        {
          _args = [
            (inline ''mainMod .. " + SHIFT + V"'')
            (inline "hl.dsp.exec_cmd(vim)")
          ];
        }
        {
          _args = [
            (inline ''mainMod .. " + SHIFT + E"'')
            (inline "hl.dsp.exec_cmd(emacs)")
          ];
        }
        {
          _args = [
            (inline ''mainMod .. " + SHIFT + F"'')
            (inline "hl.dsp.exec_cmd(fileManager)")
          ];
        }

        # Process monitor
        {
          _args = [
            (inline ''mainMod .. " + ALT + H"'')
            (inline ''hl.dsp.exec_cmd(terminalCommand .. " btm")'')
          ];
        }
        # Sound mixer
        {
          _args = [
            (inline ''mainMod .. " + ALT + M"'')
            (inline ''hl.dsp.exec_cmd(terminalCommand .. " wiremix --tab configuration")'')
          ];
        }
        # Systemd
        {
          _args = [
            (inline ''mainMod .. " + ALT + S"'')
            (inline ''hl.dsp.exec_cmd(terminalCommand .. " systemctl-tui")'')
          ];
        }

        # Kill window
        {
          _args = [
            (inline ''mainMod .. " + SHIFT + Q"'')
            (inline "hl.dsp.window.close()")
          ];
        }

        # Cycle windows
        {
          _args = [
            (inline ''mainMod .. " + K"'')
            (inline "hl.dsp.window.cycle_next({ next = false })")
          ];
        }
        {
          _args = [
            (inline ''mainMod .. " + J"'')
            (inline "hl.dsp.window.cycle_next({ next = true })")
          ];
        }

        # Cycle monitors
        {
          _args = [
            (inline ''mainMod .. " + H"'')
            (inline ''hl.dsp.focus({ monitor = "-1" })'')
          ];
        }
        {
          _args = [
            (inline ''mainMod .. " + L"'')
            (inline ''hl.dsp.focus({ monitor = "+1" })'')
          ];
        }

        # Move windows
        {
          _args = [
            (inline ''mainMod .. " + SHIFT + H"'')
            (inline ''hl.dsp.window.move({ direction = "left" })'')
          ];
        }
        {
          _args = [
            (inline ''mainMod .. " + SHIFT + J"'')
            (inline ''hl.dsp.window.move({ direction = "down" })'')
          ];
        }
        {
          _args = [
            (inline ''mainMod .. " + SHIFT + K"'')
            (inline ''hl.dsp.window.move({ direction = "up" })'')
          ];
        }
        {
          _args = [
            (inline ''mainMod .. " + SHIFT + L"'')
            (inline ''hl.dsp.window.move({ direction = "right" })'')
          ];
        }

        # Layouts
        {
          _args = [
            (inline ''mainMod .. " + space"'')
            (inline ''hl.dsp.window.fullscreen({ action = "toggle" })'')
          ];
        }
        {
          _args = [
            (inline ''mainMod .. " + T"'') # dwindle
            (inline ''hl.dsp.layout("togglesplit")'')
          ];
        }
        {
          _args = [
            (inline ''mainMod .. " + S"'') # dwindle
            (inline ''hl.dsp.window.pseudo({ action = "toggle" })'')
          ];
        }
        {
          _args = [
            (inline ''mainMod .. " + V"'')
            (inline ''hl.dsp.window.float({ action = "toggle" })'')
          ];
        }

        # Select workspace
        { _args = [ (inline ''mainMod .. " + 1"'') (inline "hl.dsp.focus({ workspace = 1 })") ]; }
        { _args = [ (inline ''mainMod .. " + 2"'') (inline "hl.dsp.focus({ workspace = 2 })") ]; }
        { _args = [ (inline ''mainMod .. " + 3"'') (inline "hl.dsp.focus({ workspace = 3 })") ]; }
        { _args = [ (inline ''mainMod .. " + 4"'') (inline "hl.dsp.focus({ workspace = 4 })") ]; }
        { _args = [ (inline ''mainMod .. " + 5"'') (inline "hl.dsp.focus({ workspace = 5 })") ]; }
        { _args = [ (inline ''mainMod .. " + 6"'') (inline "hl.dsp.focus({ workspace = 6 })") ]; }
        { _args = [ (inline ''mainMod .. " + 7"'') (inline "hl.dsp.focus({ workspace = 7 })") ]; }
        { _args = [ (inline ''mainMod .. " + 8"'') (inline "hl.dsp.focus({ workspace = 8 })") ]; }
        { _args = [ (inline ''mainMod .. " + 9"'') (inline "hl.dsp.focus({ workspace = 9 })") ]; }
        { _args = [ (inline ''mainMod .. " + 0"'') (inline "hl.dsp.focus({ workspace = 10 })") ]; }

        # Move to workspace (silently, no follow)
        {
          _args = [
            (inline ''mainMod .. " + SHIFT + 1"'')
            (inline "hl.dsp.window.move({ workspace = 1, follow = false })")
          ];
        }
        {
          _args = [
            (inline ''mainMod .. " + SHIFT + 2"'')
            (inline "hl.dsp.window.move({ workspace = 2, follow = false })")
          ];
        }
        {
          _args = [
            (inline ''mainMod .. " + SHIFT + 3"'')
            (inline "hl.dsp.window.move({ workspace = 3, follow = false })")
          ];
        }
        {
          _args = [
            (inline ''mainMod .. " + SHIFT + 4"'')
            (inline "hl.dsp.window.move({ workspace = 4, follow = false })")
          ];
        }
        {
          _args = [
            (inline ''mainMod .. " + SHIFT + 5"'')
            (inline "hl.dsp.window.move({ workspace = 5, follow = false })")
          ];
        }
        {
          _args = [
            (inline ''mainMod .. " + SHIFT + 6"'')
            (inline "hl.dsp.window.move({ workspace = 6, follow = false })")
          ];
        }
        {
          _args = [
            (inline ''mainMod .. " + SHIFT + 7"'')
            (inline "hl.dsp.window.move({ workspace = 7, follow = false })")
          ];
        }
        {
          _args = [
            (inline ''mainMod .. " + SHIFT + 8"'')
            (inline "hl.dsp.window.move({ workspace = 8, follow = false })")
          ];
        }
        {
          _args = [
            (inline ''mainMod .. " + SHIFT + 9"'')
            (inline "hl.dsp.window.move({ workspace = 9, follow = false })")
          ];
        }
        {
          _args = [
            (inline ''mainMod .. " + SHIFT + 0"'')
            (inline "hl.dsp.window.move({ workspace = 10, follow = false })")
          ];
        }

        # Move workspace between monitors
        {
          _args = [
            (inline ''mainMod .. " + CTRL + H"'')
            (inline ''hl.dsp.workspace.move({ monitor = "-1" })'')
          ];
        }
        {
          _args = [
            (inline ''mainMod .. " + CTRL + L"'')
            (inline ''hl.dsp.workspace.move({ monitor = "+1" })'')
          ];
        }

        # Special workspaces
        {
          _args = [
            (inline ''mainMod .. " + P"'')
            (inline ''hl.dsp.workspace.toggle_special("magic")'')
          ];
        }
        {
          _args = [
            (inline ''mainMod .. " + SHIFT + P"'')
            (inline ''hl.dsp.window.move({ workspace = "special:magic" })'')
          ];
        }

        # Media
        {
          _args = [
            (inline ''mainMod .. " + minus"'')
            (inline ''hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_SINK@ 5%-")'')
            {
              locked = true;
              repeating = true;
            }
          ];
        }
        {
          _args = [
            (inline ''mainMod .. " + equal"'')
            (inline ''hl.dsp.exec_cmd("wpctl set-volume -l 1.5 @DEFAULT_SINK@ 5%+")'')
            {
              locked = true;
              repeating = true;
            }
          ];
        }
        {
          _args = [
            (inline ''mainMod .. " + backslash"'')
            (inline ''hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_SINK@ toggle")'')
            {
              locked = true;
            }
          ];
        }

        # Controls
        {
          _args = [
            "XF86AudioLowerVolume"
            (inline ''hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_SINK@ 5%-")'')
            {
              locked = true;
              repeating = true;
            }
          ];
        }
        {
          _args = [
            "XF86AudioRaiseVolume"
            (inline ''hl.dsp.exec_cmd("wpctl set-volume -l 1.5 @DEFAULT_SINK@ 5%+")'')
            {
              locked = true;
              repeating = true;
            }
          ];
        }
        {
          _args = [
            "XF86AudioMute"
            (inline ''hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_SINK@ toggle")'')
            {
              locked = true;
            }
          ];
        }

        {
          _args = [
            "XF86MonBrightnessDown"
            (inline ''hl.dsp.exec_cmd("brightnessctl set 5%-")'')
            {
              locked = true;
              repeating = true;
            }
          ];
        }
        {
          _args = [
            "XF86MonBrightnessUp"
            (inline ''hl.dsp.exec_cmd("brightnessctl set 5%+")'')
            {
              locked = true;
              repeating = true;
            }
          ];
        }

        # Screenshot a window
        {
          _args = [
            (inline ''mainMod .. " + PRINT"'')
            (inline ''hl.dsp.exec_cmd("hyprshot -m window")'')
          ];
        }
        # Screenshot a monitor
        {
          _args = [
            "PRINT"
            (inline ''hl.dsp.exec_cmd("hyprshot -m output")'')
          ];
        }
        # Screenshot a region
        {
          _args = [
            (inline ''mainMod .. " + SHIFT + PRINT"'')
            (inline ''hl.dsp.exec_cmd("hyprshot -m region")'')
          ];
        }
      ];

      ###################################
      ### WINDOWS AND WORKSPACES ###
      ###################################

      workspace_rule = [
        {
          workspace = "w[tv1]";
          gaps_out = 0;
          gaps_in = 0;
        }
        {
          workspace = "f[1]";
          gaps_out = 0;
          gaps_in = 0;
        }
      ];

      window_rule = [
        # Smart gaps
        {
          name = "no-gaps-wtv1";
          match = {
            float = false;
            workspace = "w[tv1]";
          };
          border_size = 0;
          rounding = 0;
        }
        {
          name = "no-gaps-f1";
          match = {
            float = false;
            workspace = "f[1]";
          };
          border_size = 0;
          rounding = 0;
        }

        # Ignore maximize requests from apps. You'll probably like this.
        {
          name = "suppress-maximize-events";
          match = {
            class = ".*";
          };
          suppress_event = "maximize";
        }

        # Fix some dragging issues with XWayland
        {
          name = "fix-xwayland-drags";
          match = {
            class = "^$";
            title = "^$";
            xwayland = true;
            float = true;
            fullscreen = false;
            pin = false;
          };
          no_focus = true;
        }

        # Rofi menu
        {
          name = "rofi-menu";
          match = {
            class = "Rofi";
          };
          opacity = 0.7;
          xray = true;
        }

        # Terminal
        {
          name = "tag-term-ghostty";
          match = {
            class = "com.mitchellh.ghostty";
          };
          tag = "+term";
        }
        {
          name = "tag-term-kitty";
          match = {
            class = "kitty";
          };
          tag = "+term";
        }
        {
          name = "term-opacity";
          match = {
            tag = "term";
          };
          opacity = 0.95;
        }

        # Editors
        {
          name = "tag-editor-emacs";
          match = {
            class = "Emacs";
          };
          tag = "+editor";
        }
        {
          name = "tag-editor-zed";
          match = {
            class = "dev.zed.Zed";
          };
          tag = "+editor";
        }
        {
          name = "tag-editor-vscode";
          match = {
            class = "code-oss";
          };
          tag = "+editor";
        }
        {
          name = "tag-editor-antigravity";
          match = {
            class = "antigravity";
          };
          tag = "+editor";
        }
        {
          name = "editor-workspace";
          match = {
            tag = "editor";
          };
          opaque = true;
          workspace = 2;
        }

        # Browsers
        {
          name = "tag-browser-firefox";
          match = {
            class = "firefox";
          };
          tag = "+browser";
          workspace = 3;
        }
        {
          name = "tag-browser-qutebrowser";
          match = {
            class = "qutebrowser";
          };
          tag = "+browser";
          workspace = 3;
        }
        {
          name = "tag-browser-brave";
          match = {
            class = "brave-browser";
          };
          tag = "+browser";
          workspace = 4;
        }
        {
          name = "tag-browser-chromium";
          match = {
            class = "chromium-browser";
          };
          tag = "+browser";
          workspace = 5;
        }
        {
          name = "browser-opaque";
          match = {
            tag = "browser";
          };
          opaque = true;
        }

        # Documents
        {
          name = "tag-documents-zathura";
          match = {
            class = "org.pwmt.zathura";
          };
          tag = "+documents";
        }
        {
          name = "tag-documents-zotero";
          match = {
            class = "Zotero";
          };
          tag = "+documents";
        }
        {
          name = "tag-documents-obsidian";
          match = {
            class = "obsidian";
          };
          tag = "+documents";
        }
        {
          name = "tag-documents-calibre";
          match = {
            class = "calibre-gui";
          };
          tag = "+documents";
        }
        {
          name = "documents-workspace";
          match = {
            tag = "documents";
          };
          opaque = true;
          workspace = 6;
        }

        # Chat
        {
          name = "tag-chat-telegram";
          match = {
            class = "org.telegram.desktop";
          };
          tag = "+chat";
        }
        {
          name = "tag-chat-discord";
          match = {
            class = "discord";
          };
          tag = "+chat";
        }
        {
          name = "tag-chat-legcord";
          match = {
            class = "legcord";
          };
          tag = "+chat";
        }
        {
          name = "chat-workspace";
          match = {
            tag = "chat";
          };
          opaque = true;
          workspace = 7;
        }

        # Game launchers
        {
          name = "tag-gamelauncher-steam";
          match = {
            class = "steam";
          };
          tag = "+gamelauncher";
        }
        {
          name = "tag-gamelauncher-prism";
          match = {
            class = "org.prismlauncher.PrismLauncher";
          };
          tag = "+gamelauncher";
        }
        {
          name = "gamelauncher-workspace";
          match = {
            tag = "gamelauncher";
          };
          opaque = true;
          workspace = 8;
        }

        # Games
        {
          name = "tag-game-cs2";
          match = {
            class = "^(cs2)$";
          };
          tag = "+game";
        }
        {
          name = "tag-game-minecraft";
          match = {
            class = "Minecraft.*";
          };
          tag = "+game";
        }
        {
          name = "game-fullscreen";
          match = {
            tag = "game";
          };
          fullscreen = true;
          opaque = true;
          immediate = true;
          workspace = 8;
        }

        # mpv
        {
          name = "mpv";
          match = {
            class = "mpv";
          };
          opaque = true;
          fullscreen = true;
          workspace = 4;
        }

        # Spotify
        {
          name = "spotify";
          match = {
            class = "Spotify";
          };
          opaque = true;
          workspace = 4;
        }

        # VMs
        {
          name = "tag-vms-virtmanager";
          match = {
            class = ".virt-manager-wrapped";
          };
          tag = "+vms";
        }
        {
          name = "vms-workspace";
          match = {
            tag = "vms";
          };
          opaque = true;
          workspace = 9;
        }
      ];
    };
  };

  # Clipboard manager
  services.copyq.enable = true;

  # Screenshot
  programs.hyprshot = {
    enable = true;
    saveLocation = "$HOME/Storage/Images/screenshots";
  };

}
