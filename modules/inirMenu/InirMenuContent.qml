import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.modules.inirMenu
import Qt5Compat.GraphicalEffects
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

// Mirrors SearchWidget.qml exactly — same chrome, same focus model.
// Categories shown as result rows. Click one → drills in. Esc/back → returns.
Item {
    id: root

    // ── public interface (mirrors SearchWidget) ───────────────────────────
    property string searchingText: ""
    property bool showResults: activeCat !== null || searchingText !== ""

    // same sizing formula as SearchWidget
    implicitWidth:  searchWidgetContent.implicitWidth + Appearance.sizes.elevationMargin * 2
    implicitHeight: searchBar.implicitHeight + searchBar.verticalPadding * 2
                    + Appearance.sizes.elevationMargin * 2

    // ── nav state ─────────────────────────────────────────────────────────
    property var  activeCat: null          // null = category menu
    property bool inCategory: activeCat !== null
    property var  cachedResults: []        // populated by _refresh()

    // debounce — same as SearchWidget
    property string debouncedSearchText: ""
    Timer {
        id: searchDebounceTimer
        interval: 100
        onTriggered: {
            root.debouncedSearchText = root.searchingText
            root._refresh()
        }
    }
    onSearchingTextChanged: searchDebounceTimer.restart()

    // ── public functions (mirrors SearchWidget) ───────────────────────────
    function focusFirstItem()  { appResults.currentIndex = 0 }
    function focusSearchInput() { searchBar.forceFocus() }
    function cancelSearch() {
        searchBar.searchInput.text = ""
        root.searchingText = ""
        root.activeCat = null
    }

    // ── result builder ────────────────────────────────────────────────────
    function _refresh() {
        if (!root.inCategory) {
            // category menu: always show all 6 categories (no search on this level)
            root.cachedResults = InirMenuService.categories.map(function(cat) {
                return {
                    key:             "cat_" + cat.id,
                    name:            cat.label,
                    clickActionName: "Open",
                    materialSymbol:  cat.icon,
                    type:            cat.description,
                    _isCategoryRow:  true,
                    execute:         (function(c) {
                        return function() { root._openCat(c) }
                    })(cat)
                }
            })
            return
        }

        // drilled: filter category items by searchingText
        const q = root.debouncedSearchText
        const items = root.activeCat.buildResults(q)

        // back row always first
        const backRow = {
            key:             "__back__",
            name:            "Back",
            clickActionName: "Back",
            materialSymbol:  "arrow_back",
            type:            root.activeCat.label,
            _isBackRow:      true,
            execute:         function() { root._goBack() }
        }

        root.cachedResults = [backRow].concat(items.map(function(r, i) {
            return {
                key:             r.id ? ("r_" + r.id) : ("r_" + i),
                name:            r.name  ?? "",
                clickActionName: r.verb  ?? "Open",
                materialSymbol:  (r.iconType !== 2) ? (r.icon ?? "") : "",
                icon:            (r.iconType === 2) ? (r.icon ?? "") : "",
                type:            r.description ?? "",
                _isResultRow:    true,
                execute:         r.execute
            }
        }))
    }

    function _openCat(cat) {
        root.activeCat = cat
        root.searchingText = ""
        searchBar.searchInput.text = ""
        root._refresh()
        appResults.currentIndex = 0
        Qt.callLater(root.focusSearchInput)
    }

    function _goBack() {
        root.activeCat = null
        root.searchingText = ""
        searchBar.searchInput.text = ""
        root._refresh()
        appResults.currentIndex = 0
        Qt.callLater(root.focusSearchInput)
    }

    Component.onCompleted: _refresh()

    // same key handling as SearchWidget — type anywhere, redirects to input
    Keys.onPressed: event => {
        if (event.key === Qt.Key_Escape) return

        if (event.key === Qt.Key_Backspace) {
            if (!searchBar.searchInput.activeFocus) {
                root.focusSearchInput()
                if (event.modifiers & Qt.ControlModifier) {
                    let text = searchBar.searchInput.text
                    let pos  = searchBar.searchInput.cursorPosition
                    if (pos > 0) {
                        let left  = text.slice(0, pos)
                        let match = left.match(/(\s*\S+)\s*$/)
                        let del   = match ? match[0].length : 1
                        searchBar.searchInput.text = text.slice(0, pos - del) + text.slice(pos)
                        searchBar.searchInput.cursorPosition = pos - del
                    }
                } else {
                    if (searchBar.searchInput.cursorPosition > 0) {
                        let t = searchBar.searchInput.text
                        let p = searchBar.searchInput.cursorPosition
                        searchBar.searchInput.text = t.slice(0, p - 1) + t.slice(p)
                        searchBar.searchInput.cursorPosition = p - 1
                    }
                }
                searchBar.searchInput.cursorPosition = searchBar.searchInput.text.length
                event.accepted = true
            }
            return
        }

        if (event.text && event.text.length === 1
                && event.key !== Qt.Key_Enter && event.key !== Qt.Key_Return
                && event.key !== Qt.Key_Delete && event.text.charCodeAt(0) >= 0x20) {
            if (!searchBar.searchInput.activeFocus) {
                root.focusSearchInput()
                let t = searchBar.searchInput.text
                let p = searchBar.searchInput.cursorPosition
                searchBar.searchInput.text = t.slice(0, p) + event.text + t.slice(p)
                searchBar.searchInput.cursorPosition = p + 1
                event.accepted = true
                root.focusFirstItem()
            }
        }
    }

    // ── shadow + glass card — exact copy of SearchWidget ─────────────────
    StyledRectangularShadow {
        target: searchWidgetContent
    }

    GlassBackground {
        id: searchWidgetContent
        anchors {
            top: parent.top
            horizontalCenter: parent.horizontalCenter
            topMargin: Appearance.sizes.elevationMargin
        }
        clip: true
        implicitWidth:  columnLayout.implicitWidth
        implicitHeight: columnLayout.implicitHeight
        radius: searchBar.height / 2 + searchBar.verticalPadding
        fallbackColor: Appearance.colors.colBackgroundSurfaceContainer
        inirColor:     Appearance.inir.colLayer1
        auroraTransparency: Appearance.aurora.popupTransparentize
        border.width: Appearance.auroraEverywhere || Appearance.inirEverywhere ? 1 : 0
        border.color: Appearance.angelEverywhere ? Appearance.angel.colCardBorder
            : Appearance.inirEverywhere ? Appearance.inir.colBorder
            : Appearance.colors.colLayer0Border

        Behavior on implicitHeight {
            enabled: InirMenuService.open && root.showResults
            NumberAnimation { duration: 200; easing.type: Easing.OutQuart }
        }

        ColumnLayout {
            id: columnLayout
            anchors {
                top: parent.top
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

            // ── search bar — same as SearchWidget uses SearchBar ──────────
            InirMenuSearchBar {
                id: searchBar
                property real verticalPadding: 4
                Layout.fillWidth:    true
                Layout.leftMargin:   10
                Layout.rightMargin:  4
                Layout.topMargin:    verticalPadding
                Layout.bottomMargin: verticalPadding

                searchingText: root.searchingText
                inCategory:    root.inCategory
                categoryIcon:  root.activeCat?.icon  ?? "apps"
                categoryLabel: root.activeCat?.label ?? ""

                onSearchingTextChanged: {
                    if (searchingText !== root.searchingText)
                        root.searchingText = searchingText
                }
                onBackRequested: root._goBack()
            }

            // ── separator ─────────────────────────────────────────────────
            Rectangle {
                visible: root.showResults
                Layout.fillWidth: true
                height: 1
                color: Appearance.colors.colOutlineVariant
            }

            // ── result list — same as SearchWidget ────────────────────────
            ListView {
                id: appResults
                visible: root.showResults
                Layout.fillWidth: true
                implicitWidth: Appearance.sizes.searchWidth + 80
                implicitHeight: Math.min(600, appResults.contentHeight + topMargin + bottomMargin)
                clip:        true
                topMargin:   10
                bottomMargin: 10
                spacing: 2
                KeyNavigation.up: searchBar
                highlightMoveDuration: 100

                onFocusChanged: {
                    if (focus) currentIndex = 1
                }

                Connections {
                    target: root
                    function onSearchingTextChanged() {
                        if (appResults.count > 0) appResults.currentIndex = 0
                    }
                    function onActiveCatChanged() {
                        appResults.currentIndex = 0
                    }
                }

                model: root.cachedResults

                delegate: InirMenuResultItem {
                    required property var modelData
                    required property int index
                    anchors.left:  parent?.left
                    anchors.right: parent?.right
                    entry:         modelData
                    query:         root.inCategory ? root.debouncedSearchText : ""
                    isCategoryRow: modelData._isCategoryRow ?? false
                    isBackRow:     modelData._isBackRow     ?? false
                }
            }
        }
    }
}
