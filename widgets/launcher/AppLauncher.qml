pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import "../../core"
import "../../services"

// Overlay и стеклянная панель разделены на surface, чтобы blur работал у обоих.
Scope {
    id: launcher

    required property var targetScreen
    property real reveal: 0
    property string searchQuery: ""
    property string openFolderId: ""
    property var gridItems: []
    property ListModel gridModel: ListModel { dynamicRoles: true }
    property var displayGridItems: []
    property var folderGridItems: []
    property bool draggingIcon: false
    property var draggedItem: null
    property string draggedIconSource: ""
    property point dragPosition: Qt.point(-1000, -1000)
    property int dragInsertionIndex: -1
    property var dragIconTarget: null
    property string landingItemKey: ""

    signal dismissed()

    function close() {
        dismissed();
    }

    function itemName(item) {
        return item?.type === "folder" ? item.name
            : String(item?.entry?.name ?? "");
    }

    function itemIconSource(item) {
        const iconName = item?.type === "folder" ? "folder"
            : String(item?.entry?.icon ?? "");
        if (!iconName)
            return "";
        if (iconName.startsWith("/"))
            return "file://" + iconName;
        return Quickshell.hasThemeIcon(iconName)
            ? Quickshell.iconPath(iconName) : "";
    }

    function filteredItems(items) {
        const query = searchQuery.trim().toLocaleLowerCase();
        return query.length === 0 ? items : items.filter(item =>
            itemName(item).toLocaleLowerCase().includes(query));
    }

    function refreshGridItems(preserveScroll) {
        if (draggingIcon)
            return;
        if (preserveScroll && appGrid)
            appGrid.restoreY = appGrid.contentY;
        gridItems = filteredItems(AppLauncherService.presentationItems(""));
        updateGridModel(gridItems);
        rebuildDisplayGridItems();
        if (preserveScroll && appGrid)
            Qt.callLater(appGrid.restoreAfterModelChange);
    }

    // В отличие от JS-массива, ListModel сообщает GridView о точечном move,
    // insert и remove. Делегаты сохраняются, поэтому drop не мигает всей сеткой.
    function updateGridModel(items) {
        for (let index = 0; index < items.length; index++) {
            const next = items[index];
            let current = -1;
            for (let candidate = index; candidate < gridModel.count; candidate++) {
                if (gridModel.get(candidate).key === next.key) {
                    current = candidate;
                    break;
                }
            }
            if (current < 0)
                gridModel.insert(index, { key: next.key, launcherItem: next });
            else {
                if (current !== index)
                    gridModel.move(current, index, 1);
                gridModel.set(index, { key: next.key, launcherItem: next });
            }
        }
        while (gridModel.count > items.length)
            gridModel.remove(items.length);
    }

    function refreshFolderItems() {
        folderGridItems = AppLauncherService.presentationItems(openFolderId);
    }

    // Preview описывает пустой слот и позиции соседей, но не заменяет модель
    // GridView: MouseArea источника должна сохранять grab до отпускания.
    function rebuildDisplayGridItems() {
        if (!draggingIcon || !draggedItem) {
            displayGridItems = gridItems;
            return;
        }
        const sourceIndex = gridItems.findIndex(item =>
            item.key === draggedItem.key);
        const items = gridItems.slice();
        if (sourceIndex >= 0)
            items.splice(sourceIndex, 1);
        const insertion = Math.max(0, Math.min(items.length,
            dragInsertionIndex - (sourceIndex >= 0 && sourceIndex < dragInsertionIndex ? 1 : 0)));
        items.splice(insertion, 0, {
            type: "placeholder",
            key: "drag-placeholder"
        });
        displayGridItems = items;
    }

    function beginIconDrag(item, iconSource, source, pointerX, pointerY) {
        if (openFolderId || searchQuery.trim() || !item)
            return;
        draggingIcon = true;
        draggedItem = item;
        draggedIconSource = iconSource;
        dragInsertionIndex = gridItems.findIndex(gridItem =>
            gridItem.key === item.key);
        dragIconTarget = null;
        rebuildDisplayGridItems();
        updateIconDrag(source, pointerX, pointerY);
    }

    function updateIconDrag(source, pointerX, pointerY) {
        if (!draggingIcon)
            return;
        dragPosition = source.mapToItem(launcherFocus, pointerX, pointerY);
        const target = dropTarget(source, pointerX, pointerY);
        dragIconTarget = target?.icon && target.item?.key !== draggedItem?.key
            ? target.item : null;
        // Drop на иконку уменьшит корневую модель: source уйдёт в папку или
        // станет её частью. Slot уходит в конец, поэтому все элементы после
        // source уже при hover сдвигаются в свои итоговые позиции.
        const insertion = target?.icon && target.item?.key !== draggedItem?.key
            ? gridItems.length : target?.insertionIndex;
        if (target && insertion !== dragInsertionIndex) {
            dragInsertionIndex = insertion;
            rebuildDisplayGridItems();
        }
    }

    function dropTarget(source, pointerX, pointerY) {
        const point = source.mapToItem(appGrid.contentItem, pointerX, pointerY);
        const first = appGrid.itemAtIndex(0);
        const left = first ? first.x : 0;
        const top = appGrid.originY;
        const column = Math.floor((point.x - left) / appGrid.cellWidth);
        const row = Math.floor((point.y - top) / appGrid.cellHeight);
        if (column < 0 || column >= Metrics.appLauncherColumns || row < 0)
            return null;
        if (row * Metrics.appLauncherColumns + column >= displayGridItems.length)
            return ({ item: {type: "placeholder", key: "end-slot"},
                insertionIndex: gridItems.length, icon: false });
        const visualIndex = Math.max(0, Math.min(displayGridItems.length - 1,
            row * Metrics.appLauncherColumns + column));
        const item = displayGridItems[visualIndex];
        const index = gridItems.findIndex(gridItem => gridItem.key === item?.key);
        if (item?.type === "placeholder")
            return ({ item: item, insertionIndex: dragInsertionIndex, icon: false });
        const tile = appGrid.itemAtIndex(index);
        if (!tile)
            return ({ item: item, insertionIndex: dragInsertionIndex, icon: false });
        const local = Qt.point(point.x - left - column * appGrid.cellWidth,
            point.y - top - row * appGrid.cellHeight);
        return {
            item: item,
            // Свободная левая/правая половина плитки означает позицию до/после
            // неё. Иконки не меняются местами: переносится только source.
            insertionIndex: index + (local.x >= tile.width / 2 ? 1 : 0),
            icon: local.x >= tile.iconDropLeft && local.x <= tile.iconDropRight
                && local.y >= tile.iconDropTop && local.y <= tile.iconDropBottom
        };
    }

    function finishIconDrag(source, pointerX, pointerY) {
        if (!draggingIcon)
            return;
        const panelPoint = source.mapToItem(appsSurface, pointerX, pointerY);
        if (panelPoint.x < 0 || panelPoint.y < 0
            || panelPoint.x > appsSurface.width || panelPoint.y > appsSurface.height) {
            endIconDrag();
            return;
        }
        const target = dropTarget(source, pointerX, pointerY);
        if (!target) {
            endIconDrag();
            return;
        }
        // Обновляем модель после onReleased, сохраняя владельца mouse grab.
        const movingKey = draggedItem.key;
        const movingType = draggedItem.type;
        // Цель сохраняется отдельно: при hover она уже могла сместиться из-под
        // неподвижного курсора вместе с остальными плитками.
        const targetItem = dragIconTarget ?? target.item;
        const targetIsIcon = dragIconTarget !== null || target.icon;
        Qt.callLater(() => {
            if (targetItem && targetIsIcon && movingType === "application"
                && targetItem.type === "application"
                && targetItem.key !== movingKey) {
                AppLauncherService.createFolder(movingKey, targetItem.key);
            } else if (targetItem && targetIsIcon && movingType === "application"
                && targetItem.type === "folder") {
                AppLauncherService.addToFolder(movingKey, targetItem.folderId);
            } else if (targetItem && targetItem.key !== movingKey) {
                AppLauncherService.moveRootItem(movingKey, target.insertionIndex);
            }
            landingItemKey = movingKey;
            landingTimer.restart();
            endIconDrag();
            refreshGridItems(true);
        });
    }

    function endIconDrag() {
        draggingIcon = false;
        draggedItem = null;
        draggedIconSource = "";
        dragPosition = Qt.point(-1000, -1000);
        dragInsertionIndex = -1;
        dragIconTarget = null;
        rebuildDisplayGridItems();
    }

    Timer {
        // Работает только при переносе над зонами затемнения.
        interval: 16
        repeat: true
        running: launcher.draggingIcon
        onTriggered: {
            const point = launcherFocus.mapToItem(appsSurface,
                launcher.dragPosition.x, launcher.dragPosition.y);
            const edge = Math.min(appsSurface.height / 2,
                Metrics.appLauncherScrollFadeRadius);
            if (point.x < 0 || point.x > appsSurface.width || point.y < 0
                || point.y > appsSurface.height)
                return;
            const direction = point.y < edge ? -1
                : point.y > appsSurface.height - edge ? 1 : 0;
            if (direction)
                appGrid.scrollDuringDrag(direction * appGrid.cellHeight
                    * Metrics.appLauncherDragAutoScrollRowsPerSecond * interval / 1000);
        }
    }

    Timer {
        id: landingTimer
        interval: Motion.spring.durationMs
        onTriggered: launcher.landingItemKey = ""
    }

    Component.onCompleted: {
        refreshGridItems();
        refreshFolderItems();
        revealAnimation.start();
        launcherSearch.forceActiveFocus();
    }

    Connections {
        target: AppLauncherService

        function onLayoutItemsChanged() {
            launcher.refreshGridItems(true);
            launcher.refreshFolderItems();
        }
    }

    onSearchQueryChanged: {
        refreshGridItems();
        refreshFolderItems();
    }
    onOpenFolderIdChanged: refreshFolderItems()

    NumberAnimation {
        id: revealAnimation
        target: launcher
        property: "reveal"
        from: 0
        to: 1
        duration: Motion.spring.durationMs
        easing.type: Motion.spring.easingType
        easing.bezierCurve: Motion.spring.bezierCurve
    }

    PanelWindow {
        id: backdropWindow

        screen: launcher.targetScreen
        anchors { top: true; bottom: true; left: true; right: true }
        exclusionMode: ExclusionMode.Ignore
        color: Theme.transparentColor
        focusable: false
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.namespace: "aerix:app-launcher"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        BackgroundEffect.blurRegion: Region { item: backdropWindow.contentItem }

        Rectangle {
            anchors.fill: parent
            color: Theme.overlayColor
            opacity: Math.max(0, Math.min(1, launcher.reveal))
        }
    }

    PanelWindow {
        id: launcherWindow

        screen: launcher.targetScreen
        anchors { top: true; bottom: true; left: true; right: true }
        exclusionMode: ExclusionMode.Ignore
        color: Theme.transparentColor
        focusable: true
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "aerix:app-launcher"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        BackgroundEffect.blurRegion: Region {
            Region { item: searchSurface; radius: Metrics.panelRadius }
            // Значки папок запрашивают дополнительный blur в своих surface.
            Region { item: appsSurface; radius: Metrics.panelRadius }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: launcher.close()
        }

        FocusScope {
            id: launcherFocus
            anchors.fill: parent
            focus: true

            Keys.onPressed: event => {
                if (event.key !== Qt.Key_Escape)
                    return;
                launcher.close();
                event.accepted = true;
            }

            Item {
                id: launcherLayout
                anchors.centerIn: parent
                width: parent.width / 2
                height: parent.height * 0.7
                scale: Motion.spring.startScale
                    + (1 - Motion.spring.startScale) * launcher.reveal
                opacity: Math.max(0, Math.min(1, launcher.reveal))

                Rectangle {
                    id: searchSurface
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: parent.width / 2
                    height: 44
                    radius: Metrics.panelRadius
                    color: Theme.backgroundColor
                    border.width: 1
                    border.color: Theme.borderColor

                    Image {
                        id: searchIconSource
                        anchors.left: parent.left
                        anchors.leftMargin: Metrics.spacing
                        anchors.verticalCenter: parent.verticalCenter
                        width: Metrics.statusBarWidgetIconSize
                        height: width
                        source: "../../assets/icons/search.svg"
                        // Рендерим SVG в физическом размере до MultiEffect,
                        // как общие иконки status bar, без апскейлинга texture.
                        sourceSize.width: Math.ceil(width
                            * launcherWindow.devicePixelRatio)
                        sourceSize.height: Math.ceil(height
                            * launcherWindow.devicePixelRatio)
                        fillMode: Image.PreserveAspectFit
                        smooth: true
                        visible: false
                    }

                    MultiEffect {
                        anchors.fill: searchIconSource
                        source: searchIconSource
                        colorization: 1
                        colorizationColor: Theme.foregroundColor
                    }

                    TextInput {
                        id: launcherSearch
                        anchors.left: searchIconSource.right
                        anchors.leftMargin: Metrics.spacing
                        anchors.right: parent.right
                        anchors.rightMargin: Metrics.spacing
                        anchors.verticalCenter: parent.verticalCenter
                        color: Theme.foregroundColor
                        font.pixelSize: Metrics.statusBarFontSize
                        clip: true
                        selectByMouse: true
                        onTextChanged: launcher.searchQuery = text

                        Text {
                            anchors.fill: parent
                            visible: !launcherSearch.text
                            text: "Start typing to search applications"
                            color: Theme.disabledForegroundColor
                            font: launcherSearch.font
                            verticalAlignment: Text.AlignVCenter
                        }
                    }
                }

                Rectangle {
                    id: appsSurface
                    anchors.top: searchSurface.bottom
                    anchors.topMargin: 2 * Metrics.spacing
                    width: parent.width
                    height: parent.height - searchSurface.height
                        - 2 * Metrics.spacing
                    radius: Metrics.panelRadius
                    color: Theme.backgroundColor
                    border.width: 1
                    border.color: Theme.borderColor
                    clip: true
                    // clip режет только прямоугольником. Маска ниже вырезает
                    // из слоя сетку и градиенты по скруглению самой панели.
                    layer.enabled: true
                    layer.effect: MultiEffect {
                        maskEnabled: true
                        maskSource: appsMask
                        maskThresholdMin: 0.5
                        maskSpreadAtMin: 1.0
                    }

                GridView {
                    id: appGrid
                    anchors.fill: parent
                    // Viewport совпадает с панелью: элементы уходят за её
                    // край. Margins задают стартовое положение сетки.
                    leftMargin: Metrics.appLauncherPadding
                    rightMargin: Metrics.appLauncherPadding
                    topMargin: Metrics.appLauncherPadding
                    bottomMargin: Metrics.appLauncherPadding
                    clip: true
                    cellWidth: (width - 2 * Metrics.appLauncherPadding)
                        / Metrics.appLauncherColumns
                    cellHeight: (height - 2 * Metrics.appLauncherPadding)
                        / Metrics.appLauncherVisibleRows
                    model: launcher.gridModel
                    interactive: !launcher.draggingIcon
                    // Удерживаем источник mouse grab при уходе за viewport.
                    cacheBuffer: Math.max(0, launcher.draggingIcon ? contentHeight : height)
                    // Значение задаётся до смены model, потому что GridView
                    // при перестановке пересоздаёт делегаты и сбрасывает contentY.
                    property real restoreY: NaN
                    readonly property real minimumY: originY - topMargin
                    readonly property real maximumY: Math.max(minimumY,
                        originY + contentHeight - height + bottomMargin)

                    function settleWheel() {
                        wheelIdle.stop();
                        wheelReturn.stop();
                        wheelReturn.to = Math.max(minimumY,
                            Math.min(maximumY, contentY));
                        if (Math.abs(contentY - wheelReturn.to) > 0.01)
                            wheelReturn.start();
                    }

                    function restoreAfterModelChange() {
                        const savedY = restoreY;
                        restoreY = NaN;
                        forceLayout();
                        if (Number.isFinite(savedY))
                            contentY = Math.max(minimumY, Math.min(maximumY, savedY));
                        returnToBounds();
                    }

                    function scrollDuringDrag(delta) {
                        wheelIdle.stop();
                        wheelReturn.stop();
                        cancelFlick();
                        contentY = Math.max(minimumY, Math.min(maximumY, contentY + delta));
                        launcher.updateIconDrag(launcherFocus,
                            launcher.dragPosition.x, launcher.dragPosition.y);
                    }

                    function scrollByWheel(event) {
                        // Даже нулевой множитель должен поглотить событие,
                        // иначе его обработает встроенная прокрутка GridView.
                        event.accepted = true;
                        const rawDelta = event.pixelDelta.y !== 0
                            ? event.pixelDelta.y
                            : event.angleDelta.y / 120 * cellHeight;
                        const delta = rawDelta * Metrics.appLauncherWheelScrollRows;
                        if (delta === 0)
                            return;
                        if (launcher.draggingIcon) {
                            scrollDuringDrag(-delta);
                            return;
                        }
                        wheelReturn.stop();
                        cancelFlick();
                        const current = contentY;
                        let next = current - delta;
                        const limit = Math.max(0,
                            Metrics.appLauncherOverscrollDistance);
                        // Для обычного wheel-step значение distance задаёт
                        // полный видимый выезд; маленькие touchpad deltas
                        // пропорционально уменьшают его.
                        const fraction = Math.min(1, Math.abs(delta)
                            / Math.max(1, cellHeight / 2));
                        if (delta > 0 && next < minimumY)
                            next = minimumY - limit * fraction;
                        else if (delta < 0 && next > maximumY)
                            next = maximumY + limit * fraction;
                        contentY = next;
                        wheelIdle.restart();
                    }

                    Timer {
                        id: wheelIdle
                        interval: 150
                        onTriggered: appGrid.settleWheel()
                    }

                    NumberAnimation {
                        id: wheelReturn
                        target: appGrid
                        property: "contentY"
                        duration: Motion.quickDurationMs
                        easing.type: Easing.OutCubic
                    }

                    onDraggingChanged: {
                        if (dragging) {
                            wheelIdle.stop();
                            wheelReturn.stop();
                        }
                    }
                    // Упругая граница даёт короткий выезд в пустоту при
                    // прокрутке за начало или конец списка.
                    boundsBehavior: Flickable.DragAndOvershootBounds
                    rebound: Transition {
                        NumberAnimation {
                            properties: "x,y"
                            duration: Motion.quickDurationMs
                            easing.type: Easing.OutCubic
                        }
                    }
                    ScrollBar.vertical: ScrollBar {
                        onPressedChanged: {
                            if (pressed) {
                                wheelIdle.stop();
                                wheelReturn.stop();
                            } else {
                                appGrid.settleWheel();
                            }
                        }
                        // Полоса остаётся в правом padding и не сужает сетку.
                        parent: appsSurface
                        x: appsSurface.width - Metrics.appLauncherPadding - width
                        y: (appsSurface.height - height) / 2
                        height: appsSurface.height * 2 / 3
                        width: 5
                        z: 2
                        policy: ScrollBar.AlwaysOn

                        HoverHandler {
                            cursorShape: Qt.PointingHandCursor
                        }

                        background: Rectangle {
                            radius: width / 2
                            color: Theme.withOpacity("foreground", 0.14)
                        }

                        contentItem: Rectangle {
                            radius: width / 2
                            color: Theme.withOpacity("foreground", 0.68)
                        }
                    }

                    delegate: Item {
                        id: appTile

                        required property var launcherItem
                        required property int index
                        width: appGrid.cellWidth
                        height: appGrid.cellHeight
                        readonly property string iconSource: launcher.itemIconSource(
                            launcherItem)
                        readonly property real iconDropLeft: appIcon.x
                            - Metrics.appLauncherIconSafeZone
                        readonly property real iconDropRight: appIcon.x + appIcon.width
                            + Metrics.appLauncherIconSafeZone
                        readonly property real iconDropTop: appIcon.y
                            - Metrics.appLauncherIconSafeZone
                        readonly property real iconDropBottom: appIcon.y + appIcon.height
                            + Metrics.appLauncherIconSafeZone
                        readonly property bool isDragSource: launcher.draggingIcon
                            && launcher.draggedItem?.key === launcherItem.key
                        readonly property int visualIndex: isDragSource ? index
                            : Math.max(0, launcher.displayGridItems.findIndex(
                                item => item.key === appTile.launcherItem.key))
                        // Модель и MouseArea живут до release. Смещение только
                        // визуальное; индекс для hit-test берётся из preview.
                        transform: Translate {
                            id: tileTranslation
                            x: ((appTile.visualIndex % Metrics.appLauncherColumns)
                                - (appTile.index % Metrics.appLauncherColumns)) * appGrid.cellWidth
                            y: (Math.floor(appTile.visualIndex / Metrics.appLauncherColumns)
                                - Math.floor(appTile.index / Metrics.appLauncherColumns)) * appGrid.cellHeight
                            Behavior on x { Motion.ProfileAnimation {} }
                            Behavior on y { Motion.ProfileAnimation {} }
                        }
                        readonly property bool isLanding:
                            launcher.landingItemKey === launcherItem.key
                        property real landingProgress: 1
                        scale: Motion.spring.startScale + (1
                            - Motion.spring.startScale) * landingProgress
                        transformOrigin: Item.Center

                        onIsLandingChanged: {
                            if (isLanding) {
                                landingProgress = 0;
                                landingAnimation.restart();
                            }
                        }
                        Component.onCompleted: {
                            if (isLanding) {
                                landingProgress = 0;
                                landingAnimation.restart();
                            }
                        }

                        NumberAnimation {
                            id: landingAnimation
                            target: appTile
                            property: "landingProgress"
                            to: 1
                            duration: Motion.spring.durationMs
                            easing.type: Motion.spring.easingType
                            easing.bezierCurve: Motion.spring.bezierCurve
                        }

                        Item {
                            id: appIcon
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.top: parent.top
                            width: Math.min(Metrics.appLauncherIconSize,
                                parent.width, parent.height)
                            height: width
                            opacity: appTile.isDragSource ? 0 : 1

                            Image {
                                anchors.fill: parent
                                visible: appTile.launcherItem.type === "application"
                                source: appTile.iconSource
                                sourceSize: Qt.size(Math.ceil(width
                                    * launcherWindow.devicePixelRatio),
                                    Math.ceil(height * launcherWindow.devicePixelRatio))
                                fillMode: Image.PreserveAspectFit
                                smooth: true
                            }

                            // Папка — такая же стеклянная карточка, как другие
                            // поверхности shell, с четырьмя миниатюрами внутри.
                            Rectangle {
                                id: folderIcon
                                anchors.fill: parent
                                opacity: launcher.openFolderId || appTile.isDragSource ? 1 : 0
                                visible: appTile.launcherItem.type === "folder"
                                radius: Metrics.panelRadius
                                color: Theme.backgroundColor
                                border.width: 1
                                border.color: Theme.borderColor

                                Loader {
                                    active: appTile.launcherItem.type === "folder"
                                    sourceComponent: Component {
                                        FolderIconSurface {
                                            targetScreen: launcher.targetScreen
                                            // При drag surface следует за отдельным preview,
                                            // а не остаётся на исходной позиции в сетке.
                                            sourceItem: appTile.isDragSource
                                                ? dragPreview : folderIcon
                                            referenceItem: launcherFocus
                                            viewport: appTile.isDragSource
                                                ? launcherFocus : appsSurface
                                            entries: appTile.launcherItem.previewEntries ?? []
                                            active: !launcher.openFolderId
                                            contentOpacity: launcherLayout.opacity
                                            geometryRevision: [appGrid.contentY,
                                                appGrid.contentX, appTile.x, appTile.y,
                                                appTile.scale, tileTranslation.x,
                                                tileTranslation.y, launcherLayout.scale,
                                                launcherLayout.x, launcherLayout.y,
                                                appsSurface.width, appsSurface.height,
                                                appsSurface.y, appIcon.width, appIcon.x,
                                                dragPreview.x, dragPreview.y,
                                                dragPreview.width, dragPreview.height]
                                        }
                                    }
                                }

                                Item {
                                    id: folderPreview
                                    anchors.fill: parent
                                    anchors.margins: Math.max(2, Metrics.spacing / 2)
                                    property var entries: appTile.launcherItem.previewEntries ?? []

                                    Repeater {
                                        model: 4

                                        delegate: Image {
                                            required property int index
                                            readonly property var entry:
                                                folderPreview.entries[index] ?? null
                                            visible: entry !== null
                                            width: (folderPreview.width - Metrics.spacing / 2) / 2
                                            height: (folderPreview.height - Metrics.spacing / 2) / 2
                                            x: (index % 2) * (width + Metrics.spacing / 2)
                                            y: Math.floor(index / 2)
                                                * (height + Metrics.spacing / 2)
                                            source: entry ? launcher.itemIconSource({
                                                type: "application",
                                                entry: entry
                                            }) : ""
                                            sourceSize: Qt.size(Math.ceil(width
                                                * launcherWindow.devicePixelRatio),
                                                Math.ceil(height
                                                * launcherWindow.devicePixelRatio))
                                            fillMode: Image.PreserveAspectFit
                                            smooth: true
                                        }
                                    }
                                }
                            }
                        }

                        Text {
                            anchors.top: appIcon.bottom
                            anchors.topMargin: 4
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.margins: 4
                            text: launcher.itemName(appTile.launcherItem)
                            color: Theme.foregroundColor
                            font.pixelSize: Metrics.appLauncherFontSize
                            elide: Text.ElideRight
                            horizontalAlignment: Text.AlignHCenter
                            // Подпись появляется только после spring-посадки.
                            opacity: appIcon.opacity * (appTile.isLanding ? 0 : 1)

                            Behavior on opacity {
                                NumberAnimation { duration: Motion.quickDurationMs }
                            }
                        }

                        // Запуск доступен только у иконки и её safe zone,
                        // остальная площадь плитки не ведёт себя как кнопка.
                        Item {
                            anchors.horizontalCenter: appIcon.horizontalCenter
                            anchors.top: appIcon.top
                            anchors.topMargin: -Metrics.appLauncherIconSafeZone
                            width: appIcon.width
                                + 2 * Metrics.appLauncherIconSafeZone
                            height: appIcon.height
                                + 2 * Metrics.appLauncherIconSafeZone

                            LauncherDragSurface {
                                id: tileDrag
                                anchors.fill: parent
                                onTapped: {
                                    if (appTile.launcherItem.type === "folder")
                                        launcher.openFolderId = appTile.launcherItem.folderId;
                                    else {
                                        appTile.launcherItem.entry?.execute();
                                        launcher.close();
                                    }
                                }
                                onDragStarted: (x, y) => launcher.beginIconDrag(
                                    appTile.launcherItem, appTile.iconSource, tileDrag, x, y)
                                onDragMoved: (x, y) => launcher.updateIconDrag(tileDrag, x, y)
                                onDragDropped: (x, y) => launcher.finishIconDrag(tileDrag, x, y)
                                onDragCanceled: launcher.endIconDrag()
                            }
                        }
                    }
                }

                    // Перехватываем wheel до GridView. Кнопки и hover проходят
                    // к иконкам, поэтому клики, курсоры и drag сохраняются.
                    MouseArea {
                        id: appGridWheelCapture
                        anchors.fill: parent
                        z: 100
                        acceptedButtons: Qt.NoButton
                        hoverEnabled: true
                        scrollGestureEnabled: true
                        cursorShape: {
                            const target = launcher.dropTarget(appGridWheelCapture,
                                mouseX, mouseY);
                            const overScrollbar = mouseX >= appsSurface.width
                                - Metrics.appLauncherPadding - 5
                                && mouseX <= appsSurface.width
                                    - Metrics.appLauncherPadding;
                            return target?.icon || overScrollbar
                                ? Qt.PointingHandCursor : Qt.ArrowCursor;
                        }
                        onWheel: wheel => appGrid.scrollByWheel(wheel)
                    }

                    Text {
                        anchors.centerIn: parent
                        visible: launcher.gridItems.length === 0
                        text: launcher.searchQuery ? "No matching applications"
                            : launcher.openFolderId ? "Folder is empty"
                            : "No desktop applications"
                        color: Theme.disabledForegroundColor
                        font.pixelSize: Metrics.statusBarFontSize
                    }

                    // Fade — часть поверхности приложений: это только
                    // полупрозрачный градиент, без отдельной layer-surface.
                    Rectangle {
                        id: topScrollFade
                        z: 3
                        anchors.top: parent.top
                        width: parent.width
                        height: Math.min(parent.height,
                            Metrics.appLauncherScrollFadeRadius)
                        opacity: launcher.draggingIcon || !appGrid.atYBeginning ? 1 : 0
                        Behavior on opacity {
                            NumberAnimation { duration: Motion.quickDurationMs }
                        }
                        gradient: Gradient {
                            GradientStop {
                                position: 0
                                color: Theme.withOpacity("overlay",
                                    Metrics.appLauncherScrollFadeStrength)
                            }
                            GradientStop { position: 1; color: Theme.transparentColor }
                        }
                    }

                    Rectangle {
                        id: bottomScrollFade
                        z: 3
                        anchors.bottom: parent.bottom
                        width: parent.width
                        height: Math.min(parent.height,
                            Metrics.appLauncherScrollFadeRadius)
                        opacity: launcher.draggingIcon || !appGrid.atYEnd ? 1 : 0
                        Behavior on opacity {
                            NumberAnimation { duration: Motion.quickDurationMs }
                        }
                        gradient: Gradient {
                            GradientStop { position: 0; color: Theme.transparentColor }
                            GradientStop {
                                position: 1
                                color: Theme.withOpacity("overlay",
                                    Metrics.appLauncherScrollFadeStrength)
                            }
                        }
                    }
                }

                // Маска лежит вне appsSurface, чтобы не попадать в её texture
                // layer и точно повторять скруглённую геометрию панели.
                Item {
                    id: appsMask
                    visible: false
                    layer.enabled: true
                    width: appsSurface.width
                    height: appsSurface.height

                    Rectangle {
                        anchors.fill: parent
                        radius: Metrics.panelRadius
                        color: Theme.shadowMaskColor
                        antialiasing: true
                    }
                }

            }

            // Только иконка под курсором, без подписи приложения.
            Image {
                id: dragPreview
                visible: launcher.draggingIcon && !folderPopup.exporting
                x: launcher.dragPosition.x - width / 2
                y: launcher.dragPosition.y - height / 2
                width: Metrics.appLauncherIconSize
                height: width
                z: 10
                source: launcher.draggedItem?.type === "folder" ? ""
                    : launcher.draggedIconSource
                sourceSize: Qt.size(Math.ceil(width * launcherWindow.devicePixelRatio),
                    Math.ceil(height * launcherWindow.devicePixelRatio))
                fillMode: Image.PreserveAspectFit
                smooth: true
                Rectangle {
                    anchors.fill: parent
                    visible: launcher.draggedItem?.type === "folder"
                        && launcher.openFolderId.length > 0
                    radius: Metrics.panelRadius
                    color: Theme.backgroundColor
                    border.color: Theme.borderColor
                    border.width: 1
                    Grid {
                        anchors.fill: parent
                        anchors.margins: Metrics.spacing / 2
                        columns: 2
                        spacing: Metrics.spacing / 2
                        Repeater {
                            model: launcher.draggedItem?.previewEntries ?? []
                            Image {
                                required property var modelData
                                width: (dragPreview.width - 1.5 * Metrics.spacing) / 2
                                height: width
                                source: launcher.itemIconSource({entry: modelData})
                                sourceSize: Qt.size(width * launcherWindow.devicePixelRatio,
                                    height * launcherWindow.devicePixelRatio)
                            }
                        }
                    }
                }
            }
        }
    }

    AppLauncherShadow {
        targetScreen: launcher.targetScreen
        layoutItem: launcherLayout
        sourcePanels: [searchSurface, appsSurface]
    }

    // У HyprGlass contour-маска: fullscreen overlay не должен объединять
    // контур панели папки с полноэкранным прямоугольником.
    PanelWindow {
        screen: launcher.targetScreen
        anchors { top: true; bottom: true; left: true; right: true }
        exclusionMode: ExclusionMode.Ignore
        color: Theme.transparentColor
        visible: folderPopup.panelOpen
        focusable: false
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "aerix:app-launcher-folder-overlay"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        mask: Region { width: 0; height: 0 }

        Rectangle {
            anchors.fill: parent
            color: Theme.overlayColor
        }
    }

    // Тень папки — отдельная layer-surface. Её namespace можно исключить из
    // HyprGlass, не выключая blur самой папки.
    PanelWindow {
        id: folderShadowWindow
        readonly property Item sourcePanel: folderPopup.panelSurface

        screen: launcher.targetScreen
        anchors { top: true; bottom: true; left: true; right: true }
        exclusionMode: ExclusionMode.Ignore
        color: Theme.transparentColor
        visible: folderPopup.panelOpen && sourcePanel !== null
        focusable: false
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.namespace: "aerix:app-launcher-folder-shadow"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        mask: Region { width: 0; height: 0 }

        Item {
            id: folderShadowPanel
            visible: folderShadowWindow.sourcePanel !== null
            x: folderShadowWindow.sourcePanel?.x ?? 0
            y: folderShadowWindow.sourcePanel?.y ?? 0
            width: folderShadowWindow.sourcePanel?.width ?? 0
            height: folderShadowWindow.sourcePanel?.height ?? 0
            scale: folderShadowWindow.sourcePanel?.scale ?? 1
            transformOrigin: Item.Center
            opacity: folderShadowWindow.sourcePanel?.opacity ?? 0

            Rectangle {
                id: folderShadowSource
                anchors.fill: parent
                radius: Metrics.panelRadius
                color: Theme.transparentColor
                antialiasing: true
            }

            PanelShadow {
                sourceItem: folderShadowSource
            }
        }
    }

    AppLauncherFolder {
        id: folderPopup
        targetScreen: launcher.targetScreen
        layoutItem: launcherLayout
        appsSurface: appsSurface
        items: launcher.folderGridItems
        folderId: launcher.openFolderId
        titleText: AppLauncherService.folderName(launcher.openFolderId)
        open: launcher.openFolderId.length > 0
        onDismissed: {
            launcher.endIconDrag();
            launcher.openFolderId = "";
        }
        onExportMoved: position => {
            if (!launcher.draggingIcon) {
                launcher.draggingIcon = true;
                launcher.draggedItem = launcher.folderGridItems.find(
                    item => item.key === folderPopup.draggedKey);
                launcher.dragInsertionIndex = launcher.gridItems.length;
                launcher.rebuildDisplayGridItems();
            }
            launcher.updateIconDrag(launcherFocus, position.x, position.y);
        }
        onExportWheel: event => appGrid.scrollByWheel(event)
        onExported: (itemKey, position) => {
            // Вынос из папки всегда возвращает корневую сетку, даже если
            // pointer отпущен вне её полезной области.
            const folderId = launcher.openFolderId;
            const target = launcher.dropTarget(launcherFocus, position.x, position.y);
            launcher.endIconDrag();
            launcher.openFolderId = "";
            const point = launcherFocus.mapToItem(appsSurface, position.x, position.y);
            if (point.x < 0 || point.y < 0 || point.x > appsSurface.width
                || point.y > appsSurface.height)
                return;
            if (!target)
                return;
            AppLauncherService.moveFolderItem(folderId, itemKey, target.insertionIndex, true);
            if (target.icon && target.item?.type === "folder"
                && target.item.folderId !== folderId)
                AppLauncherService.addToFolder(itemKey, target.item.folderId);
            else if (target.icon && target.item?.type === "application")
                AppLauncherService.createFolder(itemKey, target.item.key);
            launcher.landingItemKey = itemKey;
            landingTimer.restart();
        }
    }
}
