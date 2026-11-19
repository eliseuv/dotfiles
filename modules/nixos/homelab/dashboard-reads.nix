# Wheatley's dashboard decides a host's tile buttons and terminal from what
# that host enables (dashboard/_machines.nix), reading it from the shared
# layer of the host's config alone, hosts/<name>/default.nix
# (lib/default.nix): set anywhere else, a setting would silently not reach
# it. Each host checks that here, against its full config. The dashboard
# host reads its own full config instead.
{
  config,
  lib,
  hostSpecs,
  ...
}:
let
  readByDashboard = services: {
    remotePowerOff = services.remotePowerOff.enable;
    dotfilesSwitch = services.dotfilesSwitch.enable;
    remoteTailscale = services.remoteTailscale.enable;
    inherit (services) remoteUnits;
    ttyd = {
      inherit (services.ttyd) enable basePath;
    };
  };
in
{

  config.assertions = lib.optional (!config.my.homelab.enable) {
    assertion =
      readByDashboard config.my.services == readByDashboard hostSpecs.${config.my.host.name}.services;
    message = "my.services.{remotePowerOff,dotfilesSwitch,remoteTailscale,remoteUnits,ttyd} must be set in hosts/${config.my.host.name}/default.nix, where the homelab dashboard reads them";
  };

}
