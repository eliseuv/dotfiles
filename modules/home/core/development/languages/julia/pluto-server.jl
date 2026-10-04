# Pluto server for the `pluto` systemd user service.
#
# The secret is persisted instead of Pluto's per-run random one, so clients
# (pluto-connect) can read it from a file and URLs survive restarts.
# `ServerSession(; secret)` is the kwdef constructor; `Pluto.run` kwargs have no
# secret option.

using Pluto
using Random: randstring

state_dir = joinpath(get(ENV, "XDG_STATE_HOME", joinpath(homedir(), ".local", "state")), "pluto")
secret_path = joinpath(state_dir, "secret")

if !isfile(secret_path)
    mkpath(state_dir; mode=0o700)
    # Restrict before writing so the secret is never world-readable
    touch(secret_path)
    chmod(secret_path, 0o600)
    write(secret_path, randstring(32))
end
secret = String(strip(read(secret_path, String)))

# Bound to loopback only: access is through an SSH tunnel. Port comes from
# julia.nix so the service, its readiness check and pluto-connect agree.
options = Pluto.Configuration.from_flat_kwargs(;
    host="127.0.0.1",
    port=parse(Int, ARGS[1]),
    launch_browser=false,
)
Pluto.run(Pluto.ServerSession(; secret, options))
