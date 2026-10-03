{
  config,
  lib,
  pkgs,
  ...
}:
{

  config = lib.mkIf config.my.home.apps.enable {

    # Temporarily disabled: zotero fails to build since nixpkgs dropped
    # firefox-esr-140 (NixOS/nixpkgs#568692). Re-enable once
    # NixOS/nixpkgs#569006 lands in nixos-unstable. Avoid GC until then so the
    # old store path (and its profile compatibility) stays around.
    # home.packages = with pkgs; [ zotero ];

  };

}
