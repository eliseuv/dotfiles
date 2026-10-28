# Aven sync server for the devices that run aven (home/aven.nix). Payloads
# are end-to-end encrypted by the clients, so this host stores tasks it cannot
# read; it is not a backup, since only the devices hold the keys.
#
# Plain HTTP on the tailnet address, as upstream recommends for a VPN: no TLS
# to manage and nothing reachable from outside the tailnet.
#
# One-time setup, as the service user so the storage is theirs, then start it
# (the unit is skipped until the storage exists):
#   sudo -u aven aven server setup --data <dataPath> --url <url> --invitation-only
#   sudo systemctl start aven-server
# The invitation it prints claims the server; paste it straight into
# `aven sync setup` on the source device, never into a log or a commit.
{
  config,
  inputs,
  pkgs,
  ...
}:
let
  package = inputs.aven.packages.${pkgs.stdenv.hostPlatform.system}.default;
  port = 3746;
  address = config.homelab.network.tailnetAddress;
  stateDirectory = "aven-server";
  dataPath = "/var/lib/${stateDirectory}/sync-server.sqlite";
in
{

  # A static user, not DynamicUser, so the setup above can run as it.
  users.users.aven = {
    isSystemUser = true;
    group = "aven";
  };
  users.groups.aven = { };

  environment.systemPackages = [ package ];

  # Created here rather than by StateDirectory=, which only exists once the
  # unit runs, and the unit waits for setup to have written into it.
  systemd.tmpfiles.settings.aven-server."/var/lib/${stateDirectory}".d = {
    user = "aven";
    group = "aven";
    mode = "0700";
  };

  systemd.services.aven-server = {
    description = "Aven sync server";
    wantedBy = [ "multi-user.target" ];
    after = [
      "network-online.target"
      "tailscaled.service"
      "tailscale-up-at-boot.service"
    ];
    wants = [ "network-online.target" ];
    unitConfig.ConditionPathExists = dataPath;
    serviceConfig = {
      ExecStart = "${package}/bin/aven server --bind ${address}:${toString port} --data ${dataPath}";
      User = "aven";
      Group = "aven";
      StateDirectory = stateDirectory;
      StateDirectoryMode = "0700";
      # The tailnet address may not be assigned yet at boot; binding fails
      # until it is, so retry instead of giving up.
      Restart = "on-failure";
      RestartSec = 5;
      NoNewPrivileges = true;
      ProtectSystem = "strict";
      ProtectHome = true;
      PrivateTmp = true;
      PrivateDevices = true;
    };
  };

  homelab.services.aven = {
    inherit port;
    expose = "tailnet";
  };

}
