{ lib, pkgs, ... }:
let
  # Notifications are best-effort: headless hosts have no notification daemon,
  # and a failed notify-send must not mark the job itself as failed.
  # Update environment script
  # The language server lives in the nvim-lspconfig env, which nvim-lspconfig's
  # julials loads ahead of the global one; Zed manages its own @zed-julia env.
  # Both envs are updated even if one fails, so one breakage doesn't leave the
  # other stale. Pkg.update only logs precompile failures, so the language
  # server env is precompiled strictly to make a broken server fail the update.
  julia-env-update = pkgs.writeShellScriptBin "julia-env-update" ''
    status=0
    ${lib.getExe pkgs.julia-bin} --eval 'using Pkg; Pkg.add("Pluto"); Pkg.update()' || status=1
    ${lib.getExe pkgs.julia-bin} --project=@nvim-lspconfig --eval 'using Pkg; Pkg.update(); Pkg.precompile(strict=true)' || status=1
    if [ "$status" -eq 0 ]; then
      ${pkgs.libnotify}/bin/notify-send "Julia" "Environment update completed" || true
    else
      ${pkgs.libnotify}/bin/notify-send "Julia" "Environment update failed" -u critical || true
      exit 1
    fi
  '';
  # Cleanup environment script
  julia-env-gc = pkgs.writeShellScriptBin "julia-env-gc" ''
    if ${lib.getExe pkgs.julia-bin} --eval "using Pkg; Pkg.gc()"; then
      ${pkgs.libnotify}/bin/notify-send "Julia" "Environment cleanup completed" || true
    else
      ${pkgs.libnotify}/bin/notify-send "Julia" "Environment cleanup failed" -u critical || true
      exit 1
    fi
  '';

  # Start (or reattach to) the Pluto service on a host (nixos services/pluto),
  # tunnel to it and open it in the browser. The tunnel uses the same local
  # port as the remote one, so a clash (e.g. a local Pluto) fails fast instead
  # of opening the wrong server. Closing the tunnel leaves the server and its
  # notebooks running.
  pluto-connect = pkgs.writeShellApplication {
    name = "pluto-connect";
    runtimeInputs = with pkgs; [
      openssh
      xdg-utils
      curl
    ];
    text = ''
      usage() {
        echo "Usage: pluto-connect [--stop] [host]   (host defaults to glados; 'localhost' skips SSH)"
      }

      stop=false
      case "''${1:-}" in
      -h | --help)
        usage
        exit 0
        ;;
      --stop)
        stop=true
        shift
        ;;
      esac
      [ $# -le 1 ] || {
        usage >&2
        exit 2
      }
      host="''${1:-glados}"

      on_host() {
        if [ "$host" = localhost ]; then
          sh -c "$1"
        else
          # $1 is the remote command line itself
          # shellcheck disable=SC2029
          ssh "$host" "$1"
        fi
      }

      if $stop; then
        on_host 'systemctl stop pluto'
        exit 0
      fi

      echo "Starting Pluto on $host (the first start precompiles and can take minutes)..." >&2
      # http://localhost:<port><base path>?secret=...
      url=$(on_host 'systemctl start pluto && pluto-url')
      port=''${url#http://localhost:}
      port=''${port%%/*}

      if [ "$host" != localhost ]; then
        ssh -N -o ExitOnForwardFailure=yes -L "$port:127.0.0.1:$port" "$host" &
        tunnel=$!
        trap 'kill "$tunnel" 2>/dev/null || true' EXIT
        # With the secret: Pluto logs it on unauthenticated requests
        until curl -sf -o /dev/null "$url"; do
          kill -0 "$tunnel" 2>/dev/null || {
            echo "SSH tunnel to $host failed (is local port $port in use?)" >&2
            exit 1
          }
          sleep 0.5
        done
      fi

      echo "$url"
      xdg-open "$url" >/dev/null 2>&1 || true

      if [ "$host" != localhost ]; then
        echo "Tunnel open; Ctrl-C closes it, the server keeps running (stop it with: pluto-connect --stop $host)" >&2
        wait "$tunnel"
      fi
    '';
  };
in
{

  home.packages = with pkgs; [
    julia-bin

    # Environment management scripts
    julia-env-update
    julia-env-gc

    pluto-connect

  ];

  home.file = {
    # REPL startup script
    ".julia/config/startup.jl".source = ./julia/startup.jl;
    # LSP requirements makefile
    ".julia/environments/nvim-lspconfig/Makefile".source = ./julia/Makefile;
    # Pluto notebook templates
    ".julia/pluto_notebooks/ingredients.jl".source = ./julia/ingredients.jl;
  };

  home.sessionVariables = {
    JULIA_NUM_THREADS = "auto";
  };

  # Julia environment update
  systemd.user.services.julia-env-update = {
    Unit = {
      Description = "Update Julia environment";
      Wants = [
        "network.target"
        "nss-lookup.target"
      ];
      After = [
        "network.target"
        "nss-lookup.target"
      ];
    };
    Service = {
      Type = "oneshot";
      ExecStart = lib.getExe julia-env-update;
    };
    # Not WantedBy default.target: activation waits for it, and a full update
    # plus precompile blocks the switch for minutes. The timer runs it instead.
  };

  systemd.user.timers.julia-env-update = {
    Unit.Description = "Scheduled Julia environment update";
    Timer = {
      OnCalendar = "daily";
      Persistent = true;
      RandomizedDelaySec = "1h";
    };
    Install.WantedBy = [ "timers.target" ];
  };

  # Julia environment cleanup
  systemd.user.services.julia-env-gc = {
    Unit = {
      Description = "Cleanup Julia environment";
    };
    Service = {
      Type = "oneshot";
      ExecStart = lib.getExe julia-env-gc;
    };
  };

  systemd.user.timers.julia-env-gc = {
    Unit.Description = "Scheduled Julia environment cleanup";
    Timer = {
      OnCalendar = "daily";
      Persistent = true;
      RandomizedDelaySec = "1h";
    };
    Install.WantedBy = [ "timers.target" ];
  };

}
