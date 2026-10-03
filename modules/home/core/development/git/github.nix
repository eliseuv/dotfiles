{ ... }:
{

  programs.gh = {
    enable = true;
    settings = {
      git_protocol = "ssh";
      prompt = "enabled";
      pager = "bat";
      aliases = {
        co = "pr checkout";
        pv = "pr view";
      };
    };
  };

}
