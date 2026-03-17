pragma ComponentBehavior: Bound

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
        { name: "Movement", icon: "open_with", keybinds: movementKeybinds },
        { name: "Insert Mode", icon: "edit", keybinds: insertKeybinds },
        { name: "Visual Mode", icon: "highlight", keybinds: visualKeybinds },
        { name: "Text Objects", icon: "text_fields", keybinds: textobjKeybinds },
        { name: "Window Management", icon: "view_quilt", keybinds: windowKeybinds },
        { name: "Tabs", icon: "tab", keybinds: tabKeybinds },
        { name: "Search & Find", icon: "search", keybinds: searchKeybinds },
        { name: " LSP ", icon: "code", keybinds: lspKeybinds },
        { name: "Telescope", icon: "zoom_in", keybinds: telescopeKeybinds },
        { name: "Git", icon: "commit", keybinds: gitKeybinds },
        { name: "Misc", icon: "more_horiz", keybinds: miscKeybinds },
    ]

    readonly property var movementKeybinds: [
        { key: "h", mods: [], comment: "Left" },
        { key: "j", mods: [], comment: "Down" },
        { key: "k", mods: [], comment: "Up" },
        { key: "l", mods: [], comment: "Right" },
        { key: "w", mods: [], comment: "Word forward" },
        { key: "b", mods: [], comment: "Word backward" },
        { key: "e", mods: [], comment: "Word end" },
        { key: "0", mods: [], comment: "Line start" },
        { key: "^", mods: [], comment: "Line start (non-blank)" },
        { key: "$", mods: [], comment: "Line end" },
        { key: "gg", mods: [], comment: "File start" },
        { key: "G", mods: [], comment: "File end" },
        { key: "n", mods: [], comment: "Next search match" },
        { key: "N", mods: [], comment: "Previous search match" },
        { key: "%", mods: [], comment: "Matching bracket" },
    ]

    readonly property var insertKeybinds: [
        { key: "i", mods: [], comment: "Insert before cursor" },
        { key: "I", mods: [], comment: "Insert at line start" },
        { key: "a", mods: [], comment: "Insert after cursor" },
        { key: "A", mods: [], comment: "Insert at line end" },
        { key: "o", mods: [], comment: "New line below" },
        { key: "O", mods: [], comment: "New line above" },
        { key: "s", mods: [], comment: "Substitute character" },
        { key: "S", mods: [], comment: "Substitute line" },
        { key: "c", mods: ["c"], comment: "Change line" },
        { key: "C", mods: [], comment: "Change to EOL" },
        { key: "r", mods: [], comment: "Replace single char" },
        { key: "R", mods: [], comment: "Replace mode" },
    ]

    readonly property var visualKeybinds: [
        { key: "v", mods: [], comment: "Visual mode" },
        { key: "V", mods: [], comment: "Visual line mode" },
        { key: "Ctrl+v", mods: [], comment: "Visual block mode" },
        { key: "y", mods: [], comment: "Yank (copy)" },
        { key: "d", mods: [], comment: "Delete (cut)" },
        { key: "c", mods: [], comment: "Change (delete + insert)" },
        { key: "gu", mods: [], comment: "Lowercase" },
        { key: "gU", mods: [], comment: "Uppercase" },
        { key: "g~", mods: [], comment: "Toggle case" },
        { key: "<", mods: [], comment: "Indent left" },
        { key: ">", mods: [], comment: "Indent right" },
        { key: "J", mods: [], comment: "Join lines" },
    ]

    readonly property var textobjKeybinds: [
        { key: "iw", mods: [], comment: "Inner word" },
        { key: "aw", mods: [], comment: "A word" },
        { key: "iW", mods: [], comment: "Inner WORD" },
        { key: "aW", mods: [], comment: "A WORD" },
        { key: "is", mods: [], comment: "Inner sentence" },
        { key: "as", mods: [], comment: "A sentence" },
        { key: "ip", mods: [], comment: "Inner paragraph" },
        { key: "ap", mods: [], comment: "A paragraph" },
        { key: "i)", mods: [], comment: "Inner parens ()" },
        { key: "a)", mods: [], comment: "A parens ()" },
        { key: "i]", mods: [], comment: "Inner brackets []" },
        { key: "a]", mods: [], comment: "A brackets []" },
        { key: "i}", mods: [], comment: "Inner braces {}" },
        { key: "a}", mods: [], comment: "A braces {}" },
        { key: "i\"", mods: [], comment: "Inner quotes \"\"" },
        { key: "a\"", mods: [], comment: "A quotes \"\"" },
        { key: "i'", mods: [], comment: "Inner quotes ''" },
        { key: "a'", mods: [], comment: "A quotes ''" },
        { key: "i`", mods: [], comment: "Inner backtick" },
        { key: "a`", mods: [], comment: "A backtick" },
        { key: "ib", mods: [], comment: "Inner parentheses" },
        { key: "ab", mods: [], comment: "A block" },
    ]

    readonly property var windowKeybinds: [
        { key: "sv", mods: ["Leader"], comment: "Split vertical" },
        { key: "sh", mods: ["Leader"], comment: "Split horizontal" },
        { key: "so", mods: ["Leader"], comment: "Close other splits" },
        { key: "s=", mods: ["Leader"], comment: "Equalize splits" },
        { key: "sj", mods: ["Leader"], comment: "Move split down" },
        { key: "sk", mods: ["Leader"], comment: "Move split up" },
        { key: "sl", mods: ["Leader"], comment: "Move split right" },
        { key: "sh", mods: ["Leader"], comment: "Move split left" },
        { key: "Ctrl+h", mods: [], comment: "Navigate left" },
        { key: "Ctrl+j", mods: [], comment: "Navigate down" },
        { key: "Ctrl+k", mods: [], comment: "Navigate up" },
        { key: "Ctrl+l", mods: [], comment: "Navigate right" },
        { key: "Ctrl+Arrow", mods: [], comment: "Resize split" },
    ]

    readonly property var tabKeybinds: [
        { key: "tn", mods: ["Leader"], comment: "New tab" },
        { key: "tc", mods: ["Leader"], comment: "Close tab" },
        { key: "to", mods: ["Leader"], comment: "Close other tabs" },
        { key: "tp", mods: ["Leader"], comment: "Previous tab" },
        { key: "tn", mods: ["Leader"], comment: "Next tab" },
        { key: "1-9", mods: ["Leader"], comment: "Go to tab 1-9" },
    ]

    readonly property var searchKeybinds: [
        { key: "/", mods: [], comment: "Search forward" },
        { key: "?", mods: [], comment: "Search backward" },
        { key: "*", mods: [], comment: "Search word under cursor" },
        { key: "#", mods: [], comment: "Search word backward" },
        { key: "gn", mods: [], comment: "Next search match" },
        { key: "gN", mods: [], comment: "Previous search match" },
    ]

    readonly property var lspKeybinds: [
        { key: "gd", mods: ["Leader"], comment: "Go to definition" },
        { key: "gD", mods: ["Leader"], comment: "Go to declaration" },
        { key: "gi", mods: ["Leader"], comment: "Go to implementation" },
        { key: "gr", mods: ["Leader"], comment: "References" },
        { key: "K", mods: [], comment: "Hover info" },
        { key: "Ctrl+p", mods: ["Leader"], comment: "Signature help" },
        { key: "rn", mods: ["Leader"], comment: "Rename" },
        { key: "ca", mods: ["Leader"], comment: "Code action" },
        { key: "e", mods: ["Leader"], comment: "Line diagnostics" },
        { key: "]d", mods: ["Leader"], comment: "Next diagnostic" },
        { key: "[d", mods: ["Leader"], comment: "Previous diagnostic" },
    ]

    readonly property var telescopeKeybinds: [
        { key: "ff", mods: ["Leader"], comment: "Find files" },
        { key: "fg", mods: ["Leader"], comment: "Live grep" },
        { key: "fb", mods: ["Leader"], comment: "Buffers" },
        { key: "fh", mods: ["Leader"], comment: "Help tags" },
        { key: "fr", mods: ["Leader"], comment: "Recent files" },
        { key: "fc", mods: ["Leader"], comment: "Find config" },
        { key: "ft", mods: ["Leader"], comment: "Find todo" },
        { key: "fw", mods: ["Leader"], comment: "Greap word" },
        { key: "f/", mods: ["Leader"], comment: "Search in buffer" },
    ]

    readonly property var gitKeybinds: [
        { key: "gs", mods: ["Leader"], comment: "Git status" },
        { key: "gc", mods: ["Leader"], comment: "Git commit" },
        { key: "gp", mods: ["Leader"], comment: "Git push" },
        { key: "gb", mods: ["Leader"], comment: "Git blame" },
        { key: "gl", mods: ["Leader"], comment: "Git log" },
        { key: "gd", mods: ["Leader"], comment: "Git diff" },
        { key: "]c", mods: ["Leader"], comment: "Next hunk" },
        { key: "[c", mods: ["Leader"], comment: "Previous hunk" },
        { key: "ha", mods: ["Leader"], comment: "Hunk actions" },
    ]

    readonly property var miscKeybinds: [
        { key: ".", mods: ["Leader"], comment: "Repeat last action" },
        { key: "u", mods: [], comment: "Undo" },
        { key: "Ctrl+r", mods: [], comment: "Redo" },
        { key: "p", mods: [], comment: "Paste after" },
        { key: "P", mods: [], comment: "Paste before" },
        { key: "x", mods: [], comment: "Delete char" },
        { key: "X", mods: [], comment: "Delete char before" },
        { key: "dd", mods: [], comment: "Delete line" },
        { key: "yy", mods: [], comment: "Yank line" },
        { key: "zz", mods: [], comment: "Center screen" },
        { key: "zt", mods: [], comment: "Top screen" },
        { key: "zb", mods: [], comment: "Bottom screen" },
        { key: "Ctrl+^", mods: [], comment: "Alternate file" },
    ]

    readonly property bool isSearching: searchText.trim().length > 0

    readonly property var filteredCategories: {
        if (!isSearching) return categories
        const q = searchText.toLowerCase().trim()
        return categories.map(cat => {
            const filtered = cat.keybinds.filter(kb =>
                kb.key?.toLowerCase().includes(q) ||
                kb.comment?.toLowerCase().includes(q)
            )
            return { ...cat, keybinds: filtered }
        }).filter(cat => cat.keybinds.length > 0)
    }
    
    readonly property bool hasResults: filteredCategories.some(c => c.keybinds.length > 0)

    property var keyBlacklist: []
    property var keySubstitutions: ({
        "Super": "󰖳", "Return": "Enter", "Space": "SPC",
        "Ctrl": "C", "Alt": "A", "Shift": "S", "Leader": "L",
    })

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
                color: Appearance.colors.colPrimary
            }
            
            StyledText {
                text: Translation.tr("Neovim / LazyVim")
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
            visible: !root.hasResults && root.searchText.length > 0

            CheatsheetNoResults {
                anchors.centerIn: parent
                onClearSearchRequested: searchField.text = ""
            }
        }

        Repeater {
            model: root.filteredCategories

            delegate: Rectangle {
                id: catCard
                required property int index
                readonly property var catData: root.filteredCategories[index]
                readonly property string catName: catData?.name ?? ""
                readonly property string catIcon: catData?.icon ?? "keyboard"
                readonly property var catKeybinds: catData?.keybinds ?? []

                Layout.fillWidth: true
                Layout.preferredHeight: catColumn.implicitHeight + 8
                visible: catKeybinds.length > 0
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
                                text: catCard.catIcon
                                iconSize: 18
                                color: Appearance.colors.colPrimary
                            }

                            StyledText {
                                text: catCard.catName
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
                                    text: catCard.catKeybinds.length
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
                        model: catCard.catKeybinds

                        delegate: CheatsheetKeybindRow {
                            required property var modelData
                            required property int index
                            width: catColumn.width
                            keybindData: Object.assign({category: ""}, modelData)
                            keyBlacklist: root.keyBlacklist
                            keySubstitutions: root.keySubstitutions
                            showDivider: index < catCard.catKeybinds.length - 1
                        }
                    }
                }
            }
        }
    }
}
