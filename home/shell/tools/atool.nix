{ pkgs, ... }:
{

  programs.atool = {
    enable = true;
    extraPackages = with pkgs; [
      bzip2
      cpio
      gnutar
      gzip
      lhasa
      lzop
      p7zip
      unrar-free
      unzip
      xz
      zip
    ];
  };

}
