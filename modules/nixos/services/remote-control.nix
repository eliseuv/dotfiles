# Lets the homelab dashboard (svcctl on wheatley, dashboard/controls.nix)
# power this host off, reboot it and switch it to the latest dotfiles. svcctl
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
  # Public half of the `svcctl/poweroff-ssh-key` secret in secrets/wheatley.yaml.
  svcctlKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBkYyj2vQNoL702tMIZPdaLAXt6qNA9loALCYKBij9Sx svcctl@wheatley";
  shutdown = "${config.systemd.package}/bin/shutdown";
  systemctl = "${config.systemd.package}/bin/systemctl";
  switchUnit = "dotfiles-switch.service";

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
    *)
      echo "remote-control: refused: ''${SSH_ORIGINAL_COMMAND:-<none>}" >&2
      exit 1
      ;;
    esac
  '';
in
{

  config = lib.mkIf (services.remotePowerOff.enable || services.dotfilesSwitch.enable) {

    # sshd runs the forced command through the login shell, so this user needs
    # a real one; `restrict` and the forced command are what keep it inert.
    users.users.${user} = {
      isSystemUser = true;
      group = user;
      useDefaultShell = true;
      openssh.authorizedKeys.keys = [ ''restrict,command="${dispatch}" ${svcctlKey}'' ];
    };
    users.groups.${user} = { };

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
      '';

  };

}
