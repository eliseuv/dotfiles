
-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --
-- Lua translation of hyprland.conf, following the shape  --
-- of the stock example ~/.config/hypr/hyprland.lua.back  --
-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --
--
-- NOTE: dispatcher argument shapes for the less common dispatchers below
-- (window.cycle_next, focus by monitor, window.move by direction,
-- workspace.move to monitor, window.fullscreen/pseudo toggle) are inferred
-- from the naming convention used by the official hl.dsp.* examples, since
-- the Lua config API was still very new at the time of writing. Double check
-- against the wiki if one of these binds doesn't do what it says.

------------------
---- MONITORS ----
------------------

-- /etc/hypr/monitors.conf is NixOS-generated hyprlang and there is no
-- documented Lua equivalent of `source = <path>` for pulling in another
-- host-generated hyprlang file. This mirrors what that file currently
-- contains on this host; update by hand if it changes.
hl.monitor({ output = "eDP-1", mode = "1920x1080@60", position = "0x0", scale = 1 })

---------------------
---- MY PROGRAMS ----
---------------------

local terminal        = "ghostty"
local terminalCommand = "ghostty -e"
local menu            = "~/.config/rofi/bin/launcher"
local powermenu       = "~/.config/rofi/bin/powermenu"
local browser         = "firefox"
local emacs           = "emacsclient -nc -a 'emacs'"
local vim             = "neovide"
local fileManager     = "nautilus"

-------------------
---- AUTOSTART ----
-------------------

hl.on("hyprland.start", function()
    hl.exec_cmd("waybar")
    hl.exec_cmd("dbus-update-activation-environment --systemd --all")
end)

-------------------------------
---- ENVIRONMENT VARIABLES ----
-------------------------------

hl.env("XDG_CURRENT_DESKTOP", "Hyprland")
hl.env("XCURSOR_THEME", "Adwaita")
hl.env("XCURSOR_SIZE", "10")

-----------------------
----- PERMISSIONS -----
-----------------------

-- See https://wiki.hypr.land/Configuring/Advanced-and-Cool/Permissions/
-- Please note permission changes here require a Hyprland restart and are
-- not applied on-the-fly for security reasons

-- hl.config({
--   ecosystem = {
--     enforce_permissions = true,
--   },
-- })

-- hl.permission("/usr/(bin|local/bin)/grim", "screencopy", "allow")
-- hl.permission("/usr/(lib|libexec|lib64)/xdg-desktop-portal-hyprland", "screencopy", "allow")
-- hl.permission("/usr/(bin|local/bin)/hyprpm", "plugin", "allow")

-----------------------
---- LOOK AND FEEL ----
-----------------------

hl.config({
    general = {
        layout = "dwindle",

        gaps_in  = 2,
        gaps_out = 2,

        border_size = 2,

        col = {
            active_border   = { colors = { "rgba(33ccffee)", "rgba(8948aaee)" }, angle = 45 },
            inactive_border = { colors = { "rgba(707070aa)", "rgba(303030aa)" }, angle = 45 },
        },

        allow_tearing = true,
    },

    decoration = {
        rounding       = 6,
        rounding_power = 3,

        active_opacity   = 1.0,
        inactive_opacity = 0.9,

        shadow = {
            enabled      = false,
            range        = 4,
            render_power = 3,
            color        = 0xee1a1a1a,
        },

        blur = {
            enabled = true,
            size    = 3,
            passes  = 3,
        },
    },

    animations = {
        enabled = true,
    },
})

hl.curve("easeOutQuint",   { type = "bezier", points = { {0.23, 1},    {0.32, 1} } })
hl.curve("easeInOutCubic", { type = "bezier", points = { {0.65, 0.05}, {0.36, 1} } })
hl.curve("linear",         { type = "bezier", points = { {0, 0},       {1, 1}    } })
hl.curve("almostLinear",   { type = "bezier", points = { {0.5, 0.5},   {0.75, 1} } })
hl.curve("quick",          { type = "bezier", points = { {0.15, 0},    {0.1, 1}  } })

