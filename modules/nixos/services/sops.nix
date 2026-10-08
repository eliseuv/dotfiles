# System-level sops-nix. Decrypts with the host's SSH ed25519 key (the module
# default when openssh is enabled), so each host needs its ssh-to-age
# recipient in .sops.yaml. Secrets live in a per-host file rather than the
# user file (secrets/users/) so root on one host can't read the user-level secrets.
#
# The module is imported on every host, enabled or not: modules that declare
# secrets (e.g. the homelab dashboard) must evaluate everywhere.
{
  config,
  inputs,
  lib,
  ...
}:
{

  imports = [ inputs.sops-nix.nixosModules.sops ];

  config = lib.mkIf config.my.secrets.system.enable {

    sops.defaultSopsFormat = "yaml";

    # Modules declare the secrets they use.
    sops.defaultSopsFile = ../../../secrets/hosts + "/${config.my.host.name}.yaml";

  };

}
