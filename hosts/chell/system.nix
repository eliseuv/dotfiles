{ config, lib, ... }:
let
  # Dev servers, as on GLaDOS: 8080, zola serve (1111) and vite (5173).
  devPorts = [
    8080
    1111
    5173
  ];
in
{

  # kanata remaps every keyboard for every user (Esc types a backtick), which
  # would greet dani with a broken Esc; evf gets caps:escape per session
  # instead (home-evf.nix).
  services.kanata.enable = lib.mkForce false;

  # Its ttyd runs a shell as evf, so only wheatley (its reverse proxy) may
  # reach it, over the tailnet. The dev ports are open to the LAN (matched by
  # source address) and the tailnet. Both as for GLaDOS
  # (hosts/GLaDOS/system.nix).
  networking.firewall.extraCommands = ''
    iptables -A nixos-fw -i tailscale0 -s 100.97.1.97 -p tcp --dport ${toString config.my.services.ttyd.port} -j nixos-fw-accept
  ''
  + lib.concatMapStrings (port: ''
    iptables -A nixos-fw -s 192.168.0.0/24 -p tcp --dport ${toString port} -j nixos-fw-accept
    iptables -A nixos-fw -i tailscale0 -p tcp --dport ${toString port} -j nixos-fw-accept
  '') devPorts;

}
