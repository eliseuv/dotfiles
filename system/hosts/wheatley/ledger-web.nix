# Runs ~/Services/ledger's web app (see pkgs/ledger-web/default.nix) as a
# boot-time system service, backed by its own local Postgres instance.
{ pkgs, inputs, ... }:

let
  ledgerWeb = import ../../../pkgs/ledger-web { inherit pkgs inputs; };
in
{

  services.postgresql = {
    enable = true;
    ensureDatabases = [ "ledger" ];
    ensureUsers = [
      {
        name = "ledger";
        ensureDBOwnership = true;
      }
    ];
  };

  users.groups.ledger = { };
  users.users.ledger = {
    isSystemUser = true;
    group = "ledger";
  };

  systemd.services.ledger-web = {
    description = "ledger web app";
    after = [
      "network.target"
      "postgresql.service"
    ];
    wants = [ "postgresql.service" ];
    wantedBy = [ "multi-user.target" ];

    environment = {
      # Peer-authenticated over the unix socket as the `ledger` system user.
      # The username must be explicit: sqlx doesn't resolve it from the
      # connecting OS user when omitted, so peer auth fails without it.
      DATABASE_URL = "postgres://ledger@localhost/ledger?host=/run/postgresql";
      # 3000 is taken by ttyd (see wheatley's configuration.nix firewall
      # comment).
      PORT = "3001";
      # No auth on this app — bound wide open on the LAN deliberately, per
      # request, since wheatley's network is trusted.
      BIND_ADDR = "0.0.0.0";
      STATIC_DIR = "${ledgerWeb.webUi}/dist";
    };

    serviceConfig = {
      User = "ledger";
      Group = "ledger";
      ExecStart = "${ledgerWeb.bin}/bin/ledger-web";
      Restart = "on-failure";
    };
  };

}
