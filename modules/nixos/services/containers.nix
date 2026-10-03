{
  config,
  lib,
  pkgs,
  ...
}:
{

  config = lib.mkIf config.my.services.containers.enable {

    virtualisation.docker = {

      enable = true;

      rootless = {
        enable = true;
        setSocketVariable = true;

        daemon.settings = {
          userland-proxy = false;
          experimental = true;
          live-restore = true;
          metrics-addr = "0.0.0.0:9323";
          fixed-cidr-v6 = "fd00::/80";
          ipv6 = true;
        };

      };

    };

    # Enable common container config files in /etc/containers
    virtualisation.containers.enable = true;

    virtualisation.podman = {

      enable = true;

      # Create a `docker` alias for podman, to use it as a drop-in replacement
      # dockerCompat = true;

      # Required for containers under podman-compose to be able to talk to each other.
      defaultNetwork.settings.dns_enabled = true;

    };

    # Useful other development tools
    environment.systemPackages = with pkgs; [
      docker-compose # start group of containers for dev
      dive # look into docker image layers
      podman-tui # status of containers in the terminal
      podman-compose # start group of containers for dev
    ];

  };

}
