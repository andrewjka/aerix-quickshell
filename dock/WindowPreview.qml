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

    readonly property real contentAspect: previewImage.hasContent
        && previewImage.sourceSize.width > 0
        && previewImage.sourceSize.height > 0
        ? previewImage.sourceSize.width / previewImage.sourceSize.height
        : Metrics.previewWidth / Metrics.previewHeight

    anchor.window: panelWindow
    anchor.rect.x: panelWindow ? Math.round((panelWindow.width - width) / 2) : 0
    anchor.rect.y: Math.round(capsuleY - height - 12)
    implicitWidth: contentAspect >= Metrics.previewWidth / Metrics.previewHeight
        ? Metrics.previewWidth
        : Metrics.previewHeight * contentAspect
    implicitHeight: implicitWidth / contentAspect + Metrics.previewTitleHeight
    color: "transparent"
    visible: panelOpen && hoveredToplevel !== null

    Rectangle {
        id: previewFrame
        anchors.fill: parent
        radius: Metrics.previewRadius
        color: "#ff1b2431"
        clip: true

        Item {
            id: previewImageArea
            x: 0
            y: Metrics.previewTitleHeight
            width: parent.width
            height: preview.implicitWidth / preview.contentAspect

            ScreencopyView {
                id: previewImage
                anchors.fill: parent
                captureSource: preview.hoveredToplevel?.wayland ?? null
                live: true
                paintCursor: false
                visible: hasContent
                z: 1

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
                    return preview.hoveredToplevel ? IconService.resolve(preview.hoveredToplevel) : "";
                }
                cache: true
                fillMode: Image.PreserveAspectFit
                smooth: true
            }

            Text {
                anchors.left: previewIcon.right
                anchors.leftMargin: 8
                anchors.right: parent.right
                anchors.rightMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                text: String(preview.hoveredToplevel?.title
                             ?? preview.hoveredToplevel?.lastIpcObject?.title
                             ?? "Preview")
                color: "#f2ffffff"
                font.pixelSize: 12
                elide: Text.ElideRight
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: Metrics.previewRadius
        color: "transparent"
        border.width: 1
        border.color: "#66ffffff"
        z: 3
    }
}
