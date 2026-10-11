# Flat character icons with fixed body colors. Only the optics and heart
# turn dark when off; unknown optics use a neutral outline.
let
  inherit (import ./_svg.nix) svgUri;
  variants =
    draw:
    builtins.mapAttrs (_: draw) {
      on = "on";
      off = "off";
      unknown = "unknown";
    };
  icon = body: svgUri "<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 32 32'>${body}</svg>";
  shell = "#fff";
  accent = state: color: if state == "on" then color else "#79858f";
  optic =
    state: x: y: radius: color:
    "<circle cx='${toString x}' cy='${toString y}' r='${toString radius}' fill='${
      if state == "on" then
        color
      else if state == "off" then
        "#10171e"
      else
        "none"
    }' stroke='${if state == "off" then "#56616b" else accent state color}' stroke-width='1.2'/>";
in
{
  wheatley = variants (
    state:
    icon "<path d='M5 8Q16 -1 27 8M5 25Q16 34 27 25' fill='none' stroke='#69747e' stroke-width='2.2' stroke-linecap='round'/><circle cx='16' cy='16' r='11' fill='${shell}'/><circle cx='16' cy='16' r='7' fill='#242b32'/>${optic state 16 16 4 "#5fc3ff"}"
  );

  cube = variants (
    state:
    icon "<rect x='2' y='2' width='28' height='28' rx='4' fill='#626b73'/><rect x='4' y='4' width='24' height='24' rx='2' fill='#929ba3'/><g fill='#dce1e5'><rect x='3' y='3' width='7' height='7' rx='2'/><rect x='22' y='3' width='7' height='7' rx='2'/><rect x='3' y='22' width='7' height='7' rx='2'/><rect x='22' y='22' width='7' height='7' rx='2'/></g><circle cx='16' cy='16' r='6' fill='none' stroke='#f48cbe' stroke-width='2' /><path d='M16 20l-4-4c-3-4 2-7 4-3c2-4 7-1 4 3z' fill='${
      if state == "off" then "#242b32" else accent state "#f48cbe"
    }'/>"
  );

  glados = variants (
    state:
    icon "<path d='M14 1v5M18 1v5M13 1Q9 3 9 8M19 1Q23 3 23 8' fill='none' stroke='#69747e' stroke-width='1.4'/><path d='M7 10Q0 17 7 24M25 10Q32 17 25 24' fill='none' stroke='#a4adb5' stroke-width='2'/><path d='M10 8Q16 2 22 8L23 25Q16 32 9 25z' fill='${shell}'/><rect x='12' y='10' width='8' height='15' rx='3' fill='#242b32'/>${
      optic state 16 18 2.4 "#ffcc33"
    }"
  );

}
