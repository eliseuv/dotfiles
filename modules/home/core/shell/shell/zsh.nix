{
  config,
  pkgs,
  lib,
  ...
}:
{

  programs.zsh = {
    enable = true;
    syntaxHighlighting.enable = true;
    enableCompletion = true;
    autosuggestion = {
      enable = true;
      strategy = [
        "history"
        "completion"
      ];
    };
    enableVteIntegration = true;
    defaultKeymap = "emacs";
    history = {
      append = true;
      extended = true;
      expireDuplicatesFirst = true;
      ignoreAllDups = true;
      ignoreSpace = true;
      save = 1000000;
      size = 1000000;
    };
    initContent = ''
      bindkey '^ ' autosuggest-accept
      bindkey  "^[[H"   beginning-of-line
      bindkey  "^[[F"   end-of-line
      bindkey  "^[[3~"  delete-char
      # tmux drops fastfetch's unwrapped kitty graphics, and kitty-icat is
      # unreliable there (oversized in splits, lost before the client attaches)
      if [[ -n $TMUX ]]; then
        ${lib.getExe pkgs.fastfetch} --logo-type builtin
      else
        ${lib.getExe pkgs.fastfetch}
      fi
    '' + lib.optionalString config.my.secrets.user.enable ''

      export ALPHAVANTAGE_API_KEY=$(<${config.sops.secrets."alphavantage/api-key".path})
      export DEEPSEEK_API_KEY=$(<${config.sops.secrets."deepseek/api-key".path})
      export GEMINI_API_KEY=$(<${config.sops.secrets."gemini/api-key".path})
      export OPENWEATHER_API_KEY=$(<${config.sops.secrets."openweather/api-key".path})
      export QUANDL_API_KEY=$(<${config.sops.secrets."quandl/api-key".path})
      export NTFY_TOPIC=$(<${config.sops.secrets."ntfy/topic".path})
    '';
    oh-my-zsh = {
      enable = true;
      # Ahead of plugins other modules add (direnv)
      plugins = lib.mkBefore [
        "git"
        "git-auto-fetch"
      ];
    };
  };

}
