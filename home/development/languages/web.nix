{ pkgs, ... }:
{

  home.packages = with pkgs; [

    # yarn
    yarn

    # Typescript
    typescript
    typescript-language-server
    vtsls

    # html/css/json/eslint language servers
    vscode-langservers-extracted

    # Sass
    sass

    # Tools
    biome

  ];

  programs = {

    # NodeJS
    npm = {
      enable = true;
    };

    # Bun JS runtime
    bun = {
      enable = true;
      enableGitIntegration = true;
    };
  };

}
