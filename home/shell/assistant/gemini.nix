{
  pkgs-unstable,
  lib,
  ...
}:
let
  gemini-cli-override = pkgs-unstable.gemini-cli.overrideAttrs (old: rec {
    version = "0.17.1";
    src = pkgs-unstable.fetchFromGitHub {
      owner = "google-gemini";
      repo = "gemini-cli";
      tag = "v${version}";
      hash = "sha256-zfORrAMVozHiUawWiy3TMT+pjEaRJ/DrHeDFPJiCp38=";
    };
    npmDepsHash = "sha256-dKaKRuHzvNJgi8LP4kKsb68O5k2MTqblQ+7cjYqLqs0=";
    npmDeps = pkgs-unstable.fetchNpmDeps {
      inherit src;
      name = "${old.pname}-${version}-npm-deps";
      hash = npmDepsHash;
    };
  });
in
{
  home.packages = [

    # Custom version of Gemini CLI
    gemini-cli-override

  ];
}
