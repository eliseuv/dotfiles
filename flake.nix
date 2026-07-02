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
      "https://hyprland.cachix.org"
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

    # Antigravity
    antigravity = {
      url = "github:Hy4ri/antigravity-flake";
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

    # Late.sh
    late-sh = {
      url = "github:mpiorowski/late-sh";
      inputs.nixpkgs.follows = "nixpkgs";
    };

  };

  outputs =
    {
      self,
      nixpkgs,
      nixpkgs-stable,
      home-manager,
      ...
    }@inputs:
    let
      system = "x86_64-linux";
      lib = nixpkgs.lib;
      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
        overlays = [
          inputs.neovim-nightly-overlay.overlays.default
        ];
      };
      mkHome =
        modules:
        home-manager.lib.homeManagerConfiguration {
          inherit pkgs;
          extraSpecialArgs = {
            inherit inputs;
          };
          modules = modules;
        };
    in
    {

      nixosConfigurations = {

        GLaDOS = lib.nixosSystem {
          inherit system;
          specialArgs = { inherit inputs; };
          modules = [ ./system/hosts/GLaDOS/configuration.nix ];
        };

        tardis = lib.nixosSystem {
          inherit system;
          specialArgs = { inherit inputs; };
          modules = [ ./system/hosts/tardis/configuration.nix ];
        };

        wheatley = nixpkgs-stable.lib.nixosSystem {
          inherit system;
          specialArgs = { inherit inputs; };
          modules = [ ./system/hosts/wheatley/configuration.nix ];
        };

        chell = lib.nixosSystem {
          inherit system;
          specialArgs = { inherit inputs; };
          modules = [ ./system/hosts/chell/configuration.nix ];
        };

        rattmann = lib.nixosSystem {
          inherit system;
          specialArgs = { inherit inputs; };
          modules = [ ./system/hosts/rattmann/configuration.nix ];
        };

      };

      homeConfigurations = {

        "evf@GLaDOS" = mkHome [
          ./home/evf-GLaDOS.nix
        ];

        "evf@tardis" = mkHome [
          ./home/evf-tardis.nix
        ];

        "evf@wheatley" = mkHome [
          ./home/evf-wheatley.nix
        ];

        "evf@rattmann" = mkHome [
          ./home/evf-rattmann.nix
        ];

        "evf@chell" = mkHome [
          ./home/home-chell.nix
          {
            home = {
              username = "evf";
              homeDirectory = "/home/evf";
            };
          }
        ];

        "dani@chell" = mkHome [
          ./home/home-chell.nix
          {
            home = {
              username = "dani";
              homeDirectory = "/home/dani";
            };
          }
        ];

      };

    };

}
