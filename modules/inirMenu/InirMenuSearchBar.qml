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

// ============================================================================
// InirMenuSearchBar
// Clones the look of SearchBar.qml:
//   MaterialShapeWrappedMaterialSymbol | ToolbarTextField | optional buttons
// ============================================================================

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

    // icon shape & symbol mirrors SearchBar logic
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
        implicitHeight:      40
        font.pixelSize:      Appearance.font.pixelSize.small
        placeholderText:     root.inCategory
            ? "Search " + root.categoryLabel + "…"
            : "Inir Menu"
        implicitWidth: Appearance.sizes.searchWidth

        onTextChanged: root.searchingText = text

        onAccepted: {
            // handled by parent via Keys.onPressed
        }
    }

    // Back button when drilled into a category
    Loader {
        active: root.inCategory
        sourceComponent: IconToolbarButton {
            Layout.topMargin:    4
            Layout.bottomMargin: 4
            text: "arrow_back"
            onClicked: root.backRequested()
            StyledToolTip { text: "Back to menu" }
        }
    }
}
