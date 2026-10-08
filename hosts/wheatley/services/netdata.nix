# Netdata: per-second system metrics with history, which the dashboard's Tasks
# panel doesn't keep. Cloud and telemetry are off; the dashboard is open to the
# LAN like Homepage itself.
# Also the streaming parent for GLaDOS and rattmann (hosts/<child>/netdata.nix),
# so their metrics show up as further nodes here and their history lives on
# this host, which is always on.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  # Tailnet addresses of the children, as for GLaDOS's terminal and Pluto: the
  # router hands out no fixed LAN addresses. A null one (not yet on the
  # tailnet) is left out of the allow list and the firewall.
  children = lib.filterAttrs (_: address: address != null) {
    GLaDOS = "100.110.170.42";
    # TODO: rattmann's tailnet address once he has joined (`tailscale up`)
    rattmann = null;
  };

  # Charts for the tile's second row, all fetched in one allmetrics request:
  # what the header's resources widget doesn't show. Sensor names are this
  # Dell's (dell_smm, coretemp); enp7s0f1 carries the default route.
  charts = {
    cpuTemp = "sensors.temperature_coretemp-isa-0000_temp1_Package_id_0_input";
    fan = "sensors.fan_dell_smm-isa-0000_fan1_Processor_Fan_input";
    lan = "net.enp7s0f1";
  };
  # customapi reads a string field as a dotted path, which chart names would
  # break; a nested attrset is followed key by key instead.
  value = chart: dimension: { ${chart}.dimensions.${dimension} = "value"; };
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

  # Shared with the children through secrets/shared/netdata.yaml; a stream
  # section is named by the API key it accepts.
  sops.secrets."netdata/stream-key".sopsFile = ../../../secrets/shared/netdata.yaml;
  sops.templates."netdata-stream.conf" = {
    content = ''
      [${config.sops.placeholder."netdata/stream-key"}]
          enabled = yes
          allow from = ${lib.concatStringsSep " " (lib.attrValues children)}
    '';
    owner = config.services.netdata.user;
    restartUnits = [ "netdata.service" ];
  };

  # The port is LAN-only in the registry; the children stream over the tailnet.
  networking.firewall.extraCommands = lib.concatMapStrings (address: ''
    iptables -A nixos-fw -i tailscale0 -s ${address} -p tcp --dport ${toString config.homelab.services.netdata.port} -j nixos-fw-accept
  '') (lib.attrValues children);

  homelab.services.netdata = {
    port = 19999;
    dashboard = {
      name = "Netdata";
      group = "Tools";
      order = 1;
      description = "System metrics";
      icon = "netdata.png";
      widget.type = "netdata";
      extraWidgets = [
        {
          type = "customapi";
          url = "http://127.0.0.1:${toString config.homelab.services.netdata.port}/api/v1/allmetrics?format=json&filter=${lib.concatStringsSep "%20" (lib.attrValues charts)}";
          mappings = [
            {
              label = "CPU temp";
              field = value charts.cpuTemp "input";
              format = "number";
              suffix = "°C";
            }
            {
              label = "Fan";
              field = value charts.fan "input";
              format = "number";
              suffix = "RPM";
            }
            # Netdata reports kilobits/s, and sent as negative.
            {
              label = "LAN ↓";
              field = value charts.lan "received";
              format = "bitrate";
              scale = 1000;
            }
            {
              label = "LAN ↑";
              field = value charts.lan "sent";
              format = "bitrate";
              scale = -1000;
            }
          ];
        }
      ];
      unit = "netdata.service";
    };
  };

}
