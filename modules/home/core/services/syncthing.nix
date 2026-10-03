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

        A56.id = "73TB3JF-EE6S5NA-L6GG3C5-HCD3IP2-CK2KEJ4-D4XYTFV-SV2QEEF-AGRJUQM";

        GLaDOS.id = "UX6PZ74-S4VYOHG-ZWPX2ME-2ONFFNN-GWWRYCJ-4S7ZIGW-P3Z3ITG-WWELFAV";

        TARDIS.id = "NR7XLUG-MNAFRJS-IKP3EGN-TBHXJMW-YGMDSES-MLPOKYD-I5PJ23K-J7AJZQE";

        wheatley.id = "UY2GE7S-3IADOE6-WWDQKJD-72P5G2A-RPIBVSR-KXVKZWT-D45T4Y3-PRVB3QW";

      };

    };
  };

}
