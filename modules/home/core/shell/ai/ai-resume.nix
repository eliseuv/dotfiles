# Fuzzy picker over Claude Code and Codex sessions, including the ones the
# remote-control services own; see ai-resume.py for where each list comes
# from. `claude` and `codex` resolve from PATH so the Home Manager wrappers
# are used rather than pinning a second copy into this closure.
{ lib, pkgs, ... }:
let
  aiResume = pkgs.writeShellScriptBin "ai-resume" ''
    export PATH=${lib.makeBinPath [ pkgs.fzf ]}:$PATH
    exec ${pkgs.python3}/bin/python3 -I ${./ai-resume.py} "$@"
  '';
in
{

  home.packages = [ aiResume ];

  home.shellAliases.ar = "ai-resume";

}
