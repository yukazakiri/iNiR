import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io

// Mirrors SearchBar.qml — MaterialShapeWrappedMaterialSymbol + ToolbarTextField
RowLayout {
    id: root
    spacing: 6

    property alias searchInput: searchInput
    property string searchingText: ""
    property bool   inCategory:    false
    property string categoryIcon:  "apps"
    property string categoryLabel: ""

    signal backRequested()

    function forceFocus() { searchInput.forceActiveFocus() }

    // Dynamic icon — same pattern as SearchBar.qml
    MaterialShapeWrappedMaterialSymbol {
        id: searchIcon
        Layout.alignment: Qt.AlignVCenter
        iconSize: Appearance.font.pixelSize.huge
        shape: root.inCategory
            ? MaterialShape.Shape.Clover4Leaf
            : MaterialShape.Shape.Cookie7Sided
        text: root.inCategory ? root.categoryIcon : "apps"
    }

    ToolbarTextField {
        id: searchInput
        Layout.topMargin:    4
        Layout.bottomMargin: 4
        implicitHeight: 40
        font.pixelSize: Appearance.font.pixelSize.small
        placeholderText: root.inCategory
            ? "Search " + root.categoryLabel + "…"
            : "Search, calculate or run"
        implicitWidth: root.searchingText === ""
            ? Appearance.sizes.searchWidthCollapsed
            : Appearance.sizes.searchWidth

        Behavior on implicitWidth {
            NumberAnimation { duration: 250; easing.type: Easing.OutQuart }
        }

        onTextChanged: root.searchingText = text

        onAccepted: {
            // Enter key — handled at parent level via Keys
        }
    }

    // Back button — visible only when drilled into a category
    IconToolbarButton {
        Layout.topMargin:    4
        Layout.bottomMargin: 4
        Layout.rightMargin:  4
        visible: root.inCategory
        text: "arrow_back"
        onClicked: root.backRequested()
        StyledToolTip { text: "Back" }
    }
}
