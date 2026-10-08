# Languages that need no more than a package or two; the rest have a module
# each.
{
  config,
  lib,
  pkgs,
  ...
}:
{

  config = lib.mkIf config.my.home.development.enable {

    home.packages = with pkgs; [

      # Assembly LSP
      asm-lsp

      # Fortran LSP
      fortls

      # Lean
      lean4

      # Shell formatter and linter
      shfmt
      shellcheck

      # Uiua
      uiua

    ];

    # OCaml toolchain (ocamlformat, dune, utop, ocp-indent, merlin) is
    # per-switch via `opam install`, not nixpkgs, so it tracks whatever
    # compiler each project uses.
    programs.opam = {
      enable = true;
      enableZshIntegration = true;
    };

  };

}
