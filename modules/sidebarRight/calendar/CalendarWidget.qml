import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import "calendar_layout.js" as CalendarLayout
import QtQuick
import QtQuick.Layouts
import Quickshell

Item {
    id: root

    // Style tokens (5-style support)
    readonly property color colText: Appearance.angelEverywhere ? Appearance.angel.colText
        : Appearance.inirEverywhere ? Appearance.inir.colText : Appearance.colors.colOnLayer1
    readonly property color colTextSecondary: Appearance.angelEverywhere ? Appearance.angel.colTextSecondary
        : Appearance.inirEverywhere ? Appearance.inir.colTextSecondary : Appearance.colors.colSubtext
    readonly property color colPrimary: Appearance.angelEverywhere ? Appearance.angel.colPrimary
        : Appearance.inirEverywhere ? Appearance.inir.colPrimary : Appearance.colors.colPrimary
    readonly property color colCard: Appearance.angelEverywhere ? Appearance.angel.colGlassCard
        : Appearance.inirEverywhere ? Appearance.inir.colLayer1
        : Appearance.auroraEverywhere ? Appearance.aurora.colSubSurface
        : Appearance.colors.colLayer1
    readonly property real radius: Appearance.angelEverywhere ? Appearance.angel.roundingSmall
        : Appearance.inirEverywhere ? Appearance.inir.roundingSmall : Appearance.rounding.small

    property var locale: {
        const envLocale = Quickshell.env("LC_TIME") || Quickshell.env("LC_ALL") || Quickshell.env("LANG") || "";
        const cleaned = (envLocale.split(".")[0] ?? "").split("@")[0] ?? "";
        return cleaned ? Qt.locale(cleaned) : Qt.locale();
    }

    property list<var> weekDaysModel: {
        const fdow = locale?.firstDayOfWeek ?? Qt.locale().firstDayOfWeek;
        const first = DateUtils.getFirstDayOfWeek(new Date(), fdow);
        const days = [];
        for (let i = 0; i < 7; i++) {
            const d = new Date(first);
            d.setDate(first.getDate() + i);
            days.push({
                label: locale.toString(d, "ddd"),
                today: DateUtils.sameDate(d, DateTime.clock.date)
            });
        }
        return days;
    }

    property int monthShift: 0
    property var viewingDate: CalendarLayout.getDateInXMonthsTime(monthShift)
    property var calendarLayout: CalendarLayout.getCalendarLayout(viewingDate, monthShift === 0, locale?.firstDayOfWeek ?? 1)
    width: calendarColumn.width
    implicitHeight: calendarColumn.height + 10 * 2

    Keys.onPressed: (event) => {
        if ((event.key === Qt.Key_PageDown || event.key === Qt.Key_PageUp)
            && event.modifiers === Qt.NoModifier) {
            if (event.key === Qt.Key_PageDown) {
                monthShift++;
            } else if (event.key === Qt.Key_PageUp) {
                monthShift--;
            }
            event.accepted = true;
        }
    }
    MouseArea {
        anchors.fill: parent
        onWheel: (event) => {
            if (event.angleDelta.y > 0) {
                monthShift--;
            } else if (event.angleDelta.y < 0) {
                monthShift++;
            }
        }
    }

    ColumnLayout {
        id: calendarColumn
        anchors.centerIn: parent
        spacing: 8

        // Enhanced calendar header
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            // Today's date highlight
            Rectangle {
                visible: monthShift === 0
                Layout.preferredWidth: todayCol.implicitWidth + 16
                Layout.preferredHeight: todayCol.implicitHeight + 8
                radius: root.radius
                color: root.colPrimary

                ColumnLayout {
                    id: todayCol
                    anchors.centerIn: parent
                    spacing: -2

                    StyledText {
                        Layout.alignment: Qt.AlignHCenter
                        text: DateTime.clock.date.getDate()
                        font.pixelSize: Appearance.font.pixelSize.larger
                        font.weight: Font.Bold
                        font.family: Appearance.font.family.numbers
                        color: Appearance.angelEverywhere ? Appearance.angel.colOnPrimary
                            : Appearance.inirEverywhere ? Appearance.inir.colOnPrimary
                            : Appearance.colors.colOnPrimary
                    }

                    StyledText {
                        Layout.alignment: Qt.AlignHCenter
                        text: locale.toString(DateTime.clock.date, "ddd")
                        font.pixelSize: Appearance.font.pixelSize.smallest
                        font.weight: Font.Medium
                        color: Appearance.angelEverywhere ? Appearance.angel.colOnPrimary
                            : Appearance.inirEverywhere ? Appearance.inir.colOnPrimary
                            : Appearance.colors.colOnPrimary
                        opacity: 0.9
                    }
                }
            }

            // Month/Year title
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                StyledText {
                    text: locale.toString(viewingDate, "MMMM")
                    font.pixelSize: Appearance.font.pixelSize.normal
                    font.weight: Font.Medium
                    color: root.colText
                }

                StyledText {
                    text: locale.toString(viewingDate, "yyyy")
                    font.pixelSize: Appearance.font.pixelSize.smallest
                    color: root.colTextSecondary
                }
            }

            // Navigation buttons
            RowLayout {
                spacing: 4

                // Jump to today (when not viewing current month)
                CalNavButton {
                    visible: monthShift !== 0
                    icon: "today"
                    tooltipText: Translation.tr("Jump to today")
                    onClicked: monthShift = 0
                }

                CalNavButton {
                    icon: "chevron_left"
                    tooltipText: Translation.tr("Previous month")
                    onClicked: monthShift--
                }

                CalNavButton {
                    icon: "chevron_right"
                    tooltipText: Translation.tr("Next month")
                    onClicked: monthShift++
                }
            }
        }

        // Week days row
        RowLayout {
            id: weekDaysRow
            Layout.alignment: Qt.AlignHCenter
            Layout.fillHeight: false
            Layout.topMargin: 4
            spacing: 5
            Repeater {
                model: weekDaysModel
                delegate: CalendarDayButton {
                    day: modelData.label
                    isToday: modelData.today ? 1 : 0
                    isHeader: true
                    bold: true
                    enabled: false
                }
            }
        }

        // Real week rows
        Repeater {
            id: calendarRows
            model: 6
            delegate: RowLayout {
                Layout.alignment: Qt.AlignHCenter
                Layout.fillHeight: false
                spacing: 5
                Repeater {
                    model: Array(7).fill(modelData)
                    delegate: CalendarDayButton {
                        day: calendarLayout[modelData][index].day
                        isToday: calendarLayout[modelData][index].today
                    }
                }
            }
        }
    }

    // Navigation button component
    component CalNavButton: Item {
        id: navBtn
        required property string icon
        property string tooltipText: ""

        signal clicked()

        implicitWidth: 32
        implicitHeight: 32

        Rectangle {
            anchors.fill: parent
            radius: root.radius
            color: {
                if (navBtnMA.containsPress)
                    return Appearance.angelEverywhere ? Appearance.angel.colGlassCardActive
                        : Appearance.inirEverywhere ? Appearance.inir.colLayer1Active
                        : Appearance.colors.colLayer1Active
                if (navBtnMA.containsMouse)
                    return Appearance.angelEverywhere ? Appearance.angel.colGlassCardHover
                        : Appearance.inirEverywhere ? Appearance.inir.colLayer1Hover
                        : Appearance.colors.colLayer1Hover
                return "transparent"
            }
            Behavior on color { ColorAnimation { duration: Appearance.animation.elementMoveFast.duration } }

            MaterialSymbol {
                anchors.centerIn: parent
                text: navBtn.icon
                iconSize: 18
                color: root.colTextSecondary
            }

            MouseArea {
                id: navBtnMA
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: navBtn.clicked()
            }

            StyledToolTip {
                visible: navBtnMA.containsMouse && navBtn.tooltipText !== ""
                text: navBtn.tooltipText
            }
        }
    }
}