# Beszel hub: system metrics with history and alerts for wheatley, GLaDOS, rattmann
# and chell. It polls their agents (modules/nixos/services/beszel-agent.nix)
# over SSH: wheatley's on loopback, the others' over the tailnet. Open to the
# LAN like Homepage itself.
#
# The systems come from config.yml rather than the UI. The hub syncs it on
# every start and deletes any system it doesn't list, keyed by name, host and
# port, so changing a host's address starts its history afresh.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.beszel.hub;

  # Logins only, never mailed: the hub sends no mail without SMTP settings.
  adminEmail = "evf@wheatley.lan";
  # A PocketBase superuser rather than a read-only Beszel user: Homepage's
  # widget reads the systems collection through the superuser API.
  homepageEmail = "homepage@wheatley.lan";

  # A null tailnet address (not yet joined) leaves the host out.
  agents = {
    wheatley = "127.0.0.1";
  }
  // lib.filterAttrs (_: address: address != null) {
    inherit (config.homelab.network.tailnet) GLaDOS rattmann chell;
  };

  # JSON is YAML.
  systemsConfig = pkgs.writeText "beszel-config.yml" (
    builtins.toJSON {
      systems = lib.mapAttrsToList (name: host: {
        inherit name host;
        users = [ adminEmail ];
      }) agents;
    }
  );
in
{

  services.beszel.hub = {
    enable = true;
    host = "0.0.0.0";
    environment.USER_EMAIL = adminEmail;
    environmentFile = config.sops.templates."beszel-hub.env".path;
  };

  # USER_EMAIL/USER_PASSWORD only create the admin on a fresh data dir; later
  # password changes happen in the UI. The Homepage superuser is upserted on
  # every start, so its password follows the secret.
  sops.secrets."beszel/admin-password" = { };
  sops.secrets."beszel/homepage-password" = { };
  sops.templates."beszel-hub.env" = {
    content = ''
      USER_PASSWORD=${config.sops.placeholder."beszel/admin-password"}
      HOMEPAGE_PASSWORD=${config.sops.placeholder."beszel/homepage-password"}
    '';
    restartUnits = [ "beszel-hub.service" ];
  };

  # The hub's data dir is beszel_data under its working directory (the
  # module's dataDir). After the module's migrations, which create the
  # superusers collection.
  systemd.services.beszel-hub.serviceConfig.ExecStartPre = lib.mkAfter [
    "${pkgs.coreutils}/bin/install -D -m 0640 ${systemsConfig} beszel_data/config.yml"
    "${cfg.package}/bin/beszel-hub superuser upsert ${homepageEmail} \${HOMEPAGE_PASSWORD}"
  ];

  homelab.services.beszel = {
    inherit (cfg) port;
    dashboard = {
      name = "Beszel";
      group = "Tools";
      order = 1;
      description = "System metrics";
      icon = "beszel.svg";
      widget = {
        type = "beszel";
        version = 2;
        username = homepageEmail;
        systemId = "wheatley";
        fields = [
          "cpu"
          "memory"
          "disk"
          "network"
        ];
      };
      widgetSecrets.password = "beszel/homepage-password";
      unit = "beszel-hub.service";
    };
  };

}
