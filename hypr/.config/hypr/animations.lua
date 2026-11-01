--------------------
---- ANIMATIONS ----
--------------------

hl.config({
    animations = {
        enabled = true,
    }
})

-- Curve definitions
hl.curve("cool_shit",    { type = "bezier", points = {{0.3, 1.2}, {0.3, 1}} })
hl.curve("linear_steep", { type = "bezier", points = {{0.5, 0.5}, {0.75, 1}} });
-- hl.curve("easy",      { type = "spring", mass = 1, stiffness = 238.1191, damping = 24.21279333 })

-- Global animations configuration
hl.animation({
    leaf = "global",
    enabled = true,
    speed = 10,
    bezier = "default"
})

-- Border animation
hl.animation({
    leaf = "border",
    enabled = true,
    speed = 5.39,
    bezier = "default"
})

-- FadeIn animation
hl.animation({
    leaf = "fadeIn",
    enabled = true,
    speed = 5,
    bezier = "cool_shit"
})

-- FadeOut animation
hl.animation({
    leaf = "fadeOut",
    enabled = true,
    speed = 2,
    bezier = "linear_steep"
})

-- FadeLayersIn animation
hl.animation({
    leaf = "fadeLayersIn",
    enabled = true,
    speed = 5,
    bezier = "cool_shit"
})

-- FadeLayersOut animation
hl.animation({
    leaf = "fadeLayersOut",
    enabled = true,
    speed = 2,
    bezier = "linear_steep"
})

-- Windows animation
hl.animation({
    leaf = "windows",
    enabled = true,
    speed = 5,
    bezier = "cool_shit",
    style = "popin"
})

-- Layers animation
hl.animation({
    leaf = "layers",
    enabled = true,
    speed = 5,
    bezier = "cool_shit",
    style = "popin"
})

-- Workspaces animation
hl.animation({
    leaf = "workspaces",
    enabled = true,
    speed = 6,
    bezier = "cool_shit",
    style = "slide"
})

-- SpecialWorkspace animation
hl.animation({
    leaf = "specialWorkspace",
    enabled = true,
    speed = 5,
    bezier = "cool_shit",
    style = "slidevert 60%"
})

-- ZoomFactor animation
hl.animation({
    leaf = "zoomFactor",
    enabled = true,
    speed = 7,
    bezier = "default"
})

-- MonitorAdded animation
hl.animation({
    leaf = "monitorAdded",
    enabled = true,
    speed = 2,
    bezier = "linear_steep"
})

