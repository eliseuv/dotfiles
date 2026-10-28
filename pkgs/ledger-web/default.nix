# Packaging for the committed revision pinned in ./pin.json. Keeping this
# source outside the flake inputs lets other hosts evaluate without fetching
# the repository that exists only on wheatley.
{
  pkgs,
  crane,
  src ?
    let
      pin = pkgs.lib.importJSON ./pin.json;
    in
    builtins.fetchGit {
      inherit (pin) url rev;
      allRefs = true;
    },
}:
let
  craneLib = crane.mkLib pkgs;
  commonArgs = {
    pname = "ledger-web";
    version = "0.1.0";
    inherit src;
    # Keep the workspace build and dependency features identical in both
    # stages, so Cargo can reuse the release artifacts without recompiling.
    cargoExtraArgs = "--locked --workspace";
    nativeBuildInputs = [ pkgs.pkg-config ];
    buildInputs = [ pkgs.openssl ];
    # Deployment checks run tests separately; the Nix sandbox has no Postgres.
    doCheck = false;
  };
  # Crane stubs local crate sources here. Changes to application code do not
  # invalidate this derivation; manifests, the lockfile and build inputs do.
  cargoArtifacts = craneLib.buildDepsOnly commonArgs;
in
{
  bin = craneLib.buildPackage (
    commonArgs
    // {
      inherit cargoArtifacts;
      # The service keeps these artifacts alive across garbage collection.
      passthru = { inherit cargoArtifacts; };
    }
  );

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
