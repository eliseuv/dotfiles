{
  pkgs,
  config,
  inputs,
  ...
}:
{

  imports = [ inputs.sops-nix.homeManagerModules.sops ];

  home.packages = with pkgs; [
    age
    sops
  ];

  sops = {
    age.keyFile = "${config.home.homeDirectory}/.config/sops/age/keys.txt";

    defaultSopsFile = ../../secrets.yaml;
    defaultSopsFormat = "yaml";

    secrets = {
      "api-key/alphavantage" = { };
      "api-key/deepseek" = { };
      "api-key/gemini" = { };
      "api-key/openweather" = { };
      "api-key/quandl" = { };
      "api-key/spotify/client-id" = { };
      "api-key/spotify/client-secret" = { };
      "ntfy-topic" = { };
      "ttyd/credential" = { };
    };
  };

}
