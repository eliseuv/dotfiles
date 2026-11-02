{
  config,
  lib,
  pkgs,
  ...
}:
{

  config = lib.mkIf config.my.desktop.enable {

    # Default GUI programs
    programs.firefox.enable = true;

    environment.systemPackages = with pkgs; [ xterm ];

    services.displayManager.defaultSession = config.my.desktop.defaultSession;

    # Audio
    security.rtkit = {
      enable = true;
      # Hyprland takes SCHED_RR through rtkit and sizes its RLIMIT_RTTIME from
      # rtkit's RTTimeUSecMax. The default 200ms hard limit is shorter than an
      # NVIDIA DPMS-off modeset can keep its main thread busy, and crossing it
      # is an uncatchable SIGKILL. The soft limit still drops it out of RT
      # first; the cost is a runaway RT thread holding a core for up to 2s.
      args = [ "--rttime-usec-max=2000000" ];
    };
    services.pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;
    };

    # Removable and network disks
    services = {
      udisks2.enable = true;
      gvfs.enable = true;
      devmon.enable = true;
      samba.enable = true;
    };

    # Enable CUPS to print documents.
    services.printing = {
      enable = true;
      drivers = with pkgs; [
        hplip
      ];
    };

  };

}
