{ ... }:
{

  services.syncthing = {

    enable = true;

    extraOptions = [ "--allow-newer-config" ];

    settings = {

      gui = {
        theme = "black";
      };

      devices = {

        A53.id = "7IIH4V5-BZAZC7A-JX46YON-TIKGKIJ-X7MFSPQ-C4Q5MMS-RNJAMAY-MSRZDQM";

        GLaDOS.id = "UX6PZ74-S4VYOHG-ZWPX2ME-2ONFFNN-GWWRYCJ-4S7ZIGW-P3Z3ITG-WWELFAV";

        TARDIS.id = "NR7XLUG-MNAFRJS-IKP3EGN-TBHXJMW-YGMDSES-MLPOKYD-I5PJ23K-J7AJZQE";

      };

    };
  };

}
