# Modeled after tmux.nix; kept in sync with
# ~/Projects/windows-dotfiles/zellij/config.kdl (the Windows port of this
# same tmux reference).
#
# Settings from that reference with no Zellij equivalent (checked, not
# missed):
#   - escapeTime / focusEvents / clock24: no matching settings.* option
#     exists. repeat-time's equivalent is the persistent Resize mode instead
#     (see the tmux-mode "r" binding below) rather than a timed repeat window.
#   - terminal-overrides ",*:RGB" (Neovim color fix): no equivalent knob;
#     Zellij's own terminal handling doesn't need one.
#   - tmux-fingers (URL/hash/path picker) and tmux-floax's specific
#     90%/90% floating-pane sizing: no bundled Zellij plugin/setting
#     equivalent (native floating panes, bound to "k" below, replace floax's
#     core function but not its sizing or cross-tab scratchpad).
#   - tmuxinator-cwd / smug (session-template launchers): no Zellij
#     equivalent. Zellij's own bundled session-manager plugin (reachable via
#     "w" then "s" below) and its native layouts cover similar ground.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  # Typed builders for Zellij's KDL keybind nodes (see home-manager's toKDL:
  # _args are positional arguments, _props are key=value properties and
  # _children keeps node order, which also allows repeated node names).
  bind = keys: actions: {
    bind = {
      _args = keys;
      _children = actions;
    };
  };
  unbind = key: { unbind._args = [ key ]; };
  action = name: args: { ${name}._args = args; };
  bare = name: { ${name} = { }; };
  switchTo = mode: action "SwitchToMode" [ mode ];
  moveFocus = direction: action "MoveFocus" [ direction ];
  resize = direction: action "Resize" [ direction ];

  # Most Tmux-mode binds run one action and drop back to Normal mode.
  bindThenNormal = keys: actions: bind keys (actions ++ [ (switchTo "Normal") ]);

  navigationBinds = [
    (bind [ "Ctrl h" ] [ (moveFocus "Left") ])
    (bind [ "Ctrl j" ] [ (moveFocus "Down") ])
    (bind [ "Ctrl k" ] [ (moveFocus "Up") ])
    (bind [ "Ctrl l" ] [ (moveFocus "Right") ])
    (bind [ "Ctrl Shift h" ] [ (bare "GoToPreviousTab") ])
    (bind [ "Ctrl Shift l" ] [ (bare "GoToNextTab") ])
    (bind [ "Ctrl a" ] [ (action "Write" [ 96 ]) ])
  ];

  # zjstatus (github.com/dj95/zjstatus) replaces zellij:tab-bar so tabs,
  # mode and session/host/time info render in one Catppuccin Mocha bar.
  # First launch after this changes: approve the pane's RunCommands
  # permission prompt (press "y") so the hostname widget can run.
  statusBar = {
    pane = {
      _props = {
        size = 1;
        borderless = true;
      };
      plugin = {
        _props.location = "file:${pkgs.zellijPlugins.zjstatus}";

        color_base = "#1e1e2e";
        color_mantle = "#181825";
        color_text = "#cdd6f4";
        color_overlay0 = "#6c7086";
        color_overlay2 = "#9399b2";
        color_lavender = "#b4befe";
        color_blue = "#89b4fa";
        color_peach = "#fab387";
        color_yellow = "#f9e2af";
        color_green = "#a6e3a1";
        color_teal = "#94e2d5";
        color_maroon = "#eba0ac";
        color_red = "#f38ba8";

        format_left = "{mode} #[fg=$lavender,bg=$mantle,bold]{session} ";
        format_center = "{tabs}";
        format_right = "{command_hostname}{datetime}";
        format_space = "#[bg=$mantle]";

        border_enabled = "false";

        mode_normal = "#[fg=$base,bg=$blue,bold] NORMAL ";
        mode_locked = "#[fg=$base,bg=$red,bold] LOCKED ";
        mode_resize = "#[fg=$base,bg=$yellow,bold] RESIZE ";
        mode_scroll = "#[fg=$base,bg=$green,bold] SCROLL ";
        mode_enter_search = "#[fg=$base,bg=$teal,bold] SEARCH ";
        mode_search = "#[fg=$base,bg=$teal,bold] SEARCH ";
        mode_rename_tab = "#[fg=$base,bg=$maroon,bold] RENAME ";
        mode_tmux = "#[fg=$base,bg=$peach,bold] TMUX ";
        mode_default_to_mode = "normal";

        tab_normal = "#[fg=$overlay0,bg=$mantle] {index} {name} ";
        tab_active = "#[fg=$base,bg=$lavender,bold] {index} {name} ";
        tab_separator = "#[fg=$overlay0,bg=$mantle]│";

        command_hostname_command = "hostname";
        command_hostname_format = "#[fg=$overlay2,bg=$mantle] {stdout} ";
        command_hostname_interval = "0";
        command_hostname_rendermode = "static";

        datetime = "#[fg=$text,bg=$mantle,bold] {format} ";
        datetime_format = "%Y-%m-%d %H:%M";
        datetime_timezone = "America/Sao_Paulo";
      };
    };
  };

  # ToggleFloatingPanes cannot size the pane it reveals (new floating panes
  # default to 50%), so each tab declares its own hidden 90% floating pane.
  floatingPanes.floating_panes.pane._props = {
    x = "5%";
    y = "5%";
    width = "90%";
    height = "90%";
  };

  tabBody = [
    statusBar
    { pane = { }; }
    floatingPanes
  ];
