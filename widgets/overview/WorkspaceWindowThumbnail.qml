pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import Quickshell.Wayland
import "../../core"

// Геометрия миниатюры принадлежит самому delegate, без размерного Loader.
Rectangle {
    id: thumbnail

    required property var toplevel
    required property var monitor
    required property var monitorGeometry
    required property int workspaceId
    property bool captureEnabled: true
    readonly property var capture: snapshotLoader.item
    property bool hasCachedFrame: false
    property bool captureRebuildQueued: false
    property bool retryUsed: false
    property bool captureFailed: false
    property bool awaitingFreshFrame: false
    property int previewRefreshGeneration: 0
    // true, пока WorkspaceService стабилизирует геометрию после переноса:
    // перезахват кадров ждёт сигнала settled (через previewRefreshGeneration),
    // а не идёт на каждый промежуточный размер.
    property bool suspendRebuild: false
    readonly property string toplevelAddress: {
        const address = String(toplevel?.address ?? "").replace(/^0x/i, "");
        return /^[0-9a-f]+$/i.test(address) ? "0x" + address.toLowerCase() : "";
    }

    signal dragStarted(var toplevel, int workspaceId)
    signal dragEnded()
    signal dragMoved(var source, real pointerX, real pointerY)
    signal dragReleased(var source, real pointerX, real pointerY)
    signal clicked()
    signal hoverChanged(bool hovered)
    // Emitted only for a frame from a context recreated after IPC geometry or
    // workspace metadata changed. The overview uses it to reveal its dimmed
    // target card; an existing cached texture never counts as a fresh frame.
    signal freshFrameReady(string address, int workspaceId)
    signal freshFrameUnavailable(string address, int workspaceId)

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
    radius: Metrics.panelRadius
    clip: true
    // Снимок сам задаёт вид окна; белая стеклянная подложка искажала
    // прозрачные окна, особенно в drag-копии.
    color: Theme.transparentColor
    border.width: 0
    border.color: Theme.borderColor
    Item {
        id: thumbnailMask
        visible: false
        layer.enabled: true
        anchors.fill: parent

        Rectangle {
            anchors.fill: parent
            radius: Metrics.panelRadius
            color: Theme.shadowMaskColor
            antialiasing: true
        }
    }

    // A window created/resized while the overview is open can reject its
    // initial export. Geometry and workspace hooks retry without polling.
    function recoverMissingCapture() {
        if ((!captureFailed && capture?.hasContent) || !toplevel?.wayland || !parent)
            return;
        retryUsed = false;
        queueCaptureRebuild();
    }

    // Runs after the current IPC/QML change batch, not after a time delay.
    // This coalesces workspace, geometry and parent updates into one export.
    function queueCaptureRebuild() {
        if (captureRebuildQueued)
            return;
        // Ignore a late hasContent from the previous context. Only the
        // context created by this queued rebuild may complete the workspace
        // reveal handshake.
        awaitingFreshFrame = false;
        captureRebuildQueued = true;
        Qt.callLater(() => {
            captureRebuildQueued = false;
            rebuildCapture();
        });
    }

    function requestFreshCapture() {
        retryUsed = false;
        queueCaptureRebuild();
    }

    // Opens a fresh toplevel-export context. Keep the last texture available
    // as a fallback; the card itself is dimmed while this export is pending.
    function rebuildCapture() {
        if (!toplevel?.wayland || !parent) {
            // Без export-handle кадра не будет. Сообщаем overview, иначе
            // карточка осталась бы затемнённой до закрытия.
            freshFrameUnavailable(toplevelAddress, workspaceId);
            return;
        }
        awaitingFreshFrame = true;
        captureFailed = false;
        captureEnabled = false;
        Qt.callLater(() => thumbnail.captureEnabled = true);
    }

    // Размер окна меняется много раз подряд, пока идёт анимация раскладки.
    // Перезахват откладывается до паузы в изменениях. Во время переноса он
    // вообще не запускается: после settled его вызовет previewRefreshGeneration.
    Timer {
        id: geometryDebounce
        interval: 160
        repeat: false
        onTriggered: thumbnail.requestFreshCapture()
    }

    function scheduleGeometryRebuild() {
        if (suspendRebuild)
            return;
        geometryDebounce.restart();
    }

    onSourceWidthChanged: scheduleGeometryRebuild()
    onSourceHeightChanged: scheduleGeometryRebuild()
    onWorkspaceIdChanged: Qt.callLater(() => {
        if (!thumbnail.suspendRebuild)
            thumbnail.requestFreshCapture();
    })
    onPreviewRefreshGenerationChanged: {
        if (previewRefreshGeneration > 0)
            requestFreshCapture();
    }

    // Metadata changes may arrive after the export was rejected, even when
    // width/height themselves did not change. No periodic retries are needed.
    Connections {
        target: thumbnail.toplevel
        function onLastIpcObjectChanged() { Qt.callLater(thumbnail.recoverMissingCapture); }
        function onWaylandHandleChanged() { Qt.callLater(thumbnail.recoverMissingCapture); }
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
                    // The workspace canvas supplies the compositor geometry.
                    // A stale export is hidden by the workspace dimmer while
                    // a fresh frame is pending; a confirmed frame must fill
                    // the new long/short rectangle instead of being letterboxed.
                    anchors.fill: parent
                    captureSource: thumbnail.toplevel?.wayland ?? null
                    constraintSize: Qt.size(320, 180)
                    paintCursor: false
                    live: false
                }
            }
        }
    }

    // Static exports avoid retaining a source-workspace frame after a move.
    ShaderEffectSource {
        id: cachedFrame
        anchors.fill: parent
        sourceItem: captureSurface
        hideSource: true
        // Follow scene-graph updates of the single captured frame.
        // This does not enable streaming in ScreencopyView.
        live: !!thumbnail.capture?.hasContent && !thumbnail.captureFailed
        // MultiEffect ниже — единственный видимый вывод кадра. Сам source
        // скрыт, иначе прямоугольная версия была бы видна под маской.
        visible: false
        textureSize: Qt.size(Math.max(1, Math.ceil(width * 2)),
            Math.max(1, Math.ceil(height * 2)))
    }

    // MultiEffect является отдельным выводом, а не свойством исходного Item.
    // Явный source гарантирует, что скругляется texture cachedFrame, а не
    // только его контейнер.
    MultiEffect {
        anchors.fill: cachedFrame
        source: cachedFrame
        visible: thumbnail.hasCachedFrame
        maskEnabled: true
        maskSource: thumbnailMask
        // Нулевой порог с нулевой растушёвкой не отсекает alpha=0
        // надёжно. Порог внутри диапазона явно удаляет прозрачные углы,
        // а spread сохраняет сглаженный край маски.
        maskThresholdMin: 0.5
        maskSpreadAtMin: 1.0
    }

    Connections {
        target: thumbnail.capture

        function onHasContentChanged() {
            if (!thumbnail.capture?.hasContent)
                return;
            thumbnail.hasCachedFrame = true;
            if (thumbnail.awaitingFreshFrame) {
                thumbnail.awaitingFreshFrame = false;
                thumbnail.freshFrameReady(thumbnail.toplevelAddress,
                    thumbnail.workspaceId);
            }
            // With live=false refresh the frozen texture exactly once.
            Qt.callLater(() => cachedFrame.scheduleUpdate());
        }

        function onStopped() {
            thumbnail.captureFailed = true;
            if (!thumbnail.retryUsed) {
                thumbnail.retryUsed = true;
                thumbnail.queueCaptureRebuild();
                return;
            }
            console.warn("Overview capture unavailable:", thumbnail.toplevelAddress,
                "workspace", thumbnail.workspaceId, "cached", thumbnail.hasCachedFrame);
            if (thumbnail.awaitingFreshFrame) {
                thumbnail.awaitingFreshFrame = false;
                thumbnail.freshFrameUnavailable(thumbnail.toplevelAddress,
                    thumbnail.workspaceId);
            }
            // Preserve the last successful image if a fresh export failed.
            // A later metadata event or pointer entry can retry again.
        }
    }

    Text {
        anchors.centerIn: parent
        visible: !thumbnail.hasCachedFrame
        width: parent.width - 6
        text: String(thumbnail.toplevel?.title ?? I18n.tr("overview.windowFallback"))
        color: Theme.foregroundColor
        font.pixelSize: 10
        elide: Text.ElideRight
        horizontalAlignment: Text.AlignHCenter
    }

    DragSurface {
        id: pointer
        anchors.fill: parent
        onContainsMouseChanged: {
            thumbnail.hoverChanged(containsMouse);
            if (containsMouse) thumbnail.recoverMissingCapture();
        }
        onStarted: thumbnail.dragStarted(thumbnail.toplevel, thumbnail.workspaceId)
        onMoved: (x, y) => thumbnail.dragMoved(thumbnail, x, y)
        onDropped: (x, y) => thumbnail.dragReleased(thumbnail, x, y)
        onCanceledDrag: thumbnail.dragEnded()
        onTapped: thumbnail.clicked()
    }
    Rectangle {
        anchors.fill: parent
        color: Theme.transparentColor
        radius: Metrics.panelRadius
        border.width: pointer.containsMouse ? 2 : 0
        border.color: Theme.borderColor
    }
}
