{
  config,
  lib,
  pkgs,
  ...
}:
{

  config = lib.mkIf config.my.home.development.enable {

    home.packages = with pkgs; [

      # LSP
      gopls

      # godoc, goimports, etc.
      gotools

      # Formatter
      gofumpt

      # Modify struct field tags
      gomodifytags
      # Method stubs for interfaces
      impl

      # Debugger
      delve

    ];

    programs.go = {
      enable = true;
      env = {
        GOPATH = ".go";
      };
      telemetry.mode = "off";
    };

  };

}
