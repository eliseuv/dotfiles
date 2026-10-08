# Netdata as a streaming child of wheatley's (hosts/wheatley/services/
# netdata.nix), like GLaDOS: its metrics are viewed and kept there, so nothing
# is stored or served here, and alerts are left to the parent, which also
# notices when it goes away.
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

  # Shared with wheatley through secrets/shared/netdata.yaml. The destination
  # is wheatley's tailnet address (homelab.network.tailnetAddress in
  # his system.nix), whose firewall accepts this stream only over the
  # tailnet.
  sops.secrets."netdata/stream-key".sopsFile = ../../secrets/shared/netdata.yaml;
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
