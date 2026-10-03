{ ... }:
{

  programs.starship = {
    enable = true;
    settings = {
      add_newline = true;
      character.success_symbol = "[λ](bold green)";
      directory = {
        truncation_length = 5;
        truncation_symbol = ".../";
        read_only = " 󰌾";
        substitutions = {
          "Documents" = "󰈙 ";
          "Projects" = "</>";
          "Downloads" = " ";
          "Music" = " ";
          "Pictures" = " ";
        };
      };
    };
  };

}
