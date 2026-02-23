pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.common

QtObject {
    id: root

    readonly property int pageSpacing: 12

    readonly property int cardRadius: Appearance.angelEverywhere ? Appearance.angel.roundingNormal
        : Appearance.rounding.normal
    readonly property int cardPadding: 14

    readonly property int headerRadius: Appearance.angelEverywhere ? Appearance.angel.roundingSmall
        : Appearance.rounding.small
    readonly property int headerPaddingX: 10
    readonly property int headerPaddingY: 6

    readonly property int groupRadius: Appearance.angelEverywhere ? Appearance.angel.roundingSmall
        : Appearance.rounding.small
    readonly property int groupPadding: 12
    readonly property int groupSpacing: 8

    readonly property color cardColor: Appearance.angelEverywhere
        ? Appearance.angel.colGlassCard : Appearance.colors.colLayer1
    readonly property color cardBorderColor: Appearance.angelEverywhere
        ? Appearance.angel.colBorder : Appearance.colors.colLayer0Border

    readonly property color groupColor: Appearance.angelEverywhere
        ? Appearance.angel.colGlassPopup : Appearance.colors.colLayer2
    readonly property color groupBorderColor: Appearance.angelEverywhere
        ? Appearance.angel.colBorderSubtle : Appearance.colors.colLayer0Border
}
