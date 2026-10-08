{
  config,
  lib,
  pkgs,
  ...
}:
let
  # By MagicDNS name (wheatley's homelab.network.tailnetDomain): the
  # dashboard's allowed hosts admit it, and it works wherever the tailnet does.
  dashboardUrl = "http://wheatley.taild628c9.ts.net/";
in
{

  # Kiosk: cage runs a single full-screen Firefox on the laptop panel, logged
  # in as the primary user so its profile keeps the dashboard's basic-auth
  # login. A whole desktop (my.desktop) would bring audio, printing and
  # several browsers this machine has no use for. Ctrl-Alt-F2 reaches a
  # console.
  services.cage = {
    enable = true;
    user = config.my.host.primaryUser;
    program = "${lib.getExe config.programs.firefox.package} --kiosk ${dashboardUrl}";
  };
  # The first load needs the tailnet up, or it lands on an error page.
  systemd.services.cage-tty1 = {
    wants = [ "network-online.target" ];
    after = [
      "network-online.target"
      "tailscale-up-at-boot.service"
    ];
  };

  programs.firefox = {
    enable = true;
    # Nothing but the dashboard: no welcome or what's-new tabs, no prompts
    policies = {
      OverrideFirstRunPage = "";
      OverridePostUpdatePage = "";
      DontCheckDefaultBrowser = true;
      DisableTelemetry = true;
      DisableFirefoxStudies = true;
      DisablePocket = true;
    };
  };

  # Its ttyd runs a shell as evf, so only wheatley (its reverse proxy) may
  # reach it, over the tailnet; as for GLaDOS (hosts/GLaDOS/system.nix).
  networking.firewall.extraCommands = ''
    iptables -A nixos-fw -i tailscale0 -s 100.97.1.97 -p tcp --dport ${toString config.my.services.ttyd.port} -j nixos-fw-accept
  '';

  # No swap partition; Firefox plus a local switch can outgrow 8GB
  zramSwap.enable = true;

  # Remove bootloader timeout
  boot.loader.timeout = 0;

  # Runs with the lid closed or open, never suspends on it
  services.logind.settings.Login = {
    HandleLidSwitch = "ignore";
    HandleLidSwitchDocked = "ignore";
  };

}
