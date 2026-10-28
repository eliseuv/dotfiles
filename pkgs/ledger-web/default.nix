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
  # fetchGit has already materialized the source. Convert its store string
  # to a path for filesets; toSource will track the selected contents.
  sourceRoot = /. + builtins.unsafeDiscardStringContext (toString src);
  uiRoot = sourceRoot + "/ledger-web-ui";
  rustSource = pkgs.lib.fileset.toSource {
    root = sourceRoot;
    fileset =
      with pkgs.lib.fileset;
      unions [
        (sourceRoot + "/Cargo.toml")
        (sourceRoot + "/Cargo.lock")
        (maybeMissing (sourceRoot + "/.cargo"))
        # Keep these roots in sync with Cargo.toml's workspace members. Include
        # crate resources, build scripts and vendored licenses as well as Rust.
        # Markdown is documentation; none is embedded by the current crates.
        (fileFilter (file: !(file.hasExt "md")) (sourceRoot + "/ledger-core"))
        (fileFilter (file: !(file.hasExt "md")) (sourceRoot + "/ledger-web"))
        (fileFilter (file: !(file.hasExt "md")) (sourceRoot + "/ledger-tui"))
      ];
  };
  uiSource = pkgs.lib.fileset.toSource {
    root = uiRoot;
    fileset =
      with pkgs.lib.fileset;
      unions [
        (uiRoot + "/src")
        (maybeMissing (uiRoot + "/public"))
        (uiRoot + "/index.html")
        (uiRoot + "/package.json")
        (uiRoot + "/package-lock.json")
        (uiRoot + "/tsconfig.json")
        (uiRoot + "/tsconfig.app.json")
        (uiRoot + "/tsconfig.node.json")
        (uiRoot + "/vite.config.ts")
      ];
  };
  commonArgs = {
    pname = "ledger-web";
    version = "0.1.0";
    src = rustSource;
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
    src = uiSource;
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
