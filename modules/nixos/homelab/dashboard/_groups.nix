# Tile groups, in display order, on one four-column grid: theme.css evens
# out the rows and sets the first two side by side, as halves whose two
# columns land on the four below. Shared by the dashboard (default.nix) and
# svcctl's host menu (controls.nix), which lists hosts in the same order.
[
  {
    name = "Servers";
    columns = 2;
  }
  {
    name = "Desktops";
    columns = 2;
  }
  {
    name = "Tools";
    columns = 4;
  }
  {
    name = "Media";
    columns = 4;
  }
  {
    name = "Games";
    columns = 4;
  }
]
