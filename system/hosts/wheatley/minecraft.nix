# Modded (Fabric) Minecraft server via nix-minecraft. Everything - loader,
# game version, mods - is pinned here, so a mod set change is a rebuild and
# rolls back with the generation. World state lives in /srv/minecraft and is
# backed up to the NAS with restic (see below).
#
# Reachable over Tailscale only: the port is opened on tailscale0 alone, not
# in the global allowedTCPPorts list like this host's other services.
#
# Console: `echo '<command>' > /run/minecraft/survival.stdin`; output goes to
# `journalctl -u minecraft-server-survival -f`.
{ config, inputs, lib, pkgs, ... }:
let
  serverName = "survival";
  serverUnit = "minecraft-server-${serverName}.service";
  serverDir = "${config.services.minecraft-servers.dataDir}/${serverName}";
  stdinSocket = "/run/minecraft/${serverName}.stdin";
  backupRoot = "/mnt/minecraft";

  # Mods: `nix run github:Infinidoge/nix-minecraft#nix-modrinth-prefetch -- <version id>`
  # prints the fetchurl for a Modrinth version. Keep every mod on the same
  # game version as `package`.
  mods = pkgs.linkFarmFromDrvs "mods" [
    (pkgs.fetchurl {
      url = "https://cdn.modrinth.com/data/P7dR8mSH/versions/bNnaTiuM/fabric-api-0.161.0%2B26.3.jar";
      sha512 = "ed6b2586d6fde11fde8472f5a527c51e99b67026e46f94d4bfd85e7e28ce5ee299173ee16ad576ceb51f39f98d30a811086a6deb1a86a524859cc16e12da109d";
    })
  ];

  # The stdin FIFO is socket-activated, so writing to it while the server is
  # stopped would start it; only talk to a server that is already running.
  sendCommand = command: ''
    if systemctl is-active --quiet ${serverUnit}; then
      echo ${lib.escapeShellArg command} > ${stdinSocket}
    fi
  '';
in
{

  imports = [ inputs.nix-minecraft.nixosModules.minecraft-servers ];
  nixpkgs.overlays = [ inputs.nix-minecraft.overlay ];

  services.minecraft-servers = {
    enable = true;
    eula = true;
    # A command socket instead of tmux, so the backup job can script
    # save-off/save-on without attaching to a session.
    managementSystem = {
      tmux.enable = false;
      systemd-socket.enable = true;
    };

    servers.${serverName} = {
      enable = true;
      # Pinned rather than `fabricServers.fabric` (latest): a game version
      # bump silently breaks every mod built for the old one.
      # The Fabric wrapper launches with nixpkgs' default jre_headless (21)
      # instead of the Java the game declares (25 for 26.x), so borrow the
      # vanilla server's.
      package = pkgs.fabricServers.fabric-26_3.override {
        loaderVersion = "0.19.5";
        jre_headless = pkgs.vanillaServers.vanilla-26_3.java;
      };
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

  # Daily restic snapshots to the NAS. Autosave is paused and a full flush
  # forced first, so no region file is captured half-written; the cleanup
  # step runs even when the backup fails, so autosave is always restored.
  sops.secrets."restic/minecraft" = { };

  services.restic.backups.minecraft = {
    repository = "${backupRoot}/restic";
    initialize = true;
    passwordFile = config.sops.secrets."restic/minecraft".path;
    paths = [ serverDir ];
    # mods is a store symlink rebuilt from this file; logs aren't worth keeping.
    exclude = [
      "${serverDir}/mods"
      "${serverDir}/logs"
      "${serverDir}/crash-reports"
    ];
    timerConfig = {
      OnCalendar = "04:00";
      Persistent = true;
    };
    pruneOpts = [
      "--keep-daily 7"
      "--keep-weekly 4"
      "--keep-monthly 6"
    ];
    backupPrepareCommand = ''
      ${sendCommand "save-off"}
      if systemctl is-active --quiet ${serverUnit}; then
        since=$(date '+%Y-%m-%d %H:%M:%S')
        ${sendCommand "save-all flush"}
        # The FIFO write returns immediately; wait for the server to confirm.
        for _ in $(seq 120); do
          journalctl --quiet --unit ${serverUnit} --since "$since" | grep --quiet 'Saved the game' && break
          sleep 1
        done
      fi
    '';
    backupCleanupCommand = sendCommand "save-on";
  };

  # Same pattern as the media share (nas.nix): never back up into the bare
  # mountpoint on the root filesystem if the NAS is down.
  systemd.services.restic-backups-minecraft.unitConfig.RequiresMountsFor = backupRoot;

}
