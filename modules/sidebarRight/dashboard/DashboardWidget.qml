import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.services
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "root:"

Item {
    id: root
    property int margin: 10
    implicitHeight: mainColumn.implicitHeight + margin * 2

    // ── Style tokens (tri-style) ─────────────────────────────────
    readonly property color colText: Appearance.angelEverywhere ? Appearance.angel.colText
        : Appearance.inirEverywhere ? Appearance.inir.colText : Appearance.colors.colOnLayer1
    readonly property color colTextSecondary: Appearance.angelEverywhere ? Appearance.angel.colTextSecondary
        : Appearance.inirEverywhere ? Appearance.inir.colTextSecondary : Appearance.colors.colSubtext
    readonly property color colBg: Appearance.angelEverywhere ? Appearance.angel.colGlassCard
        : Appearance.inirEverywhere ? Appearance.inir.colLayer0
        : Appearance.auroraEverywhere ? Appearance.aurora.colSubSurface
        : Appearance.colors.colLayer0
    readonly property color colCard: Appearance.angelEverywhere ? Appearance.angel.colGlassCard
        : Appearance.inirEverywhere ? Appearance.inir.colLayer1
        : Appearance.auroraEverywhere ? Appearance.aurora.colSubSurface
        : Appearance.colors.colLayer1
    readonly property color colBorder: Appearance.angelEverywhere ? Appearance.angel.colCardBorder
        : Appearance.inirEverywhere ? Appearance.inir.colBorder : Appearance.colors.colLayer0Border
    readonly property int borderWidth: (Appearance.angelEverywhere || Appearance.inirEverywhere) ? 1 : (Appearance.auroraEverywhere ? 0 : 1)
    readonly property real radius: Appearance.angelEverywhere ? Appearance.angel.roundingNormal
        : Appearance.inirEverywhere ? Appearance.inir.roundingNormal : Appearance.rounding.normal
    readonly property real radiusSmall: Appearance.angelEverywhere ? Appearance.angel.roundingSmall
        : Appearance.inirEverywhere ? Appearance.inir.roundingSmall : Appearance.rounding.small

    Component.onCompleted: ResourceUsage.ensureRunning()
    Component.onDestruction: ResourceUsage.stop()

    // Re-ensure polling when visible
    Connections {
        target: GlobalStates
        function onSidebarRightOpenChanged() {
            if (GlobalStates.sidebarRightOpen) ResourceUsage.ensureRunning()
        }
    }

    ColumnLayout {
        id: mainColumn
        anchors.fill: parent
        anchors.margins: root.margin
        spacing: 12

        // Vertical spacer — center content when there's extra space (compact mode)
        Item { Layout.fillHeight: true; Layout.minimumHeight: 0 }

        // ── Header ───────────────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            StyledText {
                Layout.fillWidth: true
                text: Translation.tr("Dashboard")
                font.pixelSize: Appearance.font.pixelSize.larger
                font.weight: Font.Medium
                color: root.colText
            }
            StyledText {
                text: DateTime.uptime ? Translation.tr("Up %1").arg(DateTime.uptime) : ""
                font.pixelSize: Appearance.font.pixelSize.smallest
                color: root.colTextSecondary
            }
        }

        // ── Status Rings Row ─────────────────────────────────────
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: ringsRow.implicitHeight + 16
            radius: root.radius
            color: root.colBg
            border.width: root.borderWidth
            border.color: root.colBorder

            RowLayout {
                id: ringsRow
                anchors.centerIn: parent
                spacing: 8

                StatusRing {
                    icon: "memory"
                    label: "CPU"
                    progressValue: ResourceUsage.cpuUsage
                    progressColor: ResourceUsage.cpuUsage >= 0.9 ? Appearance.colors.colError
                        : ResourceUsage.cpuUsage >= 0.7 ? Appearance.colors.colTertiary
                        : Appearance.colors.colPrimary
                    tooltipText: Translation.tr("CPU: %1%").arg(Math.round(ResourceUsage.cpuUsage * 100))
                }

                StatusRing {
                    icon: "memory_alt"
                    label: "RAM"
                    progressValue: ResourceUsage.memoryUsedPercentage
                    progressColor: ResourceUsage.memoryUsedPercentage >= 0.9 ? Appearance.colors.colError
                        : ResourceUsage.memoryUsedPercentage >= 0.7 ? Appearance.colors.colTertiary
                        : Appearance.colors.colPrimary
                    tooltipText: Translation.tr("RAM: %1%").arg(Math.round(ResourceUsage.memoryUsedPercentage * 100))
                }

                StatusRing {
                    icon: "hard_drive"
                    label: Translation.tr("Disk")
                    progressValue: ResourceUsage.diskUsedPercentage
                    progressColor: ResourceUsage.diskUsedPercentage >= 0.9 ? Appearance.colors.colError
                        : ResourceUsage.diskUsedPercentage >= 0.8 ? Appearance.colors.colTertiary
                        : Appearance.colors.colPrimary
                    tooltipText: Translation.tr("Disk: %1%").arg(Math.round(ResourceUsage.diskUsedPercentage * 100))
                }

                StatusRing {
                    visible: ResourceUsage.maxTemp > 0
                    icon: "thermostat"
                    label: Translation.tr("Temp")
                    progressValue: Math.min(ResourceUsage.maxTemp / 100, 1.0)
                    progressColor: ResourceUsage.maxTemp >= 80 ? Appearance.colors.colError
                        : ResourceUsage.maxTemp >= 60 ? Appearance.colors.colTertiary
                        : Appearance.colors.colPrimary
                    tooltipText: Translation.tr("Temperature: %1°C").arg(ResourceUsage.maxTemp)
                }

                StatusRing {
                    visible: Battery.available
                    icon: Battery.isCharging ? "battery_charging_full" : (Battery.isLow ? "battery_alert" : "battery_std")
                    label: Translation.tr("Bat")
                    progressValue: Battery.percentage
                    progressColor: Battery.isCritical ? Appearance.colors.colError
                        : Battery.isCharging ? Appearance.colors.colPrimary
                        : Battery.percentage < 0.3 ? Appearance.colors.colTertiary
                        : Appearance.colors.colPrimary
                    tooltipText: Translation.tr("Battery: %1%").arg(Math.round(Battery.percentage * 100))
                        + (Battery.isCharging ? " ⚡" : "")
                }
            }
        }

        // ── Info Cards Row ───────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            // Weather mini card
            InfoCard {
                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: Weather.enabled
                icon: Icons.getWeatherIcon(Weather.data?.wCode ?? "113", Weather.isNightNow())
                useCustomIcon: true
                title: Weather.data?.temp ?? "--"
                subtitle: Weather.data?.city ?? Translation.tr("Loading...")
            }

            // Battery mini card
            InfoCard {
                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: Battery.available
                icon: Battery.isCharging ? "battery_charging_full"
                    : Battery.isCritical ? "battery_alert"
                    : Battery.isLow ? "battery_2_bar"
                    : Battery.percentage < 0.5 ? "battery_4_bar"
                    : "battery_full"
                title: Math.round(Battery.percentage * 100) + "%"
                subtitle: Battery.isCharging
                    ? Translation.tr("Charging")
                    : Battery.timeToEmpty > 0
                        ? formatDuration(Battery.timeToEmpty)
                        : Translation.tr("Battery")
                iconColor: Battery.isCritical ? Appearance.colors.colError
                    : Battery.isCharging ? Appearance.colors.colPrimary
                    : Battery.isLow ? Appearance.colors.colTertiary
                    : root.colText
            }

            // CPU/RAM summary card (when no weather and no battery)
            InfoCard {
                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: !Weather.enabled && !Battery.available
                icon: "speed"
                title: Math.round(ResourceUsage.cpuUsage * 100) + "%"
                subtitle: "CPU"
            }
        }

        // Bottom spacer — balance vertical centering
        Item { Layout.fillHeight: true; Layout.minimumHeight: 0 }
    }

    // ── Helper ────────────────────────────────────────────────────
    function formatDuration(seconds) {
        if (seconds <= 0) return ""
        const h = Math.floor(seconds / 3600)
        const m = Math.floor((seconds % 3600) / 60)
        if (h > 0) return Translation.tr("%1h %2m left").arg(h).arg(m)
        return Translation.tr("%1m left").arg(m)
    }

    // ═════════════════════════════════════════════════════════════
    // INLINE COMPONENTS
    // ═════════════════════════════════════════════════════════════

    component StatusRing: Item {
        id: ring
        required property string icon
        required property string label
        property real progressValue: 0
        property color progressColor: Appearance.colors.colPrimary
        property string tooltipText: ""

        implicitWidth: 52
        implicitHeight: 60

        // Ring background
        Rectangle {
            id: ringBg
            width: 44
            height: 44
            anchors.horizontalCenter: parent.horizontalCenter
            radius: width / 2
            color: "transparent"
            border.width: 3
            border.color: Appearance.angelEverywhere ? Appearance.angel.colBorderSubtle
                : Appearance.inirEverywhere ? Appearance.inir.colBorderSubtle
                : Appearance.auroraEverywhere ? "transparent"
                : Appearance.colors.colLayer2

            // Progress arc
            Canvas {
                id: arcCanvas
                anchors.fill: parent
                property real animatedValue: ring.progressValue
                Behavior on animatedValue {
                    NumberAnimation {
                        duration: Appearance.animation.elementMoveFast.duration
                        easing.type: Easing.OutCubic
                    }
                }
                onAnimatedValueChanged: requestPaint()
                onPaint: {
                    const ctx = getContext("2d")
                    ctx.clearRect(0, 0, width, height)
                    ctx.strokeStyle = Qt.color(ring.progressColor)
                    ctx.lineWidth = 3
                    ctx.lineCap = "round"
                    ctx.beginPath()
                    const startAngle = -Math.PI / 2
                    const endAngle = startAngle + (2 * Math.PI * animatedValue)
                    ctx.arc(width / 2, height / 2, width / 2 - 2, startAngle, endAngle)
                    ctx.stroke()
                }
            }

            // Center icon
            MaterialSymbol {
                anchors.centerIn: parent
                text: ring.icon
                iconSize: 14
                color: ring.progressColor
            }
        }

        // Label below ring
        StyledText {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: ringBg.bottom
            anchors.topMargin: 2
            text: Math.round(ring.progressValue * 100) + "%"
            font.pixelSize: Appearance.font.pixelSize.smallest
            font.family: Appearance.font.family.numbers
            color: root.colTextSecondary
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            StyledToolTip { text: ring.tooltipText }
        }
    }

    component InfoCard: Rectangle {
        id: infoCard
        required property string icon
        required property string title
        property string subtitle: ""
        property color iconColor: root.colText
        property bool useCustomIcon: false

        implicitHeight: infoCardColumn.implicitHeight + 16
        radius: root.radiusSmall
        color: root.colCard
        border.width: root.borderWidth
        border.color: root.colBorder

        ColumnLayout {
            id: infoCardColumn
            anchors {
                left: parent.left
                right: parent.right
                verticalCenter: parent.verticalCenter
                margins: 10
            }
            spacing: 2

            RowLayout {
                spacing: 6
                MaterialSymbol {
                    text: infoCard.icon
                    iconSize: 18
                    color: infoCard.iconColor
                    fill: 1
                }
                StyledText {
                    text: infoCard.title
                    font.pixelSize: Appearance.font.pixelSize.large
                    font.weight: Font.Bold
                    font.family: Appearance.font.family.numbers
                    color: root.colText
                }
            }

            StyledText {
                visible: infoCard.subtitle !== ""
                Layout.fillWidth: true
                text: infoCard.subtitle
                font.pixelSize: Appearance.font.pixelSize.smallest
                color: root.colTextSecondary
                elide: Text.ElideRight
            }
        }
    }
}
