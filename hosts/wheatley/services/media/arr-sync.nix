# Wiring between the *arrs, qBittorrent and FlareSolverr. nixpkgs has no
# options for the *arrs' own settings, so arr-sync.sh applies `wiring` below
# through their REST APIs. Entries are matched by name and only the fields
# listed are enforced; nothing is ever deleted, so anything added in the UI
# survives. To see what a resource accepts:
#   curl -H "X-Api-Key: $key" http://localhost:<port>/api/v3/<resource>/schema
{ config, lib, pkgs, ... }:
let
  mediaRoot = config.homelab.media.root;
  arrUrl = service: "http://localhost:${toString config.services.${service}.settings.server.port}";

  # `{ credential = <name>; }` stands for a secret from `credentials`, resolved
  # at runtime; `tags` are labels, resolved to (and created as) ids.
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

  # Per service: its API root, then API resources (`rootfolder` takes paths,
  # the rest take entry specs).
  wiring = {
    sonarr = {
      api = "${arrUrl "sonarr"}/api/v3";
      downloadclient = [ (qbittorrentClient { tvCategory = "tv-sonarr"; }) ];
      rootfolder = [ "${mediaRoot}/library/tv" "${mediaRoot}/library/anime" ];
    };
    radarr = {
      api = "${arrUrl "radarr"}/api/v3";
      downloadclient = [ (qbittorrentClient { movieCategory = "radarr"; }) ];
      rootfolder = [ "${mediaRoot}/library/movies" ];
    };
    prowlarr = {
      api = "${arrUrl "prowlarr"}/api/v1";
      applications = [
        (prowlarrApp "Sonarr" "sonarr")
        (prowlarrApp "Radarr" "radarr")
      ];
      # Only applies to indexers carrying the tag.
      indexerproxy = [
        {
          name = "FlareSolverr";
          implementation = "FlareSolverr";
          tags = [ "flaresolverr" ];
          fields.host = "http://localhost:${toString config.services.flaresolverr.port}/";
        }
      ];
    };
  };

  # Services the *arrs test a connection to when saving an entry pointing at
  # them, so they must be answering first.
  waitFor = [
    "http://localhost:${toString config.services.qbittorrent.webuiPort}"
    "http://localhost:${toString config.services.flaresolverr.port}"
  ];

  # Each *arr's own key (for its API) plus any the specs reference.
  credentials = {
    sonarr = config.sops.secrets."sonarr/api-key".path;
    radarr = config.sops.secrets."radarr/api-key".path;
    prowlarr = config.sops.secrets."prowlarr/api-key".path;
    qbittorrent = config.sops.secrets."qbittorrent/api-key".path;
  };

  arrSync = pkgs.writeShellApplication {
    name = "arr-sync";
    runtimeInputs = [ pkgs.curl pkgs.jq ];
    text = builtins.readFile ./arr-sync.sh;
  };
  configFile = pkgs.writeText "arr-sync.json" (builtins.toJSON { services = wiring; inherit waitFor; });
  units = map (service: "${service}.service");
in
{

  # Runs again whenever one of the *arrs restarts (Requires= propagates
  # restarts), e.g. after an API key rotation.
  systemd.services.arr-sync = {
    description = "Wire qBittorrent, Prowlarr and FlareSolverr into the *arrs";
    requires = units (lib.attrNames wiring);
    wants = units [ "qbittorrent" "flaresolverr" ];
    after = units (lib.attrNames wiring ++ [ "qbittorrent" "flaresolverr" ]);
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${lib.getExe arrSync} ${configFile}";
      DynamicUser = true;
      LoadCredential = lib.mapAttrsToList (name: path: "${name}:${path}") credentials;
    };
  };

}
