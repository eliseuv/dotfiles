{ ... }:
{

  services.syncthing = {
    settings = {
      folders = {

        "org" = {
          path = "~/Documents/org";
          devices = [
            "GLaDOS"
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
            "A56"
          ];
        };

        "notes" = {
          path = "~/Documents/notes";
          devices = [
            "GLaDOS"
            "A56"
          ];
        };

      };
    };
  };

}
