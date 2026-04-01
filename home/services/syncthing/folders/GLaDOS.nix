{ ... }:
{

  services.syncthing = {
    settings = {
      folders = {

        "music" = {
          path = "/run/media/evf/Storage/CompanionCube/music";
          devices = [
            "GLaDOS"
            "A56"
          ];
        };

        "org" = {
          path = "~/Documents/org";
          devices = [
            "GLaDOS"
            "TARDIS"
          ];
          versioning = {
            type = "simple";
            params.keep = "8";
          };
        };

        "obsidian" = {
          path = "~/Documents/obsidian";
          devices = [
            "GLaDOS"
            "TARDIS"
            "A56"
          ];
        };

      };
    };
  };

}
