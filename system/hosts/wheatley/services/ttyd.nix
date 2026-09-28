# ttyd web terminal running herdr as evf. A system unit rather than a
# home-manager user service so it lives with the other wheatley services and
# gets dashboard controls; the in-terminal tooling (herdr config, lrzsz,
# sixel) stays in home/extra/ttyd.nix.
{ config, pkgs, ... }:
let
  port = 3000;
  theme = {
    background = "#1e1e2e";
    foreground = "#cdd6f4";
    cursor = "#f5e0dc";
    cursorAccent = "#1e1e2e";
    selection = "#585b70";
    black = "#45475a";
    red = "#f38ba8";
    green = "#a6e3a1";
    yellow = "#f9e2af";
    blue = "#89b4fa";
    magenta = "#f5c2e7";
    cyan = "#94e2d5";
    white = "#bac2de";
    brightBlack = "#585b70";
    brightRed = "#f38ba8";
    brightGreen = "#a6e3a1";
    brightYellow = "#f9e2af";
    brightBlue = "#89b4fa";
    brightMagenta = "#f5c2e7";
    brightCyan = "#94e2d5";
    brightWhite = "#a6adc8";
  };
in
{

  homelab.services.terminal = {
    inherit port;
    expose = "tailnet";
    dashboard = {
      name = "Terminal";
      group = "Dev";
      order = 1;
      description = "ttyd web terminal";
      icon = "mdi-console";
      unit = "ttyd.service";
    };
  };

  sops.secrets."ttyd/credential" = { };

  systemd.services.ttyd = {
    description = "ttyd web terminal";
    after = [ "network.target" ];
    wantedBy = [ "multi-user.target" ];

    environment.LD_LIBRARY_PATH = "${pkgs.libwebsockets}/lib:${pkgs.libuv}/lib";

    serviceConfig = {
      User = "evf";
      Group = "users";
      WorkingDirectory = "/home/evf";
      LoadCredential = "credential:${config.sops.secrets."ttyd/credential".path}";
      Restart = "always";
      ExecStart = pkgs.writeShellScript "ttyd-start.sh" ''
        CREDENTIAL=$(<"$CREDENTIALS_DIRECTORY/credential")
        export SHELL=${pkgs.zsh}/bin/zsh
        # A system unit doesn't inherit the user manager's environment, so
        # give the shell the PATH a user service would see, plus the
        # standalone home-manager profile.
        export PATH=/run/wrappers/bin:$HOME/.nix-profile/bin:/etc/profiles/per-user/evf/bin:/nix/var/nix/profiles/default/bin:/run/current-system/sw/bin
        # herdr keeps its session sockets here; resolved at runtime since
        # evf's uid is assigned at activation. Exists because evf lingers.
        export XDG_RUNTIME_DIR=/run/user/$(${pkgs.coreutils}/bin/id -u)
        exec ${pkgs.ttyd}/bin/ttyd \
          -c "$CREDENTIAL" \
          -t 'theme=${builtins.toJSON theme}' \
          -t 'fontFamily=IosevkaTerm Nerd Font' \
          -p ${toString port} -W ${pkgs.herdr}/bin/herdr
      '';
    };
  };

}
