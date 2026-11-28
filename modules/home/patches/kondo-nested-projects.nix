{
  lib,
  pkgs,
  ...
}:
let
  id = "kondo-nested-projects";
in
{

  # The fix is the kondo override in modules/home/core/maintenance/kondo.nix,
  # which builds the `kondo` flake input (the fork) instead of the nixpkgs
  # source: both the package list and the unit there need it. kondo.nix is
  # ungated, so neither is this.
  config = {

    my.patches.${id} = {
      description = ''
        Builds kondo from a fork (github:eliseuv/kondo, upstream master plus
        a --nested flag) and passes --nested in kondo-clean.service.
        kondo stops descending at the first directory with a project marker,
        so a root Cargo.toml (Cargo workspaces, the leetcode repo) hides every
        nested project's target or node_modules. With --nested it keeps
        descending, entering everything except the found projects' artifact
        directories.
      '';
      upstream = [ "https://github.com/tbillington/kondo/issues/29" ];
      removeWhen = ''
        A kondo release in the locked nixpkgs can find nested projects
        (a flag like --nested, or the discovery rework of
        https://github.com/tbillington/kondo/issues/111). Switch the unit to
        that flag, then drop the override and the `kondo` flake input.
      '';
      added = "2026-11-26";
      status = {
        checked = "2026-11-27";
        note = ''
          Locked nixpkgs and the latest release are kondo 0.9, whose --help
          has no --nested. Issues #29 and #111 are open. On GLaDOS the patched
          kondo-clean.service run of Nov 27 00:09 cleaned 22/22 projects
          (762.5 MiB).
        '';
      };
      staleWhen = lib.versionOlder "0.9" pkgs.kondo.version;
      locations = [
        "flake.nix"
        "modules/home/core/maintenance/kondo.nix"
      ];
    };

  };

}
