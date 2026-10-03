{ ... }:
{

  programs.bottom = {
    enable = true;
    settings = {
      flags = {
        hide_avg_cpu = true;
        rate = 500;
        unnormalized_cpu = true;
        disable_click = true;
        process_memory_as_value = true;
      };
      process = {
        columns = [
          "PID"
          "Name"
          "User"
          "State"
          "CPU%"
          "Mem%"
          "R/s"
          "W/s"
          "GPU%"
          "GMem%"
          "T.Read"
          "T.Write"
        ];
      };
      styles = {
        memory = {
          ram_color = "cyan";
          swap_color = "blue";
        };
        network = {
          rx_color = "light green";
          tx_color = "light red";
        };

        tables = {
          headers = {
            color = "blue";
            bold = true;
          };
        };

        graphs = {
          graph_color = "dark gray";
        };

        widgets = {
          border_color = "dark gray";
          selected_border_color = "magenta";
          selected_text = {
            color = "black";
            bg_color = "cyan";
          };
        };

      };

    };
  };
  home.shellAliases = {
    bt = "btm";
  };

}
