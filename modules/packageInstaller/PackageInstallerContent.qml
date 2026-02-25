import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick
import QtQuick.Controls
import Quickshell

MouseArea {
    id: root

    Component.onCompleted: {
        console.log("[PackageInstallerContent] Content loaded");
    }

    // State management
    enum ViewState {
        Categories,
        Packages
    }

    property int currentState: PackageInstallerContent.ViewState.Categories
    property var selectedCategory: null
    property string searchQuery: ""

    onCurrentStateChanged: {
        console.log(`[PackageInstallerContent] State changed to:`, currentState === PackageInstallerContent.ViewState.Categories ? "Categories" : "Packages");
    }

    onSelectedCategoryChanged: {
        console.log(`[PackageInstallerContent] Selected category changed:`, selectedCategory?.name ?? "null");
    }

    onSearchQueryChanged: {
        console.log(`[PackageInstallerContent] Search query changed to:`, searchQuery);
    }

    // Get packages from selected category, filtered by search
    readonly property var filteredPackages: {
        if (!selectedCategory)
            return [];
        if (!searchQuery)
            return selectedCategory.packages;
        return selectedCategory.packages.filter(pkg => pkg.name.toLowerCase().includes(searchQuery.toLowerCase()) || pkg.description.toLowerCase().includes(searchQuery.toLowerCase()));
    }

    // Get categories filtered by search
    readonly property var filteredCategories: {
        if (!searchQuery)
            return root.parent.categories;
        return root.parent.categories.filter(cat => cat.name.toLowerCase().includes(searchQuery.toLowerCase()) || cat.description.toLowerCase().includes(searchQuery.toLowerCase()));
    }

    function selectCategory(category) {
        console.log(`[PackageInstallerContent] selectCategory called with:`, category?.name);
        selectedCategory = category;
        currentState = PackageInstallerContent.ViewState.Packages;
        searchQuery = "";
    }

    function goBack() {
        selectedCategory = null;
        currentState = PackageInstallerContent.ViewState.Categories;
        searchQuery = "";
    }

    function handlePackageClick(packageItem) {
        console.log(`[PackageInstallerContent] handlePackageClick called with:`, packageItem?.name);
        const isAur = selectedCategory?.aur ?? false;
        root.parent.installPackage(packageItem.name, isAur);
    }

    StyledRectangularShadow {
        anchors.fill: parent
        radius: 16

        GlassBackground {
            id: glassBg
            anchors.fill: parent
            radius: 16
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 24
            spacing: 16

            // Header
            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                // Back button (only visible in packages view)
                IconToolbarButton {
                    visible: currentState === PackageInstallerContent.ViewState.Packages
                    icon.name: "arrow_back"
                    onClicked: root.goBack()
                }

                // Title and description
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4

                    StyledText {
                        text: currentState === PackageInstallerContent.ViewState.Categories ? "Package Categories" : selectedCategory?.name ?? ""
                        font.pixelSize: 24
                        font.bold: true
                    }

                    StyledText {
                        text: currentState === PackageInstallerContent.ViewState.Categories ? "Select a category to browse packages" : selectedCategory?.description ?? ""
                        font.pixelSize: 14
                        color: Appearance.m3colors.onSurfaceVariant
                    }
                }

                // Search field
                ToolbarTextField {
                    id: searchField
                    Layout.preferredWidth: 300
                    placeholderText: currentState === PackageInstallerContent.ViewState.Categories ? "Search categories..." : "Search packages..."
                    onTextChanged: {
                        searchQuery = text;
                    }
                }
            }

            // Content area
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                // Categories Grid
                GridView {
                    id: categoriesGrid
                    anchors.fill: parent
                    visible: currentState === PackageInstallerContent.ViewState.Categories
                    model: filteredCategories
                    cellWidth: 240
                    cellHeight: 180
                    clip: true

                    delegate: Rectangle {
                        width: categoriesGrid.cellWidth - 8
                        height: categoriesGrid.cellHeight - 8
                        radius: 12
                        color: catMouseArea.containsMouse ? Appearance.m3colors.surfaceContainerHigh : Appearance.m3colors.surfaceContainer
                        border.color: Appearance.m3colors.outlineVariant
                        border.width: 1

                        Behavior on color {
                            animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
                        }

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 16
                            spacing: 12

                            MaterialSymbol {
                                Layout.alignment: Qt.AlignHCenter
                                name: modelData?.icon ?? "category"
                                size: 48
                                color: Appearance.m3colors.primary
                            }

                            StyledText {
                                Layout.alignment: Qt.AlignHCenter
                                Layout.fillWidth: true
                                text: modelData?.name ?? ""
                                font.pixelSize: 16
                                font.bold: true
                                horizontalAlignment: Text.AlignHCenter
                                wrapMode: Text.WordWrap
                            }

                            StyledText {
                                Layout.alignment: Qt.AlignHCenter
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                text: modelData?.description ?? ""
                                font.pixelSize: 12
                                color: Appearance.m3colors.onSurfaceVariant
                                horizontalAlignment: Text.AlignHCenter
                                wrapMode: Text.WordWrap
                            }

                            Rectangle {
                                Layout.alignment: Qt.AlignHCenter
                                Layout.preferredHeight: 32
                                Layout.preferredWidth: Math.min(width, parent.width - 32)
                                implicitWidth: browseText.width + 16
                                radius: 8
                                color: Appearance.m3colors.primary
                                opacity: catMouseArea.containsMouse ? 1.0 : 0.8

                                StyledText {
                                    id: browseText
                                    anchors.centerIn: parent
                                    text: "Browse"
                                    font.pixelSize: 13
                                    color: Appearance.m3colors.onPrimary
                                }

                                Behavior on opacity {
                                    animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
                                }
                            }
                        }

                        MouseArea {
                            id: catMouseArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.selectCategory(modelData)
                        }
                    }

                    ScrollBar.vertical: StyledScrollBar {
                        policy: ScrollBar.AsNeeded
                    }
                }

                // Packages List
                ListView {
                    id: packagesList
                    anchors.fill: parent
                    visible: currentState === PackageInstallerContent.ViewState.Packages
                    model: filteredPackages
                    spacing: 8
                    clip: true

                    delegate: Rectangle {
                        width: ListView.view ? ListView.view.width - 8 : parent.width - 8
                        height: 72
                        radius: 8
                        color: pkgMouseArea.containsMouse ? Appearance.m3colors.surfaceContainerHigh : Appearance.m3colors.surfaceContainer
                        border.color: Appearance.m3colors.outlineVariant
                        border.width: 1

                        Behavior on color {
                            animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
                        }

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 12
                            spacing: 16

                            // Package icon
                            Rectangle {
                                Layout.preferredWidth: 40
                                Layout.preferredHeight: 40
                                radius: 8
                                color: (selectedCategory?.aur ?? false) ? Appearance.m3colors.tertiaryContainer : Appearance.m3colors.primaryContainer

                                MaterialSymbol {
                                    anchors.centerIn: parent
                                    name: "extension"
                                    size: 24
                                    color: (selectedCategory?.aur ?? false) ? Appearance.m3colors.onTertiaryContainer : Appearance.m3colors.onPrimaryContainer
                                }
                            }

                            // Package info
                            ColumnLayout {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                spacing: 4

                                RowLayout {
                                    spacing: 8

                                    StyledText {
                                        Layout.fillWidth: true
                                        text: modelData?.name ?? ""
                                        font.pixelSize: 15
                                        font.bold: true
                                    }

                                    // AUR badge
                                    Rectangle {
                                        visible: (selectedCategory?.aur ?? false)
                                        Layout.preferredHeight: 20
                                        implicitWidth: aurText.width + 12
                                        radius: 4
                                        color: Appearance.m3colors.tertiaryContainer

                                        StyledText {
                                            id: aurText
                                            anchors.centerIn: parent
                                            text: "AUR"
                                            font.pixelSize: 10
                                            font.bold: true
                                            color: Appearance.m3colors.onTertiaryContainer
                                        }
                                    }
                                }

                                StyledText {
                                    Layout.fillWidth: true
                                    text: modelData?.description ?? ""
                                    font.pixelSize: 12
                                    color: Appearance.m3colors.onSurfaceVariant
                                    elide: Text.ElideRight
                                }
                            }

                            // Install button
                            Rectangle {
                                Layout.preferredHeight: 36
                                Layout.preferredWidth: installText.width + 24
                                radius: 8
                                color: Appearance.m3colors.primary
                                opacity: pkgMouseArea.containsMouse ? 1.0 : 0.8

                                StyledText {
                                    id: installText
                                    anchors.centerIn: parent
                                    text: "Install"
                                    font.pixelSize: 13
                                    color: Appearance.m3colors.onPrimary
                                }

                                Behavior on opacity {
                                    animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
                                }
                            }
                        }

                        MouseArea {
                            id: pkgMouseArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.handlePackageClick(modelData)
                        }
                    }

                    ScrollBar.vertical: StyledScrollBar {
                        policy: ScrollBar.AsNeeded
                    }
                }

                // Empty state
                ColumnLayout {
                    anchors.centerIn: parent
                    visible: (currentState === PackageInstallerContent.ViewState.Categories && filteredCategories.length === 0) || (currentState === PackageInstallerContent.ViewState.Packages && filteredPackages.length === 0)
                    spacing: 16

                    MaterialSymbol {
                        Layout.alignment: Qt.AlignHCenter
                        name: "search_off"
                        size: 64
                        color: Appearance.m3colors.onSurfaceVariant
                    }

                    StyledText {
                        Layout.alignment: Qt.AlignHCenter
                        text: currentState === PackageInstallerContent.ViewState.Categories ? "No categories found" : "No packages found"
                        font.pixelSize: 18
                        color: Appearance.m3colors.onSurfaceVariant
                    }

                    StyledText {
                        Layout.alignment: Qt.AlignHCenter
                        text: "Try a different search term"
                        font.pixelSize: 14
                        color: Appearance.m3colors.onSurfaceVariant
                    }
                }
            }
        }
    }
}
