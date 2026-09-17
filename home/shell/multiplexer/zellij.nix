{ ... }:
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

    layouts.tmux = ''
      layout {
          default_tab_template {
              pane size=1 borderless=true {
                  plugin location="zellij:tab-bar"
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
  # cross-tab scratchpad. The built-in bar does not show application/uptime.
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
