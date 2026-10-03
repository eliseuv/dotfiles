# ttyd web terminal running zellij as evf. A system unit rather than a
# home-manager user service so it lives with the other wheatley services and
# gets dashboard controls; the in-terminal tooling (lrzsz,
# sixel) stays in modules/home/remote/ttyd.nix.
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

  systemd.services.ttyd =
    let
      user = config.users.users.${config.my.host.primaryUser};
      uid = toString user.uid;
    in
    {
      description = "ttyd web terminal";
      # The user manager is what creates /run/user/<uid>, which zellij's
      # sockets and the session bus live in.
      requires = [ "user@${uid}.service" ];
      after = [
        "network.target"
        "user@${uid}.service"
      ];
      wantedBy = [ "multi-user.target" ];

      # Only what a login shell can't derive on its own; zsh -l builds the
      # rest (PATH, home-manager session vars) the same way an SSH login does.
      environment = {
        LD_LIBRARY_PATH = "${pkgs.libwebsockets}/lib:${pkgs.libuv}/lib";
        XDG_RUNTIME_DIR = "/run/user/${uid}";
        DBUS_SESSION_BUS_ADDRESS = "unix:path=/run/user/${uid}/bus";
      };

      serviceConfig = {
        User = user.name;
        Group = "users";
        WorkingDirectory = user.home;
        LoadCredential = "credential:${config.sops.secrets."ttyd/credential".path}";
        Restart = "always";
        ExecStart = pkgs.writeShellScript "ttyd-start.sh" ''
          CREDENTIAL=$(<"$CREDENTIALS_DIRECTORY/credential")
          exec ${pkgs.ttyd}/bin/ttyd \
            -c "$CREDENTIAL" \
            -t 'theme=${builtins.toJSON theme}' \
            -t 'fontFamily=IosevkaTerm Nerd Font' \
            -p ${toString port} -W \
            ${pkgs.zsh}/bin/zsh -lc 'exec ${pkgs.zellij}/bin/zellij attach --create ttyd'
        '';
      };
    };

}
