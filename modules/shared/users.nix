# Who the users are, independent of host; users/<name>.nix fills one entry
# each. NixOS creates the accounts listed in `my.host.users`, and Home Manager
# reads the entry for `home.username`.
{ lib, ... }:
{

  options.my.users = lib.mkOption {
    default = { };
    type = lib.types.attrsOf (
      lib.types.submodule (
        { name, ... }:
        {
          options = {

            description = lib.mkOption {
              type = lib.types.str;
              default = name;
            };

            uid = lib.mkOption {
              type = lib.types.nullOr lib.types.int;
              default = null;
            };

            language = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
              example = "pt_BR.UTF-8";
              description = "UI locale given to the user's account until they pick one themselves (desktop/accounts.nix); null for the system's.";
            };

            linger = lib.mkOption {
              type = lib.types.bool;
              default = false;
              description = "Keep the user manager running with no session logged in.";
            };

            git = {
              name = lib.mkOption {
                type = lib.types.str;
                default = name;
              };
              email = lib.mkOption { type = lib.types.str; };
            };

          };
        }
      )
    );
  };

}
