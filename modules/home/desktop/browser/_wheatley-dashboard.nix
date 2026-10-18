{ pkgs }:
pkgs.writeShellApplication {
  name = "wheatley-dashboard";
  runtimeInputs = with pkgs; [
    tailscale
    jq
  ];
  text = ''
    # The short MagicDNS name only resolves while the tailnet is up; otherwise
    # fall back to mDNS. Any failure of the check (daemon down, no tailscale
    # state) counts as "not on the tailnet".
    state=$(tailscale status --peers=false --json 2>/dev/null | jq -r '.BackendState' 2>/dev/null || true)
    if [ "$state" = "Running" ]; then
      url="http://wheatley/"
    else
      url="http://wheatley.local"
    fi

    # Chromium rather than Brave so links out of the app window (service ports)
    # open in Chromium's own browser window. Own profile so --app opens a new
    # window instead of attaching to the running browser session.
    exec chromium --app="$url" --user-data-dir="''${XDG_DATA_HOME:-$HOME/.local/share}/wheatley-dashboard"
  '';
}
