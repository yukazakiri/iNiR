pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects

import qs.modules.common

Item {
    id: root

    // ── Public API ──────────────────────────────────────────────────────
    property string source
    property int fillMode: Image.PreserveAspectCrop
    property size sourceSize

    // Transition config — read from Config with sensible defaults
    property int transitionDuration: Config.options?.background?.transition?.duration ?? 800
    property string transitionType: Config.options?.background?.transition?.type ?? "crossfade"
    property bool enableTransitions: Config.options?.background?.transition?.enable ?? true

    // Read-only state — `ready` stays true during transitions so that
    // external consumers (blur layers, visibility guards) don't flicker.
    readonly property bool ready: img0.status === Image.Ready || img1.status === Image.Ready
    readonly property alias activeIndex: internal.activeIndex

    // ── Internal state ─────────────────────────────────────────────────
    property bool _transitioning: false

    // Helpers
    readonly property bool _canTransition: enableTransitions && Appearance.animationsEnabled
    readonly property string _effectiveType: _canTransition ? transitionType : "none"

    // Per-type easing for a polished feel
    readonly property int _easingType: {
        switch (_effectiveType) {
        case "slide":    return Easing.OutCubic      // decelerating slide-in
        case "zoom":     return Easing.OutQuart      // cinematic slow-stop
        case "blurFade": return Easing.InOutQuad     // gentle symmetric blur
        default:         return Easing.InOutCubic    // crossfade default
        }
    }

    // Zoom: entering image starts slightly scaled up → settles to 1.0
    readonly property real _zoomFrom: 1.04

    QtObject {
        id: internal
        property int activeIndex: 0
        property string lastSource: ""

        function switchTo(newSource) {
            if (newSource === lastSource) return
            if (newSource === "") {
                img0.source = ""
                img1.source = ""
                lastSource = ""
                return
            }

            lastSource = newSource

            // Instant swap when transitions disabled
            if (!root._canTransition) {
                const active = (activeIndex === 0) ? img0 : img1
                active.source = newSource
                return
            }

            // Load into the inactive slot
            const inactive = (activeIndex === 0) ? img1 : img0

            if (inactive.source == newSource && inactive.status === Image.Ready) {
                performSwitch()
            } else {
                inactive.source = newSource
            }
        }

        function performSwitch() {
            root._transitioning = true
            transitionEndTimer.restart()
            activeIndex = (activeIndex === 0) ? 1 : 0
        }
    }

    Timer {
        id: transitionEndTimer
        interval: root.transitionDuration + 100
        repeat: false
        onTriggered: root._transitioning = false
    }

    onSourceChanged: internal.switchTo(source)

    clip: true

    // ── Shared helpers ──────────────────────────────────────────────────
    // Each image slot uses identical logic — these functions avoid duplication.
    function _opacityFor(isActive) {
        if (_effectiveType === "slide") return 1
        return isActive ? 1 : 0
    }

    function _xFor(isActive, outDir) {
        if (_effectiveType !== "slide") return 0
        return isActive ? 0 : (outDir * root.width)
    }

    function _scaleFor(isActive) {
        if (_effectiveType !== "zoom") return 1
        return isActive ? 1 : _zoomFrom
    }

    // ── Image 0 ─────────────────────────────────────────────────────────
    Image {
        id: img0

        // Manual geometry — anchors.fill conflicts with x animation for slide
        y: 0
        width: root.width
        height: root.height

        fillMode: root.fillMode
        sourceSize: root.sourceSize
        asynchronous: true
        cache: true
        mipmap: true
        smooth: true
        transformOrigin: Item.Center

        property bool isActive: internal.activeIndex === 0
        visible: isActive || root._transitioning

        opacity: root._opacityFor(isActive)
        x: root._xFor(isActive, -1)
        scale: root._scaleFor(isActive)

        Behavior on opacity {
            enabled: root._canTransition && root._effectiveType !== "slide"
            NumberAnimation { duration: root.transitionDuration; easing.type: root._easingType }
        }
        Behavior on x {
            enabled: root._canTransition && root._effectiveType === "slide"
            NumberAnimation { duration: root.transitionDuration; easing.type: root._easingType }
        }
        Behavior on scale {
            enabled: root._canTransition && root._effectiveType === "zoom"
            NumberAnimation { duration: root.transitionDuration; easing.type: root._easingType }
        }

        onStatusChanged: {
            if (status === Image.Ready && internal.activeIndex === 1 && source == root.source) {
                internal.performSwitch()
            }
        }

        // BlurFade: exiting image gets progressively blurred
        layer.enabled: root._canTransition && Appearance.effectsEnabled
                       && root._effectiveType === "blurFade" && !isActive && root._transitioning
        layer.effect: MultiEffect {
            blurEnabled: true
            blur: img0.isActive ? 0 : 0.6
            blurMax: 56
            Behavior on blur {
                enabled: root._canTransition
                NumberAnimation { duration: root.transitionDuration; easing.type: Easing.OutQuad }
            }
        }
    }

    // ── Image 1 ─────────────────────────────────────────────────────────
    Image {
        id: img1

        y: 0
        width: root.width
        height: root.height

        fillMode: root.fillMode
        sourceSize: root.sourceSize
        asynchronous: true
        cache: true
        mipmap: true
        smooth: true
        transformOrigin: Item.Center

        property bool isActive: internal.activeIndex === 1
        visible: isActive || root._transitioning

        opacity: root._opacityFor(isActive)
        x: root._xFor(isActive, 1)
        scale: root._scaleFor(isActive)

        Behavior on opacity {
            enabled: root._canTransition && root._effectiveType !== "slide"
            NumberAnimation { duration: root.transitionDuration; easing.type: root._easingType }
        }
        Behavior on x {
            enabled: root._canTransition && root._effectiveType === "slide"
            NumberAnimation { duration: root.transitionDuration; easing.type: root._easingType }
        }
        Behavior on scale {
            enabled: root._canTransition && root._effectiveType === "zoom"
            NumberAnimation { duration: root.transitionDuration; easing.type: root._easingType }
        }

        onStatusChanged: {
            if (status === Image.Ready && internal.activeIndex === 0 && source == root.source) {
                internal.performSwitch()
            }
        }

        // BlurFade: exiting image gets progressively blurred
        layer.enabled: root._canTransition && Appearance.effectsEnabled
                       && root._effectiveType === "blurFade" && !isActive && root._transitioning
        layer.effect: MultiEffect {
            blurEnabled: true
            blur: img1.isActive ? 0 : 0.6
            blurMax: 56
            Behavior on blur {
                enabled: root._canTransition
                NumberAnimation { duration: root.transitionDuration; easing.type: Easing.OutQuad }
            }
        }
    }

    // ── Initial load ────────────────────────────────────────────────────
    Component.onCompleted: {
        if (root.source !== "") {
            img0.source = root.source
            internal.lastSource = root.source
        }
    }
}
