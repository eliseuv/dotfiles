# Lets the homelab dashboard (svcctl on wheatley, dashboard/controls.nix)
# power this host off, reboot it, switch it to the latest dotfiles, turn
# Tailscale on and off, and start and stop the units in `remoteUnits`. svcctl
# logs in over SSH as a dedicated user whose only key is pinned to one forced
# command, so the key can't open a shell, forward anything or run anything
# else, whatever the client asks for. The forced command reads the requested
# verb from SSH_ORIGINAL_COMMAND and accepts only the ones this host enables.
# polkit lets that user, and only it, do exactly those; no sudo.
#
# `shutdown +1` rather than an immediate poweroff, so whoever is at the
# machine gets a minute to `shutdown -c`. Reboots are immediate, like the
# dashboard host's own.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  user = "remote-control";
  services = config.my.services;
  # Public half of the `svcctl/poweroff-ssh-key` secret in secrets/hosts/wheatley.yaml.
  svcctlKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBkYyj2vQNoL702tMIZPdaLAXt6qNA9loALCYKBij9Sx svcctl@wheatley";
  shutdown = "${config.systemd.package}/bin/shutdown";
  systemctl = "${config.systemd.package}/bin/systemctl";
  switchUnit = "dotfiles-switch.service";
  enabled =
    services.remotePowerOff.enable
    || services.dotfilesSwitch.enable
    || services.remoteTailscale.enable
    || services.remoteUnits != [ ];
  tailscale = lib.getExe config.services.tailscale.package;
  # The tailscale CLI only obeys its operator, the primary user (see
  # services/tailscale.nix), so these root units run it on remote-control's
  # behalf; polkit lets that user start them and nothing else.
  tailscaleUnits = {
    up = "remote-tailscale-up.service";
    down = "remote-tailscale-down.service";
  };

  dispatch = pkgs.writeShellScript "remote-control" ''
    case "''${SSH_ORIGINAL_COMMAND:-}" in
    ${lib.optionalString services.remotePowerOff.enable ''
      poweroff) exec ${shutdown} +1 'Powered off from the dashboard' ;;
      reboot) exec ${systemctl} --no-block --check-inhibitors=no reboot ;;
    ''}
    ${lib.optionalString services.dotfilesSwitch.enable ''
      switch) exec ${systemctl} start --no-block ${switchUnit} ;;
      switch-status) exec ${systemctl} show --property=ActiveState,Result --value ${switchUnit} ;;
    ''}
    ${lib.optionalString services.remoteTailscale.enable ''
      tailscale-on) exec ${systemctl} start --no-block ${tailscaleUnits.up} ;;
      tailscale-off) exec ${systemctl} start --no-block ${tailscaleUnits.down} ;;
      tailscale-status) exec ${tailscale} status --json --peers=false ;;
    ''}
    ${lib.concatMapStrings (unit: ''
      ${lib.escapeShellArg "start ${unit}"}) exec ${systemctl} start --no-block ${unit} ;;
      ${lib.escapeShellArg "stop ${unit}"}) exec ${systemctl} stop --no-block ${unit} ;;
      ${lib.escapeShellArg "restart ${unit}"}) exec ${systemctl} restart --no-block ${unit} ;;
      # is-active exits non-zero for anything but active; the state is the answer.
      ${lib.escapeShellArg "status ${unit}"}) ${systemctl} is-active ${unit}; exit 0 ;;
    '') services.remoteUnits}
    *)
      echo "remote-control: refused: ''${SSH_ORIGINAL_COMMAND:-<none>}" >&2
      exit 1
      ;;
    esac
  '';
