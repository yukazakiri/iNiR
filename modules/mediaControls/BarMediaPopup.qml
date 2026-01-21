pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Services.Mpris
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.services
import "root:"

// Simplified BarMediaPopup - uses activePlayer directly like MediaPlayerWidget
// No complex Repeater/filtering that causes flicker during track transitions
Item {
    id: root
    signal closeRequested()

    readonly property MprisPlayer player: MprisController.activePlayer
    readonly property bool isYtMusicPlayer: MprisController.isYtMusicActive
    // hasPlayer: true if we have any valid player (like MediaPlayerWidget)
    readonly property bool hasPlayer: (player !== null) || isYtMusicPlayer
    
    readonly property real widgetWidth: Appearance.sizes.mediaControlsWidth
    readonly property real widgetHeight: Appearance.sizes.mediaControlsHeight
    property real popupRounding: Appearance.rounding.normal

    implicitWidth: widgetWidth
    implicitHeight: widgetHeight

    // Single PlayerControl - always visible when popup is open
    // The popup itself is only loaded when barMediaPopupVisible is true
    // so we don't need additional visibility logic here
    PlayerControl {
        id: playerControl
        anchors.fill: parent
        player: root.player
        visualizerPoints: []
        radius: root.popupRounding
    }
}
