# evf on chell. Caps as Esc per session, standing in for kanata, which is
# off here because it would remap dani's keyboard too (system.nix). Loses
# kanata's Esc-to-backtick, which xkb has no option for.
{ lib, ... }:
{

  wayland.windowManager.hyprland.settings.config.input.kb_options =
    lib.mkForce "grp:alt_shift_toggle,caps:escape";

  # For the odd GNOME session
  dconf.settings."org/gnome/desktop/input-sources".xkb-options = [ "caps:escape" ];

}
