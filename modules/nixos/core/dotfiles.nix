# A dotfiles repository shared by every user in the `dotfiles` group
# (core/users.nix), for hosts where each user runs Home Manager from the same
# checkout.
#
# Access comes from ACLs rather than modes or umasks: the default ACL makes
# whatever is created inside group-writable regardless of the creator's umask,
# and the named-group entry grants access whichever group owns a file. Both
# are reapplied recursively at boot and on every switch, which also repairs a
# re-clone or anything copied in with a restrictive mode.
{ config, lib, ... }:
let
  inherit (config.my.dotfiles) path shared;
in
{

  config = lib.mkIf shared {

    assertions = [
      {
        # Homes are 0700, so a repository inside one can't be shared
        assertion = !lib.hasPrefix "/home/" path;
        message = "my.dotfiles.shared needs my.dotfiles.path outside /home, not ${path}";
      }
    ];

    systemd.tmpfiles.rules = [
      # setgid so new entries are grouped with the repository
      "d ${path} 2775 ${config.my.host.primaryUser} dotfiles - -"
      "A+ ${path} - - - - default:group:dotfiles:rwx,group:dotfiles:rwX"
    ];

    # Users get this from Home Manager (home/core/development/git/git.nix);
    # root, for git under sudo, needs it system-wide
    programs.git = {
      enable = true;
      config.safe.directory = [ path ];
    };

  };

}
