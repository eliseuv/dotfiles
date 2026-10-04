# Lets the homelab dashboard (svcctl on wheatley, dashboard/controls.nix)
# power this host off. svcctl logs in over SSH as a dedicated user whose only
# key is pinned to one forced command, so the key can't open a shell, forward
# anything or run anything else, whatever the client asks for. polkit lets
# that user, and only it, schedule a power-off through logind; no sudo.
#
# `shutdown +1` rather than an immediate poweroff, so whoever is at the
# machine gets a minute to `shutdown -c`.
{
  config,
  lib,
  ...
}:
let
  user = "remote-poweroff";
  # Public half of the `svcctl/poweroff-ssh-key` secret in secrets/wheatley.yaml.
  svcctlKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBkYyj2vQNoL702tMIZPdaLAXt6qNA9loALCYKBij9Sx svcctl@wheatley";
  shutdown = "${config.systemd.package}/bin/shutdown";
in
{

  config = lib.mkIf config.my.services.remotePowerOff.enable {

    # sshd runs the forced command through the login shell, so this user needs
    # a real one; `restrict` and the forced command are what keep it inert.
    users.users.${user} = {
      isSystemUser = true;
      group = user;
      useDefaultShell = true;
      openssh.authorizedKeys.keys = [
        ''restrict,command="${shutdown} +1 'Powered off from the dashboard'" ${svcctlKey}''
      ];
    };
    users.groups.${user} = { };

    # power-off-multiple-sessions because someone is usually logged in, and
    # ignore-inhibit because desktop sessions hold inhibitor locks.
    security.polkit.extraConfig = ''
      polkit.addRule(function (action, subject) {
        var actions = [
          "org.freedesktop.login1.power-off",
          "org.freedesktop.login1.power-off-multiple-sessions",
          "org.freedesktop.login1.power-off-ignore-inhibit",
        ];
        if (subject.user == "${user}" && actions.indexOf(action.id) >= 0) {
          return polkit.Result.YES;
        }
      });
    '';

  };

}
