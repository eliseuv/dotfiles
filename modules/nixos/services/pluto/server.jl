# Pluto server for pluto.service (default.nix).
# Usage: julia server.jl HOST PORT BASE_PATH SECRET_FILE
#
# The secret comes from sops instead of Pluto's per-run random one, so the
# dashboard's nginx can send it as a cookie and pluto-connect can build the
# URL. `ServerSession(; secret)` is the kwdef constructor; `Pluto.run` kwargs
# have no secret option.

using Pluto

host, port, base_url, secret_path = ARGS
secret = String(strip(read(secret_path, String)))

options = Pluto.Configuration.from_flat_kwargs(;
    host,
    port=parse(Int, port),
    base_url,
    launch_browser=false,
)
Pluto.run(Pluto.ServerSession(; secret, options))
