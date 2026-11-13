pragma ComponentBehavior: Bound

import QtQuick
import QtQml.Models
import QtQuick.Effects
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
    // Ссылки нужны BackgroundEffect: region обновляется сразу после создания
    // или уничтожения delegate, без геометрического bounding-box всей сетки.
    property var cardItems: []
    property bool keyboardSelection: false
    property real reveal: 0
    // WorkspaceService.slots — стабильный массив из десяти долгоживущих
    // объектов, delegates не пересоздаются при IPC-обновлениях.
    readonly property var slots: WorkspaceService.slots

    // Раскладка карточек. blurRegion ниже перечисляет ровно columns * rows
    // карточек; при изменении сетки обнови и его.
    readonly property int columns: 5
    readonly property int rows: 2
    readonly property real cardHeaderHeight: 44
    readonly property real cardFooterHeight: 40
    // Не совпадает с id workspace: именованные и special имеют отрицательные id.
    readonly property int noWorkspaceId: -1000000

    signal dismissed()

    WallpaperSource { id: wallpapers }

    // Сбрасывает ожидание подтверждения переключения, если compositor не
    // прислал focusedWorkspaceChanged (например, отклонил dispatch).
    Timer {
        id: workspaceWatchdog
        interval: 1500
        repeat: false
        onTriggered: overview.pendingWorkspaceId = -1
    }

    // The model can retain one toplevel object while changing its properties.
    // These hooks confirm moves without polling the compositor.
    Instantiator {
        model: Hyprland.toplevels
        delegate: Connections {
            required property var modelData
            target: modelData

            function onWorkspaceChanged() {
                WorkspaceService.scheduleSync();
            }

            function onLastIpcObjectChanged() {
                WorkspaceService.scheduleSync();
            }
        }
    }

    // Сохраняет ссылку на delegate карточки для точного blur-region.
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
            workspaceId: modelData.workspace?.id ?? overview.noWorkspaceId
            enabled: !WorkspaceService.busy
            // Floating-окна Hyprland рисует поверх тайловых.
            z: (modelData.lastIpcObject?.floating ? 5000 : 0)
                + 1000 - (modelData.lastIpcObject?.focusHistoryID ?? 0)
            onHoverChanged: hovered => {
                overview.keyboardSelection = false;
                if (hovered) overview.hoveredWindow = windowThumbnail;
                else if (overview.hoveredWindow === windowThumbnail) overview.hoveredWindow = null;
            }
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

    // Закрывает overview и отменяет локальное ожидание смены workspace.
    function close() {
        pendingWorkspaceId = -1;
        dismissed();
    }

    // Устанавливает индекс карточки, если он попадает в текущую сетку.
    function selectIndex(index) {
        if (index < 0 || index >= slots.length)
            return;
        selectionIndex = index;
    }

    // Смещает keyboard-фокус по сетке, не выходя за её границы.
    function moveSelection(delta) {
        keyboardSelection = true;
        selectIndex(Math.max(0, Math.min(slots.length - 1,
            selectionIndex + delta)));
    }

    // Активирует workspace выбранной карточки и ждёт compositor-подтверждение.
    function requestWorkspace(index) {
        const slot = slots[index];
        if (!slot || pendingWorkspaceId >= 0 || WorkspaceService.busy)
            return;
        if (Hyprland.focusedWorkspace?.id === slot.workspaceId) {
            close();
            return;
        }
        selectionIndex = index;
        if (WorkspaceService.activateWorkspace(slot.workspaceId)) {
            pendingWorkspaceId = slot.workspaceId;
            workspaceWatchdog.restart();
        }
    }

    // Преобразует цифровую клавишу в подпись карточки (0 соответствует 10).
    function selectLabel(label) {
        const normalizedLabel = label === "0" ? "10" : label;
        const index = slots.findIndex(slot => slot.label === normalizedLabel);
        if (index >= 0)
            requestWorkspace(index);
    }

    // Начинает перенос окна и запоминает источник для drag-копии.
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

    // Сбрасывает всё временное состояние переноса окна или workspace.
    function endWindowDrag() {
        draggingWindow = false;
        draggedToplevel = null;
        dragSourceWorkspaceId = -1;
        dragTargetIndex = -1;
        dragKind = "";
        dragSourceIndex = -1;
        dragVisual = null;
    }

    // Начинает перенос workspace; drag-копия содержит только его canvas.
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

    // Меняет содержимое двух карточек местами через WorkspaceService.
    function swapWorkspaces(targetIndex) {
        if (dragKind !== "workspace" || dragSourceIndex < 0
            || targetIndex < 0 || targetIndex === dragSourceIndex)
            return;
        const source = slots[dragSourceIndex];
        const target = slots[targetIndex];
        WorkspaceService.swapWorkspaces(source, target);
    }

    // Переносит окно в workspace целевой карточки, если он отличается от текущего.
    function moveWindow(toplevel, targetIndex) {
        const target = slots[targetIndex];
        if (!toplevel || !target || WorkspaceService.busy
            || toplevel.workspace?.id === target.workspaceId)
            return;
        WorkspaceService.moveWindow(toplevel.address, target.workspaceId);
    }

    // Возвращает индекс карточки, расположенной под координатами drag-жеста.
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

    // Перемещает drag-копию и подсвечивает допустимую целевую карточку.
    function updateWindowDropTarget(source, pointerX, pointerY) {
        if (!draggingWindow)
            return;
        dragPosition = source.mapToItem(focusScope, pointerX, pointerY);
        const index = cardIndexAt(source, pointerX, pointerY);
        dragTargetIndex = index >= 0 && slots[index].workspaceId !== dragSourceWorkspaceId
            ? index : -1;
    }

    // Завершает жест: запускает перенос при попадании в карточку и очищает state.
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
        WorkspaceService.acquire();
        if (slots.length !== columns * rows)
            console.warn("Overview: slots =", slots.length, "but grid is",
                columns, "x", rows, "- update blurRegion and grid constants");
        Hyprland.refreshToplevels();
        focusScope.forceActiveFocus();
        revealAnimation.start();
    }

    Component.onDestruction: WorkspaceService.release()

    NumberAnimation {
        id: revealAnimation
        target: overview
        property: "reveal"
        from: 0
        to: 1
        duration: Motion.spring.durationMs
        easing.type: Motion.spring.easingType
        easing.bezierCurve: Motion.spring.bezierCurve
    }

    Connections {
        target: Hyprland

        function onFocusedWorkspaceChanged() {
            if (overview.pendingWorkspaceId >= 0
                && Hyprland.focusedWorkspace?.id === overview.pendingWorkspaceId)
                overview.close();
        }
    }

    Rectangle {
        id: backdrop
        anchors.fill: parent
        color: Theme.overlayColor
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
                overview.moveSelection(-overview.columns);
            } else if (event.key === Qt.Key_Down) {
                overview.moveSelection(overview.columns);
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
            height: overview.rows * ((width - (overview.columns - 1) * Metrics.spacing)
                / overview.columns * 9 / 16
                + overview.cardHeaderHeight + overview.cardFooterHeight)
                + (overview.rows - 1) * Metrics.spacing
            transformOrigin: Item.Center
            scale: Motion.spring.startScale
                + (1 - Motion.spring.startScale) * overview.reveal
            opacity: Math.max(0, Math.min(1, overview.reveal))

            Grid {
                id: grid
                anchors.fill: parent
                columns: overview.columns
                rows: overview.rows
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
                        height: (grid.height - (overview.rows - 1) * grid.spacing)
                            / overview.rows
                        radius: Metrics.panelRadius
                        color: Theme.backgroundColor
                        border.width: overview.dragTargetIndex === index
                            || (!overview.draggingWindow && !overview.hoveredWindow
                                && (cardHover.hovered || (overview.keyboardSelection
                                    && overview.selectionIndex === index))) ? 2 : 0
                        border.color: Theme.borderColor
                        opacity: overview.pendingWorkspaceId >= 0
                            && overview.pendingWorkspaceId !== modelData.workspaceId ? 0.65 : 1

                        readonly property var monitorGeometry: WorkspaceService.monitorGeometry(
                            modelData.monitor ?? Hyprland.monitorFor(overview.targetScreen))
                        readonly property real monitorScale: monitorGeometry.scale
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
                            onStarted: overview.beginWorkspaceDrag(card.index)
                            onMoved: (x, y) => overview.updateWindowDropTarget(workspacePointer, x, y)
                            onDropped: (x, y) => overview.finishWindowDrag(workspacePointer, x, y)
                            onCanceledDrag: overview.endWindowDrag()
                            onTapped: overview.requestWorkspace(card.index)
                        }

                        Rectangle {
                            id: workspaceCanvas
                            anchors.horizontalCenter: parent.horizontalCenter
                            y: overview.cardHeaderHeight
                            width: Math.min(parent.width - 2 * Metrics.spacing,
                                (parent.height - overview.cardHeaderHeight
                                    - overview.cardFooterHeight)
                                * card.monitorGeometry.width
                                / card.monitorGeometry.height)
                            height: width * card.monitorGeometry.height
                                / card.monitorGeometry.width
                            color: card.wallpaper.color !== "transparent"
                                ? card.wallpaper.color : Theme.desktopBackgroundColor
                            radius: Math.max(2, Metrics.panelRadius - 2)
                            // QQuickItem.clip is rectangular. Единственная маска
                            // на весь холст скругляет обои и все экспорты окон;
                            // отдельных слоёв на каждое окно больше нет.
                            layer.enabled: true
                            layer.effect: MultiEffect {
                                maskEnabled: true
                                maskSource: canvasMask
                            }

                            // Обои — отдельный нижний слой workspace. Он
                            // создаётся раньше динамических миниатюр, поэтому
                            // те располагаются выше без ручного z-index.
                            // Это ровно один закэшированный texture-layer на
                            // workspace, а не отдельная загрузка под окно.
                            Item {
                                id: wallpaperLayer
                                anchors.fill: parent
                                layer.enabled: true

                                Image {
                                    anchors.fill: parent
                                    source: card.wallpaper.image
                                    cache: true
                                    sourceSize.width: Math.ceil(
                                        workspaceCanvas.width * card.monitorScale)
                                    sourceSize.height: Math.ceil(
                                        workspaceCanvas.height * card.monitorScale)
                                    fillMode: Image.PreserveAspectCrop
                                    asynchronous: true
                                }
                            }

                            Text {
                                anchors.centerIn: parent
                                visible: card.modelData.windows.length === 0
                                text: I18n.tr("overview.empty")
                                color: Theme.foregroundColor
                                opacity: 0.72
                                font.pixelSize: 14
                            }

                        }

                        // Источник маски для MultiEffect: скрытый слой того же
                        // размера, что и холст.
                        Item {
                            id: canvasMask
                            visible: false
                            layer.enabled: true
                            width: workspaceCanvas.width
                            height: workspaceCanvas.height

                            Rectangle {
                                anchors.fill: parent
                                radius: workspaceCanvas.radius
                                color: Theme.shadowMaskColor
                            }
                        }

                        Text {
                            anchors.left: parent.left
                            anchors.leftMargin: Metrics.spacing
                            anchors.top: parent.top
                            anchors.topMargin: 6
                            text: card.modelData.label
                            color: Theme.foregroundColor
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
                                ? card.modelData.monitorName : I18n.tr("overview.notCreated")
                            color: Theme.foregroundColor
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
            width: Math.max(72, (overview.dragVisual?.width ?? 1) * 0.65)
            height: Math.max(44, (overview.dragVisual?.height ?? 1) * 0.65)
            radius: Math.max(2, Metrics.panelRadius * 0.65)
            // Не подкрашивать копию: особенно важно для прозрачных окон.
            color: Theme.transparentColor
            clip: true
            border.width: 1
            border.color: Theme.borderColor
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
            text: WorkspaceService.busy ? I18n.tr("overview.moving")
                                        : I18n.tr(WorkspaceService.operationErrorKey)
            color: WorkspaceService.operationErrorKey ? Theme.accentColor : Theme.foregroundColor
        }
    }
}
