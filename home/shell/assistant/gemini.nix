{
  pkgs,
  lib,
  ...
}:
let
  gemini-cli-override = pkgs.gemini-cli.overrideAttrs (old: rec {
    version = "0.19.4";
    src = pkgs.fetchFromGitHub {
      owner = "google-gemini";
      repo = "gemini-cli";
      tag = "v${version}";
      hash = "sha256-bXolK7TEfrmSuntE0uP6MpLNypgyqjaL85bbPi19T5k=";
    };
    npmDepsHash = "sha256-sE3dTngvVukcL7Cwm5MG1NVCBGDbSW2YrkJyGEbg2Ow=";
    npmDeps = pkgs.fetchNpmDeps {
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
