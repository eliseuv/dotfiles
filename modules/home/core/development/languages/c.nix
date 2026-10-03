{ pkgs, lib, ... }:
{

  home.packages = with pkgs; [

    # LLVM tools for C/C++ development
    clang
    # lowPrio: clang-tools and clang-analyzer both ship bin/scan-view;
    # defer to clang-analyzer's copy on conflict.
    (lib.lowPrio clang-tools)
    clang-manpages
    clang-analyzer

    # Compilation database
    bear

    # Debuggers
    gdb
    lldb
    gf

  ];

}
