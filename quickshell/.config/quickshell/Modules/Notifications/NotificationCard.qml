// NotificationCard.qml — one popup card in the notification stack.
//
// Every card is exactly 420x140: the body clamps at two lines with an
// ellipsis and the card never resizes, so the stack stays uniform no
// matter how much text an app sends. The actions row claims a fixed
// bottom slot when the app offered actions; when it is absent the body
// takes that space instead.
//
// Delegate over NotificationServer.trackedNotifications, so modelData is
// the Notification. Click anywhere dismisses; action buttons invoke their
// action then dismiss; a Timer expires the card per its expireTimeout,
// which is three-valued: 0 means the app asked to keep it up until
// dismissed (that is how critical notifications behave), and a negative
// value means "server default" — Discord sends -1 — which falls back to
// the card's defaultExpireTimeout rather than being read as "never".
//
// The header is one line, and its proportions are the island's
// notification-history row's own (LO's call — that layout reads better
// than the flush-left first pass): the image sits on the card's own
// margin and every text block clears it by one 10px gap. The
// image is not the row's 22px avatar, though — it is a square two text
// lines tall (imageSize, 38: the summary's 20px line box plus the body's
// 18px one), so it spans the summary and the body's first line and its
// centre lands on theirs. The app name used to sit above the summary in
// dim 11px; it is gone, so the summary carries the header alone, with the
// receipt time after it on the same line. The history row stacks a dim
// body line under its summary, but the popup's header has to be one line,
// so the body keeps its own block below with the two-line clamp —
// anchored to the summary's bottom with no margin, so the two are one
// text column with nothing between them.
//
// The card's air is three named constants (margin, gap, timeGap) rather
// than literals scattered through the anchors, so the spacing is changed
// in one place. margin is the same on all four sides, the image included.
import QtQml
import QtQuick
import Quickshell
import Quickshell.Services.Notifications
import "../../Theme"

