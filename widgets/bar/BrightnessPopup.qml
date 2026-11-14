pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import "shared" as Shared
import "../../core"
import "../../services"

// Один слой яркости: верх управляет VCP 10 выбранного дисплея, низ выбирает его.
PanelWindow {
    id: popup

    required property var barWindow
    required property Item anchorItem
    property bool expanded: false
    property real reveal: expanded ? 1 : 0
    readonly property var entries: BrightnessService.monitors
    readonly property int rowHeight: 32
    readonly property int mixerHeight: 42
    readonly property int sectionLabelHeight: 16
    readonly property int revealTravel: 24
    readonly property real springScaleOverflow: Math.max(0,
        Motion.spring.maximumScale - 1)
    readonly property real springProgressOverflow: Math.max(0,
        Motion.spring.maximumProgress - 1)
    readonly property int shadowMargin: Math.ceil(Metrics.panelShadowRadius) + 1
    readonly property int topRenderMargin: shadowMargin + revealTravel
    readonly property int bottomSpringOverflow: Math.ceil(
        revealTravel * springProgressOverflow)
    readonly property int bottomRenderMargin: shadowMargin + bottomSpringOverflow
        + Math.ceil(surfaceHeight * springScaleOverflow)
    readonly property int horizontalRenderMargin: shadowMargin + Math.ceil(
        surfaceWidth * springScaleOverflow / 2)
    readonly property int popupTop: barWindow.height + 2 * Metrics.spacing
    readonly property int visibleRowCount: Math.min(5,
        Math.max(1, entries.length))
    readonly property int listHeight: visibleRowCount * rowHeight
        + Math.max(0, visibleRowCount - 1) * Metrics.popupRowSpacing + 2
    // qmllint disable missing-property
    readonly property int surfaceWidth: Math.min(280,
        screen.width - 2 * Metrics.statusBarHorizontalMargin)
    // qmllint enable missing-property
    // Все стороны frame получают единый внутренний отступ Metrics.spacing.
    readonly property int surfaceHeight: 4 * Metrics.spacing + mixerHeight + 1
        + sectionLabelHeight + 4 + listHeight
    readonly property real surfaceX: {
        const barWidth = barWindow.width;
        const itemX = anchorItem.x;
        const itemWidth = anchorItem.width;
        const position = anchorItem.mapToItem(barWindow.contentItem, 0, 0);
        return Math.round(Math.max(Metrics.statusBarHorizontalMargin,
            Math.min(position.x + itemWidth / 2 - surfaceWidth / 2,
                barWidth - Metrics.statusBarHorizontalMargin - surfaceWidth)));
    }

    signal dismissed()

    screen: barWindow.screen
    anchors { top: true; left: true }
    exclusionMode: ExclusionMode.Ignore
    focusable: false
    margins.left: surfaceX - horizontalRenderMargin
    margins.top: popupTop - topRenderMargin
    implicitWidth: surfaceWidth + 2 * horizontalRenderMargin
    implicitHeight: surfaceHeight + topRenderMargin + bottomRenderMargin
    color: Theme.transparentColor
    WlrLayershell.namespace: "aerix:brightness"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    mask: Region { item: popupFrame }

    Behavior on reveal {
        NumberAnimation {
            duration: Motion.spring.durationMs
            easing.type: Motion.spring.easingType
            easing.bezierCurve: Motion.spring.bezierCurve
            onRunningChanged: {
                if (!running && !popup.expanded && popup.reveal === 0)
                    popup.dismissed();
            }
        }
    }

    function dismiss() { expanded = false; }
    function toggle() { expanded = !expanded; }
    function selectMonitor(monitor) {
        if (BrightnessService.selectMonitor(monitor))
            dismiss();
    }
    function syncFocusGrab() {
        Qt.callLater(() => focusGrab.active = popup.expanded);
    }

    Component.onCompleted: expanded = true
    onExpandedChanged: syncFocusGrab()

    HyprlandFocusGrab {
        id: focusGrab
        windows: [popup, popup.barWindow]
        onCleared: popup.dismiss()
    }

    PanelShadowWindow {
        targetScreen: popup.screen
        shadowSource: shadowSurface
        shadowNamespace: "aerix:brightness-shadow"
        shadowOpacity: popupFrame.opacity
        WlrLayershell.layer: WlrLayer.Overlay
        anchors { top: true; left: true }
        margins.left: popup.margins.left
        margins.top: popup.margins.top
        implicitWidth: popup.width
        implicitHeight: popup.height

        Rectangle {
            id: shadowSurface
            x: popupFrame.x
            y: popupFrame.y
            width: popupFrame.width
            height: popupFrame.height
            radius: Metrics.panelRadius
            scale: popupFrame.scale
            transformOrigin: popupFrame.transformOrigin
            color: Theme.transparentColor
            antialiasing: true
        }
    }

    Rectangle {
        id: popupFrame
        x: popup.horizontalRenderMargin
        y: popup.topRenderMargin - popup.revealTravel * (1 - popup.reveal)
        width: popup.surfaceWidth
        height: popup.surfaceHeight
        radius: Metrics.panelRadius
        color: Theme.backgroundColor
        antialiasing: true
        scale: Motion.spring.startScale
            + (1 - Motion.spring.startScale) * popup.reveal
        transformOrigin: Item.Top
        opacity: Math.max(0, Math.min(1, popup.reveal))

        Item {
            anchors.fill: parent

            Item {
                id: mixer
                x: Metrics.spacing
                y: Metrics.spacing
                width: parent.width - 2 * Metrics.spacing
                height: popup.mixerHeight

                Shared.StatusBarIcon {
                    id: brightnessIcon
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    width: Metrics.statusBarFontSize + 6
                    height: width
                    iconSource: Qt.resolvedUrl("../../assets/icons/brightness.svg")
                    tintColor: Theme.foregroundColor
                    devicePixelRatio: popup.barWindow?.devicePixelRatio ?? 1
                }

                Text {
                    id: brightnessPercent
                    anchors.left: brightnessIcon.right
                    anchors.leftMargin: Metrics.spacing
                    anchors.verticalCenter: parent.verticalCenter
                    text: String(BrightnessService.brightnessPercent).padStart(2, "0")
                    color: Theme.foregroundColor
                    font.pixelSize: Metrics.statusBarFontSize
                    font.weight: Font.Medium
                    verticalAlignment: Text.AlignVCenter
                }

                Item {
                    id: brightnessSlider
                    anchors.left: brightnessPercent.right
                    anchors.leftMargin: Metrics.spacing
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    height: mixer.height
                    readonly property real percent: sliderMouse.pressed
                        ? sliderMouse.draggedPercent : BrightnessService.brightnessPercent

                    function setFromX(positionX) {
                        const next = Math.round(Math.max(0, Math.min(width,
                            positionX)) / Math.max(1, width) * 100);
                        sliderMouse.draggedPercent = next;
                        BrightnessService.setBrightnessPercent(next);
                    }

                    Rectangle {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        height: 4
                        radius: Metrics.panelRadius
                        color: Theme.overlayColor

                        Rectangle {
                            width: brightnessSlider.percent / 100 * parent.width
                            height: parent.height
                            radius: Metrics.panelRadius
                            color: Theme.accentColor
                        }
                    }

                    Rectangle {
                        x: brightnessSlider.percent / 100 * (brightnessSlider.width - width)
                        anchors.verticalCenter: parent.verticalCenter
                        width: 12
                        height: 12
                        radius: Metrics.panelRadius
                        color: Theme.foregroundColor
                        antialiasing: true
                    }

                    MouseArea {
                        id: sliderMouse
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        height: 16
                        enabled: BrightnessService.available
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        property real draggedPercent: BrightnessService.brightnessPercent
                        onPressed: mouse => brightnessSlider.setFromX(mouse.x)
                        onPositionChanged: mouse => {
                            if (pressed)
                                brightnessSlider.setFromX(mouse.x);
                        }
                        onReleased: mouse => brightnessSlider.setFromX(mouse.x)
                    }
                }
            }

            Rectangle {
                x: Metrics.spacing
                y: mixer.y + mixer.height + Metrics.spacing
                width: parent.width - 2 * Metrics.spacing
                height: 1
                color: Theme.borderColor
            }

            Text {
                id: monitorsLabel
                x: Metrics.spacing
                y: mixer.y + mixer.height + 2 * Metrics.spacing + 1
                width: parent.width - 2 * Metrics.spacing
                height: popup.sectionLabelHeight
                text: I18n.tr("brightness.monitors")
                color: Theme.foregroundColor
                font.pixelSize: 12
                font.weight: Font.Medium
                verticalAlignment: Text.AlignVCenter
            }

            ListView {
                id: monitorList
                x: Metrics.spacing
                y: monitorsLabel.y + monitorsLabel.height + 4
                width: parent.width - 2 * Metrics.spacing
                height: popup.listHeight
                clip: true
                topMargin: 1
                bottomMargin: 1
                spacing: Metrics.popupRowSpacing
                boundsBehavior: Flickable.StopAtBounds
                model: popup.entries
                ScrollBar.vertical: ScrollBar {
                    parent: monitorList.parent
                    x: monitorList.x + monitorList.width + 2
                    y: monitorList.y
                    height: monitorList.height
                    width: 4
                    policy: ScrollBar.AsNeeded
                }

                delegate: Item {
                    id: row
                    required property var modelData
                    required property int index
                    readonly property bool selected:
                        BrightnessService.isSelectedMonitor(modelData)
                    width: monitorList.width
                    height: popup.rowHeight

                    Rectangle {
                        id: pointerHover
                        anchors.fill: parent
                        anchors.leftMargin: 1
                        anchors.rightMargin: 1
                        radius: Metrics.panelRadius
                        color: Theme.hoverColor
                        opacity: 0
                        state: rowMouse.containsMouse ? "hovered" : ""
                        antialiasing: true

                        states: State {
                            name: "hovered"
                            PropertyChanges {
                                target: pointerHover
                                opacity: 1
                            }
                        }

                        transitions: Transition {
                            NumberAnimation {
                                property: "opacity"
                                duration: Motion.quickDurationMs
                                easing.type: Easing.Linear
                            }
                        }
                    }

                    Rectangle {
                        anchors.fill: parent
                        anchors.leftMargin: 1
                        anchors.rightMargin: 1
                        radius: Metrics.panelRadius
                        color: Theme.hoverColor
                        opacity: row.selected ? 1 : 0
                        border.width: 0.5
                        border.pixelAligned: false
                        border.color: Theme.borderColor
                        antialiasing: true

                        Behavior on opacity {
                            Motion.ProfileAnimation {
                                duration: Motion.quickDurationMs
                            }
                        }
                    }

                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: Metrics.spacing
                        anchors.right: parent.right
                        anchors.rightMargin: Metrics.spacing
                        anchors.verticalCenter: parent.verticalCenter
                        text: row.modelData.label
                        color: Theme.foregroundColor
                        font.pixelSize: Metrics.statusBarFontSize
                        font.weight: row.selected ? Font.DemiBold : Font.Medium
                        elide: Text.ElideRight
                        verticalAlignment: Text.AlignVCenter
                    }

                    MouseArea {
                        id: rowMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: popup.selectMonitor(row.modelData)
                    }
                }
            }
        }
    }
}
