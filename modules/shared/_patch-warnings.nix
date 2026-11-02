# Warns about patches whose staleWhen test passes. Imported by the NixOS and
# Home Manager sides only: the shared layer is also evaluated bare (hostFacts
# in lib/default.nix), where no `warnings` option exists.
{ config, lib, ... }:
{

  warnings = lib.mapAttrsToList (
    id: patch:
    let
      removeWhen = lib.concatStringsSep " " (
        lib.filter (line: line != "") (map lib.trim (lib.splitString "\n" patch.removeWhen))
      );
    in
    "patch ${id} may be obsolete (see PATCHES.md); remove when: ${removeWhen}"
  ) (lib.filterAttrs (_: patch: patch.staleWhen == true) config.my.patches);

}
