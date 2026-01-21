pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Services.Mpris
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.modules.common.models
import qs.services
import "root:"

Item {
    id: root
    signal closeRequested()

    readonly property MprisPlayer activePlayer: MprisController.activePlayer
    readonly property real widgetWidth: Appearance.sizes.mediaControlsWidth
    readonly property real widgetHeight: Appearance.sizes.mediaControlsHeight
    property real popupRounding: Appearance.rounding.normal
    
    // Debounce timer to prevent "No active player" flicker during track changes
    property bool _showPlaceholder: false
    Timer {
        id: placeholderDebounce
        interval: 800
        onTriggered: root._showPlaceholder = (root.displayPlayers.length === 0)
    }
    
    // Simple: filter YtMusic mpv players when YtMusic is active
    readonly property var displayPlayers: {
        const players = MprisController.players;
        if (!MprisController.isYtMusicActive || !YtMusic.currentVideoId) {
            return players; // No filtering needed
        }
        // Filter out ALL mpv players playing YouTube content
        return players.filter(p => !_isYtMusicMpv(p));
    }
    
    onDisplayPlayersChanged: {
        if (displayPlayers.length > 0) {
            root._showPlaceholder = false;
            placeholderDebounce.stop();
        } else {
            // Start debounce - only show placeholder after delay
            placeholderDebounce.restart();
        }
    }

    function _isYtMusicMpv(player) {
        if (!player) return false;
        // Direct reference check
        if (YtMusic.mpvPlayer && player === YtMusic.mpvPlayer) return true;
        // Identity check
        const id = (player.identity ?? "").toLowerCase();
        const entry = (player.desktopEntry ?? "").toLowerCase();
        const isMpv = id === "mpv" || id.includes("mpv") || entry === "mpv" || entry.includes("mpv");
        if (!isMpv) return false;
        // URL check for YouTube content
        const trackUrl = player.metadata?.["xesam:url"] ?? "";
        if (trackUrl.includes("youtube.com") || trackUrl.includes("youtu.be")) return true;
        // Title match with current YtMusic track
        if (YtMusic.currentTitle && player.trackTitle) {
            const ytTitle = YtMusic.currentTitle.toLowerCase();
            const playerTitle = player.trackTitle.toLowerCase();
            if (ytTitle.includes(playerTitle) || playerTitle.includes(ytTitle)) return true;
        }
        return false;
    }

    implicitWidth: widgetWidth
    implicitHeight: playerColumn.implicitHeight

    ColumnLayout {
        id: playerColumn
        anchors.fill: parent
        spacing: 8

        Repeater {
            model: ScriptModel {
                values: root.displayPlayers
            }
            delegate: Item {
                required property MprisPlayer modelData
                required property int index
                Layout.fillWidth: true
                implicitWidth: root.widgetWidth
                implicitHeight: root.widgetHeight + (isActive && root.displayPlayers.length > 1 ? 4 : 0)
                
                readonly property bool isActive: modelData === MprisController.trackedPlayer
                
                Rectangle {
                    visible: root.displayPlayers.length > 1
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    anchors.margins: Appearance.sizes.elevationMargin
                    width: 3
                    radius: 2
                    color: isActive 
                        ? ((Appearance.inirEverywhere && Appearance.inir) ? Appearance.inir.colPrimary : Appearance.colors.colPrimary)
                        : ((Appearance.inirEverywhere && Appearance.inir) ? Appearance.inir.colLayer2 : Appearance.colors.colLayer2)
                    
                    Behavior on color {
                        enabled: Appearance.animationsEnabled
                        ColorAnimation { duration: 150 }
                    }
                }
                
                PlayerControl {
                    anchors.fill: parent
                    anchors.leftMargin: root.displayPlayers.length > 1 ? 6 : 0
                    player: modelData
                    visualizerPoints: []
                    radius: root.popupRounding
                }
                
                MouseArea {
                    anchors.fill: parent
                    visible: !isActive && root.displayPlayers.length > 1
                    onClicked: MprisController.setActivePlayer(modelData)
                    cursorShape: Qt.PointingHandCursor
                    z: -1
                }
            }
        }

        // No player placeholder - only show after debounce to prevent flicker
        Item {
            id: placeholderItem
            visible: root._showPlaceholder && root.displayPlayers.length === 0
            Layout.fillWidth: true
            implicitWidth: placeholderBackground.implicitWidth + Appearance.sizes.elevationMargin
            implicitHeight: placeholderBackground.implicitHeight + Appearance.sizes.elevationMargin

            StyledRectangularShadow {
                target: placeholderBackground
            }

            Rectangle {
                id: placeholderBackground
                anchors.centerIn: parent
                color: (Appearance.inirEverywhere && Appearance.inir) ? Appearance.inir.colLayer1
                : (Appearance.auroraEverywhere && Appearance.aurora) ? Appearance.aurora.colPopupSurface
                     : Appearance.colors.colLayer0
                radius: (Appearance.inirEverywhere && Appearance.inir) ? Appearance.inir.roundingNormal : root.popupRounding
                border.width: (Appearance.inirEverywhere || Appearance.auroraEverywhere) ? 1 : 0
                border.color: (Appearance.inirEverywhere && Appearance.inir) ? Appearance.inir.colBorder
                            : (Appearance.auroraEverywhere && Appearance.aurora) ? Appearance.aurora.colPopupBorder
                            : "transparent"
                property real padding: 20
                implicitWidth: placeholderLayout.implicitWidth + padding * 2
                implicitHeight: placeholderLayout.implicitHeight + padding * 2

                ColumnLayout {
                    id: placeholderLayout
                    anchors.centerIn: parent

                    StyledText {
                        text: Translation.tr("No active player")
                        font.pixelSize: Appearance.font.pixelSize.large
                        color: (Appearance.inirEverywhere && Appearance.inir) ? Appearance.inir.colText
                            : (Appearance.auroraEverywhere && Appearance.aurora) ? Appearance.colors.colOnLayer0
                            : Appearance.colors.colOnLayer0
                    }
                    StyledText {
                        color: (Appearance.inirEverywhere && Appearance.inir) ? Appearance.inir.colTextSecondary
                            : (Appearance.auroraEverywhere && Appearance.aurora) ? Appearance.aurora.colTextSecondary
                            : Appearance.colors.colSubtext
                        text: Translation.tr("Make sure your player has MPRIS support\nor try turning off duplicate player filtering")
                        font.pixelSize: Appearance.font.pixelSize.small
                    }
                }
            }
        }
    }
}
