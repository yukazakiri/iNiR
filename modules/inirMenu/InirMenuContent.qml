pragma ComponentBehavior: Bound

import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.modules.inirMenu
import Qt5Compat.GraphicalEffects
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Widgets

// ============================================================================
// InirMenuContent
//
// Identical chrome to the app launcher (GlassBackground + search bar +
// separator + ListView).  Categories are themselves result rows — clicking one
// drills into that category's items.  A back-arrow row at the top of the
// drilled list returns to the category menu.
// ============================================================================

Item {
    id: root

    // ── sizing — same as SearchWidget ──────────────────────────────────────
    implicitWidth:  searchWidgetContent.implicitWidth + Appearance.sizes.elevationMargin * 2
    implicitHeight: searchBar.implicitHeight + searchBarPad * 2 + Appearance.sizes.elevationMargin * 2

    property real searchBarPad: 4

    // ── view state ─────────────────────────────────────────────────────────
    // null  → showing category menu
    // obj   → showing results for that category
    property var activeCat: null
    property bool inCategory: activeCat !== null

    // search text (only active when inCategory)
    property string searchText: ""
    property string debouncedSearch: ""

    Timer {
        id: debounce
        interval: 80
        onTriggered: root.debouncedSearch = root.searchText
    }
    onSearchTextChanged: {
        if (searchText === "") { debouncedSearch = ""; debounce.stop() }
        else debounce.restart()
    }

    // current result list
    property var displayList: {
        if (!root.inCategory) {
            // category menu — one row per category
            return InirMenuService.categories.map(function(cat) {
                return {
                    key:             cat.id,
                    name:            cat.label,
                    clickActionName: "Open",
                    materialSymbol:  cat.icon,
                    type:            cat.description,
                    _isCategoryRow:  true,
                    _cat:            cat,
                    execute:         function() { root._openCat(cat) }
                }
            })
        }
        // drilled — prepend a ‹ Back row then the category results
        const results = root.activeCat.buildResults(root.debouncedSearch)
        const backRow = {
            key:             "__back__",
            name:            root.activeCat.label,
            clickActionName: "Back",
            materialSymbol:  "arrow_back",
            type:            "",
            _isBackRow:      true,
            execute:         function() { root._goBack() }
        }
        return [backRow].concat(results.map(function(r, i) {
            return {
                key:             r.id ?? ("r" + i),
                name:            r.name,
                clickActionName: r.verb ?? "Open",
                materialSymbol:  (r.iconType === 2) ? "" : (r.icon ?? ""),
                icon:            (r.iconType === 2) ? (r.icon ?? "") : "",
                type:            r.description ?? "",
                execute:         r.execute
            }
        }))
    }

    function _openCat(cat) {
        root.activeCat = cat
        root.searchText = ""
        searchBar.searchInput.text = ""
        resultList.currentIndex = 0
        Qt.callLater(function() { searchBar.forceFocus() })
    }

    function _goBack() {
        root.activeCat = null
        root.searchText = ""
        searchBar.searchInput.text = ""
        resultList.currentIndex = 0
        Qt.callLater(function() { searchBar.forceFocus() })
    }

    // reset when menu closes
    Connections {
        target: InirMenuService
        function onOpenChanged() {
            if (!InirMenuService.open) {
                root.activeCat = null
                root.searchText = ""
                searchBar.searchInput.text = ""
            } else {
                resultList.currentIndex = 0
                Qt.callLater(function() { searchBar.forceFocus() })
            }
        }
    }

    // ── shadow + glass card — exactly as SearchWidget ──────────────────────
    StyledRectangularShadow {
        target: searchWidgetContent
    }

    GlassBackground {
        id: searchWidgetContent
        anchors {
            top:              parent.top
            horizontalCenter: parent.horizontalCenter
            topMargin:        Appearance.sizes.elevationMargin
        }
        clip: true
        implicitWidth:  columnLayout.implicitWidth
        implicitHeight: columnLayout.implicitHeight
        radius: searchBar.searchInput.implicitHeight / 2 + root.searchBarPad
        fallbackColor: Appearance.colors.colBackgroundSurfaceContainer
        inirColor:     Appearance.inir.colLayer1
        auroraTransparency: Appearance.aurora.popupTransparentize
        border.width: Appearance.auroraEverywhere || Appearance.inirEverywhere ? 1 : 0
        border.color: Appearance.angelEverywhere ? Appearance.angel.colCardBorder
            : Appearance.inirEverywhere ? Appearance.inir.colBorder
            : Appearance.colors.colLayer0Border

        Behavior on implicitHeight {
            enabled: InirMenuService.open
            NumberAnimation { duration: 200; easing.type: Easing.OutQuart }
        }

        ColumnLayout {
            id: columnLayout
            anchors {
                top:              parent.top
                horizontalCenter: parent.horizontalCenter
            }
            spacing: 0

            layer.enabled: true
            layer.effect: OpacityMask {
                maskSource: Rectangle {
                    width:  searchWidgetContent.width
                    height: searchWidgetContent.width
                    radius: searchWidgetContent.radius
                }
            }

            // ── Search bar row — identical to SearchBar.qml ────────────────
            InirMenuSearchBar {
                id: searchBar
                property real verticalPadding: root.searchBarPad
                Layout.fillWidth:   true
                Layout.leftMargin:  10
                Layout.rightMargin: 4
                Layout.topMargin:   verticalPadding
                Layout.bottomMargin: verticalPadding

                searchingText:   root.searchText
                inCategory:      root.inCategory
                categoryIcon:    root.activeCat?.icon ?? "apps"
                categoryLabel:   root.activeCat?.label ?? ""

                onSearchingTextChanged: {
                    if (searchingText !== root.searchText)
                        root.searchText = searchingText
                }

                onBackRequested: root._goBack()

                searchInput.Keys.onPressed: function(event) {
                    if (event.key === Qt.Key_Down) {
                        resultList.forceActiveFocus()
                        resultList.currentIndex = 0
                        event.accepted = true
                    } else if (event.key === Qt.Key_Escape) {
                        if (root.inCategory) root._goBack()
                        else InirMenuService.open = false
                        event.accepted = true
                    } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                        if (root.displayList.length > 0) {
                            const entry = root.displayList[0]
                            if (entry && entry.execute) entry.execute()
                        }
                        event.accepted = true
                    }
                }
            }

            // ── Separator ──────────────────────────────────────────────────
            Rectangle {
                visible:        root.displayList.length > 0
                Layout.fillWidth: true
                height: 1
                color:  Appearance.colors.colOutlineVariant
            }

            // ── Result list ────────────────────────────────────────────────
            ListView {
                id: resultList
                visible:        root.displayList.length > 0
                Layout.fillWidth: true
                implicitWidth:  Appearance.sizes.searchWidth + 80
                implicitHeight: Math.min(600, contentHeight + topMargin + bottomMargin)
                clip:    true
                topMargin:    10
                bottomMargin: 10
                spacing: 2
                KeyNavigation.up: searchBar
                highlightMoveDuration: 100

                onFocusChanged: {
                    if (focus) currentIndex = 1
                }

                Connections {
                    target: root
                    function onDisplayListChanged() {
                        if (resultList.count > 0) resultList.currentIndex = 0
                    }
                }

                model: root.displayList

                delegate: InirMenuResultItem {
                    required property var  modelData
                    required property int  index
                    anchors.left:  parent?.left
                    anchors.right: parent?.right
                    entry:         modelData
                    query:         root.inCategory ? root.debouncedSearch : ""
                    isBackRow:     modelData._isBackRow   ?? false
                    isCategoryRow: modelData._isCategoryRow ?? false
                }
            }
        }
    }
}
