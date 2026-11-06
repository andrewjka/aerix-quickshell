pragma ComponentBehavior: Bound

import QtQuick
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Wayland
import "../core"
import "../services"

PopupWindow {
    id: preview

    required property var panelWindow
    required property var hoveredToplevel
    required property bool panelOpen
    required property real capsuleY
    property var displayedToplevel: null

    readonly property real contentAspect: previewImage.hasContent
        && previewImage.sourceSize.width > 0
        && previewImage.sourceSize.height > 0
        ? previewImage.sourceSize.width / previewImage.sourceSize.height
        : Metrics.previewWidth / Metrics.previewHeight

    anchor.window: panelWindow
    anchor.rect.x: panelWindow
        ? Math.round(Math.max(8, Math.min(panelWindow.width - width - 8,
                                          panelWindow.hoveredIconCenterX - width / 2)))
        : 0
    anchor.rect.y: Math.round(capsuleY - height - 12)
    implicitWidth: contentAspect >= Metrics.previewWidth / Metrics.previewHeight
        ? Metrics.previewWidth
        : Metrics.previewHeight * contentAspect
    implicitHeight: implicitWidth / contentAspect + Metrics.previewTitleHeight
    color: "transparent"
    visible: panelOpen && hoveredToplevel !== null

    onHoveredToplevelChanged: {
        if (!hoveredToplevel || !previewFrame)
            return;

        displayedToplevel = hoveredToplevel;
        previewFrame.scale = 0.12;
        previewFrame.opacity = 0;
        revealAnimation.restart();
    }

    Component.onCompleted: {
        displayedToplevel = hoveredToplevel;
        if (hoveredToplevel) {
            previewFrame.scale = 0.12;
            previewFrame.opacity = 0;
            revealAnimation.restart();
        }
    }

    ParallelAnimation {
        id: revealAnimation

        StandardAnimation {
            target: previewFrame
            property: "scale"
            from: 0.12
            to: 1
            duration: 512
        }
        StandardAnimation {
            target: previewFrame
            property: "opacity"
            from: 0
            to: 1
            duration: 512
        }
    }

    Rectangle {
        id: previewFrame
        anchors.fill: parent
        radius: Metrics.previewRadius
        color: "#ff1b2431"
        clip: true
        transformOrigin: Item.Bottom

        Item {
            id: previewImageArea
            x: 0
            y: Metrics.previewTitleHeight
            width: parent.width
            height: preview.implicitWidth / preview.contentAspect

            ScreencopyView {
                id: previewImage
                anchors.fill: parent
                captureSource: preview.displayedToplevel?.wayland ?? null
                // Один кадр вместо постоянно работающего видеопотока.
                live: false
                paintCursor: false
                visible: hasContent
                z: 1

                onCaptureSourceChanged: {
                    if (!captureSource)
                        return;
                    Qt.callLater(function() {
                        if (previewImage.captureSource)
                            previewImage.captureFrame();
                    });
                }

                layer.enabled: true
                layer.effect: OpacityMask {
                    maskSource: Rectangle {
                        width: previewImage.width
                        height: previewImage.height
                        radius: Metrics.previewRadius
                    }
                }
            }
        }

        Rectangle {
            id: previewTitleBar
            x: 0
            y: 0
            width: parent.width
            height: Metrics.previewTitleHeight
            color: "#e61b2431"
            z: 2
            radius: Metrics.previewRadius

            Image {
                id: previewIcon
                x: 10
                y: (parent.height - height) / 2
                width: 16
                height: 16
                source: {
                    IconService.revision;
                    return preview.displayedToplevel ? IconService.resolve(preview.displayedToplevel) : "";
                }
                cache: true
                sourceSize: Qt.size(32, 32)
                fillMode: Image.PreserveAspectFit
                smooth: true
            }

            Text {
                anchors.left: previewIcon.right
                anchors.leftMargin: 8
                anchors.right: parent.right
                anchors.rightMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                text: String(preview.displayedToplevel?.title
                             ?? preview.displayedToplevel?.lastIpcObject?.title
                             ?? "Preview")
                color: "#f2ffffff"
                font.pixelSize: 12
                elide: Text.ElideRight
            }
        }
    }

    Rectangle {
        id: previewBorder
        anchors.fill: parent
        radius: Metrics.previewRadius
        color: "transparent"
        border.width: 1
        border.color: "#66ffffff"
        z: 3
        scale: previewFrame.scale
        opacity: previewFrame.opacity
        transformOrigin: Item.Bottom
    }
}
