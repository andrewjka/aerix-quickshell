pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import "../shared" as Shared
import "../../core"
import "../../services"

// Один OSD на экран. Виден только экземпляр, выбранный OsdService.
PanelWindow {
    id: osd

    required property var modelData

    readonly property bool active: OsdService.targetScreen === modelData
        && OsdService.mode.length > 0
    property real reveal: active ? 1 : 0
    readonly property int revealTravel: 24
    readonly property int surfaceWidth: Math.min(Metrics.osdWidth,
        modelData.width - 2 * Metrics.statusBarHorizontalMargin)
    // В отличие от обычных popup, высота OSD задаётся целиком одной метрикой.
    readonly property int surfaceHeight: Metrics.osdHeight
    readonly property int topOffset: Metrics.statusBarHeight + 2 * Metrics.spacing
    readonly property real springScaleOverflow: Math.max(0,
        Metrics.spring.maximumScale - 1)
    readonly property int renderMargin: Math.ceil(Metrics.panelShadowRadius) + 1
        + Math.ceil(surfaceWidth * springScaleOverflow / 2)

    screen: modelData
    anchors { top: true; left: true; right: true }
    implicitHeight: topOffset + surfaceHeight + renderMargin
    color: Theme.transparentColor
    focusable: false
    visible: active || reveal > 0
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "aerix:osd"
    mask: Region { item: osdFrame }

    Behavior on reveal {
        NumberAnimation {
            duration: Metrics.spring.durationMs
            easing.type: Metrics.spring.easingType
            easing.bezierCurve: Metrics.spring.bezierCurve
        }
    }

    function restartCloseDelay() {
        if (active)
            closeDelay.restart();
    }

    Timer {
        id: closeDelay
        interval: Metrics.osdCloseDelayMs
        repeat: false
        onTriggered: OsdService.hide()
    }

    Connections {
        target: OsdService

        function onRequestSequenceChanged() {
            osd.restartCloseDelay();
        }
    }

    onActiveChanged: {
        if (active) {
            restartCloseDelay();
        } else {
            closeDelay.stop();
        }
    }

    PanelShadowWindow {
        targetScreen: osd.modelData
        shadowSource: shadowSurface
        shadowNamespace: "aerix:osd-shadow"
        shadowVisible: osd.visible
        shadowOpacity: osdFrame.opacity
        WlrLayershell.layer: WlrLayer.Overlay
        anchors { top: true; left: true; right: true }
        implicitHeight: osd.height

        Rectangle {
            id: shadowSurface
            x: osdFrame.x
            y: osdFrame.y
            width: osdFrame.width
            height: osdFrame.height
            radius: Metrics.panelRadius
            scale: osdFrame.scale
            transformOrigin: osdFrame.transformOrigin
            color: Theme.transparentColor
            antialiasing: true
        }
    }

    Rectangle {
        id: osdFrame
        x: Math.round((osd.width - width) / 2)
        y: osd.topOffset - osd.revealTravel * (1 - osd.reveal)
        width: osd.surfaceWidth
        height: osd.surfaceHeight
        radius: Metrics.panelRadius
        color: Theme.backgroundColor
        border.width: 1
        border.color: Theme.borderColor
        antialiasing: true
        scale: Metrics.spring.startScale
            + (1 - Metrics.spring.startScale) * osd.reveal
        transformOrigin: Item.Top
        opacity: Math.max(0, Math.min(1, osd.reveal))

        Shared.ValueSlider {
            anchors.fill: parent
            anchors.margins: Metrics.spacing
            iconSource: Qt.resolvedUrl("../../assets/icons/" + (OsdService.displayedMode
                === "volume" ? AudioService.iconName : "brightness.svg"))
            devicePixelRatio: osd.devicePixelRatio
            value: OsdService.displayedMode === "volume"
                ? AudioService.volumePercent : BrightnessService.brightnessPercent
            text: String(value).padStart(2, "0")
            onValueEdited: value => {
                if (OsdService.displayedMode === "volume") AudioService.setVolumePercent(value);
                else BrightnessService.setBrightnessPercent(value);
                osd.restartCloseDelay();
            }
        }
    }
}
