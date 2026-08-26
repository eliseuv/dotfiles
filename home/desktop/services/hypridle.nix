{ ... }:
{

  services.hypridle = {
    enable = true;
    settings = {

      general = {
        lock_cmd = "pidof hyprlock || hyprlock";
        after_sleep_cmd = ''hyprctl dispatch 'hl.dsp.dpms, "on"' '';
        ignore_dbus_inhibit = false;
      };

      listener = [
        # Dim screen
        {
          timeout = 300; # 5 minutes
          on-timeout = "brightnessctl -s set 10";
          on-resume = "brightnessctl -r";
        }

        # Turn off screen
        {
          timeout = 600; # 10 minutes
          on-timeout = ''hyprctl dispatch 'hl.dsp.dpms, "off"' '';
          on-resume = ''hyprctl dispatch 'hl.dsp.dpms, "on"' '';
        }

        # Lock screen
        {
          timeout = 900; # 15 minutes
          on-timeout = "hyprlock";
        }
      ];

    };
  };

}
