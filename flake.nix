{

  description = "evf's dotfiles";

  nixConfig = {

    substituters = [
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

    # Home Manager
    home-manager = {
      url = "github:nix-community/home-manager/release-25.11";
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

  };

  outputs =
    {
      self,
      nixpkgs,
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

      };

      homeConfigurations = {

        "evf@GLaDOS" = home-manager.lib.homeManagerConfiguration {
          inherit pkgs;
          extraSpecialArgs = {
            inherit inputs;
          };
          modules = [

            ./home/home.nix

            # Syncthing folders
            ./home/services/syncthing/folders/GLaDOS.nix

            # Music Player Daemon
            ./home/media/music/mpd.nix

            # Games
            ./home/games/default.nix

            # Extra stuff
            ./home/extra/rclone/default.nix
            ./home/extra/synology.nix

          ];
        };

        "evf@tardis" = home-manager.lib.homeManagerConfiguration {
          inherit pkgs;
          extraSpecialArgs = {
            inherit inputs;
          };
          modules = [

            ./home/home.nix

            # Syncthing folders
            ./home/services/syncthing/folders/tardis.nix

          ];
        };

      };

    };

}
