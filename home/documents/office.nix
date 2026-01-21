{ pkgs, ... }:
{

  home.packages = with pkgs; [

    libreoffice

    # Spellcheck
    hunspell
    hunspellDicts.pt_BR
    hunspellDicts.en_US

    # Hyphenation
    hyphenDicts.pt_BR
    hyphenDicts.en_US

  ];

}
