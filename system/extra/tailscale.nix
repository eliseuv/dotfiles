{ ... }:
{

  services.tailscale = {
    enable = true;
    # Lets evf run `tailscale up/down` without root (used by the waybar toggle)
    extraSetFlags = [ "--operator=evf" ];
  };

}
