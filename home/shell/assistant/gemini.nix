{
  pkgs-unstable,
  lib,
  ...
}:
let
  gemini-cli-override = pkgs-unstable.gemini-cli.overrideAttrs (old: rec {
    version = "0.18.4";
    src = pkgs-unstable.fetchFromGitHub {
      owner = "google-gemini";
      repo = "gemini-cli";
      tag = "v${version}";
      hash = "sha256-TSHL3X+p74yFGTNFk9r4r+nnul2etgVdXxy8x9BjsRg=";
    };
    npmDepsHash = "sha256-2Z6YrmUHlYKRU3pR0ZGwQbBgzNFqakBB6LYZqf66nSs=";
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
