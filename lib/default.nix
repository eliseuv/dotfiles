# Builds the flake's configurations. Every directory under hosts/ is a host;
# everything else about it (users, nixpkgs branch, features) comes from its
# options, set in hosts/<name>/default.nix.
{
  inputs,
  system,
  pkgs,
  pkgs-master,
}:
let
  inherit (inputs.nixpkgs) lib;

  # Every .nix file under `dir`, except helpers named _*.nix
  importTree =
    dir:
    lib.filter (path: lib.hasSuffix ".nix" path && !lib.hasPrefix "_" (baseNameOf path)) (
      lib.filesystem.listFilesRecursive dir
    );

  hostNames = lib.attrNames (
    lib.filterAttrs (_: type: type == "directory") (builtins.readDir ../hosts)
  );

  # Option declarations, user facts and the host's spec: part of both the
  # NixOS and the Home Manager evaluation, so they agree on every `my.*` value
  sharedModules =
    hostName:
    importTree ../modules/shared
    ++ importTree ../users
    ++ [
      ../hosts/${hostName}/default.nix
      { my.host.name = hostName; }
    ];

  # Host-specific raw configuration, for whatever has no option
  ifExists = path: lib.optional (builtins.pathExists path) path;

  # Only the shared layer, for what the flake needs to know before it can
  # pick a nixpkgs or enumerate users
  hostFacts =
    hostName:
    (lib.evalModules {
      modules = sharedModules hostName;
      specialArgs = { inherit pkgs; };
    }).config.my.host;

  mkSystem =
    hostName:
    let
      nixpkgs =
        {
          unstable = inputs.nixpkgs;
          stable = inputs.nixpkgs-stable;
        }
        .${(hostFacts hostName).channel};
    in
    nixpkgs.lib.nixosSystem {
      inherit system;
      specialArgs = { inherit inputs; };
      modules =
        sharedModules hostName
        ++ importTree ../modules/nixos
        ++ [ ../hosts/${hostName}/hardware.nix ]
        ++ ifExists ../hosts/${hostName}/system.nix;
    };

  mkHome =
    user: hostName:
    inputs.home-manager.lib.homeManagerConfiguration {
      inherit pkgs;
      extraSpecialArgs = { inherit inputs pkgs-master; };
      modules = sharedModules hostName ++ [
        ../hosts/${hostName}/home.nix
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

  nixosConfigurations = lib.genAttrs hostNames mkSystem;

  homeConfigurations = lib.listToAttrs (
    lib.concatMap (
      hostName:
      map (user: {
        name = "${user}@${hostName}";
        value = mkHome user hostName;
      }) (hostFacts hostName).users
    ) hostNames
  );

}
