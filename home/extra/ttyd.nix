{ pkgs, config, ... }:
let
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
  imports = [
    ../shell/multiplexer/herdr.nix
  ];

  home.packages = with pkgs; [
    ttyd
    zsh
    lrzsz
    lsix
    libsixel
    openssl
    libwebsockets
    libuv
    nerd-fonts.iosevka-term
  ];

  fonts.fontconfig.enable = true;

  systemd.user.services.ttyd = {
    Unit = {
      Description = "ttyd web terminal";
      After = [ "network.target" ];
    };

    Service = {
      Environment = "LD_LIBRARY_PATH=${pkgs.libwebsockets}/lib:${pkgs.libuv}/lib";
      ExecStart = pkgs.writeShellScript "ttyd-start.sh" ''
        CREDENTIAL=$(<${config.sops.secrets."ttyd/credential".path})
        export SHELL=${pkgs.zsh}/bin/zsh
        exec ${pkgs.ttyd}/bin/ttyd \
          -c "$CREDENTIAL" \
          -t 'theme=${builtins.toJSON theme}' \
          -t 'fontFamily=IosevkaTerm Nerd Font' \
          -p 3000 -W ${pkgs.herdr}/bin/herdr
      '';
      Restart = "always";
    };

    Install = {
      WantedBy = [ "default.target" ];
    };
  };
}
