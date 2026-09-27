# System-level sops-nix. Decrypts with the host's SSH ed25519 key (the module
# default when openssh is enabled), so each host needs its ssh-to-age
# recipient in .sops.yaml. Secrets live in a per-host file rather than the
# shared secrets.yaml so root on one host can't read the user-level secrets.
{ inputs, ... }:
{

  imports = [ inputs.sops-nix.nixosModules.sops ];

  sops.defaultSopsFormat = "yaml";

}
