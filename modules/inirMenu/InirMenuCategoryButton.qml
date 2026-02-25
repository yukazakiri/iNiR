import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts

// A tab-style button for each Inir Menu category
RippleButton {
    id: root

    property string categoryId:    ""
    property string categoryLabel: ""
    property string categoryIcon:  "apps"
    property bool   active:        false

    implicitHeight: 48
    implicitWidth:  columnContent.implicitWidth + 20

    buttonRadius: Appearance.rounding.normal

    colBackground: active
        ? (Appearance.inirEverywhere ? Appearance.inir.colPrimary
            : Appearance.colors.colPrimary)
        : (hovered
            ? (Appearance.inirEverywhere ? Appearance.inir.colLayer2Hover
                : Appearance.colors.colSurfaceContainerHigh)
            : "transparent")

    colBackgroundHover: Appearance.inirEverywhere
        ? Appearance.inir.colLayer2Hover
        : Appearance.colors.colSurfaceContainerHigh

    colRipple: Appearance.inirEverywhere
        ? Appearance.inir.colPrimaryActive
        : Appearance.colors.colPrimaryContainerActive

    Behavior on colBackground {
        ColorAnimation { duration: 150 }
    }

    ColumnLayout {
        id: columnContent
        anchors.centerIn: parent
        spacing: 2

        MaterialSymbol {
            Layout.alignment: Qt.AlignHCenter
            text: root.categoryIcon
            iconSize: 20
            color: root.active
                ? (Appearance.inirEverywhere ? Appearance.inir.colOnPrimary : Appearance.m3colors.m3onPrimary)
                : (Appearance.inirEverywhere ? Appearance.inir.colText : Appearance.m3colors.m3onSurface)
            Behavior on color { ColorAnimation { duration: 120 } }
        }

        StyledText {
            Layout.alignment: Qt.AlignHCenter
            text: root.categoryLabel
            font.pixelSize: Appearance.font.pixelSize.tiny ?? 10
            color: root.active
                ? (Appearance.inirEverywhere ? Appearance.inir.colOnPrimary : Appearance.m3colors.m3onPrimary)
                : (Appearance.inirEverywhere ? Appearance.inir.colSubtext : Appearance.colors.colSubtext)
            Behavior on color { ColorAnimation { duration: 120 } }
        }
    }

    PointingHandInteraction {}
}
