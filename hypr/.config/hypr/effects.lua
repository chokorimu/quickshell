-----------------------
---- LOOK AND FEEL ----
-----------------------

hl.config({
    general = {
        gaps_in         = 6,
        gaps_out        = 12,
        gaps_workspaces = -12, 

        border_size     = 0,
        col = {
            active_border = "rgba(47b8c1ff)",
            inactive_border = "rgba(47b8c1ff)"
        },
        resize_on_border = true,
        allow_tearing = false,
    },

    decoration = {
        rounding         = 12,
        rounding_power   = 2,
        active_opacity   = 0.95,
        inactive_opacity = 0.95,

        shadow = {
            enabled      = false,
            range        = 4,
            render_power = 3,
            color        = 0xee1a1a1a,
        },

        blur = {
            enabled    = true,
            size       = 20,
            passes     = 2,
            vibrancy   = 0,
            noise      = 0.2,
            brightness = 1,
            contrast   = 1,
        }
    },
})
