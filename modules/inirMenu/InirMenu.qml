import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland

// ============================================================================
// InirMenu — Global launcher panel
// Triggered by Ctrl+Super+Space via IPC target "inirMenu"
// ============================================================================

Scope {
    id: inirMenuScope

    Variants {
        model: Quickshell.screens
        PanelWindow {
            id: panelRoot
            required property var modelData

            screen: modelData
            visible: InirMenuService.open

            exclusiveZone: 0
            implicitWidth:  screen?.width  ?? 1920
            implicitHeight: screen?.height ?? 1080

            WlrLayershell.namespace:     "quickshell:inirMenu"
            WlrLayershell.layer:         WlrLayer.Overlay
            WlrLayershell.keyboardFocus: InirMenuService.open
                                            ? WlrKeyboardFocus.Exclusive
                                            : WlrKeyboardFocus.None
            color: "transparent"

            anchors { top: true; bottom: true; left: true; right: true }

            // ── Hyprland focus grab ─────────────────────────────────────────
            CompositorFocusGrab {
                id: grab
                windows: [panelRoot]
                active: CompositorService.isHyprland && panelRoot.visible
                onCleared: { if (!active) InirMenuService.open = false }
            }

            // ── Scrim ───────────────────────────────────────────────────────
            Rectangle {
                anchors.fill: parent
                z: 0
                color: ColorUtils.transparentize(Appearance.m3colors.m3background, 0.6)
                opacity: InirMenuService.open ? 1 : 0
                visible: opacity > 0.001
                Behavior on opacity {
                    animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
                }
            }

            // ── Backdrop click to dismiss ───────────────────────────────────
            MouseArea {
                anchors.fill: parent
                z: 1
                onClicked: mouse => {
                    const local = mapToItem(contentLoader, mouse.x, mouse.y)
                    const inside = local.x >= 0 && local.x <= contentLoader.width
                                && local.y >= 0 && local.y <= contentLoader.height
                    if (!inside) InirMenuService.open = false
                }
            }

            // ── Content panel ───────────────────────────────────────────────
            Loader {
                id: contentLoader
                z: 2
                active: InirMenuService.open

                anchors {
                    horizontalCenter: parent.horizontalCenter
                    verticalCenter:   parent.verticalCenter
                    verticalCenterOffset: Config.options?.bar?.bottom
                        ? -(Appearance.sizes.baseBarHeight / 2)
                        :  (Appearance.sizes.baseBarHeight / 2)
                }

                // Animate open/close
                opacity: InirMenuService.open ? 1 : 0
                scale:   InirMenuService.open ? 1 : 0.94
                transform: Translate {
                    y: InirMenuService.open ? 0 : -24
                    Behavior on y {
                        enabled: Appearance.animationsEnabled
                        NumberAnimation { duration: 250; easing.type: Easing.OutQuart }
                    }
                }
                Behavior on opacity {
                    enabled: Appearance.animationsEnabled
                    NumberAnimation { duration: 180; easing.type: Easing.OutQuart }
                }
                Behavior on scale {
                    enabled: Appearance.animationsEnabled
                    NumberAnimation { duration: 250; easing.type: Easing.OutQuart }
                }

                sourceComponent: InirMenuContent {
                    // Close on Escape
                    Keys.onPressed: event => {
                        if (event.key === Qt.Key_Escape) InirMenuService.open = false
                    }
                }
            }

            // ── Global Escape key ───────────────────────────────────────────
            Keys.onPressed: event => {
                if (event.key === Qt.Key_Escape) InirMenuService.open = false
            }
        }
    }

    // Reset query when menu closes
    Connections {
        target: InirMenuService
        function onOpenChanged() {
            if (!InirMenuService.open) {
                InirMenuService.query = ""
            }
        }
    }
}
