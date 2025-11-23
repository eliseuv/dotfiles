{ pkgs, ... }:

let
  imageLink = "https://github.com/eliseuv/dotfiles/blob/master/wallpapers/dunes.webp";
  image = pkgs.fetchurl {
    url = imageLink;
    hash = "sha256-e03e6d5a6a831eea2885b9f536388a65845852adeaefd8dedac170208793e014=";
  };
in
pkgs.stdenv.mkDerivation {
  name = "sddm-theme";
  src = pkgs.fetchFromGitHub {
    owner = "MarianArlt";
    repo = "sddm-sugar-dark";
    rev = "ceb2c455663429be03ba62d9f898c571650ef7fe";
    hash = "0153z1kylbhc9d12nxy9vpn0spxgrhgy36wy37pk6ysq7akaqlvy";
  };
  installPhase = ''
    mkdir -p $out
    cp -R ./* $out/
    rm $out/Background.jpg
    cp -r ${image} $out/Background.jpg
  '';
}
