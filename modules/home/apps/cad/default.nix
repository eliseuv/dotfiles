{
  config,
  lib,
  pkgs,
  ...
}:
{

  config = lib.mkIf config.my.home.apps.enable {

    home.packages = with pkgs; [

      # Interior design
      (sweethome3d.application.overrideAttrs (old: {
        nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [ makeWrapper ];
        # The nixpkgs launcher passes no -Xmx; set the heap explicitly so large
        # models with many textures/furniture don't hit the JVM's default ceiling.
        postFixup = (old.postFixup or "") + ''
          wrapProgram $out/bin/sweethome3d --set JAVA_TOOL_OPTIONS "-Xmx8g"
        '';
      }))

    ];

  };

}
