{ ... }:
{

  # Toolchain (ocamlformat, dune, utop, ocp-indent, merlin) is per-switch via
  # `opam install`, not nixpkgs, so it tracks whatever compiler each project uses.
  programs.opam = {
    enable = true;
    enableZshIntegration = true;
  };

}
