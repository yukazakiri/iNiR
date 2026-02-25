import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets

// A single clickable result row in the Inir Menu result list
RippleButton {
    id: root

    // The plain JS result object from InirMenuService category buildResults()
    property var entry: null

    property string itemName:        entry?.name        ?? ""
    property string itemIcon:        entry?.icon        ?? ""
    property int    itemIconType:    entry?.iconType    ?? 0   // 0=material 2=system
    property string itemVerb:        entry?.verb        ?? "Open"
    property string itemDescription: entry?.description ?? ""

    implicitHeight: rowLayout.implicitHeight + 12
    implicitWidth:  rowLayout.implicitWidth  + 20

    buttonRadius: Appearance.inirEverywhere
        ? Appearance.inir.roundingSmall
        : Appearance.rounding.normal

    colBackground: (down || ListView.isCurrentItem)
        ? (Appearance.inirEverywhere ? Appearance.inir.colPrimaryActive : Appearance.colors.colPrimaryContainerActive)
        : hovered
            ? (Appearance.inirEverywhere ? Appearance.inir.colLayer2 : Appearance.colors.colPrimaryContainer)
            : "transparent"

    colBackgroundHover: Appearance.inirEverywhere
        ? Appearance.inir.colLayer2Hover
        : Appearance.colors.colPrimaryContainer

    colRipple: Appearance.inirEverywhere
        ? Appearance.inir.colPrimaryActive
        : Appearance.colors.colPrimaryContainerActive

    onClicked: {
        if (entry && entry.execute) entry.execute()
    }

    Keys.onPressed: event => {
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            if (entry && entry.execute) entry.execute()
            event.accepted = true
        }
    }

    RowLayout {
        id: rowLayout
        spacing: 12
        anchors {
            verticalCenter: parent.verticalCenter
            left:  parent.left;  leftMargin:  10
            right: parent.right; rightMargin: 10
        }

        // Icon
        Loader {
            id: iconLoader
            Layout.alignment: Qt.AlignVCenter
            active: root.itemIcon !== ""
            sourceComponent: root.itemIconType === 2 ? systemIconComp : materialIconComp
        }

        Component {
            id: materialIconComp
            MaterialSymbol {
                text:     root.itemIcon
                iconSize: 24
                color:    Appearance.inirEverywhere
                              ? Appearance.inir.colText
                              : Appearance.m3colors.m3onSurface
            }
        }

        Component {
            id: systemIconComp
            IconImage {
                source: Quickshell.iconPath(root.itemIcon, "application-x-executable")
                implicitWidth:  28
                implicitHeight: 28
            }
        }

        // Text column
        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            spacing: 1

            StyledText {
                Layout.fillWidth: true
                text:             root.itemName
                font.pixelSize:   Appearance.font.pixelSize.small
                color:            Appearance.inirEverywhere
                                      ? Appearance.inir.colText
                                      : Appearance.m3colors.m3onSurface
                elide: Text.ElideRight
            }

            StyledText {
                Layout.fillWidth: true
                visible:          root.itemDescription !== ""
                text:             root.itemDescription
                font.pixelSize:   Appearance.font.pixelSize.tiny ?? 10
                color:            Appearance.inirEverywhere
                                      ? Appearance.inir.colSubtext
                                      : Appearance.colors.colSubtext
                elide: Text.ElideRight
            }
        }

        // Action label (visible on hover)
        StyledText {
            visible:          root.hovered || root.ListView.isCurrentItem
            text:             root.itemVerb
            font.pixelSize:   Appearance.font.pixelSize.tiny ?? 10
            color:            Appearance.inirEverywhere
                                  ? Appearance.inir.colPrimary
                                  : Appearance.colors.colOnPrimaryContainer
            Layout.alignment: Qt.AlignVCenter
        }
    }

    PointingHandInteraction {}
}
