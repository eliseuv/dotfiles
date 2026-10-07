# Netdata: per-second system metrics with history, which the dashboard's Tasks
# panel doesn't keep. Cloud and telemetry are off; the dashboard is open to the
# LAN like Homepage itself.
{ pkgs, ... }:
{

  services.netdata = {
    enable = true;
    enableAnalyticsReporting = false;
    # nixpkgs builds without the dashboard by default (the agent then answers
    # 404 on /). The UI bundle is under Netdata's proprietary NCUL1 license,
    # not GPL; it runs locally and the agent still isn't claimed to the cloud.
    package = pkgs.netdata.override { withCloudUi = true; };
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
