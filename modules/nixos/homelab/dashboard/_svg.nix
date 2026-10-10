# Data-URI SVGs shared by the dashboard (default.nix) and its host pages
# (hosts.nix).
rec {

  # Percent-encoded so it works as a data URI in both favicons and CSS url().
  svgUri =
    svg:
    "data:image/svg+xml," + builtins.replaceStrings [ "<" ">" "#" " " ] [ "%3C" "%3E" "%23" "%20" ] svg;

  # Generic 8-blade camera iris, used as the favicon and (as a CSS mask) the
  # header mark.
  iris =
    fill:
    svgUri "<svg xmlns='http://www.w3.org/2000/svg' viewBox='-50 -50 100 100'><mask id='m'><circle r='46' fill='white'/><polygon points='15,0 10.6,10.6 0,15 -10.6,10.6 -15,0 -10.6,-10.6 0,-15 10.6,-10.6'/><path stroke='black' stroke-width='4' d='M15 0L24.4 45.9M10.6 10.6L-15.2 49.7M0 15L-45.9 24.4M-10.6 10.6L-49.7 -15.2M-15 0L-24.4 -45.9M-10.6 -10.6L15.2 -49.7M0 -15L45.9 -24.4M10.6 -10.6L49.7 15.2'/></mask><circle r='46' fill='${fill}' mask='url(#m)'/></svg>";

}
