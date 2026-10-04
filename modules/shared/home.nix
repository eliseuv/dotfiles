# Home Manager feature sets. Declared in the shared layer like everything
# else, so host specs can set them; only Home Manager modules act on them.
{ lib, ... }:
{

  options.my.home = {

    apps.enable = lib.mkEnableOption "the full desktop app set (GUI editors, documents, media, social)";

    notes.enable = lib.mkEnableOption "the notes vault environment and its agent skills";

    cloudSync.enable = lib.mkEnableOption "rclone and its sync services";

    remoteAccess.enable = lib.mkEnableOption "ttyd terminal tooling and the Claude Code and Codex remote-control services";

    firefox.customUI = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Firefox with the custom userChrome and Tridactyl; off for stock Firefox.";
    };

  };

}
