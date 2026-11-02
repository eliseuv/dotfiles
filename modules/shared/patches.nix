# Temporary workarounds for upstream breakage. Each lives in its own
# modules/{nixos,home}/patches/<id>.nix, which sets my.patches.<id> under the
# same condition as its fix, so the metadata exists exactly where the patch is
# active. PATCHES.md at the root is generated from it (`just patches`).
{ lib, ... }:
let
  patchType = lib.types.submodule {
    options = {

      description = lib.mkOption {
        type = lib.types.str;
        description = "What the patch changes and why.";
      };

      upstream = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "Issue/PR URLs tracking the underlying problem; empty if none is known.";
      };

      removeWhen = lib.mkOption {
        type = lib.types.str;
        description = "The concrete condition under which the patch can be removed.";
      };

      added = lib.mkOption {
        type = lib.types.str;
        description = "ISO date the patch was added.";
      };

      status = {
        checked = lib.mkOption {
          type = lib.types.str;
          description = "ISO date the upstream state was last checked.";
        };
        note = lib.mkOption {
          type = lib.types.str;
          description = "What was observed on that check. Replaced on each review; history is in git.";
        };
      };

      staleWhen = lib.mkOption {
        type = lib.types.nullOr lib.types.bool;
        default = null;
        description = ''
          Optional evaluation-time test that the patch is no longer needed
          (e.g. a version comparison). When true, evaluation warns.
        '';
      };

      locations = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = ''
          Repo-relative files outside the patch module that carry part of the
          change, each marked with a `PATCH(<id>)` comment.
        '';
      };

    };
  };
in
{

  options.my.patches = lib.mkOption {
    type = lib.types.attrsOf patchType;
    default = { };
    description = "Active upstream workarounds, keyed by patch id (= file name).";
  };

}
