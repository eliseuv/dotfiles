# Runs ~/Services/ledger's web app (see pkgs/ledger-web/default.nix) as a
# boot-time system service, backed by its own local Postgres instance.
{
  config,
  lib,
  pkgs,
  ...
}:

let
  ledgerWeb = config.homelab.ledger.package;
in
{

  # An option rather than a plain import so evaluation elsewhere can swap it
  # out: the default fetches from a repo that only exists on this host (see
  # the Justfile's eval-all).
  options.homelab.ledger.package = lib.mkOption {
    type = lib.types.attrsOf lib.types.package;
    default = import ../../../../../pkgs/ledger-web { inherit pkgs; };
    description = "ledger-web build outputs: `bin` and `webUi`.";
  };

  config = {

    # 3000 is taken by ttyd (services/ttyd.nix).
    homelab.services.ledger = {
      port = 3001;
      expose = "tailnet";
      dashboard = {
        name = "Ledger";
        group = "Tools";
        order = 2;
        description = "Ledger web app";
        icon = "mdi-cash-multiple";
        unit = "ledger-web.service";
      };
    };

    services.postgresql = {
      enable = true;
      ensureDatabases = [ "ledger" ];
      ensureUsers = [
        {
          name = "ledger";
          ensureDBOwnership = true;
        }
      ];
      # Lets evf's dev server (ledger's `just dev-live`) connect as `ledger`, so
      # tables its bootstrap creates stay owned by the role the service uses.
      # The service's own user must be mapped too: with map= set, the default
      # same-name identity no longer applies.
      identMap = ''
        ledger ledger ledger
        ledger evf    ledger
      '';
      authentication = ''
        local ledger ledger peer map=ledger
      '';
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
        PORT = toString config.homelab.services.ledger.port;
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

  };

}
