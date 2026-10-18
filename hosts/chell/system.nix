{ lib, ... }:
{

  # kanata remaps every keyboard for every user (Esc types a backtick), which
  # would greet dani with a broken Esc; evf gets caps:escape per session
  # instead (home-evf.nix).
  services.kanata.enable = lib.mkForce false;

  # Shared with wheatley, whose nginx hands it to her Pluto as a cookie.
  sops.secrets."pluto/secret".sopsFile = ../../secrets/shared/pluto-chell.yaml;

}
