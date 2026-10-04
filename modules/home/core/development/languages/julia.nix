{ lib, pkgs, ... }:
let
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
      ${pkgs.libnotify}/bin/notify-send "Julia" "Environment update completed"
    else
      ${pkgs.libnotify}/bin/notify-send "Julia" "Environment update failed" -u critical
      exit 1
    fi
  '';
  # Cleanup environment script
  julia-env-gc = pkgs.writeShellScriptBin "julia-env-gc" ''
    ${lib.getExe pkgs.julia-bin} --eval "using Pkg; Pkg.gc()" && ${pkgs.libnotify}/bin/notify-send "Julia" "Environment cleanup completed" || ${pkgs.libnotify}/bin/notify-send "Julia" "Environment cleanup failed" -u critical
  '';

  # Pluto server. Fixed port so an SSH tunnel has a known target.
  plutoPort = 1234;
  # The first start precompiles Pluto, which can take minutes
  plutoStartTimeoutSec = 300;
  # Blocks `systemctl --user start pluto` until Pluto answers, so callers can
  # use it as soon as the start returns.
  pluto-wait-ready = pkgs.writeShellScript "pluto-wait-ready" ''
    for _ in $(seq ${toString plutoStartTimeoutSec}); do
      ${lib.getExe pkgs.curl} -sf http://127.0.0.1:${toString plutoPort}/ping >/dev/null && exit 0
      sleep 1
    done
    exit 1
  '';
  # Start (or reattach to) the Pluto service on a host, tunnel to it and open
  # it in the browser. The tunnel uses the same local port as the remote one,
  # so a clash (e.g. a local Pluto) fails fast instead of opening the wrong
  # server. Closing the tunnel leaves the server and its notebooks running.
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
      port=${toString plutoPort}

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
        on_host 'systemctl --user stop pluto'
        exit 0
      fi

      echo "Starting Pluto on $host (the first start precompiles and can take minutes)..." >&2
      # Single quotes: the state dir is resolved on the host
      # shellcheck disable=SC2016
      secret=$(on_host 'systemctl --user start pluto && cat "''${XDG_STATE_HOME:-$HOME/.local/state}/pluto/secret"')
      url="http://localhost:$port/?secret=$secret"

      if [ "$host" != localhost ]; then
        ssh -N -o ExitOnForwardFailure=yes -L "$port:127.0.0.1:$port" "$host" &
        tunnel=$!
        trap 'kill "$tunnel" 2>/dev/null || true' EXIT
        until curl -sf "http://127.0.0.1:$port/ping" >/dev/null; do
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

  # Port pinned so the glados-pluto SSH tunnel has a fixed target; Pluto would
  # otherwise silently move to the next free port.
  home.shellAliases = {
    pluto-run = "julia --eval 'using Pluto; Pluto.run(launch_browser=false, port=1234)'";
  };

  # Pluto notebook server, started on demand (no WantedBy). Lingering keeps it
  # alive with no session logged in, so notebooks survive dropped connections.
  systemd.user.services.pluto = {
    Unit.Description = "Pluto notebook server";
    Service = {
      # Login shell for the same environment as an SSH session (PATH,
      # home-manager session vars, GPU libraries)
      ExecStart = "${pkgs.zsh}/bin/zsh -lc 'exec julia ${./julia/pluto-server.jl} ${toString plutoPort}'";
      ExecStartPost = "${pluto-wait-ready}";
      TimeoutStartSec = plutoStartTimeoutSec + 30;
      # Pluto's file picker is relative to the working directory
      WorkingDirectory = "%h";
      Restart = "on-failure";
    };
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
    Install.WantedBy = [ "default.target" ];
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
    Install.WantedBy = [ "default.target" ];
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