in
{

  programs.zellij = {
    enable = true;

    settings = {
      theme = "catppuccin-${config.my.theme.flavor}";
      default_mode = "normal";
      default_layout = "tmux";
      scroll_buffer_size = 10000;
      copy_clipboard = "system";
      copy_on_select = true;
      pane_frames = true;
      pane_frame_style = "titles";
    };

    # No default_tab_template: it would override the tab's hide_floating_panes,
    # so the launch tab and later tabs (new_tab_template) share one body.
    layouts.tmux.layout._children = [
      {
        tab = {
          _props.hide_floating_panes = true;
          _children = tabBody;
        };
      }
      {
        new_tab_template = {
          _props.hide_floating_panes = true;
          _children = tabBody;
        };
      }
    ];

    # Only Normal mode clears Zellij's defaults outright, so ordinary
    # shell/editor keys pass through everywhere else Zellij isn't reachable
    # via the backtick prefix. Other modes layer overrides on top of Zellij's
    # own (already tmux-flavored) defaults instead of reimplementing them.
    # NewTab/NewPane inherit the focused pane's cwd; tabs are numbered from 1.
    settings.keybinds._children = [
      # A shared_except block elsewhere in this file does not reliably
      # reach a mode declared with clear-defaults=true (verified: only
      # bindings written directly inside a mode's own block apply to
      # it), so every bind this mode needs has to be restated here
      # instead of relying on the shared_except "locked" block below.
      {
        normal = {
          _props.clear-defaults = true;
          _children = [ (bind [ "`" ] [ (switchTo "Tmux") ]) ] ++ navigationBinds;
        };
      }

      # From any other reachable mode, backtick jumps straight into
      # Tmux mode too (Normal already handles its own case above).
      {
        shared_except = {
          _args = [
            "normal"
            "tmux"
            "locked"
          ];
          _children = [
            (unbind "Ctrl b")
            (bind [ "`" ] [ (switchTo "Tmux") ])
          ];
        };
      }

      # Unprefixed vi-style pane navigation (vim-tmux-navigator-style,
      # at the Zellij level rather than left to Neovim).
      {
        shared_except = {
          _args = [
            "move"
            "locked"
          ];
          _children = map unbind [
            "Ctrl h"
            "Ctrl j"
            "Ctrl k"
            "Ctrl l"
          ];
        };
      }
      {
        shared_except = {
          _args = [ "locked" ];
          _children = navigationBinds;
        };
      }

      {
        tmux._children = [
          (bind
            [
              "Esc"
              "Ctrl c"
            ]
            [ (switchTo "Normal") ]
          )
          (bind
            [
              "`"
              "Ctrl a"
            ]
            [
              (action "Write" [ 96 ])
              (switchTo "Normal")
            ]
          )
          (bindThenNormal [ "c" ] [ (bare "NewTab") ])
          (bindThenNormal [ "h" ] [ (bare "ToggleTab") ])
          (bindThenNormal [ "b" ] [ (bare "GoToPreviousTab") ])
          (bindThenNormal [ "l" "%" ] [ (action "NewPane" [ "Right" ]) ])
          (bindThenNormal [ "j" "\"" ] [ (action "NewPane" [ "Down" ]) ])
          (bindThenNormal [ "k" ] [ (bare "ToggleFloatingPanes") ])
          (bindThenNormal [ "n" ] [ (bare "GoToNextTab") ])
          (bindThenNormal [ "p" ] [ (bare "GoToPreviousTab") ])
        ]
        ++ map (tabNumber: bindThenNormal [ (toString tabNumber) ] [ (action "GoToTab" [ tabNumber ]) ]) (
          lib.range 1 9
        )
        ++ [
          (bindThenNormal [ "Left" ] [ (moveFocus "Left") ])
          (bindThenNormal [ "Down" ] [ (moveFocus "Down") ])
          (bindThenNormal [ "Up" ] [ (moveFocus "Up") ])
          (bindThenNormal [ "Right" ] [ (moveFocus "Right") ])
          (bindThenNormal [ "o" ] [ (bare "FocusNextPane") ])
          (bindThenNormal [ ";" ] [ (bare "FocusLastPane") ])
          (bindThenNormal [ "z" ] [ (bare "ToggleFocusFullscreen") ])
          (bindThenNormal [ "!" ] [ (bare "BreakPane") ])
          (bindThenNormal [ "Space" ] [ (bare "NextSwapLayout") ])
          # Zellij's native close action does not ask for confirmation.
          (bindThenNormal [ "x" ] [ (bare "CloseFocus") ])
          (bindThenNormal [ "d" ] [ (bare "Detach") ])
          (bind
            [ "," ]
            [
              (switchTo "RenameTab")
              (action "TabNameInput" [ 0 ])
            ]
          )
          (bind [ "[" ] [ (switchTo "Scroll") ])
          (bindThenNormal
            [
              "w"
              "s"
            ]
            [
              {
                LaunchOrFocusPlugin = {
                  _args = [ "zellij:session-manager" ];
                  floating = true;
                  move_to_focused_tab = true;
                };
              }
            ]
          )
          # Persistent vi resize mode replaces tmux's timed repeat keys.
          (bind [ "r" ] [ (switchTo "Resize") ])
        ];
      }
      {
        resize._children = [
          (bind
            [
              "h"
              "Left"
            ]
            [ (resize "Increase Left") ]
          )
          (bind
            [
              "j"
              "Down"
            ]
            [ (resize "Increase Down") ]
          )
          (bind
            [
              "k"
              "Up"
            ]
            [ (resize "Increase Up") ]
          )
          (bind
            [
              "l"
              "Right"
            ]
            [ (resize "Increase Right") ]
          )
          (bind
            [
              "="
              "+"
            ]
            [ (resize "Increase") ]
          )
          (bind [ "-" ] [ (resize "Decrease") ])
          (bind
            [
              "Enter"
              "Esc"
              "Ctrl c"
            ]
            [ (switchTo "Normal") ]
          )
        ];
      }
      {
        renametab._children = [
          (bind [ "Enter" ] [ (switchTo "Normal") ])
          (bind
            [
              "Esc"
              "Ctrl c"
            ]
            [
              (bare "UndoRenameTab")
              (switchTo "Normal")
            ]
          )
        ];
      }
      {
        shared_among = {
          _args = [
            "scroll"
            "search"
          ];
          _children = [
            (bind
              [
                "j"
                "Down"
              ]
              [ (bare "ScrollDown") ]
            )
            (bind
              [
                "k"
                "Up"
              ]
              [ (bare "ScrollUp") ]
            )
            (bind
              [
                "Ctrl b"
                "PageUp"
              ]
              [ (bare "PageScrollUp") ]
            )
            (bind
              [
                "Ctrl f"
                "PageDown"
              ]
              [ (bare "PageScrollDown") ]
            )
            (bind [ "Ctrl u" ] [ (bare "HalfPageScrollUp") ])
            (bind [ "Ctrl d" ] [ (bare "HalfPageScrollDown") ])
            (bind [ "g" ] [ (bare "ScrollToTop") ])
            (bind [ "G" ] [ (bare "ScrollToBottom") ])
            (bind
              [ "/" ]
              [
                (switchTo "EnterSearch")
                (action "SearchInput" [ 0 ])
              ]
            )
            (bind
              [ "y" ]
              [
                (bare "Copy")
                (bare "ScrollToBottom")
                (switchTo "Normal")
              ]
            )
            (bind
              [ "e" ]
              [
                (bare "EditScrollback")
                (switchTo "Normal")
              ]
            )
            (bind
              [
                "q"
                "Esc"
                "Ctrl c"
              ]
              [
                (bare "ScrollToBottom")
                (switchTo "Normal")
              ]
            )
          ];
        };
      }
      {
        entersearch._children = [
          (bind [ "Enter" ] [ (switchTo "Search") ])
          (bind
            [
              "Esc"
              "Ctrl c"
            ]
            [ (switchTo "Scroll") ]
          )
        ];
      }
      {
        search._children = [
          (bind [ "n" ] [ (action "Search" [ "down" ]) ])
          (bind [ "N" ] [ (action "Search" [ "up" ]) ])
        ];
      }
    ];
  };

  # Native floating panes replace floax, but do not reproduce its sizing or
  # cross-tab scratchpad. zjstatus (in the tmux layout above) replaces
  # zellij:tab-bar and covers what the built-in bar lacked (hostname/time).
  # Fingers (U/H/E and Alt-h/j/k/l/o) and tmuxinator (T) still need separate
  # Zellij integrations. Ctrl-h/j/k/l now does pane navigation at the Zellij
  # level (see extraConfig above), so Neovim's vim-tmux-navigator should defer
  # to it rather than also claiming those keys.
  # Scroll mode supports vi motion/search; select text with the mouse to copy.
  home.shellAliases = {
    zj = "zellij attach --create";
    zja = "zellij attach";
    zjn = "zellij --session";
    zjl = "zellij list-sessions";
  };

}
