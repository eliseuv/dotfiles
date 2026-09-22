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
    # sops-nix's own default.nix hardcodes buildGo125Module, which nixpkgs
    # removed after Go 1.25 went EOL; rebuild sops-install-secrets with the
    # current default builder until sops-nix bumps its own pin.
    package = pkgs.callPackage "${inputs.sops-nix}/pkgs/sops-install-secrets" {
      buildGo125Module = pkgs.buildGoModule;
      # kept in sync with the vendorHash default in sops-nix's own default.nix
      vendorHash = "sha256-SXOd+0yh0DQr3uLVQBdw07J9j5HNuFJSOajDul1B1qo=";
    };

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
