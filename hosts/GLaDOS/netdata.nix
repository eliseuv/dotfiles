# Netdata as a streaming child of wheatley's (hosts/wheatley/services/
# netdata.nix): her metrics are viewed and kept there, so nothing is stored or
# served here, and alerts are left to the parent, which also notices when she
# goes away.
{ config, ... }:
{

  services.netdata = {
    enable = true;
    enableAnalyticsReporting = false;
    config = {
      db.mode = "none";
      web.mode = "none";
      health.enabled = "no";
    };
    # The module only symlinks configDir entries, so a rendered secret works.
    configDir."stream.conf" = config.sops.templates."netdata-stream.conf".path;
  };

  # A copy of the key in secrets/wheatley.yaml. The destination is wheatley's
  # tailnet address (homelab.network.tailnetAddress in her system.nix), whose
  # firewall accepts this stream only over the tailnet.
  sops.secrets."netdata/stream-key" = { };
  sops.templates."netdata-stream.conf" = {
    content = ''
      [stream]
          enabled = yes
          destination = 100.97.1.97:19999
          api key = ${config.sops.placeholder."netdata/stream-key"}
    '';
    owner = config.services.netdata.user;
    restartUnits = [ "netdata.service" ];
  };

}
