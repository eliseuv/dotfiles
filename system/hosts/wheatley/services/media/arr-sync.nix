# Wiring between the *arrs, qBittorrent and FlareSolverr. nixpkgs has no
# options for the *arrs' own settings, so it goes through their REST APIs.
# Entries are matched by name and only the fields listed in a spec are
# enforced; nothing is ever deleted, so anything added in the UI survives.
{ config, lib, pkgs, ... }:
let
  mediaRoot = config.homelab.media.root;

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

  # Runs again whenever one of the *arrs restarts (Requires= propagates
  # restarts), e.g. after an API key rotation.
  systemd.services.arr-sync = {
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
