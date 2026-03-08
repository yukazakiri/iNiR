pragma ComponentBehavior: Bound

import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

StyledFlickable {
    id: root

    property string searchText: ""
    
    readonly property var categories: [
        { name: "Basic Motion", icon: "arrow_selector_tool", items: [
            { keys: "h", description: "Move left" },
            { keys: "j", description: "Move down" },
            { keys: "k", description: "Move up" },
            { keys: "l", description: "Move right" },
            { keys: "w", description: "Word forward" },
            { keys: "b", description: "Word backward" },
            { keys: "e", description: "Word end forward" },
            { keys: "ge", description: "Word end backward" },
            { keys: "0", description: "Line start" },
            { keys: "^", description: "Line start (non-blank)" },
            { keys: "$", description: "Line end" },
            { keys: "gg", description: "File start" },
            { keys: "G", description: "File end" },
            { keys: "H", description: "Screen top" },
            { keys: "M", description: "Screen middle" },
            { keys: "L", description: "Screen bottom" },
        ]},
        { name: "Word Motion", icon: "text_format", items: [
            { keys: "W", description: "WORD forward" },
            { keys: "B", description: "WORD backward" },
            { keys: "E", description: "WORD end forward" },
            { keys: "gE", description: "WORD end backward" },
        ]},
        { name: "Char Search", icon: "find_in_page", items: [
            { keys: "f", description: "Find char forward" },
            { keys: "F", description: "Find char backward" },
            { keys: "t", description: "Till char forward" },
            { keys: "T", description: "Till char backward" },
            { keys: ";", description: "Repeat last f/F/t/T" },
            { keys: ",", description: "Reverse f/F/t/T" },
        ]},
        { name: "Line Motion", icon: "vertical_align_bottom", items: [
            { keys: "n", description: "Line n" },
            { keys: "nG", description: "Go to line n" },
            { keys: "n%", description: "Go to n percent" },
            { keys: "n|", description: "Go to column n" },
            { keys: "gm", description: "Go to middle" },
            { keys: "g0", description: "Screen line start" },
            { keys: "g$", description: "Screen line end" },
            { keys: "gk", description: "Screen line up" },
            { keys: "gj", description: "Screen line down" },
        ]},
        { name: "Insert Mode", icon: "add_circle", items: [
            { keys: "i", description: "Insert before cursor" },
            { keys: "I", description: "Insert at line start" },
            { keys: "a", description: "Insert after cursor" },
            { keys: "A", description: "Insert at line end" },
            { keys: "o", description: "New line below" },
            { keys: "O", description: "New line above" },
            { keys: "s", description: "Delete char and insert" },
            { keys: "S", description: "Delete line and insert" },
            { keys: "C", description: "Delete to line end and insert" },
            { keys: "gi", description: "Insert at last stop" },
        ]},
        { name: "Visual Mode", icon: "highlight", items: [
            { keys: "v", description: "Visual mode" },
            { keys: "V", description: "Visual line mode" },
            { keys: "Ctrl+v", description: "Visual block mode" },
            { keys: "gv", description: "Reselect last visual" },
            { keys: "o", description: "Swap visual ends" },
            { keys: "aw", description: "Around word" },
            { keys: "iw", description: "Inner word" },
            { keys: "aW", description: "Around WORD" },
            { keys: "iW", description: "Inner WORD" },
            { keys: "ab", description: "Around parentheses" },
            { keys: "ib", description: "Inner parentheses" },
            { keys: "a(", description: "Around parentheses" },
            { keys: "i(", description: "Inner parentheses" },
            { keys: "a[", description: "Around brackets" },
            { keys: "i[", description: "Inner brackets" },
            { keys: "a{", description: "Around braces" },
            { keys: "i{", description: "Inner braces" },
            { keys: "a<", description: "Around angle brackets" },
            { keys: "i<", description: "Inner angle brackets" },
            { keys: "a\"", description: "Around double quotes" },
            { keys: "i\"", description: "Inner double quotes" },
            { keys: "a'", description: "Around single quotes" },
            { keys: "i'", description: "Inner single quotes" },
            { keys: "a`", description: "Around backticks" },
            { keys: "i`", description: "Inner backticks" },
            { keys: "ap", description: "Around paragraph" },
            { keys: "ip", description: "Inner paragraph" },
        ]},
        { name: "Operators", icon: "tune", items: [
            { keys: "d", description: "Delete (yank)" },
            { keys: "y", description: "Yank (copy)" },
            { keys: "c", description: "Change" },
            { keys: "p", description: "Paste after" },
            { keys: "P", description: "Paste before" },
            { keys: "x", description: "Delete char" },
            { keys: "X", description: "Delete before cursor" },
            { keys: "r", description: "Replace single char" },
            { keys: "R", description: "Replace mode" },
            { keys: "gu", description: "Lowercase" },
            { keys: "gU", description: "Uppercase" },
            { keys: "g~", description: "Toggle case" },
            { keys: ">", description: "Indent right" },
            { keys: "<", description: "Indent left" },
            { keys: "=", description: "Autoindent" },
            { keys: "gq", description: "Format text" },
            { keys: "J", description: "Join lines" },
            { keys: "gJ", description: "Join lines (no space)" },
            { keys: "~", description: "Toggle case and move" },
        ]},
        { name: "Counts", icon: "pin", items: [
            { keys: "n{op}", description: "Repeat op n times" },
            { keys: "nG", description: "Go to line n" },
            { keys: "ndw", description: "Delete n words" },
            { keys: "nyy", description: "Yank n lines" },
            { keys: "ndd", description: "Delete n lines" },
            { keys: "n>>", description: "Indent n lines" },
        ]},
        { name: "Search", icon: "search", items: [
            { keys: "/", description: "Search forward" },
            { keys: "?", description: "Search backward" },
            { keys: "n", description: "Next result" },
            { keys: "N", description: "Previous result" },
            { keys: "*", description: "Search word under cursor" },
            { keys: "#", description: "Search word backward" },
            { keys: "g*", description: "Search word (partial match)" },
            { keys: "g#", description: "Search word backward (partial)" },
            { keys: ":s/", description: "Substitute" },
            { keys: ":&", description: "Repeat last substitute" },
            { keys: ":~", description: "Substitute last search" },
        ]},
        { name: "Marks", icon: "bookmark", items: [
            { keys: "ma", description: "Set mark a" },
            { keys: "mA", description: "Set mark A (file)" },
            { keys: "'a", description: "Go to mark a (line)" },
            { keys: "`a", description: "Go to mark a (position)" },
            { keys: "''", description: "Go to previous position" },
            { keys: "``", description: "Go to previous position (pos)" },
            { keys: "'.", description: "Go to last change" },
            { keys: "'(", description: "Go to last sentence start" },
            { keys: "'{", description: "Go to last paragraph start" },
            { keys: ":marks", description: "List marks" },
            { keys: ":delm a", description: "Delete mark a" },
        ]},
        { name: "Jumps", icon: "open_in_new", items: [
            { keys: "Ctrl+o", description: "Jump backward" },
            { keys: "Ctrl+i", description: "Jump forward" },
            { keys: "Ctrl+t", description: "Pop tag stack" },
            { keys: "%", description: "Match pair" },
            { keys: "[(", description: "Previous (" },
            { keys: "])", description: "Next )" },
            { keys: "[{", description: "Previous {" },
            { keys: "]}", description: "Next }" },
            { keys: "[m", description: "Previous method start" },
            { keys: "]m", description: "Next method start" },
            { keys: "H", description: "Go to first screen line" },
            { keys: "M", description: "Go to middle screen line" },
            { keys: "L", description: "Go to last screen line" },
        ]},
        { name: "Windows", icon: "view_agenda", items: [
            { keys: "Ctrl+ws", description: "Split horizontal" },
            { keys: "Ctrl+wv", description: "Split vertical" },
            { keys: "Ctrl+ww", description: "Cycle windows" },
            { keys: "Ctrl+wh", description: "Window left" },
            { keys: "Ctrl+wj", description: "Window down" },
            { keys: "Ctrl+wk", description: "Window up" },
            { keys: "Ctrl+wl", description: "Window right" },
            { keys: "Ctrl+w=", description: "Equal size windows" },
            { keys: "Ctrl+w_", description: "Maximize height" },
            { keys: "Ctrl+w|", description: "Maximize width" },
            { keys: "Ctrl+w+", description: "Increase height" },
            { keys: "Ctrl+w-", description: "Decrease height" },
            { keys: "Ctrl+w>", description: "Increase width" },
            { keys: "Ctrl+w<", description: "Decrease width" },
            { keys: "Ctrl+wo", description: "Close other windows" },
        ]},
        { name: "Buffers", icon: "library_books", items: [
            { keys: ":ls", description: "List buffers" },
            { keys: ":bn", description: "Next buffer" },
            { keys: ":bp", description: "Previous buffer" },
            { keys: ":bf", description: "First buffer" },
            { keys: ":bl", description: "Last buffer" },
            { keys: ":b n", description: "Go to buffer n" },
            { keys: ":bd", description: "Delete buffer" },
            { keys: ":bw", description: "Wipe buffer" },
            { keys: ":ball", description: "All buffers" },
            { keys: ":bn!", description: "Force next buffer" },
        ]},
        { name: "Tabs", icon: "tab", items: [
            { keys: "gt", description: "Next tab" },
            { keys: "gT", description: "Previous tab" },
            { keys: "ngt", description: "Go to tab n" },
            { keys: ":tabn", description: "Next tab" },
            { keys: ":tabp", description: "Previous tab" },
            { keys: ":tabfirst", description: "First tab" },
            { keys: ":tabl", description: "Last tab" },
            { keys: ":tabnew", description: "New tab" },
            { keys: ":tabe", description: "Edit in new tab" },
            { keys: ":tabc", description: "Close tab" },
            { keys: ":tabo", description: "Close other tabs" },
            { keys: ":tabdo", description: "Run command in all tabs" },
            { keys: ":tabm n", description: "Move tab to n" },
        ]},
        { name: "Folding", icon: "unfold_more", items: [
            { keys: "zf", description: "Create fold" },
            { keys: "zd", description: "Delete fold" },
            { keys: "zD", description: "Delete all folds" },
            { keys: "zo", description: "Open fold" },
            { keys: "zO", description: "Open all folds" },
            { keys: "zc", description: "Close fold" },
            { keys: "zC", description: "Close all folds" },
            { keys: "za", description: "Toggle fold" },
            { keys: "zA", description: "Toggle all folds" },
            { keys: "zr", description: "Reduce folding" },
            { keys: "zM", description: "Fold everything" },
            { keys: "zv", description: "View cursor line" },
            { keys: "zx", description: "Update folds" },
        ]},
        { name: "Git", icon: "commit", items: [
            { keys: ":Git", description: "Git command" },
            { keys: ":G", description: "Git status" },
            { keys: ":Glog", description: "Git log" },
            { keys: ":Glog --", description: "File history" },
            { keys: ":Gvdiff", description: "Git diff" },
            { keys: ":Gbrowse", description: "Open in browser" },
            { keys: "]c", description: "Next hunk" },
            { keys: "[c", description: "Previous hunk" },
            { keys: "]C", description: "Last hunk" },
            { keys: "[C", description: "First hunk" },
            { keys: "gs", description: "Stage hunk" },
            { keys: "gu", description: "Undo hunk" },
        ]},
        { name: "Misc", icon: "more_horiz", items: [
            { keys: ".", description: "Repeat last command" },
            { keys: "u", description: "Undo" },
            { keys: "Ctrl+r", description: "Redo" },
            { keys: "Ctrl+g", description: "File info" },
            { keys: "g Ctrl+g", description: "Word/char/line count" },
            { keys: "ga", description: "Character info" },
            { keys: "K", description: "Keyword lookup" },
            { keys: "Ctrl+^", description: "Alternate file" },
            { keys: "gUU", description: "Uppercase line" },
            { keys: "gugu", description: "Lowercase line" },
            { keys: "g~~", description: "Toggle case line" },
            { keys: "J", description: "Join with space" },
            { keys: "gJ", description: "Join without space" },
            { keys: "ZZ", description: "Save and quit" },
            { keys: "ZQ", description: "Quit without saving" },
        ]},
        { name: "Command Mode", icon: "terminal", items: [
            { keys: ":", description: "Command mode" },
            { keys: "q:", description: "Command history" },
            { keys: "Ctrl+f", description: "Command history window" },
            { keys: "Ctrl+d", description: "Completion down" },
            { keys: "Ctrl+b", description: "Cursor to start" },
            { keys: "Ctrl+e", description: "Cursor to end" },
            { keys: "Ctrl+w", description: "Delete word" },
            { keys: "Ctrl+u", description: "Delete to start" },
            { keys: "Tab", description: "Complete" },
            { keys: "Shift+Tab", description: "Complete backward" },
        ]},
    ]

    property var keySubstitutions: ({
        "Ctrl": "Ctrl", "Super": "Super", "Shift": "Shift", "Alt": "Alt",
        "Escape": "Esc", "Esc": "Esc", "Return": "Enter", "Tab": "Tab",
        "Space": "Space", "Backspace": "Backspace", "Delete": "Del",
        "Up": "Up", "Down": "Down", "Left": "Left", "Right": "Right",
    })

    readonly property bool isSearching: searchText.trim().length > 0

    readonly property var filteredCategories: {
        if (!isSearching) return categories
        var result = []
        var q = searchText.toLowerCase()
        for (var i = 0; i < categories.length; i++) {
            var cat = categories[i]
            var filtered = []
            for (var j = 0; j < cat.items.length; j++) {
                var item = cat.items[j]
                if (item.keys.toLowerCase().indexOf(q) !== -1 || 
                    item.description.toLowerCase().indexOf(q) !== -1) {
                    filtered.push(item)
                }
            }
            if (filtered.length > 0) {
                result.push({ name: cat.name, icon: cat.icon, items: filtered })
            }
        }
        return result
    }

    readonly property bool hasResults: {
        for (var i = 0; i < filteredCategories.length; i++) {
            if (filteredCategories[i].items.length > 0) return true
        }
        return false
    }

    clip: true
    contentHeight: contentColumn.implicitHeight + 40

    Shortcut {
        sequences: [StandardKey.Find]
        onActivated: searchField.forceActiveFocus()
    }

    ColumnLayout {
        id: contentColumn
        anchors {
            top: parent.top
            left: parent.left
            right: parent.right
            margins: 16
        }
        spacing: 12
        
        RowLayout {
            Layout.fillWidth: true
            spacing: 10
            
            MaterialSymbol {
                text: "code"
                iconSize: Appearance.font.pixelSize.huge
               .colPrimary
            color: Appearance.colors }
            
            StyledText {
                text: Translation.tr("Neovim")
                font.pixelSize: Appearance.font.pixelSize.large
                color: Appearance.colors.colOnLayer1
            }
            
            Item { Layout.fillWidth: true }
            
            ToolbarTextField {
                id: searchField
                Layout.preferredWidth: 250
                implicitHeight: 36
                text: root.searchText
                placeholderText: Translation.tr("Search (Ctrl+F)...")
                onTextChanged: root.searchText = text
                Keys.onEscapePressed: event => {
                    if (text.length > 0) {
                        text = ""
                        event.accepted = true
                    }
                }
            }
            
            RippleButton {
                implicitWidth: 32
                implicitHeight: 32
                buttonRadius: Appearance.rounding.full
                visible: searchField.text.length > 0
                onClicked: searchField.text = ""
                contentItem: MaterialSymbol {
                    anchors.centerIn: parent
                    text: "backspace"
                    iconSize: 18
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 200
            radius: 8
            visible: !root.hasResults && root.searchText.length > 0
            color: Appearance.inirEverywhere ? Appearance.inir.colLayer1 : Appearance.colors.colLayer1

            CheatsheetNoResults {
                anchors.centerIn: parent
                onClearSearchRequested: searchField.text = ""
            }
        }

        Repeater {
            model: root.isSearching ? root.filteredCategories : root.categories

            delegate: Rectangle {
                required property int index
                readonly property var modelData: root.isSearching ? root.filteredCategories[index] : root.categories[index]
                readonly property string catName: modelData?.name ?? ""
                readonly property var catItems: modelData?.items ?? []

                Layout.fillWidth: true
                Layout.preferredHeight: catColumn.implicitHeight + 8
                visible: catItems.length > 0
                radius: Appearance.angelEverywhere ? Appearance.angel.roundingNormal
                     : Appearance.inirEverywhere ? Appearance.inir.roundingNormal : Appearance.rounding.normal
                color: Appearance.angelEverywhere ? Appearance.angel.colGlassCard
                     : Appearance.inirEverywhere ? Appearance.inir.colLayer1
                     : Appearance.auroraEverywhere ? Appearance.aurora.colSubSurface
                     : Appearance.colors.colLayer1
                border.width: Appearance.angelEverywhere ? Appearance.angel.cardBorderWidth
                            : Appearance.inirEverywhere ? 1 : 0
                border.color: Appearance.angelEverywhere ? Appearance.angel.colCardBorder
                            : Appearance.inirEverywhere ? Appearance.inir.colBorder : "transparent"

                Column {
                    id: catColumn
                    anchors {
                        top: parent.top
                        left: parent.left
                        right: parent.right
                        margins: 4
                    }

                    Item {
                        width: parent.width
                        height: 36

                        RowLayout {
                            anchors {
                                fill: parent
                                leftMargin: 12
                                rightMargin: 12
                            }
                            spacing: 8

                            MaterialSymbol {
                                text: modelData.icon
                                iconSize: 18
                                color: Appearance.colors.colPrimary
                            }

                            StyledText {
                                text: catName
                                font.pixelSize: Appearance.font.pixelSize.small
                                font.weight: Font.DemiBold
                                color: Appearance.colors.colPrimary
                            }

                            Item { Layout.fillWidth: true }

                            Rectangle {
                                implicitWidth: countLabel.implicitWidth + 12
                                implicitHeight: 20
                                radius: Appearance.rounding.full
                                color: Appearance.angelEverywhere ? Appearance.angel.colGlassCardHover
                                     : Appearance.inirEverywhere ? Appearance.inir.colLayer2
                                     : Appearance.colors.colLayer2
                                StyledText {
                                    id: countLabel
                                    anchors.centerIn: parent
                                    text: catItems.length
                                    font.pixelSize: Appearance.font.pixelSize.smaller
                                    color: Appearance.colors.colSubtext
                                }
                            }
                        }
                    }

                    Rectangle {
                        width: parent.width - 24
                        anchors.horizontalCenter: parent.horizontalCenter
                        height: 1
                        color: Appearance.angelEverywhere ? Appearance.angel.colCardBorder
                             : Appearance.inirEverywhere ? Appearance.inir.colBorderSubtle
                             : Appearance.colors.colOutlineVariant
                        opacity: 0.4
                    }

                    Repeater {
                        model: catItems

                        delegate: Item {
                            required property var modelData
                            required property int index
                            width: catColumn.width
                            height: 36

                            property bool hovered: hoverArea.containsMouse

                            Rectangle {
                                anchors.fill: rowContent
                                color: hovered
                                    ? (Appearance.angelEverywhere ? Appearance.angel.colGlassCardHover
                                     : Appearance.inirEverywhere ? Appearance.inir.colLayer2Hover
                                     : Appearance.colors.colLayer2Hover)
                                    : "transparent"
                                radius: Appearance.angelEverywhere ? Appearance.angel.roundingSmall
                                      : Appearance.inirEverywhere ? Appearance.inir.roundingSmall
                                      : Appearance.rounding.verysmall
                            }

                            MouseArea {
                                id: hoverArea
                                anchors.fill: rowContent
                                hoverEnabled: true
                                acceptedButtons: Qt.NoButton
                            }

                            RowLayout {
                                id: rowContent
                                width: parent.width
                                height: 36
                                spacing: 16

                                KeyboardKey {
                                    Layout.preferredWidth: 100
                                    Layout.alignment: Qt.AlignVCenter
                                    Layout.leftMargin: 16
                                    key: root.keySubstitutions[modelData.keys] ?? modelData.keys
                                }

                                StyledText {
                                    Layout.fillWidth: true
                                    Layout.alignment: Qt.AlignVCenter
                                    text: modelData.description
                                    color: Appearance.inirEverywhere ? Appearance.inir.colText
                                         : Appearance.colors.colOnLayer1
                                }
                            }

                            Rectangle {
                                anchors {
                                    left: parent.left
                                    right: parent.right
                                    bottom: parent.bottom
                                    leftMargin: 12
                                    rightMargin: 12
                                }
                                height: 1
                                color: Appearance.angelEverywhere ? Appearance.angel.colCardBorder
                                     : Appearance.inirEverywhere ? Appearance.inir.colBorderSubtle
                                     : Appearance.colors.colOutlineVariant
                                opacity: index < catItems.length - 1 ? 0.3 : 0
                            }
                        }
                    }
                }
            }
        }
    }
}
