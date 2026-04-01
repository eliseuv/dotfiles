{ ... }:
{

  services.syncthing = {
    settings = {
      folders = {

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
