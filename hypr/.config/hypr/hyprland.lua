require("animations")
-- require("colors")
require("effects")
require("keybinds")

------------------
---- MONITORS ----
------------------

hl.monitor({
    output   = "",
    mode     = "highres", -- 2560x1600@165
    position = "auto",    -- 0x0
    scale    = "auto",    -- 1.6
})

-- hl.monitor({
--     output = "HDMI", mode = "preferred", position = "auto", scale = 1, mirror = "eDP-2"
-- })

-------------------------------
---- ENVIRONMENT VARIABLES ----
-------------------------------

-- hyprcursor
hl.env("XCURSOR_SIZE", "32")
hl.env("HYPRCURSOR_SIZE", "32")
hl.env("HYPRCURSOR_THEME", "capitaine-cursors-light")

-- nvidia (drop these two lines on non-nvidia systems)
hl.env("LIBVA_DRIVER_NAME", "nvidia")
hl.env("__GLX_VENDOR_LIBRARY_NAME", "nvidia")

------------------
----  LAYOUT  ----
------------------


hl.config({
    general = {
        layout = "dwindle",
    },

    scrolling = {
        fullscreen_on_one_column = true,
    },

    dwindle = {
        preserve_split = true, -- You probably want this
    },

    master = {
        new_status = "master",
    },
})

----------------
----  MISC  ----
----------------

hl.config({
    misc = {
        force_default_wallpaper = -1,    -- Set to 0 or 1 to disable the anime mascot wallpapers
        disable_hyprland_logo   = false, -- If true disables the random hyprland logo / anime girl background. :(
    },
})

---------------
---- INPUT ----
---------------

hl.config({
    input = {
        kb_layout  = "us",
        kb_variant = "",
        kb_model   = "",
        kb_options = "",
        kb_rules   = "",

        follow_mouse = 1,
        sensitivity = 0.3,

        touchpad = {
            natural_scroll = true,
            disable_while_typing = false
        },

    },

    binds = {
        hide_special_on_workspace_change = true
    },

    gestures = {
        workspace_swipe_distance = 400,
        workspace_swipe_create_new = false,
        workspace_swipe_forever = true
    }
})

hl.gesture({
    fingers = 3,
    direction = "horizontal",
    action = "workspace"
})

hl.gesture({
    fingers = 3,
    direction = "vertical",
    action = "special",
    workspace_name = "1"
})

hl.gesture({
    fingers = 4,
    direction = "swipe",
    action = "resize"
})

hl.device({
    name        = "yjx-chip-ajazz-2.4g-mouse",
    sensitivity = -0.4,
})

hl.config({
    xwayland = {
        force_zero_scaling = true
    }
})

--------------------------------
---- WINDOWS AND WORKSPACES ----
--------------------------------

local suppressMaximizeRule = hl.window_rule({
    -- Ignore maximize requests from all apps. You'll probably like this.
    name  = "suppress-maximize-events",
    match = { class = ".*" },

    suppress_event = "maximize",
})
-- suppressMaximizeRule:set_enabled(false)

hl.window_rule({
    -- Fix some dragging issues with XWayland
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

-- Hyprland-run windowrule
hl.window_rule({
    name  = "move-hyprland-run",
    match = { class = "hyprland-run" },

    move  = "20 monitor_h-120",
    float = true
})

hl.window_rule({
    name = "discord",
    match = { class = "discord" },
    workspace = "special:1 silent"
})

hl.window_rule({
    name = "impala",
    match = { class = "kitty:impala" },
    float = true 
})

-----------------------
----- PERMISSIONS -----
-----------------------

-- See https://wiki.hypr.land/Configuring/Advanced-and-Cool/Permissions/
-- Please note permission changes here require a Hyprland restart and are not applied on-the-fly
-- for security reasons

-- hl.config({
--   ecosystem = {
--     enforce_permissions = true,
--   },
-- })

-- hl.permission("/usr/(bin|local/bin)/grim", "screencopy", "allow")
-- hl.permission("/usr/(lib|libexec|lib64)/xdg-desktop-portal-hyprland", "screencopy", "allow")
-- hl.permission("/usr/(bin|local/bin)/hyprpm", "plugin", "allow")