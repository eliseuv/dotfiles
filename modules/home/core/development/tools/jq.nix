{ ... }:
{

  programs.jq.enable = true;

  programs.jqp = {
    enable = true;
    settings = {
      theme.name = "catppuccin-mocha";
    };
  };

}
