{ config, lib, ... }:
{

  # kanata remaps every keyboard for every user (Esc types a backtick), which
  # would greet dani with a broken Esc; evf gets caps:escape per session
  # instead (home-evf.nix).
  services.kanata.enable = lib.mkForce false;

  # Its ttyd runs a shell as evf, so only wheatley (its reverse proxy) may
  # reach it, over the tailnet; as for GLaDOS (hosts/GLaDOS/system.nix).
  networking.firewall.extraCommands = ''
    iptables -A nixos-fw -i tailscale0 -s 100.97.1.97 -p tcp --dport ${toString config.my.services.ttyd.port} -j nixos-fw-accept
  '';

}
