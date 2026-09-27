# Modded (Fabric) Minecraft server via nix-minecraft. Everything - loader,
# game version, mods - is pinned here, so a mod set change is a rebuild and
# rolls back with the generation. World state lives in /srv/minecraft and is
# backed up to the NAS with restic (see below).
#
# Reachable on the LAN and over Tailscale (see firewall.nix).
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

    # Server halves of client mods: players need the same versions installed.
    (pkgs.fetchurl {
      url = "https://cdn.modrinth.com/data/uCdwusMi/versions/gfi11b05/DistantHorizons-3.3.2-26.3-fabric-neoforge.jar";
      sha512 = "78a378d5ec117b330923015fe6517fcfabac3db464b3321d7a25b6e5d77dd11225c83b4707e83ac720507c5ac718a1639101332295a1c580413cf2498f472959";
    })
    (pkgs.fetchurl {
      url = "https://cdn.modrinth.com/data/lfHFW1mp/versions/FTYEzxSQ/journeymap-fabric-26.3-6.0.9.jar";
      sha512 = "01951d55d3234cca319d6ce9bee8d2b95f2bea58e39532fe8e35082449c26c5e3199fbe6b66fb72d86c8693e2d7b855c3a64f3cd7d947343be87e0d3f8209654";
    })

    # Server-only performance and tooling; clients don't need these.
    (pkgs.fetchurl {
      url = "https://cdn.modrinth.com/data/gvQqBUqZ/versions/WXHRsMRl/lithium-fabric-0.26.1%2Bmc26.3.jar";
      sha512 = "acbb9b037a203f005e03a20bf1d9866019384abb5ad27664808a12b919639a2501ecb52f8f0d77d27e1409935b0dbdbb70e01ac466480c0ae421ee403f649c59";
    })
    (pkgs.fetchurl {
      url = "https://cdn.modrinth.com/data/uXXizFIs/versions/d5ddUdiB/ferritecore-9.0.0-fabric.jar";
      sha512 = "d81fa97e11784c19d42f89c2f433831d007603dd7193cee45fa177e4a6a9c52b384b198586e04a0f7f63cd996fed713322578bde9a8db57e1188854ae5cbe584";
    })
    # C2ME and ScalableLux are alpha-only on 26.3; first suspects on a crash
    # or world corruption.
    (pkgs.fetchurl {
      url = "https://cdn.modrinth.com/data/VSNURh3q/versions/sSoXjAqP/c2me-fabric-mc26.3-0.4.2-alpha.0.88.jar";
      sha512 = "bb741d118c88ea6d9577fed1affacc1f1f0a7b725a619ee933437cc5e403c8f1474a708ab9bd402d154efde3ce66ef4d83ed950c0cf4f7dc656e525837239226";
    })
    (pkgs.fetchurl {
      url = "https://cdn.modrinth.com/data/Ps1zyz6x/versions/g4eqNSKd/ScalableLux-fabric-mc26.3-0.3.0-alpha.0.6-all.jar";
      sha512 = "ded5a939fb20ab81c1f33b147ca9b98050773dbb28dff16df939c7d567b626809522994ec8dbfb99e7f498dc6a4e62f25e141a87d18efb43f73fc5ad1569ccc9";
    })
    (pkgs.fetchurl {
      url = "https://cdn.modrinth.com/data/l6YH9Als/versions/e3hsPc1o/spark-1.10.187-fabric.jar";
      sha512 = "c74bf5d5a16b2445ec6ea717eac756412b272a8015e91f91a7bf5a27e6f2f99c4a11878d434510f941f37b0344b3a7d1ba0dd6c34e80642762c48fb6e9a93894";
    })
    # Pre-generation, so Distant Horizons has chunks to build LODs from.
    (pkgs.fetchurl {
      url = "https://cdn.modrinth.com/data/fALzjamp/versions/4Eotm6ov/Chunky-Fabric-1.5.3.jar";
      sha512 = "b83bfe7b218d0aa6232af977ae741dc1f82b10e50cd12bb759f65cf416b8b62beccb543e587ef0b9670abe03815660f8e091bc6823624d65cf07300571573516";
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
        # The firewall already limits it to the LAN and tailnet; the
        # whitelist is a second layer. Left non-declarative for now:
        # `whitelist add <name>` on the console.
        white-list = true;
        enforce-whitelist = true;
      };

      symlinks.mods = mods;
    };
  };

  homelab.services.minecraft = {
    port = config.services.minecraft-servers.servers.${serverName}.serverProperties.server-port;
    expose = "tailnet";
    # No web UI to link or HTTP-monitor. The widget pings the game port itself
    # (the scheme is ignored) and reports status, version and players.
    dashboard = {
      name = "Minecraft";
      group = "Tools";
      order = 3;
      description = "Fabric server (LAN + Tailscale)";
      icon = "minecraft.png";
      link = false;
      unit = serverUnit;
      widget = {
        type = "minecraft";
        url = "udp://127.0.0.1:${toString config.homelab.services.minecraft.port}";
      };
    };
  };

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

  # Same pattern as the media share (../nas.nix): never back up into the bare
  # mountpoint on the root filesystem if the NAS is down.
  systemd.services.restic-backups-minecraft.unitConfig.RequiresMountsFor = backupRoot;

}
