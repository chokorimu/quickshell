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

-- FadeLayersIn / FadeLayersOut are disabled together with the layers leaf
-- below -- see that entry for the full reasoning.
hl.animation({
    leaf = "fadeLayersIn",
    enabled = false
})

hl.animation({
    leaf = "fadeLayersOut",
    enabled = false
})

-- Windows animation
hl.animation({
    leaf = "windows",
    enabled = true,
    speed = 5,
    bezier = "cool_shit",
    style = "popin"
})

-- Layer surfaces get no compositor animation, for hyprshot's sake. Its region
-- flow spawns two of them -- hyprpicker's freeze (namespace "hyprpicker") and
-- slurp's selection box (namespace "selection", verified via `hyprctl layers`)
-- -- and a freeze that pops or fades in reads as a live screen rather than a
-- frozen one. A no_anim layer rule cannot deliver this: 0.56.2 honors it only
-- on unmap (it skips the fade-out snapshot), while CLayerSurface::onMap runs
-- the layersIn + fadeLayersIn animations unconditionally, and the alpha fade
-- rides its own leaf -- so all three leaves die together. Permanently mapped
-- surfaces never replay it anyway (the bar, the notification stack and the
-- launcher window stay mapped for the shell's whole life); what actually
-- changes is hyprshot's pair, plus rofi's menus and hyprlock, now instant.
hl.animation({
    leaf = "layers",
    enabled = false
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

