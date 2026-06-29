{ pkgs, ... }:
{
  home.packages = [ pkgs.ttyd ];

  systemd.user.services.wetty = {
    Unit = {
      Description = "WeTTY (using ttyd as WeTTY is not in nixpkgs)";
      After = [ "network.target" ];
    };

    Service = {
      ExecStart = "${pkgs.ttyd}/bin/ttyd -p 3000 -W zsh";
      Restart = "always";
    };

    Install = {
      WantedBy = [ "default.target" ];
    };
  };
}
