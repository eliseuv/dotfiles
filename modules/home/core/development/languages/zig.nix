{
  config,
  lib,
  pkgs,
  ...
}:
{

  config = lib.mkIf config.my.home.development.enable {

    home.packages = with pkgs; [

      zig

      # Compiler shell completions
      zig-shell-completions

      # LSP
      zls

      # Debugger
      lldb
    ];

  };

}
