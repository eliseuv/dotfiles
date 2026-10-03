{ ... }:
{

  services.syncthing = {
    settings = {
      folders = {

        "home" = {
          path = "~/Documents/home";
          devices = [
            "GLaDOS"
          ];
        };

      };
    };
  };

}
