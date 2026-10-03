{

  description = "evf's dotfiles";

  nixConfig = {

    substituters = [
      "https://cache.nixos.org"
      "https://nix-community.cachix.org"
    ];

    trusted-substituters = [
      "https://cache.nixos.org"
      "https://nix-community.cachix.org"
    ];

    trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
    ];

  };

  inputs = {

    nixpkgs.url = "nixpkgs/nixos-unstable";

    # Stable Nixpkgs
    nixpkgs-stable.url = "nixpkgs/nixos-26.05";

    # Nixpkgs master, used for packages that need to track upstream releases
    # more closely than nixos-unstable does (e.g. claude-code)
    nixpkgs-master.url = "github:NixOS/nixpkgs/master";

    # Home Manager
    home-manager = {
      url = "github:nix-community/home-manager/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Nix Index Database
    nix-index-database = {
      url = "github:nix-community/nix-index-database";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # SOPS Nix
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Neovim
    neovim-nightly-overlay = {
      url = "github:nix-community/neovim-nightly-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Fenix
    fenix = {
      url = "github:nix-community/fenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Spicetify
    spicetify-nix = {
      url = "github:Gerg-L/spicetify-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # YT-X
    yt-x = {
      url = "github:Benexl/yt-x";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Catppuccin
    catppuccin.url = "github:catppuccin/nix";

    # Declarative Minecraft servers (wheatley)
    nix-minecraft = {
      url = "github:Infinidoge/nix-minecraft";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Third-party Rust tool sources (plain source, not a flake), built
    # via rustPlatform.buildRustPackage in modules/home/core/development/languages/rust-tools.nix
    shoin-src = {
      url = "github:eliseuv/shoin";
      flake = false;
    };

  };

  outputs =
    { nixpkgs, ... }@inputs:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
        overlays = [
          inputs.neovim-nightly-overlay.overlays.default
        ];
      };

      # Imported once here and shared via extraSpecialArgs, rather than
      # re-imported (and re-evaluated) by every module that needs it
      pkgs-master = import inputs.nixpkgs-master {
        inherit system;
        config.allowUnfree = true;
      };

      hosts = import ./lib { inherit inputs system pkgs pkgs-master; };
    in
    {

      packages.${system} =
        let
          ledgerWeb = import ./pkgs/ledger-web { inherit pkgs; };
        in
        {
          ledger-web-bin = ledgerWeb.bin;
          ledger-web-ui = ledgerWeb.webUi;
        };

      inherit (hosts) nixosConfigurations homeConfigurations;

    };

}
