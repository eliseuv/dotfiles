# Look shared by every themed program, on either side (ttyd's web terminal is
# a NixOS service). Terminal colour schemes (TokyoNight) are chosen per
# program and aren't covered here.
{ lib, pkgs, ... }:
{

  options.my.theme = {

    flavor = lib.mkOption {
      type = lib.types.enum [
        "latte"
        "frappe"
        "macchiato"
        "mocha"
      ];
      default = "mocha";
      description = "Catppuccin flavor.";
    };

    accent = lib.mkOption {
      type = lib.types.str;
      default = "mauve";
      description = "Catppuccin accent colour.";
    };

    monoFont = {
      name = lib.mkOption {
        type = lib.types.str;
        default = "IosevkaTerm Nerd Font";
      };
      package = lib.mkOption {
        type = lib.types.package;
        default = pkgs.nerd-fonts.iosevka-term;
        defaultText = lib.literalExpression "pkgs.nerd-fonts.iosevka-term";
      };
    };

  };

}
