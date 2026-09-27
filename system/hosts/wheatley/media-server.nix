# Media stack: qBittorrent (download client) -> Sonarr/Radarr (library
# management) <- Prowlarr (indexers) -> Jellyfin (playback) <- Seerr (requests).
# All native NixOS services, bound wide open on the LAN like this host's other
# services (see ledger-web.nix) - Tailscale is the remote-access layer, there
# is no reverse proxy. Downloads and library share one NFS mount (nas.nix) so
# Sonarr/Radarr imports are hardlinks, not cross-device copies; service state
# (SQLite) stays on local disk under /var/lib.
{ config, lib, pkgs, ... }:
let
  mediaRoot = "/mnt/media";
  mediaServices = [ "qbittorrent" "sonarr" "radarr" "jellyfin" ];

  arrUrl = service: "http://localhost:${toString config.services.${service}.settings.server.port}";
  arrApis = {
    sonarr = "${arrUrl "sonarr"}/api/v3";
    radarr = "${arrUrl "radarr"}/api/v3";
    prowlarr = "${arrUrl "prowlarr"}/api/v1";
  };

  # Specs for arr-sync. `{ credential = <name>; }` stands for a secret, resolved
  # at runtime from the unit's LoadCredential.
  spec = value: lib.escapeShellArg (builtins.toJSON value);
  qbittorrentClient = categoryField: {
    name = "qBittorrent";
    implementation = "QBittorrent";
    enable = true;
    fields = {
      host = "localhost";
      port = config.services.qbittorrent.webuiPort;
      useSsl = false;
      apiKey.credential = "qbittorrent";
    } // categoryField;
  };
  prowlarrApp = name: service: {
    inherit name;
    implementation = name;
    enable = true;
    syncLevel = "fullSync";
    fields = {
      prowlarrUrl = arrUrl "prowlarr";
      baseUrl = arrUrl service;
      apiKey.credential = service;
    };
  };

  # nixpkgs has no options for the *arrs' own settings, so the wiring between
  # them goes through their REST APIs. Entries are matched by name and only the
  # fields listed in a spec are enforced; nothing is ever deleted, so anything
  # added in the UI survives.
  arrSync = pkgs.writeShellApplication {
    name = "arr-sync";
    runtimeInputs = [ pkgs.curl pkgs.jq ];
    text = ''
      declare -A api=(
        ${lib.concatStrings (lib.mapAttrsToList (service: url: "[${service}]=${url} ") arrApis)}
      )

      # Secrets reach jq through the environment and curl through a file,
      # never argv, which any local user can read.
      CREDS=$(jq -n \
        --rawfile sonarr "$CREDENTIALS_DIRECTORY/sonarr" \
        --rawfile radarr "$CREDENTIALS_DIRECTORY/radarr" \
        --rawfile prowlarr "$CREDENTIALS_DIRECTORY/prowlarr" \
        --rawfile qbittorrent "$CREDENTIALS_DIRECTORY/qbittorrent" \
        '$ARGS.named | map_values(rtrimstr("\n"))')
      export CREDS

      # request SERVICE METHOD PATH, body (if any) on stdin. GETs retry while
      # the service is still starting up; writes don't, to avoid duplicates.
      request() {
        local service=$1 method=$2 path=$3
        local args=(--silent --show-error --fail-with-body
          --variable "key@$CREDENTIALS_DIRECTORY/$service"
          --expand-header 'X-Api-Key: {{key:trim}}'
          --request "$method" "''${api[$service]}/$path")
        if [[ $method == GET ]]; then
          args+=(--retry 60 --retry-connrefused --retry-delay 2)
        else
          args+=(--header 'Content-Type: application/json' --data-binary @-)
        fi
        local response
        response=$(curl "''${args[@]}") || { echo "$response" >&2; return 1; }
        printf '%s' "$response"
      }

      # The *arrs test a download client's or proxy's connection on every save
      # and reject it if the target isn't answering yet. Any HTTP response will
      # do.
      wait_for() {
        curl --silent --output /dev/null --retry 60 --retry-connrefused --retry-delay 2 "$1"
      }
      wait_for http://localhost:${toString config.services.qbittorrent.webuiPort}
      wait_for http://localhost:${toString config.services.flaresolverr.port}

      # upsert SERVICE RESOURCE SPEC: start from the entry with the spec's name,
      # or from the implementation's schema, then overlay the spec's top-level
      # keys and the values of the fields it names.
      upsert() {
        local service=$1 resource=$2 spec=$3 current method path
        current=$(request "$service" GET "$resource" |
          jq -c --argjson spec "$spec" '.[] | select(.name == $spec.name)')
        if [[ -n $current ]]; then
          method=PUT path="$resource/$(jq .id <<<"$current")"
        else
          current=$(request "$service" GET "$resource/schema" |
            jq -c --argjson spec "$spec" '.[] | select(.implementation == $spec.implementation)')
          [[ -n $current ]] || { echo "$service: no $resource implementation in $spec" >&2; exit 1; }
          method=POST path=$resource
        fi
        jq --argjson spec "$spec" '
          (env.CREDS | fromjson) as $creds
          | ($spec | walk(if type == "object" and has("credential") then $creds[.credential] else . end)) as $spec
          | . + ($spec | del(.fields))
          | .fields |= map(.name as $name | if $spec.fields | has($name) then .value = $spec.fields[$name] else . end)
        ' <<<"$current" | request "$service" "$method" "$path" >/dev/null
        echo "$service: $method $resource '$(jq -r .name <<<"$spec")'"
      }

      root_folder() {
        local service=$1 path=$2
        request "$service" GET rootfolder | jq -e --arg path "$path" 'any(.path == $path)' >/dev/null ||
          jq -n --arg path "$path" '{$path}' | request "$service" POST rootfolder >/dev/null
      }

      tag_id() {
        local service=$1 label=$2 id
        id=$(request "$service" GET tag | jq --arg label "$label" '.[] | select(.label == $label) | .id')
        [[ -n $id ]] || id=$(jq -n --arg label "$label" '{$label}' | request "$service" POST tag | jq .id)
        echo "$id"
      }

      upsert sonarr downloadclient ${spec (qbittorrentClient { tvCategory = "tv-sonarr"; })}
      root_folder sonarr ${mediaRoot}/library/tv
      root_folder sonarr ${mediaRoot}/library/anime

      upsert radarr downloadclient ${spec (qbittorrentClient { movieCategory = "radarr"; })}
      root_folder radarr ${mediaRoot}/library/movies

      upsert prowlarr applications ${spec (prowlarrApp "Sonarr" "sonarr")}
      upsert prowlarr applications ${spec (prowlarrApp "Radarr" "radarr")}
      # Only applies to indexers carrying the tag.
      upsert prowlarr indexerproxy "$(jq -c --argjson tag "$(tag_id prowlarr flaresolverr)" '. + {tags: [$tag]}' <<<${
        spec {
          name = "FlareSolverr";
          implementation = "FlareSolverr";
          fields.host = "http://localhost:${toString config.services.flaresolverr.port}/";
        }
      })"
    '';
  };
