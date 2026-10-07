# Netdata: per-second system metrics with history, which the dashboard's Tasks
# panel doesn't keep. Cloud and telemetry are off; the dashboard is open to the
# LAN like Homepage itself.
{ ... }:
{

  services.netdata = {
    enable = true;
    enableAnalyticsReporting = false;
  };

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
