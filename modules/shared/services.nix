{ lib, ... }:
{

  options.my = {

    services = {

      tailscale = {
        enable = lib.mkEnableOption "Tailscale";
        upAtBoot = lib.mkEnableOption "bringing Tailscale up at every boot, undoing a `tailscale down` from the last session";
      };
      containers.enable = lib.mkEnableOption "Docker (rootless) and Podman";
      virtualisation.enable = lib.mkEnableOption "libvirt/QEMU virtual machines";
      remotePowerOff.enable = lib.mkEnableOption "power-off and reboot over SSH from the homelab dashboard";
      dotfilesSwitch.enable = lib.mkEnableOption "dotfiles-switch.service, which pulls origin/master and switches to it, for the homelab dashboard";
      remoteTailscale.enable = lib.mkEnableOption "turning Tailscale on and off over SSH from the homelab dashboard (needs my.services.tailscale)";
      remoteUnits = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "systemd units the homelab dashboard may start, stop, restart and query over SSH (services/remote-control.nix).";
      };

      ttyd = {
        enable = lib.mkEnableOption "the ttyd web terminal (zellij as the primary user); it has no login of its own, so it belongs behind the homelab dashboard's nginx";
        port = lib.mkOption {
          type = lib.types.port;
          default = 3000;
        };
        basePath = lib.mkOption {
          type = lib.types.str;
          default = "/";
          description = "URL path ttyd serves under, for when it sits behind a reverse proxy at a subpath.";
        };
        interface = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = "Network interface ttyd binds to (`lo` when its proxy is on the same host); null for all.";
        };
      };

      pluto = {
        enable = lib.mkEnableOption "the Pluto notebook server (as the primary user), started on demand; its secret is the `pluto/secret` sops secret";
        port = lib.mkOption {
          type = lib.types.port;
          default = 1234;
        };
        basePath = lib.mkOption {
          type = lib.types.str;
          default = "/";
          description = "URL path Pluto serves under (its `base_url`), for when it sits behind a reverse proxy at a subpath; starts and ends with `/`.";
        };
        bindAddress = lib.mkOption {
          type = lib.types.str;
          default = "127.0.0.1";
          description = "Address Pluto listens on; anything but loopback needs a firewall rule admitting only its proxy.";
        };
      };

      # CompanionCube, the Synology NAS
      nas = {
        enable = lib.mkEnableOption "the NAS's personal share over NFS, mounted on demand with `nas mount`";
        address = lib.mkOption {
          type = lib.types.str;
          default = "companioncube.local";
          description = "The NAS's LAN name, resolved over mDNS (the router hands out no fixed addresses).";
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
