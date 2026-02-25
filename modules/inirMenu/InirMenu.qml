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
import Quickshell.Wayland
import Quickshell.Hyprland

Scope {
    id: inirMenuScope

    Variants {
        id: inirMenuVariants
        model: Quickshell.screens

        PanelWindow {
            id: root
            required property var modelData

            screen: modelData
            visible: InirMenuService.open

            exclusionMode: ExclusionMode.Ignore

            WlrLayershell.namespace: "quickshell:inirMenu"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: InirMenuService.open
                ? WlrKeyboardFocus.Exclusive
                : WlrKeyboardFocus.None

            // MUST be transparent — same as Overview
            color: "transparent"

            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }

            // Scrim — same pattern as Overview.qml
            Rectangle {
                anchors.fill: parent
                z: -1
                color: {
                    const v = 35
                    const a = v / 100
                    return ColorUtils.transparentize(Appearance.m3colors.m3background, 1 - a)
                }
                opacity: InirMenuService.open ? 1 : 0
                visible: opacity > 0.001
                Behavior on opacity {
                    animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
                }
            }

            // Backdrop click to close — same pattern as Overview.qml
            MouseArea {
                anchors.fill: parent
                onClicked: mouse => {
                    const pos = mapToItem(menuWidget, mouse.x, mouse.y)
                    const inside = pos.x >= 0 && pos.x <= menuWidget.width
                                && pos.y >= 0 && pos.y <= menuWidget.height
                    if (!inside) InirMenuService.open = false
                }
            }

            // Focus grab for Hyprland
            CompositorFocusGrab {
                id: grab
                windows: [root]
                property bool canBeActive: CompositorService.isHyprland
                active: false
                onCleared: {
                    if (!active) InirMenuService.open = false
                }
            }

            Timer {
                id: delayedGrabTimer
                interval: Config.options?.hacks?.arbitraryRaceConditionDelay ?? 150
                repeat: false
                onTriggered: {
                    if (!grab.canBeActive) return
                    grab.active = InirMenuService.open
                }
            }

            // Column — same anchor pattern as Overview.qml
            Column {
                id: columnLayout
                visible: InirMenuService.open
                transformOrigin: Item.Top
                scale: InirMenuService.open ? 1.0 : 0.97
                anchors {
                    horizontalCenter: parent.horizontalCenter
                    top: parent.top
                    bottom: parent.bottom
                    topMargin: {
                        const base = 0
                        const respectBar = true
                        if (respectBar && !(Config.options?.bar?.bottom ?? false)) {
                            return Appearance.sizes.barHeight + Appearance.rounding.screenRounding + base
                        }
                        return base
                    }
                }

                Behavior on scale {
                    animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
                }

                Keys.onPressed: event => {
                    if (event.key === Qt.Key_Escape) {
                        InirMenuService.open = false
                    }
                }

                InirMenuWidget {
                    id: menuWidget
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            }

            Connections {
                target: InirMenuService
                function onOpenChanged() {
                    if (InirMenuService.open) {
                        Qt.callLater(() => menuWidget.focusSearchInput())
                        delayedGrabTimer.start()
                    } else {
                        menuWidget.cancelSearch()
                        grab.active = false
                    }
                }
            }
        }
    }

    IpcHandler {
        target: "inirMenu"
        function toggle(): void { InirMenuService.open = !InirMenuService.open }
        function open(): void   { InirMenuService.open = true }
        function close(): void  { InirMenuService.open = false }
    }
}