hl.animation({ leaf = "global",        enabled = true, speed = 10,   bezier = "default" })
hl.animation({ leaf = "border",        enabled = true, speed = 5.39, bezier = "easeOutQuint" })
hl.animation({ leaf = "windows",       enabled = true, speed = 4.79, bezier = "easeOutQuint" })
hl.animation({ leaf = "windowsIn",     enabled = true, speed = 4.1,  bezier = "easeOutQuint", style = "popin 87%" })
hl.animation({ leaf = "windowsOut",    enabled = true, speed = 1.49, bezier = "linear",       style = "popin 87%" })
hl.animation({ leaf = "fadeIn",        enabled = true, speed = 1.73, bezier = "almostLinear" })
hl.animation({ leaf = "fadeOut",       enabled = true, speed = 1.46, bezier = "almostLinear" })
hl.animation({ leaf = "fade",          enabled = true, speed = 3.03, bezier = "quick" })
hl.animation({ leaf = "layers",        enabled = true, speed = 3.81, bezier = "easeOutQuint" })
hl.animation({ leaf = "layersIn",      enabled = true, speed = 4,    bezier = "easeOutQuint", style = "fade" })
hl.animation({ leaf = "layersOut",     enabled = true, speed = 1.5,  bezier = "linear",       style = "fade" })
hl.animation({ leaf = "fadeLayersIn",  enabled = true, speed = 1.79, bezier = "almostLinear" })
hl.animation({ leaf = "fadeLayersOut", enabled = true, speed = 1.39, bezier = "almostLinear" })
hl.animation({ leaf = "workspaces",    enabled = true, speed = 1.94, bezier = "almostLinear", style = "fade" })
hl.animation({ leaf = "workspacesIn",  enabled = true, speed = 1.21, bezier = "almostLinear", style = "fade" })
hl.animation({ leaf = "workspacesOut", enabled = true, speed = 1.94, bezier = "almostLinear", style = "fade" })

hl.config({
    dwindle = {
        preserve_split = true,
    },

    master = {
        new_status = "master",
    },

    misc = {
        disable_hyprland_logo = true,
    },
})

---------------
---- INPUT ----
---------------

hl.config({
    input = {
        numlock_by_default = true,

        kb_layout  = "us,br",
        kb_options = "grp:alt_shift_toggle",

        touchpad = {
            disable_while_typing = true,
            natural_scroll       = true,
            drag_lock            = true,
        },
    },

    cursor = {
        -- Hide cursor when idle
        inactive_timeout = 3,
    },
})

---------------------
---- KEYBINDINGS ----
---------------------

local mainMod = "SUPER"

-- Exit
hl.bind(mainMod .. " + SHIFT + backspace", hl.dsp.exec_cmd(powermenu))
hl.bind(mainMod .. " + SHIFT + R", hl.dsp.exec_cmd(
    "hyprctl reload; systemctl --user restart hyprpaper.service; systemctl --user restart hypridle.service; systemctl --user restart hyprpolkitagent"
))

-- Menu
hl.bind(mainMod .. " + SHIFT + return", hl.dsp.exec_cmd(menu))

-- Terminal
hl.bind(mainMod .. " + return", hl.dsp.exec_cmd(terminal))

-- Programs
hl.bind(mainMod .. " + SHIFT + B", hl.dsp.exec_cmd(browser))
hl.bind(mainMod .. " + SHIFT + V", hl.dsp.exec_cmd(vim))
hl.bind(mainMod .. " + SHIFT + E", hl.dsp.exec_cmd(emacs))
hl.bind(mainMod .. " + SHIFT + F", hl.dsp.exec_cmd(fileManager))

-- Process monitor
hl.bind(mainMod .. " + ALT + H", hl.dsp.exec_cmd(terminalCommand .. " btm"))
-- Sound mixer
hl.bind(mainMod .. " + ALT + M", hl.dsp.exec_cmd(terminalCommand .. " wiremix --tab configuration"))
-- Systemd
hl.bind(mainMod .. " + ALT + S", hl.dsp.exec_cmd(terminalCommand .. " systemctl-tui"))

-- Kill window
hl.bind(mainMod .. " + SHIFT + Q", hl.dsp.window.close())

-- Cycle windows
hl.bind(mainMod .. " + K", hl.dsp.window.cycle_next({ next = false }))
hl.bind(mainMod .. " + J", hl.dsp.window.cycle_next({ next = true }))