in
{

  # Pinned: NFS passes numeric IDs through, so this must stay stable for
  # ownership on the NAS to keep meaning the same group.
  users.groups.media.gid = 982;
  users.users.evf.extraGroups = [ "media" ];

  # Not tmpfiles: systemd-tmpfiles-setup runs before the network is up and
  # would stall on the automount. The share root is included because a fresh
  # Synology shared folder carries only a DSM ACL, which NFS exposes as 000.
  systemd.services = lib.mkMerge [
    {
      media-dirs = {
        description = "Create media directories on the NAS share";
        unitConfig.RequiresMountsFor = mediaRoot;
        serviceConfig.Type = "oneshot";
        serviceConfig.RemainAfterExit = true;
        script = ''
          install -d -m 2775 -o root -g media \
            ${mediaRoot} ${mediaRoot}/downloads ${mediaRoot}/library/tv ${mediaRoot}/library/movies \
            ${mediaRoot}/library/anime
        '';
      };
    }
    # Runs again whenever one of the *arrs restarts (Requires= propagates
    # restarts), e.g. after an API key rotation.
    {
      arr-sync = {
        description = "Wire qBittorrent, Prowlarr and FlareSolverr into the *arrs";
        requires = map (service: "${service}.service") (lib.attrNames arrApis);
        wants = [ "qbittorrent.service" "flaresolverr.service" ];
        after = map (service: "${service}.service") (lib.attrNames arrApis ++ [ "qbittorrent" "flaresolverr" ]);
        wantedBy = [ "multi-user.target" ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          ExecStart = lib.getExe arrSync;
          DynamicUser = true;
          LoadCredential = [
            "sonarr:${config.sops.secrets."homepage/sonarr".path}"
            "radarr:${config.sops.secrets."homepage/radarr".path}"
            "prowlarr:${config.sops.secrets."homepage/prowlarr".path}"
            "qbittorrent:${config.sops.secrets."qbittorrent/api-key".path}"
          ];
        };
      };
    }
    # Hard dependency: if the NAS is down these must not start and write into
    # the bare mountpoint on the root filesystem.
    (lib.genAttrs mediaServices (_: {
      requires = [ "media-dirs.service" ];
      after = [ "media-dirs.service" ];
      unitConfig.RequiresMountsFor = mediaRoot;
    }))
    # The qBittorrent module reinstalls qBittorrent.conf from the store on
    # every start, so the API key (see below) is spliced in afterwards - same
    # user, so the file stays writable.
    {
      qbittorrent.serviceConfig.ExecStartPre = lib.mkAfter [
        (pkgs.writeShellScript "qbittorrent-inject-api-key" ''
          conf="${config.services.qbittorrent.profileDir}/qBittorrent/config/qBittorrent.conf"
          key=$(<${config.sops.secrets."qbittorrent/api-key".path})
          contents=$(<"$conf")
          printf '%s\n' "''${contents//@QBT_API_KEY@/$key}" > "$conf"
        '')
      ];
    }
    # FlareSolverr is an open proxy driving a headless browser, and Prowlarr
    # is its only client.
    { flaresolverr.environment.HOST = "127.0.0.1"; }
  ];

  services.qbittorrent = {
    enable = true;
    webuiPort = 8080;
    torrentingPort = 51413;
    openFirewall = true;
    serverConfig.Preferences = {
      Downloads.SavePath = "${mediaRoot}/downloads";
      # Substituted from sops below, keeping the key out of the Nix store.
      WebUI.APIKey = "@QBT_API_KEY@";
    };
  };
  users.users.qbittorrent.extraGroups = [ "media" ];

  # API key for the WebUI (Authorization: Bearer), used by the dashboard.
  # qBittorrent requires the form qbt_ + 28 alphanumerics; anything else is
  # silently ignored.
  sops.secrets."qbittorrent/api-key" = {
    sopsFile = ../../../secrets/wheatley.yaml;
    owner = config.services.qbittorrent.user;
    restartUnits = [ "qbittorrent.service" "arr-sync.service" ];
  };
  # qBittorrent's openFirewall only opens the TCP side of each port.
  networking.firewall.allowedUDPPorts = [ 51413 ];

  services.sonarr.enable = true;
  services.sonarr.openFirewall = true;
  users.users.sonarr.extraGroups = [ "media" ];

  services.radarr.enable = true;
  services.radarr.openFirewall = true;
  users.users.radarr.extraGroups = [ "media" ];

  services.prowlarr.enable = true;
  services.prowlarr.openFirewall = true;

  # Pin each *arr's API key to the sops copy (declared in dashboard.nix)
  # instead of the one it generated on first start, so the keys the dashboard
  # and the cross-service wiring use can't drift from the apps'.
  sops.templates = lib.genAttrs [ "sonarr.env" "radarr.env" "prowlarr.env" ] (
    file:
    let
      service = lib.removeSuffix ".env" file;
    in
    {
      content = "${lib.toUpper service}__AUTH__APIKEY=${config.sops.placeholder."homepage/${service}"}";
      restartUnits = [ "${service}.service" ];
    }
  );
  services.sonarr.environmentFiles = [ config.sops.templates."sonarr.env".path ];
  services.radarr.environmentFiles = [ config.sops.templates."radarr.env".path ];
  services.prowlarr.environmentFiles = [ config.sops.templates."prowlarr.env".path ];

  # Cloudflare challenge solver for Prowlarr, used by indexers tagged
  # "flaresolverr" (see arr-sync). Bound to loopback in systemd.services
  # above.
  services.flaresolverr.enable = true;

  services.jellyfin.enable = true;
  services.jellyfin.openFirewall = true;
  users.users.jellyfin.extraGroups = [ "media" ];

  # configDir defaults to the pre-26.05 jellyseerr path here, since it's
  # keyed off system.stateVersion (24.11 on this host), not the nixpkgs
  # version - just a directory name, doesn't affect functionality.
  services.seerr = {
    enable = true;
    openFirewall = true;
  };

}