in
{

  config = lib.mkIf enabled {

    # sshd runs the forced command through the login shell, so this user needs
    # a real one; `restrict` and the forced command are what keep it inert.
    users.users.${user} = {
      isSystemUser = true;
      group = user;
      useDefaultShell = true;
      openssh.authorizedKeys.keys = [ ''restrict,command="${dispatch}" ${svcctlKey}'' ];
    };
    users.groups.${user} = { };

    # The dashboard logs in every few seconds, and each login would otherwise
    # start a user@.service for this user, with every per-user unit (rootless
    # Docker, devmon, ...), only to tear it down again. A switch that lands
    # while one is stopping fails reloading it. background-light sessions
    # don't pull in user@.service; polkit only checks the user, not a session.
    # pam_succeed_if skips the pam_env line for everyone else; neither can
    # fail a login.
    security.pam.services.sshd.rules.session =
      let
        systemdOrder = config.security.pam.services.sshd.rules.session.systemd.order;
        pamModule = name: "${config.security.pam.package}/lib/security/${name}.so";
      in
      {
        remote-control-only = {
          order = systemdOrder - 20;
          control = "[success=1 default=ignore]";
          modulePath = pamModule "pam_succeed_if";
          args = [
            "quiet"
            "user"
            "!="
            user
          ];
        };
        remote-control-light = {
          order = systemdOrder - 10;
          control = "optional";
          modulePath = pamModule "pam_env";
          args = [
            "conffile=${pkgs.writeText "remote-control-pam-env.conf" "XDG_SESSION_CLASS DEFAULT=background-light\n"}"
            "readenv=0"
          ];
        };
      };

    # *-multiple-sessions because someone is usually logged in, and
    # *-ignore-inhibit because desktop sessions hold inhibitor locks.
    security.polkit.extraConfig =
      lib.optionalString services.remotePowerOff.enable ''
        polkit.addRule(function (action, subject) {
          var actions = [
            "org.freedesktop.login1.power-off",
            "org.freedesktop.login1.power-off-multiple-sessions",
            "org.freedesktop.login1.power-off-ignore-inhibit",
            "org.freedesktop.login1.reboot",
            "org.freedesktop.login1.reboot-multiple-sessions",
            "org.freedesktop.login1.reboot-ignore-inhibit",
          ];
          if (subject.user == "${user}" && actions.indexOf(action.id) >= 0) {
            return polkit.Result.YES;
          }
        });
      ''
      + lib.optionalString (services.remoteUnits != [ ]) ''
        polkit.addRule(function (action, subject) {
          if (
            action.id == "org.freedesktop.systemd1.manage-units" &&
            subject.user == "${user}" &&
            ${builtins.toJSON services.remoteUnits}.indexOf(action.lookup("unit")) >= 0 &&
            ["start", "stop", "restart"].indexOf(action.lookup("verb")) >= 0
          ) {
            return polkit.Result.YES;
          }
        });
      ''
      + lib.optionalString services.dotfilesSwitch.enable ''
        polkit.addRule(function (action, subject) {
          if (
            action.id == "org.freedesktop.systemd1.manage-units" &&
            subject.user == "${user}" &&
            action.lookup("unit") == "${switchUnit}" &&
            action.lookup("verb") == "start"
          ) {
            return polkit.Result.YES;
          }
        });
      ''
      + lib.optionalString services.remoteTailscale.enable ''
        polkit.addRule(function (action, subject) {
          if (
            action.id == "org.freedesktop.systemd1.manage-units" &&
            subject.user == "${user}" &&
            ${builtins.toJSON (lib.attrValues tailscaleUnits)}.indexOf(action.lookup("unit")) >= 0 &&
            action.lookup("verb") == "start"
          ) {
            return polkit.Result.YES;
          }
        });
      '';

    systemd.services = lib.mkIf services.remoteTailscale.enable (
      lib.mapAttrs' (
        verb: unit:
        lib.nameValuePair (lib.removeSuffix ".service" unit) {
          description = "Turn Tailscale ${if verb == "up" then "on" else "off"} for the dashboard";
          serviceConfig = {
            Type = "oneshot";
            # Bounded so a node that needs a login can't hang the unit.
            # `up` as root refuses unless it repeats every non-default
            # setting, i.e. the operator from extraSetFlags.
            ExecStart = lib.escapeShellArgs (
              [
                tailscale
                verb
              ]
              ++ lib.optionals (verb == "up") ([ "--timeout=20s" ] ++ config.services.tailscale.extraSetFlags)
            );
          };
        }
      ) tailscaleUnits
    );

    assertions = lib.optional services.remoteTailscale.enable {
      assertion = services.tailscale.enable;
      message = "my.services.remoteTailscale needs my.services.tailscale";
    };

  };

}