-- Cycle monitors
hl.bind(mainMod .. " + H", hl.dsp.focus({ monitor = "-1" }))
hl.bind(mainMod .. " + L", hl.dsp.focus({ monitor = "+1" }))

-- Move windows
hl.bind(mainMod .. " + SHIFT + H", hl.dsp.window.move({ direction = "left" }))
hl.bind(mainMod .. " + SHIFT + J", hl.dsp.window.move({ direction = "down" }))
hl.bind(mainMod .. " + SHIFT + K", hl.dsp.window.move({ direction = "up" }))
hl.bind(mainMod .. " + SHIFT + L", hl.dsp.window.move({ direction = "right" }))

-- Layouts
hl.bind(mainMod .. " + space", hl.dsp.window.fullscreen({ action = "toggle" }))
hl.bind(mainMod .. " + T", hl.dsp.layout("togglesplit")) -- dwindle
hl.bind(mainMod .. " + S", hl.dsp.window.pseudo({ action = "toggle" })) -- dwindle
hl.bind(mainMod .. " + V", hl.dsp.window.float({ action = "toggle" }))

-- Select workspace / move to workspace (silently, no follow)
for i = 1, 10 do
    local key = i % 10 -- 10 maps to key 0
    hl.bind(mainMod .. " + " .. key,         hl.dsp.focus({ workspace = i }))
    hl.bind(mainMod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = i, follow = false }))
end

-- Move workspace between monitors
hl.bind(mainMod .. " + CTRL + H", hl.dsp.workspace.move({ monitor = "-1" }))
hl.bind(mainMod .. " + CTRL + L", hl.dsp.workspace.move({ monitor = "+1" }))

-- Special workspaces
hl.bind(mainMod .. " + P",         hl.dsp.workspace.toggle_special("magic"))
hl.bind(mainMod .. " + SHIFT + P", hl.dsp.window.move({ workspace = "special:magic" }))

