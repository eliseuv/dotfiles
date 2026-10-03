{ config, ... }:
{

  services.pueue = {
    enable = true;
    settings = {
      client = {
        dark_mode = true;
      };
      daemon = {
        default_parallel_tasks = { GLaDOS = 4; }.${config.my.host.name} or 2;
      };
    };
  };

}
