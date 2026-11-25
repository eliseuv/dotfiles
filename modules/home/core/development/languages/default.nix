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
    # opam has no nushell output. Every line reads `NAME='value'; export NAME;`
    programs.nushell.extraConfig = ''
      if ("~/.opam" | path expand | path exists) {
        let opam_env = (
          ^${lib.getExe' config.programs.opam.package "opam"} env --shell=bash
          | complete
          | get stdout
          | parse --regex "(?m)^(?<name>\\w+)='(?<value>.*)'; export"
          | reduce --fold {} {|row, env_record| $env_record | insert $row.name $row.value }
        )
        load-env ($opam_env | reject --optional PATH)
        if "PATH" in $opam_env { $env.PATH = ($opam_env.PATH | split row (char esep)) }
      }
    '';

  };

}
