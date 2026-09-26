# Packaging for ~/Services/ledger's web app (ledger-web + ledger-web-ui),
# sourced from the commit pinned in ./pin.json. Only git-committed files in
# that project are visible here.
#
# Deliberately not a flake input: that repo only exists on wheatley, and a
# flake input is locked and updated on every host. builtins.fetchGit is
# only forced when a host's config actually uses this package, and pure
# evaluation accepts it because the rev is pinned.
#
# This is the template for packaging other local homebrew projects: one
# `pkgs/<name>/default.nix` + `pin.json`, bumped by `just pin-service`.
{ pkgs }:

let
  pin = pkgs.lib.importJSON ./pin.json;
  src = builtins.fetchGit {
    inherit (pin) url rev;
    # The pinned commit need not be on the default branch.
    allRefs = true;
  };
in
{
  # Builds the whole `ledger` cargo workspace (ledger-core, ledger-tui,
  # ledger-web) from a single Cargo.lock, matching the pattern in
  # home/development/languages/rust-tools.nix. Only bin/ledger-web is
  # actually wired up as a service; the rest are unused byproducts.
  bin = pkgs.rustPlatform.buildRustPackage {
    pname = "ledger-web";
    version = "0.1.0";
    inherit src;
    cargoLock.lockFile = "${src}/Cargo.lock";
    nativeBuildInputs = [ pkgs.pkg-config ];
    buildInputs = [ pkgs.openssl ];
    # Tests expect a live Postgres connection, unavailable in the build
    # sandbox.
    doCheck = false;
  };

  # Builds ledger-web-ui (Vite/React) separately; ledger-web serves the
  # resulting dist/ via the STATIC_DIR env var (see system service).
  webUi = pkgs.buildNpmPackage {
    pname = "ledger-web-ui";
    version = "0.1.0";
    src = "${src}/ledger-web-ui";
    npmDepsHash = "sha256-Vd3AC39U6d3ZD/IaA3yGbkgrhNr0ktGMg3B0LR3n6Eg=";
    nodejs = pkgs.nodejs_22;
    installPhase = ''
      runHook preInstall
      mkdir -p $out
      cp -r dist $out/dist
      runHook postInstall
    '';
  };
}
