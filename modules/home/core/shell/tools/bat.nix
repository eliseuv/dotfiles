{ ... }:
{

  programs.bat = {
    enable = true;
    config = {
      theme = "TwoDark";
    };
  };

  home.shellAliases = {
    b = "bat";
  };

}
