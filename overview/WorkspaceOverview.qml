pragma ComponentBehavior: Bound

import QtQuick
import QtQml.Models
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import "../core"
import "../services"

// Ленивая overlay-поверхность: живёт только пока открыт overview.
PanelWindow {
    id: overview

    required property var targetScreen
    property int selectionIndex: 0
    property int pendingWorkspaceId: -1
    property bool draggingWindow: false
    property var draggedToplevel: null
    property int dragSourceWorkspaceId: -1
    property int dragTargetIndex: -1
    property point dragPosition: Qt.point(0, 0)
    property string dragKind: ""
    property int dragSourceIndex: -1
    property Item dragVisual: null
    property Item hoveredWindow: null
    // Список source/target карточек, которые временно показывают live export.
    property var livePreviewWorkspaceIds: []
    property var snapshotRefreshWorkspaceIds: []
    property int snapshotRefreshGeneration: 0
    // Ссылки нужны BackgroundEffect: region обновляется сразу после создания
    // или уничтожения delegate, без геометрического bounding-box всей сетки.
    property var cardItems: []
    property bool keyboardSelection: false
    property real reveal: 0
    // Не пересоздавать delegates между нажатием и отпусканием кнопки мыши.
    property var heldSlots: null
    readonly property var slots: heldSlots ?? WorkspaceService.slotsForScreen(
        String(targetScreen?.name ?? ""))

    signal dismissed()

    WallpaperSource { id: wallpapers }

    function holdSlots(held) {
        heldSlots = held ? slots : null;
    }

    function setCardItem(index, item) {
        const next = cardItems.slice();
        next[index] = item;
        cardItems = next;
    }

    // Capture ownership follows the toplevel, not a workspace's JS array.
    // Reparenting preserves the captured buffer even while Hyprland resizes
    // the moved window and cannot yet export another frame.
    Instantiator {
        model: Hyprland.toplevels
        delegate: WorkspaceWindowThumbnail {
            id: windowThumbnail
            required property var modelData
            readonly property var card: overview.cardItems.find(item =>
                item?.modelData.workspaceId === workspaceId) ?? null
            parent: card?.previewCanvas ?? null
            visible: card !== null
            toplevel: modelData
            monitor: card?.modelData.monitor ?? null
            monitorGeometry: card?.monitorGeometry ?? { x: 0, y: 0, width: 1, height: 1 }
            workspaceId: modelData.workspace?.id ?? -1
            liveCapture: overview.livePreviewWorkspaceIds.includes(workspaceId)
            snapshotRefreshWorkspaceIds: overview.snapshotRefreshWorkspaceIds
            snapshotRefreshGeneration: overview.snapshotRefreshGeneration
            enabled: !WorkspaceService.busy
            z: 1000 - (modelData.lastIpcObject?.focusHistoryID ?? 0)
            onHoverChanged: hovered => {
                overview.keyboardSelection = false;
                if (hovered) overview.hoveredWindow = windowThumbnail;
                else if (overview.hoveredWindow === windowThumbnail) overview.hoveredWindow = null;
            }
            onInteractionChanged: held => overview.holdSlots(held)
            onClicked: { if (card) overview.requestWorkspace(card.index); }
            onDragStarted: (toplevel, workspaceId) =>
                overview.beginWindowDrag(toplevel, workspaceId, windowThumbnail)
            onDragEnded: overview.endWindowDrag()
            onDragMoved: (source, pointerX, pointerY) =>
                overview.updateWindowDropTarget(source, pointerX, pointerY)
            onDragReleased: (source, pointerX, pointerY) =>
                overview.finishWindowDrag(source, pointerX, pointerY)
        }
    }

    screen: targetScreen
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    color: Theme.transparentColor
    focusable: true
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "aerix:workspace-overview"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    mask: Region { item: backdrop }
    // Hyprland применяет blur только к десяти карточкам, а не к экранному
    // backdrop. Region хранит объединение прямоугольников карточек.
    BackgroundEffect.blurRegion: Region {
        Region { item: overview.cardItems[0] ?? null; radius: Metrics.panelRadius }
        Region { item: overview.cardItems[1] ?? null; radius: Metrics.panelRadius }
        Region { item: overview.cardItems[2] ?? null; radius: Metrics.panelRadius }
        Region { item: overview.cardItems[3] ?? null; radius: Metrics.panelRadius }
        Region { item: overview.cardItems[4] ?? null; radius: Metrics.panelRadius }
        Region { item: overview.cardItems[5] ?? null; radius: Metrics.panelRadius }
        Region { item: overview.cardItems[6] ?? null; radius: Metrics.panelRadius }
        Region { item: overview.cardItems[7] ?? null; radius: Metrics.panelRadius }
        Region { item: overview.cardItems[8] ?? null; radius: Metrics.panelRadius }
        Region { item: overview.cardItems[9] ?? null; radius: Metrics.panelRadius }
    }

    function close() {
        pendingWorkspaceId = -1;
        dismissed();
    }

    function selectIndex(index) {
        if (index < 0 || index >= slots.length)
            return;
        selectionIndex = index;
    }

    function moveSelection(delta) {
        keyboardSelection = true;
        selectIndex(Math.max(0, Math.min(slots.length - 1,
            selectionIndex + delta)));
    }

    function requestWorkspace(index) {
        const slot = slots[index];
        if (!slot || pendingWorkspaceId >= 0 || WorkspaceService.busy)
            return;
        if (Hyprland.focusedWorkspace?.id === slot.workspaceId) {
            close();
            return;
        }
        selectionIndex = index;
        if (WorkspaceService.activateWorkspace(slot.workspaceId))
            pendingWorkspaceId = slot.workspaceId;
    }

    function selectLabel(label) {
        const normalizedLabel = label === "0" ? "10" : label;
        const index = slots.findIndex(slot => slot.label === normalizedLabel);
        if (index >= 0)
            requestWorkspace(index);
    }

    function beginWindowDrag(toplevel, workspaceId, visual) {
        if (WorkspaceService.busy || !toplevel)
            return;
        draggingWindow = true;
        draggedToplevel = toplevel;
        dragSourceWorkspaceId = workspaceId;
        dragTargetIndex = -1;
        dragKind = "window";
        dragVisual = visual;
        dragPosition = Qt.point(-1000, -1000);
    }

    function endWindowDrag() {
        draggingWindow = false;
        draggedToplevel = null;
        dragSourceWorkspaceId = -1;
        dragTargetIndex = -1;
        dragKind = "";
        dragSourceIndex = -1;
        dragVisual = null;
    }

    function beginWorkspaceDrag(index) {
        if (WorkspaceService.busy || index < 0 || index >= slots.length)
            return;
        draggingWindow = true;
        dragKind = "workspace";
        dragSourceIndex = index;
        dragSourceWorkspaceId = slots[index].workspaceId;
        // Берём только полотно: стеклянная карточка не должна становиться
        // непрозрачной подложкой у drag-копии.
        dragVisual = cardRepeater.itemAt(index)?.previewCanvas ?? null;
        dragTargetIndex = -1;
        dragPosition = Qt.point(-1000, -1000);
    }

    function swapWorkspaces(targetIndex) {
        if (dragKind !== "workspace" || dragSourceIndex < 0
            || targetIndex < 0 || targetIndex === dragSourceIndex)
            return;
        WorkspaceService.swapWorkspaces(slots[dragSourceIndex], slots[targetIndex]);
    }

    function moveWindow(toplevel, targetIndex) {
        const target = slots[targetIndex];
        if (!toplevel || !target || WorkspaceService.busy
            || toplevel.workspace?.id === target.workspaceId)
            return;
        WorkspaceService.moveWindow(toplevel.address, target.workspaceId);
    }

    function cardIndexAt(source, pointerX, pointerY) {
        const point = source.mapToItem(grid, pointerX, pointerY);
        for (let index = 0; index < cardRepeater.count; index++) {
            const card = cardRepeater.itemAt(index);
            if (card && point.x >= card.x && point.x <= card.x + card.width
                && point.y >= card.y && point.y <= card.y + card.height)
                return index;
        }
        return -1;
    }

    function updateWindowDropTarget(source, pointerX, pointerY) {
        if (!draggingWindow)
            return;
        dragPosition = source.mapToItem(focusScope, pointerX, pointerY);
        const index = cardIndexAt(source, pointerX, pointerY);
        dragTargetIndex = index >= 0 && slots[index].workspaceId !== dragSourceWorkspaceId
            ? index : -1;
    }

    function finishWindowDrag(source, pointerX, pointerY) {
        if (!draggingWindow)
            return;
        const index = cardIndexAt(source, pointerX, pointerY);
        if (index >= 0) {
            if (dragKind === "workspace")
                swapWorkspaces(index);
            else
                moveWindow(draggedToplevel, index);
        }
        endWindowDrag();
    }

    Component.onCompleted: {
        Hyprland.refreshToplevels();
        focusScope.forceActiveFocus();
        revealAnimation.start();
    }

    NumberAnimation {
        id: revealAnimation
        target: overview
        property: "reveal"
        from: 0
        to: 1
        duration: Motion.surfaceSpring.durationMs
        easing.type: Motion.surfaceSpring.easingType
        easing.bezierCurve: Motion.surfaceSpring.bezierCurve
    }

    // Hyprland не предоставляет события "анимация workspace закончена".
    // Это намеренно короткое окно живого рендера после подтверждённого DnD;
    // новое подтверждение перезапускает отсчёт. Затем ScreencopyView хранит
    // последний кадр и больше не производит экспорт каждый frame.
    Timer {
        id: livePreviewTimer
        interval: 1024
        repeat: false
        onTriggered: {
            const affectedWorkspaceIds = overview.livePreviewWorkspaceIds;
            overview.livePreviewWorkspaceIds = [];
            // A moved toplevel invalidates the previous Hyprland export
            // context. Recreate it only after the compositor had the live
            // window to finish the workspace animation.
            overview.snapshotRefreshWorkspaceIds = affectedWorkspaceIds;
            overview.snapshotRefreshGeneration++;
        }
    }

    // Hyprland не публикует отдельное событие для каждого изменения at/size.
    // Обновляем геометрию только пока существует lazy overview; после
    // закрытия таймер уничтожается вместе с окном. Захват остаётся однокадровым.
    Timer {
        interval: 500
        running: overview.heldSlots === null && !overview.draggingWindow && !WorkspaceService.busy
        repeat: true
        onTriggered: {
            Hyprland.refreshToplevels();
            WorkspaceService.refreshSlots();
        }
    }

    Connections {
        target: Hyprland

        function onFocusedWorkspaceChanged() {
            if (overview.pendingWorkspaceId >= 0
                && Hyprland.focusedWorkspace?.id === overview.pendingWorkspaceId)
                overview.close();
        }
    }

    Connections {
        target: WorkspaceService

        function onPreviewLiveRequested(workspaceIds) {
            if (!workspaceIds?.length)
                return;
            overview.livePreviewWorkspaceIds = workspaceIds;
            livePreviewTimer.restart();
        }
    }

    Rectangle {
        id: backdrop
        anchors.fill: parent
        color: Theme.overviewScrimColor
        opacity: Math.max(0, Math.min(1, overview.reveal))
    }

    MouseArea {
        anchors.fill: parent
        onClicked: overview.close()
    }

    FocusScope {
        id: focusScope
        anchors.fill: parent
        focus: true

        Keys.onPressed: event => {
            if (event.key === Qt.Key_Escape) {
                if (overview.draggingWindow)
                    overview.endWindowDrag();
                else
                    overview.close();
            } else if (event.key === Qt.Key_Left) {
                overview.moveSelection(-1);
            } else if (event.key === Qt.Key_Right) {
                overview.moveSelection(1);
            } else if (event.key === Qt.Key_Up) {
                overview.moveSelection(-5);
            } else if (event.key === Qt.Key_Down) {
                overview.moveSelection(5);
            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                overview.requestWorkspace(overview.selectionIndex);
            } else if (event.key >= Qt.Key_0 && event.key <= Qt.Key_9) {
                overview.selectLabel(String(event.key - Qt.Key_0));
            } else {
                return;
            }
            event.accepted = true;
        }

        Item {
            id: gridArea
            anchors.centerIn: parent
            width: Math.min(parent.width - 2 * Metrics.spacing,
                Math.max(320, parent.width * 0.82))
            height: 2 * ((width - 4 * Metrics.spacing) / 5 * 9 / 16
                + 84) + Metrics.spacing
            transformOrigin: Item.Center
            scale: Motion.surfaceSpring.startScale
                + (1 - Motion.surfaceSpring.startScale) * overview.reveal
            opacity: Math.max(0, Math.min(1, overview.reveal))

            Grid {
                id: grid
                anchors.fill: parent
                columns: 5
                rows: 2
                spacing: Metrics.spacing

                Repeater {
                    id: cardRepeater
                    model: overview.slots

                    onItemAdded: (index, item) => overview.setCardItem(index, item)
                    onItemRemoved: (index, item) => overview.setCardItem(index, null)

                    delegate: Rectangle {
                        id: card
                        required property var modelData
                        required property int index
                        width: (grid.width - (grid.columns - 1) * grid.spacing)
                            / grid.columns
                        height: (grid.height - grid.spacing) / 2
                        radius: Metrics.panelRadius
                        // Такая же стеклянная поверхность, как Dock и popup.
                        color: Theme.floatingSurfaceBackgroundColor
                        border.width: overview.dragTargetIndex === index
                            || (!overview.draggingWindow && !overview.hoveredWindow
                                && (cardHover.hovered || (overview.keyboardSelection
                                    && overview.selectionIndex === index))) ? 2 : 0
                        border.color: Theme.selectionOutlineColor
                        opacity: overview.pendingWorkspaceId >= 0
                            && overview.pendingWorkspaceId !== modelData.workspaceId ? 0.65 : 1

                        readonly property var monitorGeometry: WorkspaceService.monitorGeometry(
                            modelData.monitor ?? Hyprland.monitorFor(overview.targetScreen))
                        readonly property var wallpaper: wallpapers.backgroundFor(
                            modelData.monitorName || String(overview.targetScreen?.name ?? ""))
                        readonly property Item previewCanvas: workspaceCanvas

                        // Тень строится кольцом: центр вырезан маской и не
                        // затемняет стеклянную поверхность самой карточки.
                        PanelShadow {
                            sourceItem: card
                            z: -1
                        }

                        // Фон/подпись перетаскивает workspace; миниатюры выше
                        // самостоятельно захватывают жест переноса окна.
                        DragSurface {
                            id: workspacePointer
                            anchors.fill: parent
                            enabled: !WorkspaceService.busy
                            onInteractionChanged: held => overview.holdSlots(held)
                            onStarted: overview.beginWorkspaceDrag(card.index)
                            onMoved: (x, y) => overview.updateWindowDropTarget(workspacePointer, x, y)
                            onDropped: (x, y) => overview.finishWindowDrag(workspacePointer, x, y)
                            onCanceledDrag: overview.endWindowDrag()
                            onTapped: overview.requestWorkspace(card.index)
                        }

                        Rectangle {
                            id: workspaceCanvas
                            anchors.horizontalCenter: parent.horizontalCenter
                            y: 44
                            width: Math.min(parent.width - 2 * Metrics.spacing,
                                (parent.height - 84) * card.monitorGeometry.width
                                / card.monitorGeometry.height)
                            height: width * card.monitorGeometry.height
                                / card.monitorGeometry.width
                            color: card.wallpaper.color !== "transparent"
                                ? card.wallpaper.color : Theme.desktopBackgroundColor
                            radius: Math.max(2, Metrics.panelRadius - 2)
                            clip: true

                            Image {
                                anchors.fill: parent
                                source: card.wallpaper.image
                                sourceSize.width: Math.ceil(workspaceCanvas.width * (card.modelData.monitor?.scale ?? 1.25))
                                sourceSize.height: Math.ceil(workspaceCanvas.height * (card.modelData.monitor?.scale ?? 1.25))
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                            }

                            Text {
                                anchors.centerIn: parent
                                visible: card.modelData.windows.length === 0
                                text: "Пусто"
                                color: Theme.glassTextColor
                                opacity: 0.72
                                font.pixelSize: 14
                            }
                        }

                        Text {
                            anchors.left: parent.left
                            anchors.leftMargin: Metrics.spacing
                            anchors.top: parent.top
                            anchors.topMargin: 6
                            text: card.modelData.label
                            color: Theme.glassTextColor
                            font.pixelSize: 22
                            font.weight: Font.DemiBold
                        }

                        Text {
                            anchors.left: parent.left
                            anchors.leftMargin: Metrics.spacing
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: Metrics.spacing
                            anchors.right: parent.right
                            anchors.rightMargin: Metrics.spacing
                            text: card.modelData.monitorName.length > 0
                                ? card.modelData.monitorName : "Не создан"
                            color: Theme.glassTextColor
                            opacity: 0.72
                            font.pixelSize: 12
                            elide: Text.ElideRight
                        }

                        HoverHandler {
                            id: cardHover
                            onHoveredChanged: {
                                if (hovered) {
                                    overview.keyboardSelection = false;
                                    overview.selectIndex(card.index);
                                }
                            }
                        }

                    }
                }
            }
        }
        Rectangle {
            visible: overview.draggingWindow
            x: overview.dragPosition.x + 16
            y: overview.dragPosition.y + 16
            width: Math.max(1, (overview.dragVisual?.width ?? 1) * 0.65)
            height: Math.max(1, (overview.dragVisual?.height ?? 1) * 0.65)
            radius: Math.max(2, Metrics.panelRadius * 0.65)
            // Не подкрашивать копию: особенно важно для прозрачных окон.
            color: Theme.transparentColor
            clip: true
            border.width: 1
            border.color: Theme.selectionOutlineColor
            ShaderEffectSource {
                anchors.fill: parent
                anchors.margins: 1
                sourceItem: overview.dragVisual
                textureSize: Qt.size(Math.max(1, width * 2), Math.max(1, height * 2))
                live: false
                hideSource: false
                onSourceItemChanged: scheduleUpdate()
            }
        }
        Text {
            anchors.bottom: parent.bottom
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottomMargin: Metrics.spacing * 3
            text: WorkspaceService.busy ? "Перенос…" : WorkspaceService.operationError
            color: WorkspaceService.operationError ? Theme.errorColor : Theme.glassTextColor
        }
    }
}