-- Media
hl.bind(mainMod .. " + minus", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_SINK@ 5%-"), { locked = true, repeating = true })
hl.bind(mainMod .. " + equal", hl.dsp.exec_cmd("wpctl set-volume -l 1.5 @DEFAULT_SINK@ 5%+"), { locked = true, repeating = true })
hl.bind(mainMod .. " + backslash", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_SINK@ toggle"), { locked = true })

-- Controls
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_SINK@ 5%-"), { locked = true, repeating = true })
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1.5 @DEFAULT_SINK@ 5%+"), { locked = true, repeating = true })
hl.bind("XF86AudioMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_SINK@ toggle"), { locked = true })

hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl set 5%-"), { locked = true, repeating = true })
hl.bind("XF86MonBrightnessUp",   hl.dsp.exec_cmd("brightnessctl set 5%+"), { locked = true, repeating = true })

-- Screenshot a window
hl.bind(mainMod .. " + PRINT", hl.dsp.exec_cmd("hyprshot -m window"))
-- Screenshot a monitor
hl.bind("PRINT", hl.dsp.exec_cmd("hyprshot -m output"))
-- Screenshot a region
hl.bind(mainMod .. " + SHIFT + PRINT", hl.dsp.exec_cmd("hyprshot -m region"))

--------------------------------
---- WINDOWS AND WORKSPACES ----
--------------------------------

-- Smart gaps
hl.workspace_rule({ workspace = "w[tv1]", gaps_out = 0, gaps_in = 0 })
hl.workspace_rule({ workspace = "f[1]",   gaps_out = 0, gaps_in = 0 })
hl.window_rule({
    name  = "no-gaps-wtv1",
    match = { float = false, workspace = "w[tv1]" },
    border_size = 0,
    rounding    = 0,
})
hl.window_rule({
    name  = "no-gaps-f1",
    match = { float = false, workspace = "f[1]" },
    border_size = 0,
    rounding    = 0,
})

-- Ignore maximize requests from apps. You'll probably like this.
hl.window_rule({
    name  = "suppress-maximize-events",
    match = { class = ".*" },
    suppress_event = "maximize",
})

-- Fix some dragging issues with XWayland
hl.window_rule({
    name  = "fix-xwayland-drags",
    match = {
        class      = "^$",
        title      = "^$",
        xwayland   = true,
        float      = true,
        fullscreen = false,
        pin        = false,
    },
    no_focus = true,
})

-- Rofi menu
hl.window_rule({
    name  = "rofi-menu",
    match = { class = "Rofi" },
    opacity = 0.7,
    xray    = true,
})

-- Terminal
hl.window_rule({ name = "tag-term-ghostty", match = { class = "com.mitchellh.ghostty" }, tag = "+term" })
hl.window_rule({ name = "tag-term-kitty",   match = { class = "kitty" },                 tag = "+term" })
hl.window_rule({ name = "term-opacity",     match = { tag = "term" }, opacity = 0.95 })

-- Editors
hl.window_rule({ name = "tag-editor-emacs",       match = { class = "Emacs" },        tag = "+editor" })
hl.window_rule({ name = "tag-editor-zed",         match = { class = "dev.zed.Zed" },  tag = "+editor" })
hl.window_rule({ name = "tag-editor-vscode",      match = { class = "code-oss" },     tag = "+editor" })
hl.window_rule({ name = "tag-editor-antigravity", match = { class = "antigravity" },  tag = "+editor" })
hl.window_rule({ name = "editor-workspace", match = { tag = "editor" }, opaque = true, workspace = 2 })

-- Browsers
hl.window_rule({ name = "tag-browser-firefox",    match = { class = "firefox" },          tag = "+browser", workspace = 3 })
hl.window_rule({ name = "tag-browser-qutebrowser", match = { class = "qutebrowser" },     tag = "+browser", workspace = 3 })
hl.window_rule({ name = "tag-browser-brave",      match = { class = "brave-browser" },    tag = "+browser", workspace = 4 })
hl.window_rule({ name = "tag-browser-chromium",   match = { class = "chromium-browser" }, tag = "+browser", workspace = 5 })
hl.window_rule({ name = "browser-opaque", match = { tag = "browser" }, opaque = true })

-- Documents
hl.window_rule({ name = "tag-documents-zathura", match = { class = "org.pwmt.zathura" }, tag = "+documents" })
hl.window_rule({ name = "tag-documents-zotero",  match = { class = "Zotero" },           tag = "+documents" })
hl.window_rule({ name = "tag-documents-obsidian", match = { class = "obsidian" },        tag = "+documents" })
hl.window_rule({ name = "tag-documents-calibre", match = { class = "calibre-gui" },      tag = "+documents" })
hl.window_rule({ name = "documents-workspace", match = { tag = "documents" }, opaque = true, workspace = 6 })

-- Chat
hl.window_rule({ name = "tag-chat-telegram", match = { class = "org.telegram.desktop" }, tag = "+chat" })
hl.window_rule({ name = "tag-chat-discord",  match = { class = "discord" },              tag = "+chat" })
hl.window_rule({ name = "tag-chat-legcord",  match = { class = "legcord" },              tag = "+chat" })
hl.window_rule({ name = "chat-workspace", match = { tag = "chat" }, opaque = true, workspace = 7 })

-- Game launchers
hl.window_rule({ name = "tag-gamelauncher-steam", match = { class = "steam" },                          tag = "+gamelauncher" })
hl.window_rule({ name = "tag-gamelauncher-prism", match = { class = "org.prismlauncher.PrismLauncher" }, tag = "+gamelauncher" })
hl.window_rule({ name = "gamelauncher-workspace", match = { tag = "gamelauncher" }, opaque = true, workspace = 8 })

-- Games
hl.window_rule({ name = "tag-game-cs2",       match = { class = "^(cs2)$" },     tag = "+game" })
hl.window_rule({ name = "tag-game-minecraft", match = { class = "Minecraft.*" }, tag = "+game" })
hl.window_rule({
    name  = "game-fullscreen",
    match = { tag = "game" },
    fullscreen = true,
    opaque     = true,
    immediate  = true,
    workspace  = 8,
})
-- Enable tearing

-- mpv
hl.window_rule({ name = "mpv", match = { class = "mpv" }, opaque = true, fullscreen = true, workspace = 4 })

-- Spotify
hl.window_rule({ name = "spotify", match = { class = "Spotify" }, opaque = true, workspace = 4 })

-- VMs
hl.window_rule({ name = "tag-vms-virtmanager", match = { class = ".virt-manager-wrapped" }, tag = "+vms" })
hl.window_rule({ name = "vms-workspace", match = { tag = "vms" }, opaque = true, workspace = 9 })
