{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:
{

  imports = [ inputs.spicetify-nix.homeManagerModules.default ];

  config = lib.mkIf config.my.home.apps.enable {

    programs.spicetify =
      let
        spicePkgs = inputs.spicetify-nix.legacyPackages.${pkgs.stdenv.hostPlatform.system};
      in
      {
        enable = true;
        enabledExtensions = with spicePkgs.extensions; [
          adblock
          keyboardShortcut
          powerBar
          shuffle
          beautifulLyrics
          hidePodcasts
          fullAppDisplayMod
          coverAmbience

        ];
        theme = spicePkgs.themes.catppuccin;
        colorScheme = "mocha";
      };

  };

}
