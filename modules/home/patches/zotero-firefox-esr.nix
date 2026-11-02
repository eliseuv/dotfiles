# The change itself is in-place (a commented-out package can't be expressed
# from here); this module only registers it.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  id = "zotero-firefox-esr";
in
{

  config = lib.mkIf config.my.home.apps.enable {

    my.patches.${id} = {
      description = ''
        Zotero is left out of home.packages. Zotero 10 runs on Firefox ESR
        140, which nixpkgs dropped; the fix that landed builds it against a
        prebuilt Firefox 140 ESR that is marked insecure, so it doesn't
        evaluate without permitting that package. Don't GC the old zotero
        store path meanwhile, so its profile compatibility stays around.
      '';
      upstream = [
        "https://github.com/NixOS/nixpkgs/issues/568692"
        "https://github.com/NixOS/nixpkgs/pull/572466"
      ];
      removeWhen = ''
        pkgs.zotero evaluates without permitting an insecure package (expected
        with Zotero 11 on Firefox ESR 153), or permitting
        firefox-esr-140-bin-unwrapped is accepted.
      '';
      added = "2026-10-01";
      status = {
        checked = "2026-11-02";
        note = ''
          #568692 closed 2026-10-15; #572466 merged and in the locked nixpkgs,
          but zotero-10.0.4 refuses to evaluate: it depends on insecure
          firefox-esr-140-bin-unwrapped-140.17.0esr.
        '';
      };
      # Evaluates once the insecure Firefox dependency is gone
      staleWhen = (builtins.tryEval pkgs.zotero.drvPath).success;
      locations = [ "modules/home/apps/documents/default.nix" ];
    };

  };

}
