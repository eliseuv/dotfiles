{ ... }:
{

  services.syncthing = {
    settings = {
      folders = {

        "home" = {
          path = "~/Documents/home";
          devices = [ ];
        };

        "music" = {
          path = "/run/media/evf/Storage/CompanionCube/music";
          devices = [
            "A56"
          ];
        };

        "org" = {
          path = "~/Documents/org";
          devices = [
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
            "TARDIS"
            "A56"
          ];
        };

        "notes" = {
          path = "~/Documents/notes";
          devices = [
            "TARDIS"
            "A56"
          ];
        };

      };
    };
  };

}
