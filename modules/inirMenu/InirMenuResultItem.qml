pragma NativeMethodBehavior: AcceptThisObject

import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets

// ============================================================================
// InirMenuResultItem
// Pixel-identical to SearchItem.qml from the app launcher.
// Works for category rows, back row, and regular result rows.
// ============================================================================

RippleButton {
    id: root

    // plain JS result object from InirMenuContent.displayList
    property var    entry:   null
    property string query:   ""
    property bool   isBackRow:     false
    property bool   isCategoryRow: false

    property string itemType:            entry?.type            ?? ""
    property string itemName:            entry?.name            ?? ""
    property string itemIcon:            entry?.icon            ?? ""   // system icon name
    property string materialSymbol:      entry?.materialSymbol  ?? ""
    property string itemClickActionName: entry?.clickActionName ?? "Open"
    property bool   keyboardDown:        false

    property int horizontalMargin:      10
    property int buttonHorizontalPadding: 10
    property int buttonVerticalPadding:   6

    opacity: 1
    implicitHeight: rowLayout.implicitHeight + buttonVerticalPadding * 2
    implicitWidth:  rowLayout.implicitWidth  + buttonHorizontalPadding * 2

    buttonRadius: Appearance.angelEverywhere ? Appearance.angel.roundingSmall
        : Appearance.inirEverywhere ? Appearance.inir.roundingSmall
        : Appearance.rounding.normal

    colBackground: (root.down || root.keyboardDown)
        ? (Appearance.angelEverywhere    ? Appearance.angel.colGlassCardActive
            : Appearance.inirEverywhere  ? Appearance.inir.colPrimaryActive
            : Appearance.colors.colPrimaryContainerActive)
        : ((root.hovered || root.focus)
            ? (Appearance.angelEverywhere   ? Appearance.angel.colGlassCard
                : Appearance.inirEverywhere ? Appearance.inir.colLayer2
                : Appearance.auroraEverywhere ? Appearance.aurora.colSubSurface
                : Appearance.colors.colPrimaryContainer)
            : "transparent")

    colBackgroundHover: Appearance.angelEverywhere ? Appearance.angel.colGlassCardHover
        : Appearance.inirEverywhere ? Appearance.inir.colLayer2Hover
        : Appearance.auroraEverywhere ? Appearance.aurora.colSubSurface
        : Appearance.colors.colPrimaryContainer

    colRipple: Appearance.inirEverywhere
        ? Appearance.inir.colPrimaryActive
        : Appearance.colors.colPrimaryContainerActive

    // fuzzy highlight helpers — same logic as SearchItem
    property string highlightPrefix: `<u><font color="${Appearance.inirEverywhere ? Appearance.inir.colPrimary : Appearance.colors.colPrimary}">`
    property string highlightSuffix: `</font></u>`
    function highlightContent(content, q) {
        if (!q || q.length === 0 || content === q)
            return StringUtils.escapeHtml(content)
        let cl = content.toLowerCase(), ql = q.toLowerCase()
        let out = "", last = 0, qi = 0
        for (let i = 0; i < content.length && qi < q.length; i++) {
            if (cl[i] === ql[qi]) {
                if (i > last) out += StringUtils.escapeHtml(content.slice(last, i))
                out += root.highlightPrefix + StringUtils.escapeHtml(content[i]) + root.highlightSuffix
                last = i + 1; qi++
            }
        }
        if (last < content.length) out += StringUtils.escapeHtml(content.slice(last))
        return out
    }
    property string displayContent: highlightContent(root.itemName, root.query)

    PointingHandInteraction {}

    background {
        anchors.fill:        root
        anchors.leftMargin:  root.horizontalMargin
        anchors.rightMargin: root.horizontalMargin
    }

    onClicked: {
        if (root.entry && root.entry.execute) root.entry.execute()
    }

    Keys.onPressed: event => {
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            root.keyboardDown = true
            root.clicked()
            event.accepted = true
        }
    }
    Keys.onReleased: event => {
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            root.keyboardDown = false
            event.accepted = true
        }
    }

    RowLayout {
        id: rowLayout
        spacing: 10
        anchors.fill: parent
        anchors.leftMargin:  root.horizontalMargin + root.buttonHorizontalPadding
        anchors.rightMargin: root.horizontalMargin + root.buttonHorizontalPadding

        // Icon — material symbol OR system theme icon
        Loader {
            id: iconLoader
            active: true
            sourceComponent:
                root.materialSymbol !== "" ? materialSymbolComp :
                root.itemIcon       !== "" ? systemIconComp     : null
        }

        Component {
            id: materialSymbolComp
            MaterialSymbol {
                text:     root.materialSymbol
                iconSize: 30
                color:    Appearance.m3colors.m3onSurface
            }
        }

        Component {
            id: systemIconComp
            IconImage {
                source: Quickshell.iconPath(root.itemIcon, "image-missing")
                width:  35
                height: 35
            }
        }

        // Text column
        ColumnLayout {
            Layout.fillWidth:  true
            Layout.alignment:  Qt.AlignVCenter
            spacing: 0

            // Type label (description / category subtitle) — hidden for back row
            StyledText {
                font.pixelSize: Appearance.font.pixelSize.smaller
                color:          Appearance.colors.colSubtext
                visible:        root.itemType !== "" && !root.isBackRow
                text:           root.itemType
            }

            // Name with fuzzy highlight
            StyledText {
                Layout.fillWidth: true
                textFormat:       Text.StyledText
                font.pixelSize:   Appearance.font.pixelSize.small
                color:            Appearance.m3colors.m3onSurface
                horizontalAlignment: Text.AlignLeft
                elide:            Text.ElideRight
                text:             root.displayContent
            }
        }

        // Action label (hover only) — right-aligned like SearchItem
        StyledText {
            Layout.fillWidth: false
            visible:          root.hovered || root.focus
            font.pixelSize:   Appearance.font.pixelSize.normal
            color:            Appearance.colors.colOnPrimaryContainer
            horizontalAlignment: Text.AlignRight
            text:             root.itemClickActionName
        }

        // Trailing chevron for category rows
        MaterialSymbol {
            visible:  root.isCategoryRow
            text:     "chevron_right"
            iconSize: Appearance.font.pixelSize.large
            color:    Appearance.colors.colSubtext
        }
    }
}
