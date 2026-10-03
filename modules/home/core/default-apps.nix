# Default applications by MIME type. xdg.mimeApps keeps registering an
# association apart from making it the default; every entry here does both.
# Set by modules rather than hosts, so declared here and not in the shared
# layer.
{ config, lib, ... }:
let
  defaultApps = config.my.home.defaultApps;
in
{

  options.my.home.defaultApps = lib.mkOption {
    type = lib.types.attrsOf (lib.types.listOf lib.types.str);
    default = { };
    example = {
      "application/pdf" = [ "org.pwmt.zathura-pdf-mupdf.desktop" ];
    };
    description = "Desktop entries to associate with, and open by default, each MIME type.";
  };

  config = lib.mkIf (defaultApps != { }) {
    xdg.mimeApps = {
      enable = true;
      associations.added = defaultApps;
      defaultApplications = defaultApps;
    };
  };

}
