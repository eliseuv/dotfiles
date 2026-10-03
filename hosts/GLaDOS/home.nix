{ ... }:
{

  imports = [ ./syncthing.nix ];

  services.pueue.settings.daemon.default_parallel_tasks = 4;

}
