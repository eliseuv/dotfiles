{ pkgs, config, ... }:
{
  home.packages = with pkgs; [
    ttyd
    zsh
    lrzsz
    lsix
    libsixel
    openssl
    libwebsockets
    libuv
  ];

  systemd.user.services.ttyd = {
    Unit = {
      Description = "ttyd web terminal";
      After = [ "network.target" ];
    };

    Service = {
      Environment = "LD_LIBRARY_PATH=${pkgs.libwebsockets}/lib:${pkgs.libuv}/lib";
      ExecStart = pkgs.writeShellScript "ttyd-start.sh" ''
        CREDENTIAL=$(<${config.sops.secrets."ttyd/credential".path})
        exec ${pkgs.ttyd}/bin/ttyd -c "$CREDENTIAL" -p 3000 -W ${pkgs.zsh}/bin/zsh
      '';
      Restart = "always";
    };

    Install = {
      WantedBy = [ "default.target" ];
    };
  };
}
