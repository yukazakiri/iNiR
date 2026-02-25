pragma ComponentBehavior: Bound

import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell

// ============================================================================
// InirMenuContent — the actual UI card rendered inside InirMenu.qml
//
// Layout:
//   ┌─────────────────────────────────────┐
//   │  [🔍 search bar]                    │
//   ├──────────────────────────────────────┤
//   │ [Apps] [Setup] [Install] [Remove]…  │  ← category tab row
//   ├──────────────────────────────────────┤
//   │  result list / empty state          │
//   └─────────────────────────────────────┘
// ============================================================================

FocusScope {
    id: root
    focus: true

    implicitWidth:  560
    implicitHeight: Math.min(580, columnLayout.implicitHeight)

    // resolved results reactively from the service
    property var currentResults: []

    // Re-compute whenever category or debounced query changes
    Connections {
        target: InirMenuService
        function onActiveCategoryIdChanged() { root._refresh() }
        function on_DebouncedQueryChanged()  { root._refresh() }
        function onOpenChanged() {
            if (InirMenuService.open) {
                root._refresh()
                Qt.callLater(() => searchInput.forceActiveFocus())
            }
        }
    }
    Component.onCompleted: root._refresh()

    function _refresh() {
        currentResults = InirMenuService.results()
        resultList.currentIndex = 0
    }

    // ── background card ───────────────────────────────────────────────────────
    StyledRectangularShadow { target: card }

    Rectangle {
        id: card
        anchors.fill: parent
        radius: Appearance.inirEverywhere ? Appearance.inir.roundingLarge : Appearance.rounding.large
        color:  Appearance.inirEverywhere ? Appearance.inir.colLayer0 : Appearance.colors.colLayer0
        border.width: 1
        border.color: Appearance.inirEverywhere
            ? Appearance.inir.colBorder
            : Appearance.colors.colLayer0Border
        clip: true

        ColumnLayout {
            id: columnLayout
            anchors.fill: parent
            spacing: 0

            // ── Search bar ──────────────────────────────────────────────────
            RowLayout {
                Layout.fillWidth: true
                Layout.margins: 12
                spacing: 8

                MaterialSymbol {
                    text: "search"
                    iconSize: Appearance.font.pixelSize.large
                    color: Appearance.inirEverywhere
                        ? Appearance.inir.colSubtext
                        : Appearance.colors.colSubtext
                }

                ToolbarTextField {
                    id: searchInput
                    Layout.fillWidth: true
                    implicitHeight: 40
                    font.pixelSize: Appearance.font.pixelSize.small
                    placeholderText: {
                        const cat = InirMenuService.activeCategory()
                        return cat ? "Search " + cat.label.toLowerCase() + "…" : "Search…"
                    }

                    focus: true
                    KeyNavigation.down: resultList

                    onTextChanged: InirMenuService.query = text

                    onAccepted: {
                        if (root.currentResults.length > 0) {
                            const item = root.currentResults[resultList.currentIndex]
                            if (item && item.execute) item.execute()
                        }
                    }

                    Keys.onPressed: event => {
                        if (event.key === Qt.Key_Down) {
                            resultList.forceActiveFocus()
                            resultList.currentIndex = 0
                            event.accepted = true
                        } else if (event.key === Qt.Key_Escape) {
                            InirMenuService.open = false
                            event.accepted = true
                        }
                    }
                }

                // Clear button
                IconToolbarButton {
                    visible: InirMenuService.query !== ""
                    text: "close"
                    onClicked: {
                        InirMenuService.query = ""
                        searchInput.text = ""
                        searchInput.forceActiveFocus()
                    }
                }
            }

            // ── Divider ─────────────────────────────────────────────────────
            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: Appearance.inirEverywhere
                    ? Appearance.inir.colBorder
                    : Appearance.colors.colOutlineVariant
            }

            // ── Category tab row ────────────────────────────────────────────
            ScrollView {
                Layout.fillWidth: true
                implicitHeight: categoryRow.implicitHeight + 8
                ScrollBar.vertical.policy: ScrollBar.AlwaysOff
                ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                clip: true

                RowLayout {
                    id: categoryRow
                    anchors {
                        left: parent.left; leftMargin: 8
                        right: parent.right; rightMargin: 8
                        verticalCenter: parent.verticalCenter
                    }
                    spacing: 4

                    Repeater {
                        model: InirMenuService.categories

                        InirMenuCategoryButton {
                            required property var modelData
                            required property int index

                            categoryId:    modelData.id
                            categoryLabel: modelData.label
                            categoryIcon:  modelData.icon
                            active:        InirMenuService.activeCategoryId === modelData.id

                            onClicked: {
                                InirMenuService.activeCategoryId = modelData.id
                                InirMenuService.query = ""
                                searchInput.text = ""
                                searchInput.forceActiveFocus()
                            }

                            StyledToolTip { text: modelData.description }
                        }
                    }
                }
            }

            // ── Divider ─────────────────────────────────────────────────────
            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: Appearance.inirEverywhere
                    ? Appearance.inir.colBorder
                    : Appearance.colors.colOutlineVariant
            }

            // ── Result list / empty state ────────────────────────────────────
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
                implicitHeight: 380
                clip: true

                // Empty state
                ColumnLayout {
                    anchors.centerIn: parent
                    visible: root.currentResults.length === 0
                    spacing: 8

                    MaterialSymbol {
                        Layout.alignment: Qt.AlignHCenter
                        text: {
                            const cat = InirMenuService.activeCategory()
                            return cat ? cat.icon : "apps"
                        }
                        iconSize: 48
                        color: Appearance.inirEverywhere
                            ? Appearance.inir.colSubtext
                            : Appearance.colors.colSubtext
                        opacity: 0.4
                    }

                    StyledText {
                        Layout.alignment: Qt.AlignHCenter
                        text: InirMenuService.query === ""
                            ? (InirMenuService.activeCategory()?.description ?? "")
                            : "No results"
                        font.pixelSize: Appearance.font.pixelSize.small
                        color: Appearance.inirEverywhere
                            ? Appearance.inir.colSubtext
                            : Appearance.colors.colSubtext
                        opacity: 0.6
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.Wrap
                        Layout.maximumWidth: 320
                    }
                }

                // Results
                StyledListView {
                    id: resultList
                    anchors.fill: parent
                    anchors.margins: 8
                    spacing: 2
                    clip: true

                    KeyNavigation.up: searchInput
                    highlight: null   // we colour items ourselves

                    model: root.currentResults

                    Keys.onPressed: event => {
                        if (event.key === Qt.Key_Escape) {
                            InirMenuService.open = false
                            event.accepted = true
                        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                            const item = root.currentResults[currentIndex]
                            if (item && item.execute) item.execute()
                            event.accepted = true
                        }
                    }

                    delegate: InirMenuResultItem {
                        required property var modelData
                        required property int index

                        width: ListView.view?.width ?? 0
                        entry: modelData

                        // keyboard highlight via currentIndex
                        ListView.onIsCurrentItemChanged: {
                            if (ListView.isCurrentItem) forceActiveFocus()
                        }
                    }
                }
            }

            // ── Footer hint ──────────────────────────────────────────────────
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: footerRow.implicitHeight + 8
                color: Appearance.inirEverywhere
                    ? Appearance.inir.colLayer1
                    : Appearance.colors.colSurfaceContainerLow

                RowLayout {
                    id: footerRow
                    anchors {
                        left: parent.left; leftMargin: 12
                        right: parent.right; rightMargin: 12
                        verticalCenter: parent.verticalCenter
                    }
                    spacing: 16

                    // keyboard shortcut hints
                    Repeater {
                        model: [
                            { key: "↑↓",    hint: "Navigate" },
                            { key: "Enter", hint: "Execute"  },
                            { key: "Esc",   hint: "Close"    },
                        ]
                        RowLayout {
                            required property var modelData
                            spacing: 4

                            Rectangle {
                                radius: 3
                                color: Appearance.inirEverywhere
                                    ? Appearance.inir.colLayer2
                                    : Appearance.colors.colSurfaceContainerHigh
                                implicitWidth:  kbLabel.implicitWidth + 8
                                implicitHeight: kbLabel.implicitHeight + 4
                                StyledText {
                                    id: kbLabel
                                    anchors.centerIn: parent
                                    text: modelData.key
                                    font.pixelSize: Appearance.font.pixelSize.tiny ?? 10
                                    color: Appearance.inirEverywhere
                                        ? Appearance.inir.colText
                                        : Appearance.m3colors.m3onSurface
                                }
                            }

                            StyledText {
                                text: modelData.hint
                                font.pixelSize: Appearance.font.pixelSize.tiny ?? 10
                                color: Appearance.inirEverywhere
                                    ? Appearance.inir.colSubtext
                                    : Appearance.colors.colSubtext
                            }
                        }
                    }

                    Item { Layout.fillWidth: true }

                    StyledText {
                        text: "Inir Menu"
                        font.pixelSize: Appearance.font.pixelSize.tiny ?? 10
                        color: Appearance.inirEverywhere
                            ? Appearance.inir.colSubtext
                            : Appearance.colors.colSubtext
                        opacity: 0.5
                    }
                }
            }
        }
    }
}
