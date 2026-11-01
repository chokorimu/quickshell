// Corners.qml — rounded screen corners.
//
// No compositor rounds the physical screen: the output framebuffer is a
// rectangle, and Hyprland's native `decoration { rounding }` only rounds
// windows. The standard Wayland approach — what picom's shader did on X11 —
// is to paint the four corners in a solid color at the Overlay layer, so
// screen content appears to stop at a curve. That is what this module is.
//
// Trade-offs, stated plainly:
//   - fullscreen content (games, video) loses its corner pixels; the Overlay
//     layer sits above fullscreen windows by design
//   - the color has to match the wallpaper to blend — Theme.screenCornerColor
//   - the four corner slivers still absorb clicks (the mask has to be
//     non-empty for anything to render, and it clips input and paint alike)
//
// Self-contained window (the Launcher pattern): one instance per monitor,
// wired in shell.qml. The window reserves nothing (ExclusionMode.Ignore) and
// maps to nothing when Theme.screenCornersEnabled is false — the off switch.
import QtQuick
import Quickshell
import Quickshell.Wayland
import "../../Theme"

PanelWindow {
    id: root
    required property var modelData
    screen: modelData

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    WlrLayershell.layer: WlrLayershell.Overlay
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    visible: Theme.screenCornersEnabled

    // clamp so a silly-large radius can't invert the cutouts
    readonly property int radius: Math.min(
        Theme.screenCornerRadius,
        Math.min(screen.width, screen.height) / 2)

    // The window covers the whole screen, so without a mask its surface
    // would swallow every click and scroll on the monitor. The mask clips
    // rendering AND input to the four cutouts — everything outside passes
    // through to the windows behind. Per-corner radii make each region
    // match its painted cutout exactly (a square with the inner corner
    // rounded off is precisely square-minus-quarter-disc).
    mask: Region {
        intersection: Intersection.Combine
        Region {
            x: 0
            y: 0
            width: root.radius
            height: root.radius
            bottomRightRadius: root.radius
        }
        Region {
            x: root.screen.width - root.radius
            y: 0
            width: root.radius
            height: root.radius
            bottomLeftRadius: root.radius
        }
        Region {
            x: 0
            y: root.screen.height - root.radius
            width: root.radius
            height: root.radius
            topRightRadius: root.radius
        }
        Region {
            x: root.screen.width - root.radius
            y: root.screen.height - root.radius
            width: root.radius
            height: root.radius
            topLeftRadius: root.radius
        }
    }

    Canvas {
        anchors.fill: parent

        onPaint: {
            var ctx = getContext("2d")
            var w = width
            var h = height
            var r = root.radius

            ctx.clearRect(0, 0, w, h)
            ctx.fillStyle = Theme.screenCornerColor

            // each cutout is a corner square minus a quarter-disc: walk two
            // edges of the square, then arc back along the curve that bites
            // into it
            ctx.beginPath()

            // top-left — arc centered (r, r), bulging toward (0, 0)
            ctx.moveTo(0, 0)
            ctx.lineTo(r, 0)
            ctx.arc(r, r, r, -Math.PI / 2, -Math.PI, true)
            ctx.closePath()

            // top-right — arc centered (w - r, r), bulging toward (w, 0)
            ctx.moveTo(w, 0)
            ctx.lineTo(w - r, 0)
            ctx.arc(w - r, r, r, -Math.PI / 2, 0, false)
            ctx.closePath()

            // bottom-left — arc centered (r, h - r), bulging toward (0, h)
            ctx.moveTo(0, h)
            ctx.lineTo(0, h - r)
            ctx.arc(r, h - r, r, Math.PI, Math.PI / 2, true)
            ctx.closePath()

            // bottom-right — arc centered (w - r, h - r), bulging toward (w, h).
            // Start angle must be the point the path is already at — (w - r, h),
            // which is π/2 from the center — or canvas silently inserts a
            // straight connector and the cutout collapses into a leaf shape.
            ctx.moveTo(w, h)
            ctx.lineTo(w - r, h)
            ctx.arc(w - r, h - r, r, Math.PI / 2, 0, true)
            ctx.closePath()

            // disjoint subpaths — one fill paints all four cutouts
            ctx.fill()
        }
    }
}
