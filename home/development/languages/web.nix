{ pkgs, ... }:
{

  home.packages = with pkgs; [

    # Typescript
    typescript
    typescript-language-server
    vtsls

    # html/css/json/eslint language servers
    vscode-langservers-extracted

    # Sass
    sass

    # Vue
    vue-language-server

  ];

}
