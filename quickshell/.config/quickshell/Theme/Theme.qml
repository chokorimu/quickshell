// Theme.qml — singleton. import with `import "Theme"` (declared in Theme/qmldir).
import QtQuick
import Quickshell

pragma Singleton

Singleton {
    id: root

    readonly property Colors _colors: Colors {}

    // bar
    property color barColor: _colors.base
    property color barText: _colors.text

    // semantic
    property color accent: _colors.accent
    property color text:   _colors.text
    property color muted:  _colors.muted
    property color urgent: _colors.urgent
    property color surface: _colors.surface

    // ---- bar palette ----------------------------------------------------
    // Fixed palettes. These live here rather than in Colors.qml because
    // matugen overwrites Colors.qml on every wallpaper change, which would
    // recolour the bar the moment a palette is regenerated.
    // Light pill — pure white. The island card is the dark surface
    // against it (see cardBackground below), and the menu column
    // strip takes this same white so the bar's material reads as
    // extending down into the card. Text is deliberately
    // near-black — a white surface with the old light-gray text
    // would be unreadable.
    readonly property color fixedBarBg:      "#ffffff"
    readonly property color fixedBarSurface: "#e6e6e9"
    readonly property color fixedBarText:    "#1b1b1f"
    readonly property color fixedBarMuted:   "#8e8e93"
    readonly property color fixedBarUrgent:  "#c0392b"
    // near-black for the inverted workspace pill inside the white bar pill
    readonly property color fixedBarInk:     "#1b1b1f"
    // label color on those ink fills — white on the near-black
    readonly property color fixedBarOnInk:   "#ffffff"

    // Dark pill — deep charcoal, hardcoded for the same reason. The
    // workspace pill and the transport buttons keep the inverted
    // language: barInk stays DARKER than the bar (the light palette's
    // near-black-on-white, greyed down), and barOnInk is the label
    // color that sits on those ink fills.
    readonly property color fixedDarkBarBg:      "#222226"
    readonly property color fixedDarkBarSurface: "#323238"
    readonly property color fixedDarkBarText:    "#e8e8ea"
    readonly property color fixedDarkBarMuted:   "#9a9aa0"
    readonly property color fixedDarkBarUrgent:  "#e05252"
    // darker than the bar — the inverted fills stay the dark element
    // inside the lighter surface
    readonly property color fixedDarkBarInk:     "#16161a"
    readonly property color fixedDarkBarOnInk:   "#e8e8ea"

    // Island surfaces — the workspace pill and the island card share
    // one surface per palette, so the island reads as a single
    // material family: deep charcoal in the dark palette, light gray
    // in the light one. The card still sits darker than the pill in
    // both palettes (light gray under the white light pill, deep
    // charcoal under the dark pill).
    readonly property color fixedCardBgDark:  "#1c1c20"
    readonly property color fixedCardBgLight: "#e2e2e6"

    // TEMPORARY dark-mode toggle — flips the fixed palette between the
    // light and dark pills. Click the "//" prefix in the bar to flip it.
    // Moves to a proper menu later; the matugen path below is untouched
    // and still wins when barUseMatugen is on.
    property bool darkMode: true

    // Flip to true once the matugen toggle UI exists. Bar.qml only ever
    // references the derived properties below, so switching is a
    // one-line change here rather than a rewrite of the bar.
    readonly property bool barUseMatugen: false

    readonly property color barBackground: barUseMatugen ? barColor   : (darkMode ? fixedDarkBarBg      : fixedBarBg)
    readonly property color barHighlight:  barUseMatugen ? accent     : (darkMode ? fixedDarkBarSurface : fixedBarSurface)
    readonly property color barForeground: barUseMatugen ? barText    : (darkMode ? fixedDarkBarText    : fixedBarText)
    readonly property color barDim:        barUseMatugen ? muted      : (darkMode ? fixedDarkBarMuted   : fixedBarMuted)
    readonly property color barUrgent:     barUseMatugen ? urgent     : (darkMode ? fixedDarkBarUrgent  : fixedBarUrgent)
    readonly property color barInk:        barUseMatugen ? barColor   : (darkMode ? fixedDarkBarInk     : fixedBarInk)
    readonly property color barOnInk:      barUseMatugen ? barText    : (darkMode ? fixedDarkBarOnInk   : fixedBarOnInk)

    // ---- workspace pill ------------------------------------------------
    // Shares the island card's surface (fixedCardBg*): deep charcoal
    // in dark mode, light gray in light mode — the pill and the card
    // read as one material family. The active circle takes
    // barBackground — lighter than the surface in dark mode, white in
    // light mode — with a barForeground number, the one label color
    // that reads on both fills.
    readonly property color barWorkspacePill: darkMode ? fixedCardBgDark : fixedCardBgLight
    // inactive numbers on the pill — the dark palette's muted gray, or a
    // deeper gray that survives on the light surface (barDim's light
    // value washes out against light gray)
    readonly property color barWorkspaceDim:  darkMode ? fixedDarkBarMuted : "#6e6e73"

    // card accent — the lime fill on the island tab column's selected
    // button. Fixed in both palettes, like screenCornerColor: it is
    // an accent, not a surface.
    readonly property color cardAccent: "#cdf34e"
    // label color on the accent — the selected button's glyph. Fixed
    // for the same reason cardAccent is: the accent never flips.
    readonly property color cardAccentOn: "#1b1b1f"
    // card surface — the island surface, shared with the workspace
    // pill (fixedCardBg*): the card still sits darker than the pill
    // in both palettes (light gray under the white light pill, deep
    // charcoal under the dark pill), so card and pill read as one
    // material family. The matugen path keeps the card on the bar
    // color (no inversion is computable from an arbitrary palette).
    readonly property color cardBackground: barUseMatugen ? barColor : (darkMode ? fixedCardBgDark : fixedCardBgLight)
    // card content palette — flips with the card surface:
    // light-on-dark in the dark palette, dark-on-light in the
    // light one.
    readonly property color cardForeground: darkMode ? "#e8e8ea" : "#1b1b1f"
    readonly property color cardDim:       darkMode ? "#9a9aa0" : "#6e6e73"
    // subtle surface on the card — slider track, art circle
    readonly property color cardHighlight: darkMode ? "#3a3a40" : "#d2d2d6"
    // inverted fills on the card — the transport circles take the
    // opposite of the card surface, labelled in the card's own
    // color (cardOnInk) for the knockout look
    readonly property color cardInk:       darkMode ? "#e8e8ea" : "#1b1b1f"
    readonly property color cardOnInk:     cardBackground

    // launcher selection — the active row's fill. Fixed in both
    // palettes like cardAccent: LO asked for yellow across all
    // themes, so this deliberately does not flip with darkMode or
    // follow matugen. Near-black label for contrast on the yellow.
    readonly property color launcherSelection:   "#ffd400"
    readonly property color launcherSelectionOn: "#1b1b1f"
    // launcher search — the static label block beside the input
    // field. Inverted against the palette at LO's request: black in
    // the light theme, white in the dark one, with the label knocked
    // out in the opposite. Tied to darkMode like the rest of the
    // fixed card palette; matugen computes no inversion.
    readonly property color launcherSearchLabel:   darkMode ? "#ffffff" : "#000000"
    readonly property color launcherSearchLabelOn: darkMode ? "#000000" : "#ffffff"

    // typography
    readonly property string fontFamily: "monospace"
    readonly property string barFontFamily: "Montserrat Semibold"
    // Nerd Font for status glyphs (bar/OSD icons). Set explicitly on each
    // glyph Text — the bar's UI font is not an NF family, so inheriting it
    // would render every glyph as tofu. Verified to cover the Font Awesome
    // (f000-f381) and Material (f0001-f1af0) ranges.
    readonly property string iconFont: "JetBrainsMonoNL Nerd Font"
    readonly property int fontSize: 16
    readonly property int barFontSize: 16
    readonly property int barFontSizeSmall: 12
    readonly property int launcherFontSize: 16

    // Screen corners. No compositor rounds the physical screen — Modules/Corners
    // paints the four corner cutouts at the Overlay layer, so the color has to
    // match the wallpaper to blend (black is the safe default on dark setups).
    // screenCornersEnabled is the future off switch: flip it here, or bind it
    // to a toggle later.
    readonly property bool screenCornersEnabled: true
    readonly property int screenCornerRadius: 24
    readonly property color screenCornerColor: "#000000"
}
