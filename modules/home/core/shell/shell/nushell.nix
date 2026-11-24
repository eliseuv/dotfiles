# Nushell with zsh.nix's conveniences. Home Manager's own integrations
# (starship, zoxide, direnv, television, ...) switch on with it; tools of ours
# that need a port keep it beside their zsh counterpart.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (config.my.home) nuCommands;

  # Home Manager gives nushell home.shellAliases as they are, but a nushell
  # alias is a single command without expansions.
  posixOnly =
    command:
    lib.any (token: lib.hasInfix token command) [
      "|"
      "&"
      ";"
      ">"
      "<"
      "$"
      "`"
      "\n"
    ]
    || builtins.match "[A-Za-z_][A-Za-z0-9_]*=.*" command != null;
  unported = lib.attrNames (lib.filterAttrs (_: posixOnly) config.programs.nushell.shellAliases);

  # oh-my-zsh's git-auto-fetch, with its guard and log files, so both shells
  # share the interval
  gitAutoFetch = pkgs.writeShellApplication {
    name = "git-fetch-all";
    runtimeInputs = with pkgs; [
      coreutils
      git
      openssh
    ];
    text = ''
      gitdir=$(git rev-parse --git-dir 2>/dev/null) || exit 0
      log=$gitdir/FETCH_LOG
      if [[ ! -w $gitdir || -f $gitdir/NO_AUTO_FETCH ]] || [[ -f $log && ! -w $log ]]; then
        exit 0
      fi
      lastrun=$(stat --format=%Y "$log" 2>/dev/null || echo 0)
      if (($(date +%s) - lastrun < ''${GIT_AUTO_FETCH_INTERVAL:-60})); then
        exit 0
      fi
      date -R >"$log" 2>&1
      GIT_SSH_COMMAND="ssh -o BatchMode=yes" GIT_TERMINAL_PROMPT=0 \
        git fetch --all --recurse-submodules=yes >>"$log" 2>&1
    '';
  };
in
{

  options.my.home.nuCommands = lib.mkOption {
    type = lib.types.attrsOf lib.types.lines;
    default = { };
    example = {
      serve = ''
        def --wrapped serve [...args] { PORT=8000 python ...$args }
      '';
    };
    description = "Nushell definitions of the `home.shellAliases` that aren't valid as nushell aliases, by alias name.";
  };

  # The aliases defined in nuCommands instead
  options.programs.nushell.shellAliases = lib.mkOption {
    apply = aliases: removeAttrs aliases (lib.attrNames nuCommands);
  };

  config = {

    assertions = [
      {
        assertion = unported == [ ];
        message = "home.shellAliases that nushell can't parse need a definition in my.home.nuCommands: ${lib.concatStringsSep ", " unported}";
      }
    ];

    programs.nushell = {
      enable = true;
      # zsh passes the session on; this is for nu started any other way
      loadSessionVariables = true;

      settings = {
        show_banner = false;
        edit_mode = "emacs";
        history = {
          file_format = "sqlite";
          max_size = 1000000;
          isolation = false;
          ignore_space_prefixed = true;
        };
      };

      # Home Manager's eza module adds it to zsh only
      shellAliases.lla = "eza -la";

      extraConfig = lib.mkMerge [

        # Ahead of the rest, which may redefine some
        (lib.mkOrder 600 ''
          use ${pkgs.nu_scripts}/share/nu_scripts/aliases/git/git-aliases.nu *
        '')

        (lib.concatStrings (lib.attrValues nuCommands))

        ''
          $env.config.keybindings ++= [{
            name: accept_history_hint
            modifier: control
            keycode: space
            mode: [emacs vi_insert]
            event: { send: historyhintcomplete }
          }]

          # Detached rather than `job spawn`, whose jobs nu warns about on exit
          $env.config.hooks.pre_prompt ++= [{||
            ^${lib.getExe' pkgs.util-linux "setsid"} --fork ${lib.getExe gitAutoFetch} o+e>| ignore
          }]

          # Toggle the above for the current repository
          def git-auto-fetch [] {
            let gitdir = (^git rev-parse --git-dir | complete)
            if $gitdir.exit_code != 0 { return }
            let guard = ($gitdir.stdout | str trim | path join NO_AUTO_FETCH)
            if ($guard | path exists) {
              ^rm $guard
              print $"(ansi green_bold)enabled(ansi reset)"
            } else {
              ^touch $guard
              print $"(ansi red_bold)disabled(ansi reset)"
            }
          }
        ''

        # As in zsh.nix
        (lib.mkOrder 2000 ''
          if $nu.is-interactive {
            if ($env.TMUX? | is-not-empty) {
              ^${lib.getExe pkgs.fastfetch} --logo-type builtin
            } else {
              ^${lib.getExe pkgs.fastfetch}
            }
          }
        '')

      ];
    };

    # Completions for external commands. zsh has its own.
    programs.carapace = {
      enable = true;
      enableBashIntegration = false;
      enableZshIntegration = false;
      environment.CARAPACE_BRIDGES = "zsh,bash";
    };

    catppuccin.nushell.enable = true;

  };

}
