{
  config,
  lib,
  pkgs,
  ...
}:
let
  id = "nh-nushell-completer";
in
{

  config = lib.mkIf config.programs.nh.enable {

    # Joined rather than overrideAttrs, which would compile nh locally
    programs.nh.package = pkgs.symlinkJoin {
      inherit (pkgs.nh) name meta;
      paths = [ pkgs.nh ];
      # No -f: the build fails once nh stops shipping the file
      postBuild = ''
        rm "$out/share/nushell/vendor/autoload/nh.nu"
      '';
    };

    my.patches.${id} = {
      description = ''
        Removes nh's nushell completion script, leaving nh completion to
        carapace. The script wraps the existing external completer in a
        closure taking the positional `spans`, which nushell 0.116 deprecates,
        and hands that list on to the previous completer; fzf's expects a
        record, so completing other commands fails with "Cannot find column
        'command'".
      '';
      upstream = [
        "https://github.com/manic-systems/climax/issues/55"
        "https://github.com/manic-systems/climax/pull/56"
      ];
      removeWhen = ''
        share/nushell/vendor/autoload/nh.nu of the nh in the locked nixpkgs
        takes `place` instead of `spans`.
      '';
      added = "2026-11-27";
      status = {
        checked = "2026-11-27";
        note = ''
          nh 4.5.0 with nushell 0.116.1: deprecation warning on completion, and
          the error above when calling the wrapped completer for git. #55 and
          #56 open.
        '';
      };
    };

  };

}
