pragma ComponentBehavior: Bound

import QtQuick
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Wayland
import "../core"
import "../services"

PopupWindow {
    id: preview

    // Popup создаётся LazyLoader только при наведении. Внутри используется
    // один snapshot кадр, а не постоянный ScreencopyView live-поток.
    required property var panelWindow
    required property var hoveredToplevel
    required property var hoveredIconItem
    required property bool panelOpen
    required property real capsuleY
    property var displayedToplevel: null
    property var displayedIconItem: null

    // Размер сохраняет пропорции исходного окна, ограничиваясь базовым 16:9.
    readonly property real contentAspect: previewImage.hasContent
        && previewImage.sourceSize.width > 0
        && previewImage.sourceSize.height > 0
        ? previewImage.sourceSize.width / previewImage.sourceSize.height
        : Metrics.previewWidth / Metrics.previewHeight

    // Keep the popup attached to the stable panel window. The icon is used
    // only as a coordinate source in onAnchoring, avoiding PopupAnchor's
    // one-time item-position calculation for moving Repeater delegates.
    anchor.window: panelWindow
    anchor.edges: Edges.Top | Edges.Left
    anchor.gravity: Edges.Bottom | Edges.Right
    anchor.adjustment: PopupAdjustment.SlideX | PopupAdjustment.SlideY
    implicitWidth: contentAspect >= Metrics.previewWidth / Metrics.previewHeight
        ? Metrics.previewWidth
        : Metrics.previewHeight * contentAspect
    implicitHeight: implicitWidth / contentAspect + Metrics.previewTitleHeight
    color: "transparent"
    visible: panelOpen && hoveredToplevel !== null && displayedIconItem !== null

    // Convert the frozen icon position into panel-window coordinates only when
    // the popup is about to be shown. The preview bottom stays 10 px above the
    // bar's top edge, not above a moving icon's current visual center.
    anchor.onAnchoring: {
        if (!displayedIconItem || !panelWindow?.contentItem)
            return;

        const iconPosition = displayedIconItem.mapToItem(panelWindow.contentItem, 0, 0);
        anchor.rect.x = Math.round(iconPosition.x
                                   + displayedIconItem.width / 2
                                   - width / 2);
        anchor.rect.y = Math.round(capsuleY - height - Metrics.gaps);
    }

    // При смене окна карточка появляется от нижней центральной точки — над
    // активной иконкой. PopupWindow сам не поддерживает scale, поэтому
    // анимируется внутренний Rectangle.
    onHoveredToplevelChanged: {
        if (!hoveredToplevel || !previewFrame)
            return;

        displayedToplevel = hoveredToplevel;
        displayedIconItem = hoveredIconItem;
        previewFrame.scale = 0.12;
        previewFrame.opacity = 0;
        revealAnimation.restart();
    }

    Component.onCompleted: {
        displayedToplevel = hoveredToplevel;
        displayedIconItem = hoveredIconItem;
        if (hoveredToplevel) {
            previewFrame.scale = 0.12;
            previewFrame.opacity = 0;
            revealAnimation.restart();
        }
    }

    // The loader can create the popup one binding pass before the Repeater
    // exposes its icon. Make the icon arrival itself reopen the anchor.
    onHoveredIconItemChanged: {
        if (!hoveredIconItem || !hoveredToplevel)
            return;
        displayedIconItem = hoveredIconItem;
        if (visible)
            anchor.updateAnchor();
    }

    // Один общий transition для opacity и scale; 512 мс — согласованное время
    // движения превью.
    ParallelAnimation {
        id: revealAnimation

        StandardAnimation {
            target: previewFrame
            property: "scale"
            from: 0.12
            to: 1
            duration: Motion.defaultDuration
        }
        StandardAnimation {
            target: previewFrame
            property: "opacity"
            from: 0
            to: 1
            duration: Motion.defaultDuration
        }
    }

    Rectangle {
        id: previewFrame
        anchors.fill: parent
        radius: Metrics.previewRadius
        color: "#ff1b2431"
        clip: true
        transformOrigin: Item.Bottom

        // Область snapshot ниже status bar.
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
                // Start the capture only while the view is waiting for its
                // first frame. It is stopped in onHasContentChanged, so the
                // preview remains a snapshot instead of a live stream.
                live: captureSource !== null && !hasContent
                paintCursor: false
                // The item must be visible while the recording context is
                // being created; hiding it until hasContent prevents that
                // context from becoming ready.
                visible: preview.panelOpen

                onCaptureSourceChanged: {
                    // A reused preview must start one fresh capture for the
                    // newly hovered window.
                    live = captureSource !== null;
                }

                onHasContentChanged: {
                    if (hasContent)
                        live = false;
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

        // Status bar находится поверх snapshot и содержит только лёгкие данные.
        Rectangle {
            id: previewTitleBar
            x: 0
            y: 0
            width: parent.width
            height: Metrics.previewTitleHeight
            color: "#e61b2431"
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
        scale: previewFrame.scale
        opacity: previewFrame.opacity
        transformOrigin: Item.Bottom
    }
}
