# Per-user language and session for the display manager, seeded into
# AccountsService (which GDM and GNOME read them from) from
# my.users.<name>.language and my.desktop.userSessions. Seeded only while the
# account has none, so whatever the user later picks at the GDM gear or in
# GNOME Settings sticks: these are first-login defaults, not policy.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  languages = lib.filterAttrs (_: language: language != null) (
    lib.genAttrs config.my.host.users (name: config.my.users.${name}.language)
  );
  sessions = lib.filterAttrs (
    name: _: lib.elem name config.my.host.users
  ) config.my.desktop.userSessions;

  busctl = "${config.systemd.package}/bin/busctl";

  # seed <user> <property> <value>: set the property if the account has none
  seed = pkgs.writeShellScript "accounts-seed" ''
    set -euo pipefail
    user=$(${busctl} --system --json=short call org.freedesktop.Accounts \
      /org/freedesktop/Accounts org.freedesktop.Accounts FindUserByName s "$1" \
      | ${lib.getExe pkgs.jq} -r '.data[0]')
    current=$(${busctl} --system --json=short get-property org.freedesktop.Accounts \
      "$user" org.freedesktop.Accounts.User "$2" | ${lib.getExe pkgs.jq} -r .data)
    if [ -z "$current" ]; then
      ${busctl} --system call org.freedesktop.Accounts "$user" \
        org.freedesktop.Accounts.User "Set$2" s "$3"
      echo "accounts-seed: $1 $2=$3"
    fi
  '';
in
{

  config = lib.mkIf (config.my.desktop.enable && (languages != { } || sessions != { })) {

    # The /UTF-8 suffix is the charset glibc builds the locale in
    i18n.extraLocales = lib.unique (
      map (language: "${language}/${lib.last (lib.splitString "." language)}") (lib.attrValues languages)
    );

    systemd.services.accounts-seed = {
      description = "Seed users' language and session into AccountsService";
      after = [ "accounts-daemon.service" ];
      requires = [ "accounts-daemon.service" ];
      before = [ "display-manager.service" ];
      wantedBy = [ "graphical.target" ];
      serviceConfig = {
        Type = "oneshot";
        ExecStart =
          lib.mapAttrsToList (name: language: "${seed} ${name} Language ${language}") languages
          ++ lib.mapAttrsToList (name: session: "${seed} ${name} Session ${session}") sessions;
      };
    };

  };

}
