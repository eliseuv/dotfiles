{ ... }:
{

  my.users.evf = {
    # Pinned (to the uid it already has) so units can name evf's user
    # manager and runtime dir at eval time (see nixos/services/ttyd.nix).
    uid = 1000;
    linger = true;
    git.email = "eliseuv@pm.me";
  };

}
