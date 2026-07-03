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
      ${lib.getExe pkgs.fastfetch}
    '' + lib.optionalString (config ? sops) ''

      export ALPHAVANTAGE_API_KEY=$(<${config.sops.secrets."api-key/alphavantage".path})
      export DEEPSEEK_API_KEY=$(<${config.sops.secrets."api-key/deepseek".path})
      export GEMINI_API_KEY=$(<${config.sops.secrets."api-key/gemini".path})
      export OPENWEATHER_API_KEY=$(<${config.sops.secrets."api-key/openweather".path})
      export QUANDL_API_KEY=$(<${config.sops.secrets."api-key/quandl".path})
      export NTFY_TOPIC=$(<${config.sops.secrets."ntfy-topic".path})
    '';
    oh-my-zsh = {
      enable = true;
      plugins = [
        "git"
        "git-auto-fetch"
      ];
    };
  };

}
