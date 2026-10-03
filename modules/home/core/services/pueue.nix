{ lib, ... }:
{

  services.pueue = {
    enable = true;
    settings = {
      client = {
        dark_mode = true;
      };
      daemon = {
        default_parallel_tasks = lib.mkDefault 2;
      };
    };
  };

}
