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
  # which applies ./kondo-nested-projects.patch: both the package list and
  # the unit there need the patched build. kondo.nix is ungated, so neither
  # is this.
  config = {

    my.patches.${id} = {
      description = ''
        Adds a --nested flag to kondo and passes it in kondo-clean.service.
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
        that flag, then drop the override and the patch file.
      '';
      added = "2026-11-26";
      status = {
        checked = "2026-11-26";
        note = ''
          kondo 0.9 (latest release) on GLaDOS: every daily run of
          kondo-clean.service reported "Projects cleaned: 0/0"; a dry run of
          the patched build over ~/Projects found 23 projects (819 MiB),
          including leetcode/p169-majority-element/target and
          ledger/ledger-web-ui/node_modules. Issue #29 is open with no PR.
        '';
      };
      staleWhen = lib.versionOlder "0.9" pkgs.kondo.version;
      locations = [ "modules/home/core/maintenance/kondo.nix" ];
    };

  };

}
