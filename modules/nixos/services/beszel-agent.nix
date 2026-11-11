# Beszel agent, polled by the hub on wheatley (hosts/wheatley/services/
# beszel.nix): the hub connects to each agent over SSH, never the other way,
# so nothing is stored here and the hub notices when a host goes away.
# On wheatley it answers on loopback only; elsewhere it listens on every
# address but only wheatley may reach it, over the tailnet.
{ config, lib, ... }:
let
  # The hub's public key, which agents accept connections from. The hub
  # generates its key pair on first start, so this is only known once it has
  # run: copy it from the hub's "Add system" dialog, then switch the agents.
  # Not a secret.
  hubKey = null;

  port = 45876;
  isHub = config.my.host.name == "wheatley";
in
{

  config = lib.mkIf config.my.services.beszelAgent.enable (
    if hubKey == null then
      {
        warnings = [
          "my.services.beszelAgent: hubKey isn't set yet (services/beszel-agent.nix), so the agent is left off"
        ];
      }
    else
      {
        services.beszel.agent = {
          enable = true;
          environment = {
            KEY = hubKey;
            LISTEN = if isHub then "127.0.0.1:${toString port}" else toString port;
          };
        };

        networking.firewall.extraCommands = lib.mkIf (!isHub) ''
          iptables -A nixos-fw -i tailscale0 -s ${config.homelab.network.tailnet.wheatley} -p tcp --dport ${toString port} -j nixos-fw-accept
        '';
      }
  );

}
