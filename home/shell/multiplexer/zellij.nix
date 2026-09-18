{ pkgs, ... }:
{

  programs.zellij = {
    enable = true;

    settings = {
      theme = "catppuccin-mocha";
      default_mode = "normal";
      default_layout = "tmux";
      scroll_buffer_size = 10000;
      copy_clipboard = "system";
      copy_on_select = true;
      pane_frames = false;
      auto_layout = false;
      on_force_close = "detach";
    };

    # zjstatus (github.com/dj95/zjstatus) replaces zellij:tab-bar so tabs,
    # mode and session/host/time info render in one Catppuccin Mocha bar.
    # First launch after this changes: approve the pane's RunCommands
    # permission prompt (press "y") so the hostname widget can run.
    layouts.tmux = ''
      layout {
          default_tab_template {
              pane size=1 borderless=true {
                  plugin location="file:${pkgs.zellijPlugins.zjstatus}" {
                      color_base     "#1e1e2e"
                      color_mantle   "#181825"
                      color_text     "#cdd6f4"
                      color_overlay0 "#6c7086"
                      color_overlay2 "#9399b2"
                      color_lavender "#b4befe"
                      color_blue     "#89b4fa"
                      color_peach    "#fab387"
                      color_yellow   "#f9e2af"
                      color_green    "#a6e3a1"
                      color_teal     "#94e2d5"
                      color_maroon   "#eba0ac"
                      color_red      "#f38ba8"

                      format_left   "{mode} #[fg=$lavender,bg=$mantle,bold]{session} "
                      format_center "{tabs}"
                      format_right  "{command_hostname}{datetime}"
                      format_space  "#[bg=$mantle]"

                      border_enabled "false"

                      mode_normal          "#[fg=$base,bg=$blue,bold] NORMAL "
                      mode_locked          "#[fg=$base,bg=$red,bold] LOCKED "
                      mode_resize          "#[fg=$base,bg=$yellow,bold] RESIZE "
                      mode_scroll          "#[fg=$base,bg=$green,bold] SCROLL "
                      mode_enter_search    "#[fg=$base,bg=$teal,bold] SEARCH "
                      mode_search          "#[fg=$base,bg=$teal,bold] SEARCH "
                      mode_rename_tab      "#[fg=$base,bg=$maroon,bold] RENAME "
                      mode_tmux            "#[fg=$base,bg=$peach,bold] TMUX "
                      mode_default_to_mode "normal"

                      tab_normal    "#[fg=$overlay0,bg=$mantle] {index} {name} "
                      tab_active    "#[fg=$base,bg=$lavender,bold] {index} {name} "
                      tab_separator "#[fg=$overlay0,bg=$mantle]│"

                      command_hostname_command    "hostname"
                      command_hostname_format     "#[fg=$overlay2,bg=$mantle] {stdout} "
                      command_hostname_interval   "0"
                      command_hostname_rendermode "static"

                      datetime          "#[fg=$text,bg=$mantle,bold] {format} "
                      datetime_format   "%Y-%m-%d %H:%M"
                      datetime_timezone "America/Sao_Paulo"
                  }
              }
              children
          }
          pane
      }
    '';

    # Clear Zellij's shortcuts so ordinary shell/editor keys pass through.
    # NewTab/NewPane inherit the focused pane's cwd; tabs are numbered from 1.
    extraConfig = ''
      keybinds clear-defaults=true {
          normal {
              bind "`" { SwitchToMode "Tmux"; }
              bind "Ctrl a" { Write 96; }
              bind "Ctrl Shift h" { GoToPreviousTab; }
              bind "Ctrl Shift l" { GoToNextTab; }
          }
          tmux {
              bind "Esc" "Ctrl c" { SwitchToMode "Normal"; }
              bind "`" "Ctrl a" { Write 96; SwitchToMode "Normal"; }
              bind "c" { NewTab; SwitchToMode "Normal"; }
              bind "h" { ToggleTab; SwitchToMode "Normal"; }
              bind "l" "%" { NewPane "Right"; SwitchToMode "Normal"; }
              bind "j" "\"" { NewPane "Down"; SwitchToMode "Normal"; }
              bind "k" { ToggleFloatingPanes; SwitchToMode "Normal"; }
              bind "n" { GoToNextTab; SwitchToMode "Normal"; }
              bind "p" { GoToPreviousTab; SwitchToMode "Normal"; }
              bind "1" { GoToTab 1; SwitchToMode "Normal"; }
              bind "2" { GoToTab 2; SwitchToMode "Normal"; }
              bind "3" { GoToTab 3; SwitchToMode "Normal"; }
              bind "4" { GoToTab 4; SwitchToMode "Normal"; }
              bind "5" { GoToTab 5; SwitchToMode "Normal"; }
              bind "6" { GoToTab 6; SwitchToMode "Normal"; }
              bind "7" { GoToTab 7; SwitchToMode "Normal"; }
              bind "8" { GoToTab 8; SwitchToMode "Normal"; }
              bind "9" { GoToTab 9; SwitchToMode "Normal"; }
              bind "Left" { MoveFocus "Left"; SwitchToMode "Normal"; }
              bind "Down" { MoveFocus "Down"; SwitchToMode "Normal"; }
              bind "Up" { MoveFocus "Up"; SwitchToMode "Normal"; }
              bind "Right" { MoveFocus "Right"; SwitchToMode "Normal"; }
              bind "o" { FocusNextPane; SwitchToMode "Normal"; }
              bind ";" { FocusLastPane; SwitchToMode "Normal"; }
              bind "z" { ToggleFocusFullscreen; SwitchToMode "Normal"; }
              bind "!" { BreakPane; SwitchToMode "Normal"; }
              bind "Space" { NextSwapLayout; SwitchToMode "Normal"; }
              // Zellij's native close action does not ask for confirmation.
              bind "x" { CloseFocus; SwitchToMode "Normal"; }
              bind "d" { Detach; SwitchToMode "Normal"; }
              bind "," { SwitchToMode "RenameTab"; TabNameInput 0; }
              bind "[" { SwitchToMode "Scroll"; }
              bind "w" "s" {
                  LaunchOrFocusPlugin "zellij:session-manager" {
                      floating true
                      move_to_focused_tab true
                  }
                  SwitchToMode "Normal"
              }
              // Persistent vi resize mode replaces tmux's timed repeat keys.
              bind "r" { SwitchToMode "Resize"; }
          }
          resize {
              bind "h" "Left" { Resize "Increase Left"; }
              bind "j" "Down" { Resize "Increase Down"; }
              bind "k" "Up" { Resize "Increase Up"; }
              bind "l" "Right" { Resize "Increase Right"; }
              bind "=" "+" { Resize "Increase"; }
              bind "-" { Resize "Decrease"; }
              bind "Enter" "Esc" "Ctrl c" { SwitchToMode "Normal"; }
          }
          renametab {
              bind "Enter" { SwitchToMode "Normal"; }
              bind "Esc" "Ctrl c" { UndoRenameTab; SwitchToMode "Normal"; }
          }
          shared_among "scroll" "search" {
              bind "j" "Down" { ScrollDown; }
              bind "k" "Up" { ScrollUp; }
              bind "Ctrl b" "PageUp" { PageScrollUp; }
              bind "Ctrl f" "PageDown" { PageScrollDown; }
              bind "Ctrl u" { HalfPageScrollUp; }
              bind "Ctrl d" { HalfPageScrollDown; }
              bind "g" { ScrollToTop; }
              bind "G" { ScrollToBottom; }
              bind "/" { SwitchToMode "EnterSearch"; SearchInput 0; }
              bind "y" { Copy; ScrollToBottom; SwitchToMode "Normal"; }
              bind "e" { EditScrollback; SwitchToMode "Normal"; }
              bind "q" "Esc" "Ctrl c" { ScrollToBottom; SwitchToMode "Normal"; }
          }
          entersearch {
              bind "Enter" { SwitchToMode "Search"; }
              bind "Esc" "Ctrl c" { SwitchToMode "Scroll"; }
          }
          search {
              bind "n" { Search "down"; }
              bind "N" { Search "up"; }
          }
      }
    '';
  };

  # Native floating panes replace floax, but do not reproduce its sizing or
  # cross-tab scratchpad. zjstatus (in the tmux layout above) replaces
  # zellij:tab-bar and covers what the built-in bar lacked (hostname/time).
  # Fingers (U/H/E and Alt-h/j/k/l/o), tmuxinator (T), and vim-tmux-navigator
  # need separate Zellij integrations. Keep Ctrl-h/j/k/l available to Neovim.
  # Scroll mode supports vi motion/search; select text with the mouse to copy.
  home.shellAliases = {
    zj = "zellij attach --create";
    zja = "zellij attach";
    zjn = "zellij --session";
    zjl = "zellij list-sessions";
  };

}
