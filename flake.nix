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

      # Host matrix: which users run Home Manager on each host and which
      # nixpkgs branch the system follows (unstable unless stated otherwise).
      hosts = {
        GLaDOS = {
          users = [ "evf" ];
        };
        tardis = {
          users = [ "evf" ];
        };
        wheatley = {
          users = [ "evf" ];
          nixpkgs = nixpkgs-stable;
        };
        rattmann = {
          users = [ "evf" ];
        };
        chell = {
          users = [
            "evf"
            "dani"
          ];
        };
      };

      mkSystem =
        hostName: host:
        (host.nixpkgs or nixpkgs).lib.nixosSystem {
          inherit system;
          specialArgs = { inherit inputs; };
          modules = [ ./system/hosts/${hostName}/configuration.nix ];
        };

      mkHome =
        user: hostName:
        home-manager.lib.homeManagerConfiguration {
          inherit pkgs;
          extraSpecialArgs = {
            inherit inputs hostName;
          };
          modules = [
            ./home/hosts/${hostName}.nix
            ./home/users/${user}.nix
            {
              home = {
                username = user;
                homeDirectory = "/home/${user}";
              };
            }
          ];
        };
    in
    {

      nixosConfigurations = builtins.mapAttrs mkSystem hosts;

      homeConfigurations = lib.listToAttrs (
        lib.concatLists (
          lib.mapAttrsToList (
            hostName: host:
            map (user: {
              name = "${user}@${hostName}";
              value = mkHome user hostName;
            }) host.users
          ) hosts
        )
      );

    };

}
