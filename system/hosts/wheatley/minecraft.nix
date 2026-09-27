# Modded (Fabric) Minecraft server via nix-minecraft. Everything - loader,
# game version, mods - is pinned here, so a mod set change is a rebuild and
# rolls back with the generation. World state lives in /srv/minecraft.
#
# Reachable over Tailscale only: the port is opened on tailscale0 alone, not
# in the global allowedTCPPorts list like this host's other services.
#
# Console: `echo '<command>' > /run/minecraft/survival.stdin`; output goes to
# `journalctl -u minecraft-server-survival -f`.
{ config, inputs, lib, pkgs, ... }:
let
  serverName = "survival";

  # Mods: `nix run github:Infinidoge/nix-minecraft#nix-modrinth-prefetch -- <version id>`
  # prints the fetchurl for a Modrinth version. Keep every mod on the same
  # game version as `package`.
  mods = pkgs.linkFarmFromDrvs "mods" [
    (pkgs.fetchurl {
      url = "https://cdn.modrinth.com/data/P7dR8mSH/versions/bNnaTiuM/fabric-api-0.161.0%2B26.3.jar";
      sha512 = "ed6b2586d6fde11fde8472f5a527c51e99b67026e46f94d4bfd85e7e28ce5ee299173ee16ad576ceb51f39f98d30a811086a6deb1a86a524859cc16e12da109d";
    })
  ];
in
{

  imports = [ inputs.nix-minecraft.nixosModules.minecraft-servers ];
  nixpkgs.overlays = [ inputs.nix-minecraft.overlay ];

  services.minecraft-servers = {
    enable = true;
    eula = true;
    # A command socket instead of tmux: scriptable without attaching a session.
    managementSystem = {
      tmux.enable = false;
      systemd-socket.enable = true;
    };

    servers.${serverName} = {
      enable = true;
      # Pinned rather than `fabricServers.fabric` (latest): a game version
      # bump silently breaks every mod built for the old one.
      package = pkgs.fabricServers.fabric-26_3.override { loaderVersion = "0.19.5"; };
      # 4 cores / 15 GiB shared with Jellyfin; enough for a mid-sized pack.
      jvmOpts = "-Xms2G -Xmx6G -XX:+UseG1GC -XX:+ParallelRefProcEnabled -XX:MaxGCPauseMillis=200";

      serverProperties = {
        server-port = 25565;
        motd = "wheatley";
        difficulty = "normal";
        view-distance = 10;
        simulation-distance = 8;
        # Tailscale already gates the network; the whitelist is a second
        # layer. Left non-declarative for now: `whitelist add <name>` on the
        # console.
        white-list = true;
        enforce-whitelist = true;
      };

      symlinks.mods = mods;
    };
  };

  networking.firewall.interfaces.tailscale0.allowedTCPPorts = [ 25565 ];

}
