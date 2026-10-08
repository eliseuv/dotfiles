# Netdata: per-second system metrics with history, which the dashboard's Tasks
# panel doesn't keep. Cloud and telemetry are off; the dashboard is open to the
# LAN like Homepage itself.
# Also the streaming parent for GLaDOS (hosts/GLaDOS/netdata.nix), so her
# metrics show up as a second node here and her history lives on this host,
# which is always on.
{ config, pkgs, ... }:
let
  # Her tailnet address, as for her terminal and Pluto: the router hands out no
  # fixed LAN addresses.
  gladosAddress = "100.110.170.42";
in
{

  services.netdata = {
    enable = true;
    enableAnalyticsReporting = false;
    # nixpkgs builds without the dashboard by default (the agent then answers
    # 404 on /). The UI bundle is under Netdata's proprietary NCUL1 license,
    # not GPL; it runs locally and the agent still isn't claimed to the cloud.
    package = pkgs.netdata.override { withCloudUi = true; };
    # The module only symlinks configDir entries, so a rendered secret works.
    configDir."stream.conf" = config.sops.templates."netdata-stream.conf".path;
  };

  # A copy of the key in secrets/GLaDOS.yaml; a stream section is named by the
  # API key it accepts.
  sops.secrets."netdata/stream-key" = { };
  sops.templates."netdata-stream.conf" = {
    content = ''
      [${config.sops.placeholder."netdata/stream-key"}]
          enabled = yes
          allow from = ${gladosAddress}
    '';
    owner = config.services.netdata.user;
    restartUnits = [ "netdata.service" ];
  };

  # The port is LAN-only in the registry; she streams over the tailnet.
  networking.firewall.extraCommands = ''
    iptables -A nixos-fw -i tailscale0 -s ${gladosAddress} -p tcp --dport ${toString config.homelab.services.netdata.port} -j nixos-fw-accept
  '';

  homelab.services.netdata = {
    port = 19999;
    dashboard = {
      name = "Netdata";
      group = "Tools";
      order = 1;
      description = "System metrics";
      icon = "netdata.png";
      widget.type = "netdata";
      unit = "netdata.service";
    };
  };

}
