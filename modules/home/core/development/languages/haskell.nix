{
  config,
  lib,
  pkgs,
  ...
}:
{

  config = lib.mkIf config.my.home.development.enable {

    home.packages = with pkgs; [

      # The glorious Glasgow Haskell Compiler
      ghc

      # LSP
      haskell-language-server

      # Linter
      hlint

      # Formatter
      fourmolu

      # Prettifier
      stylish-haskell

      # Projects
      cabal-install
      cabal2nix
      stack
      haskellPackages.implicit-hie

      # Hoogle
      haskellPackages.hoogle

      # Tags generation
      haskellPackages.fast-tags

      # Tools
      ghcid
      ghciwatch

    ];

  };

}
