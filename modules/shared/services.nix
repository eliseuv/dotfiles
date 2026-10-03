{ lib, ... }:
{

  options.my = {

    services = {

      tailscale.enable = lib.mkEnableOption "Tailscale";
      containers.enable = lib.mkEnableOption "Docker (rootless) and Podman";
      virtualisation.enable = lib.mkEnableOption "libvirt/QEMU virtual machines";

      # CompanionCube, the Synology NAS
      nas = {
        enable = lib.mkEnableOption "the NAS's personal share over NFS, mounted on demand with `nas mount`";
        address = lib.mkOption {
          type = lib.types.str;
          default = "192.168.0.35";
          description = "The NAS's LAN address (DHCP reservation).";
        };
        tailnetAddress = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = ''
            The NAS's tailnet address. When set, `nas mount tailnet` mounts the
            share over the tailnet, for use away from the LAN.
          '';
        };
      };

    };

    gaming.enable = lib.mkEnableOption "games (Steam on NixOS)";

    homelab.enable = lib.mkEnableOption "the homelab service registry, its firewall policy and dashboard";

    secrets = {
      system.enable = lib.mkEnableOption "sops-nix host secrets, from secrets/<host>.yaml";
      user.enable = lib.mkEnableOption "sops-nix user secrets (secrets/user.yaml) and the password store";
    };

  };

}
