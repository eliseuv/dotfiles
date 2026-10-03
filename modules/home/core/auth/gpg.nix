{ pkgs, ... }:
{

  home.packages = [ pkgs.gcr_4 ];

  programs.gpg = {
    enable = true;
    settings = { };
  };

  services.gpg-agent = {
    enable = true;
    enableZshIntegration = true;
    enableSshSupport = true;
    defaultCacheTtl = 43200;
    maxCacheTtl = 43200;
    defaultCacheTtlSsh = 43200;
    maxCacheTtlSsh = 43200;
    pinentry.package = pkgs.pinentry-gnome3;
  };

}