Rectangle {
    id: card

    // The notification object, captured ONCE at creation rather than bound
    // to modelData: modelData is resolved through the delegate's model
    // context, and that context is invalidated the moment the notification
    // leaves the model — while this card outlives it by its exit animation.
    // Bound directly, every property read on the fading card would hit null
    // and flood the log with TypeErrors. The RetainableLock at the bottom
    // keeps the captured object alive until the card itself is destroyed.
    property var notification: null
    Component.onCompleted: notification = modelData

    // fixed geometry — the stack never jumps as content changes
    width: 420
    height: 140
    radius: 18
    color: Theme.barBackground

    // critical notifications get the urgent border, everything else the
    // subtle surface lift
    border.width: 1
    border.color: notification.urgency === NotificationUrgency.Critical
        ? Theme.barUrgent
        : Theme.barHighlight

    // dismiss on click — declared FIRST so the content above it takes
    // clicks on the action buttons while everything else falls through
    // to here
    MouseArea {
        anchors.fill: parent
        onClicked: card.notification.dismiss()
    }

    // ---- the card's air ----
    // Three numbers, and every block's edges are derived from them, so the
    // card's spacing is changed in one place rather than hunted down block
    // by block. margin is the outer padding and it is the SAME on all four
    // sides, the image included.
    //
    // It used not to be. The image took the island row's 10px avatar inset
    // while every other block sat on 14, which left the picture 4px closer
    // to the left edge than to the top one — an asymmetry with no reason
    // behind it beyond two lineages never being reconciled: 14 was this
    // card's own padding from before the image existed, 10 was copied from
    // the row. The row's 10 is a different container's number — that avatar
    // is inset inside a plate that carries its own padding — so it does not
    // transfer, and the card keeps one margin. (LO's question — "why is the
    // top margin bigger than left?" — is what found it.)
    //
    // gap is the air between the image and the text column, and timeGap the
    // air between the text column and the header's timestamp.
    readonly property int margin: 14
    readonly property int gap: 10
    readonly property int timeGap: 8

    // The image is a square two text lines tall, and "two lines" is
    // measured rather than picked: the summary's line box is 20px and the
    // body's is 18px, so the card's first two lines of text measure 38.
    // The image is exactly that tall and starts on the same line as the
    // summary, so it spans the summary and the body's first line and its
    // centre lands on theirs. (The body's own two-line clamp is 36; 38 is
    // the first-two-lines measure, and it is what ships. LO's call: "the
    // image height takes up 2 lines of text", then "align image center
    // with first 2 lines".)
    readonly property int imageSize: 38

    // Every text block takes one left inset: the image's own left margin,
    // the image itself, and the gap — the island's notification-history
    // row's own rhythm, with the row's 22px avatar grown to the popup's
    // two-line image. The gap is load-bearing on the header line too, not
    // just the body: the summary hugging the image's right edge read as one
    // block with no air, the same defect the body's first line had beside
    // the image's lower half (LO's call — "the image and body has no gap
    // now, fix it", then "dont forget the sender name left margin as
    // well").
    readonly property int textInset: margin + imageSize + gap

    // Receipt time. Freedesktop notifications carry no timestamp of their
    // own — there is no field for one — so this is when the card was
    // created, which is when the shell saw the notification. HH:MM today,
    // MM/DD before that: the island history row's own format, so the popup
    // and the row read the same way.
    property date receivedAt: new Date()

    // The sender's image: on the card's own margin, top-aligned with the
    // summary so the two start on the same line. The app name used to sit
    // above the summary in dim 11px; it is gone, so the summary carries
    // the header alone and keeps the DemiBold weight the pair used to
    // share.
    //
    // Anchored straight to the card rather than wrapped in a band Item:
    // the band existed to centre the summary against the image, and the
    // image is now aligned to the first two lines instead, which needs no
    // band. (A Row would have been worse than either — it makes the
    // summary's width arithmetic, and that arithmetic broke the moment the
    // left margin moved off zero: the text has to reach the 14px right
    // margin from a position the Row itself computes.)
    Image {
        anchors.left: parent.left
        anchors.leftMargin: card.margin
        anchors.top: parent.top
        anchors.topMargin: card.margin
        width: card.imageSize
        height: card.imageSize
        sourceSize: Qt.size(card.imageSize, card.imageSize)
        fillMode: Image.PreserveAspectFit
        // The notification's own image wins over the app icon: that
        // is the sender's picture (Discord sends the profile photo
        // as image-data, which is what swaync showed), falling back
        // to the app's icon when the app sent no image. iconPath("")
        // mangles into a broken "?fallback=..." request, so only ask
        // when the app actually named an icon.
        //
        // At x=14 it clears the corner arc with room to spare: the r18
        // arc's last row on the left edge is y18, and the image starts
        // 14px in from it.
        source: card.notification.image.length > 0
            ? card.notification.image
            : (card.notification.appIcon.length > 0
                ? Quickshell.iconPath(card.notification.appIcon, "application-x-executable")
                : "")
    }

    // summary — the header's only line, top-aligned with the image and
    // clearing it by the same gap every other text block takes, so the
    // sender name does not touch the avatar. It carries an id because the
    // body anchors to its bottom: the two are one text column with no gap,
    // which is what puts the first two lines' centre on the image's.
    //
    // Its right edge is anchored to the timestamp's left rather than to the
    // card's, so the name elides before the time instead of running under
    // it — the island row's own arrangement, where the text column stops at
    // the time and the time never moves.
    Text {
        id: summaryText
        anchors.left: parent.left
        anchors.leftMargin: card.textInset
        anchors.right: headerTime.left
        anchors.rightMargin: card.timeGap
        anchors.top: parent.top
        anchors.topMargin: card.margin
        text: card.notification.summary
        color: Theme.barForeground
        font.family: Theme.barFontFamily
        font.pixelSize: 14
        font.weight: Font.DemiBold
        elide: Text.ElideRight
        maximumLineCount: 1
    }

    // receipt time — after the sender name, on the header's own line and
    // right-aligned on the card's outer margin, so it sits in the same
    // place on every card no matter how long the name runs. Dim at 12px,
    // the island history row's own treatment: the time is metadata, not
    // content, and it should not compete with the summary.
    //
    // Vertically centred on the summary's line box rather than top-aligned
    // with it — the two are different heights (20px DemiBold against a 12px
    // line), and centring puts their ink on one line instead of leaving the
    // time sitting high.
    Text {
        id: headerTime
        anchors.right: parent.right
        anchors.rightMargin: card.margin
        anchors.verticalCenter: summaryText.verticalCenter
        text: {
            var d = card.receivedAt
            var pad = function (n) { return (n < 10 ? "0" : "") + n }
            var now = new Date()
            if (d.getFullYear() === now.getFullYear()
                    && d.getMonth() === now.getMonth()
                    && d.getDate() === now.getDate())
                return pad(d.getHours()) + ":" + pad(d.getMinutes())
            return pad(d.getMonth() + 1) + "/" + pad(d.getDate())
        }
        color: Theme.barDim
        font.family: Theme.barFontFamily
        font.pixelSize: 12
    }

    // body — two lines max, then ellipsis; fills whatever the actions
    // row leaves, top-aligned so multi-line bodies read consistently.
    // Anchored to the SUMMARY's bottom with no margin, not to a band's:
    // the summary and the body are one text column with nothing between
    // them, which is what puts the first two lines' centre on the image's
    // (LO's call — "leave no gap between sender and message content").
    Text {
        id: body
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: summaryText.bottom
        anchors.bottom: actionRow.visible ? actionRow.top : parent.bottom
        anchors.leftMargin: card.textInset
        anchors.rightMargin: card.margin
        anchors.topMargin: 0
        anchors.bottomMargin: actionRow.visible ? 8 : card.margin
        visible: card.notification.body.length > 0
        text: card.notification.body
        color: Theme.barForeground
        font.family: Theme.barFontFamily
        font.pixelSize: 13
        wrapMode: Text.WordWrap
        maximumLineCount: 2
        elide: Text.ElideRight
        verticalAlignment: Text.AlignTop
    }

    // actions — fixed bottom slot, hidden when the app offered none.
    // Takes the same textInset as every other block, and the same outer
    // margin on the right and bottom.
    Row {
        id: actionRow
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.leftMargin: card.textInset
        anchors.rightMargin: card.margin
        anchors.bottomMargin: card.margin
        height: 26
        spacing: 8
        visible: card.notification.actions.length > 0

        Repeater {
            model: card.notification.actions
            Rectangle {
                property var action: modelData

                implicitWidth: actionLabel.implicitWidth + 20
                implicitHeight: 26
                radius: 13
                color: Theme.barHighlight

                Text {
                    id: actionLabel
                    anchors.centerIn: parent
                    text: parent.action.text
                    color: Theme.barForeground
                    font.family: Theme.barFontFamily
                    font.pixelSize: 12
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        parent.action.invoke()
                        card.notification.dismiss()
                    }
                }
            }
        }
    }

    // expireTimeout is three-valued per the freedesktop spec:
    //   > 0  — the app named a timeout in milliseconds; use it
    //   0    — the app asked to keep the card up until dismissed
    //   < 0  — "server default" (Discord sends -1); fall back to
    //          defaultExpireTimeout. The old `> 0` guard read -1 as
    //          "never expire", so every Discord popup stuck on screen
    //          until it was clicked or the app closed it itself.
    readonly property int effectiveTimeout: {
        var t = card.notification.expireTimeout
        if (t > 0)
            return t
        if (t === 0)
            return 0
        return defaultExpireTimeout
    }
    // the server default used when the app sends a negative timeout
    readonly property int defaultExpireTimeout: 5000

    Timer {
        running: card.effectiveTimeout > 0
        interval: card.effectiveTimeout
        onTriggered: card.notification.expire()
    }

    // The notification object is destroyed the moment it leaves the model,
    // but this card outlives that by its exit animation — without a lock
    // every binding on the fading card reads a null notification and floods
    // the log with TypeErrors. The lock is released when the card itself is
    // destroyed, so nothing leaks.
    RetainableLock {
        object: card.notification
        locked: true
    }
}
