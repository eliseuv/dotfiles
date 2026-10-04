# ttyd web terminal running zellij as the primary user. A system unit rather
# than a home-manager user service so it runs without a login session; the
# in-terminal tooling (lrzsz, sixel) stays in modules/home/remote/ttyd.nix.
#
# No login of its own: every instance sits behind wheatley's dashboard nginx,
# which asks for the dashboard password (dashboard/controls.nix), so one
# password covers the dashboard's actions and every terminal. Keep ttyd off
# anything else that can reach it: `interface = "lo"` on wheatley, a firewall
# rule admitting only wheatley elsewhere.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.my.services.ttyd;
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

  config = lib.mkIf cfg.enable {

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
          Restart = "always";
          ExecStart = pkgs.writeShellScript "ttyd-start.sh" ''
            exec ${pkgs.ttyd}/bin/ttyd \
              -t 'theme=${builtins.toJSON theme}' \
              -t 'fontFamily=${config.my.theme.monoFont.name}' \
              -p ${toString cfg.port} -W${
                lib.optionalString (cfg.basePath != "/") " -b ${lib.escapeShellArg cfg.basePath}"
              }${lib.optionalString (cfg.interface != null) " -i ${lib.escapeShellArg cfg.interface}"} \
              ${pkgs.zsh}/bin/zsh -lc 'exec ${pkgs.zellij}/bin/zellij attach --create ttyd'
          '';
        };
      };

  };

}
