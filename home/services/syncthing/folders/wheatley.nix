{ ... }:
{

  services.syncthing = {
    settings = {
      folders = {

        "notes" = {
          path = "~/Documents/notes";
          devices = [
            "GLaDOS"
            "TARDIS"
          ];
        };

      };
    };
  };

}
