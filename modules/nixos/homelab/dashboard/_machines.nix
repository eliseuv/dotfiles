# What a tile's machine (`dashboard.host`) lets the dashboard do, and how
# svcctl reaches it: the only source of the tiles' host buttons. A host in
# hosts/ is read from its own my.services, through `hostSpecs` (the shared
# layer of its config, lib/default.nix) or, for this host, its full config,
# whose NixOS modules may set more (wheatley's ttyd); a machine outside the
# flake from homelab.externalHosts.
{
  config,
  lib,
  hostSpecs,
}:
host:
let
  network = config.homelab.network;
  local = host == config.my.host.name;
  external = config.homelab.externalHosts.${host} or null;
  services =
    if local then
      config.my.services
    else
      hostSpecs.${host}.services
        or (throw "dashboard.host: ${host} is neither a host in hosts/ nor in homelab.externalHosts");
  spec =
    if external != null then
      {
        inherit (external)
          address
          sshUser
          remotePowerOff
          remoteTailscale
          snmp
          ;
        dotfilesSwitch = false;
        remoteUnits = [ ];
        terminal = null;
      }
    else
      {
        address = null;
        # services/remote-control.nix's forced-command user.
        sshUser = "remote-control";
        remotePowerOff = services.remotePowerOff.enable;
        remoteTailscale = services.remoteTailscale.enable;
        snmp = null;
        dotfilesSwitch = services.dotfilesSwitch.enable;
        inherit (services) remoteUnits;
        terminal = if services.ttyd.enable then "${services.ttyd.basePath}/" else null;
      };
  mac = config.my.wakeOnLan.hosts.${host} or null;
  # Nothing here could wake this host, and its own buttons act on it directly.
  wake = !local && mac != null;
in
spec
// {
  inherit
    host
    local
    mac
    wake
    ;
  # Part of the wake button, which turns into a power-off button while the
  # host is up.
  poweroff = wake && spec.remotePowerOff;
  reboot = local || spec.remotePowerOff;
  switch = spec.dotfilesSwitch;
  # The host page needs the generation reports dotfiles-switch keeps; a
  # machine with only SNMP shows its uptime and no page.
  page = spec.dotfilesSwitch;
  tailscale = !local && spec.remoteTailscale;
  # Names svcctl tries in turn to SSH to it: none for this host, else its
  # MagicDNS name, then its mDNS one for when Tailscale is down on it but
  # it's on the LAN.
  sshTargets =
    if spec.address != null then
      [ spec.address ]
    else
      lib.optionals (!local) [
        "${lib.toLower host}.${network.tailnetDomain}"
        "${lib.toLower host}.local"
      ];
  # Where its wake button's up/down state pings.
  pingHost = if spec.address != null then spec.address else "${host}.local";
}
