{ pkgs, ... }:
{

  home.packages = with pkgs; [

    zig

    # Compiler shell completions
    zig-shell-completions

    # LSP
    zls

    # Debugger
    lldb
  ];

}
