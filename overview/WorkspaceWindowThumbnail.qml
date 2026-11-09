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
    property bool captureEnabled: true
    // True лишь короткое время после DnD: иначе это однокадровый export.
    property bool liveCapture: false
    property var snapshotRefreshWorkspaceIds: []
    property int snapshotRefreshGeneration: 0
    readonly property var capture: snapshotLoader.item
    property bool hasCachedFrame: false

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

    // A window created/resized while the overview is open can reject the
    // initial export. Never recreate it in the middle of the short live
    // phase: Hyprland is then still moving the window between workspaces.
    function recoverMissingCapture() {
        if (liveCapture || capture?.hasContent || !toplevel?.wayland || !parent)
            return;
        rebuildCapture();
    }

    // The only explicit rebuild occurs after the live window has elapsed.
    // It opens a fresh Hyprland toplevel-export context and captures the
    // settled geometry as a static frame.
    function rebuildCapture() {
        if (!toplevel?.wayland || !parent)
            return;
        captureEnabled = false;
        Qt.callLater(() => thumbnail.captureEnabled = true);
    }

    onSourceWidthChanged: Qt.callLater(recoverMissingCapture)
    onSourceHeightChanged: Qt.callLater(recoverMissingCapture)
    onWorkspaceIdChanged: Qt.callLater(recoverMissingCapture)
    onSnapshotRefreshGenerationChanged: {
        if (snapshotRefreshGeneration > 0
                && snapshotRefreshWorkspaceIds.indexOf(workspaceId) >= 0)
            rebuildCapture();
    }

    // This item remains the ShaderEffectSource input while Loader recreates
    // the export context. Therefore the cached texture survives the brief
    // interval where Hyprland has no frame to provide.
    Item {
        id: captureSurface
        anchors.fill: parent

        Loader {
            id: snapshotLoader
            anchors.fill: parent
            active: thumbnail.captureEnabled && thumbnail.parent !== null
                && !!thumbnail.toplevel?.wayland
            sourceComponent: Component {
                ScreencopyView {
                    id: snapshot
                    anchors.fill: parent
                    captureSource: thumbnail.toplevel?.wayland ?? null
                    constraintSize: Qt.size(320, 180)
                    paintCursor: false
                    live: thumbnail.liveCapture

                    layer.enabled: true
                    layer.effect: OpacityMask {
                        maskSource: Rectangle {
                            width: snapshot.width
                            height: snapshot.height
                            radius: thumbnail.radius
                        }
                    }
                }
            }
        }
    }

    // A failed live export must never reveal wallpaper plus a title label.
    // With live=false this is a frozen GPU texture; with live=true it tracks
    // the source until Hyprland ends the stream, then retains its last frame.
    ShaderEffectSource {
        id: cachedFrame
        anchors.fill: parent
        sourceItem: captureSurface
        hideSource: true
        live: thumbnail.liveCapture && !!thumbnail.capture?.hasContent
        visible: thumbnail.hasCachedFrame
        textureSize: Qt.size(Math.max(1, Math.ceil(width * 2)),
            Math.max(1, Math.ceil(height * 2)))
    }

    Connections {
        target: thumbnail.capture

        function onHasContentChanged() {
            if (!thumbnail.capture?.hasContent)
                return;
            thumbnail.hasCachedFrame = true;
            // With live=false refresh the frozen texture exactly once.
            Qt.callLater(() => cachedFrame.scheduleUpdate());
        }
    }

    Text {
        anchors.centerIn: parent
        visible: !thumbnail.hasCachedFrame
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
