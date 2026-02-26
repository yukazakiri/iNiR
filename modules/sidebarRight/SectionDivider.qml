import QtQuick
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets
import qs.services

RowLayout {
    id: root
    
    required property string text
    property int fontSize: Appearance.font.pixelSize.smallest
    property int fontWeight: Font.Medium
    
    Layout.fillWidth: true
    spacing: 8
    
    Rectangle {
        Layout.fillWidth: true
        height: 1
        color: Appearance.angelEverywhere ? ColorUtils.transparentize(Appearance.angel.colCardBorder, 0.5)
            : Appearance.inirEverywhere ? Appearance.inir.colBorder
            : Appearance.colors.colLayer0Border
    }
    
    StyledText {
        text: root.text
        font.pixelSize: root.fontSize
        font.weight: root.fontWeight
        color: Appearance.inirEverywhere ? Appearance.inir.colTextSecondary
            : Appearance.angelEverywhere ? Appearance.angel.colTextSecondary
            : Appearance.colors.colSubtext
    }
    
    Rectangle {
        Layout.fillWidth: true
        height: 1
        color: Appearance.angelEverywhere ? ColorUtils.transparentize(Appearance.angel.colCardBorder, 0.5)
            : Appearance.inirEverywhere ? Appearance.inir.colBorder
            : Appearance.colors.colLayer0Border
    }
}
