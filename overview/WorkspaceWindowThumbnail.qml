pragma ComponentBehavior: Bound

import QtQuick
import Qt5Compat.GraphicalEffects
import Quickshell.Wayland
import "../core"

// Геометрия миниатюры принадлежит самому delegate, без размерного Loader.
Rectangle {
    id: thumbnail

    required property var toplevel
    required property var monitor
    required property var monitorGeometry
    required property int workspaceId
    property int previewRevision: 0

    signal dragStarted(var toplevel, int workspaceId)
    signal dragEnded()
    signal dragMoved(var source, real pointerX, real pointerY)
    signal dragReleased(var source, real pointerX, real pointerY)
    signal clicked()
    signal interactionChanged(bool held)
    signal hoverChanged(bool hovered)

    readonly property var rawPosition: toplevel?.lastIpcObject?.at ?? []
    readonly property var rawSize: toplevel?.lastIpcObject?.size ?? []
    readonly property real monitorWidth: Math.max(1, monitorGeometry.width)
    readonly property real monitorHeight: Math.max(1, monitorGeometry.height)
    readonly property real sourceX: Number(rawPosition[0] ?? monitor?.x ?? 0)
    readonly property real sourceY: Number(rawPosition[1] ?? monitor?.y ?? 0)
    readonly property real sourceWidth: Math.max(1, Number(rawSize[0] ?? 1))
    readonly property real sourceHeight: Math.max(1, Number(rawSize[1] ?? 1))

    x: (sourceX - monitorGeometry.x) / monitorWidth * (parent?.width ?? 0)
    y: (sourceY - monitorGeometry.y) / monitorHeight * (parent?.height ?? 0)
    width: sourceWidth / monitorWidth * (parent?.width ?? 0)
    height: sourceHeight / monitorHeight * (parent?.height ?? 0)
    radius: 3
    clip: true
    // Снимок сам задаёт вид окна; белая стеклянная подложка искажала
    // прозрачные окна, особенно в drag-копии.
    color: Theme.transparentColor
    border.width: 0
    border.color: Theme.selectionOutlineColor

    // Как в Dock preview: маска вынуждает offscreen-композицию исходного
    // кадра с корректным premultiplied alpha. Без неё стекло могло показать
    // уже видимый за overview экран вместо полотна workspace.
    ScreencopyView {
        id: snapshot
        anchors.fill: parent
        captureSource: {
            // previewRevision сохраняет binding и запускает новый кадр после
            // переноса, не превращая captureSource в одноразовое присваивание.
            const revision = thumbnail.previewRevision;
            return revision >= 0 ? thumbnail.toplevel?.wayland ?? null : null;
        }
        constraintSize: Qt.size(320, 180)
        paintCursor: false
        live: false
        onCaptureSourceChanged: live = captureSource !== null
        onHasContentChanged: {
            if (hasContent) live = false;
        }

        layer.enabled: true
        layer.effect: OpacityMask {
            maskSource: Rectangle {
                width: snapshot.width
                height: snapshot.height
                radius: thumbnail.radius
            }
        }
    }

    Text {
        anchors.centerIn: parent
        visible: !snapshot.hasContent
        width: parent.width - 6
        text: String(thumbnail.toplevel?.title ?? "Окно")
        color: Theme.glassTextColor
        font.pixelSize: 10
        elide: Text.ElideRight
        horizontalAlignment: Text.AlignHCenter
    }

    DragSurface {
        id: pointer
        anchors.fill: parent
        onContainsMouseChanged: thumbnail.hoverChanged(containsMouse)
        onInteractionChanged: held => thumbnail.interactionChanged(held)
        onStarted: thumbnail.dragStarted(thumbnail.toplevel, thumbnail.workspaceId)
        onMoved: (x, y) => thumbnail.dragMoved(thumbnail, x, y)
        onDropped: (x, y) => thumbnail.dragReleased(thumbnail, x, y)
        onCanceledDrag: thumbnail.dragEnded()
        onTapped: thumbnail.clicked()
    }
    Rectangle {
        anchors.fill: parent
        color: "transparent"
        radius: thumbnail.radius
        border.width: pointer.containsMouse ? 2 : 0
        border.color: Theme.selectionOutlineColor
    }
}
