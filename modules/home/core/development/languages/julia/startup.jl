# Activate project environment
try
    @eval using Pkg
    if isfile("Project.toml") && isfile("Manifest.toml")
        Pkg.activate(".")
    end
catch e
    @warn "Error activating project environment" exception = (e, catch_backtrace())
end

# Executed only for the REPL 
atreplinit() do repl
    # Set editor
    try
        # If inside Emacs, use it
        if haskey(ENV, "INSIDE_EMACS")
            ENV["JULIA_EDITOR"] = "emacsclient"
        else
            # If on terminal, use NeoVim
            @eval using InteractiveUtils
            ENV["JULIA_EDITOR"] = "nvim"
            InteractiveUtils.define_editor(
                r"nvim", wait=true) do cmd, path, line
                `$cmd +$line $path`
            end
        end
    catch e
        @warn "Error setting editor" exception = (e, catch_backtrace())
    end
    # Load Revise.jl
    try
        @eval using Revise
    catch e
        @warn "Error initializing Revise" exception = (e, catch_backtrace())
    end
    # Load OhMyREPL.jl
    try
        @eval using OhMyREPL
    catch e
        @warn "Error initializing OhMyREPL" exception = (e, catch_backtrace())
    end
end
