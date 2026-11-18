import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import "../../core"
import "../../services"
import "../shared" as Shared

// Отдельная surface позволяет compositor-у размыть основное окно launcher под
// папкой; дочерний Rectangle в уже существующей surface этого сделать не может.
PanelWindow {
    id: folderWindow

    required property var targetScreen
    required property Item layoutItem
    required property Item appsSurface
    required property var items
    required property string folderId
    required property string titleText
    property bool open: false
    property real reveal: open ? 1 : 0
    readonly property Rectangle panelSurface: folderSurface
    property string draggedKey: ""
    property string draggedSource: ""
    property point pointerPosition: Qt.point(0, 0)
    property int insertionIndex: -1
    property string landingKey: ""
    property bool exporting: false
    readonly property bool panelOpen: open && !exporting

    signal exportMoved(point position)
    signal exportWheel(var event)

    function commitFolderName() {
        folderNameInput.commitName();
    }

    onOpenChanged: {
        if (open) {
            exporting = false;
            folderNameInput.text = titleText;
        }
    }

    signal exported(string itemKey, point position)

    function visualIndex(index) {
        const sourceIndex = items.findIndex(item => item.key === draggedKey);
        if (sourceIndex < 0 || index === sourceIndex)
            return index;
        const slot = insertionIndex - (sourceIndex < insertionIndex ? 1 : 0);
        const withoutSource = index - (index > sourceIndex ? 1 : 0);
        return withoutSource + (withoutSource >= slot ? 1 : 0);
    }

    function updateDrag(source, x, y) {
        pointerPosition = source.mapToItem(folderWindow.contentItem, x, y);
        const panelPoint = source.mapToItem(folderSurface, x, y);
        if (exporting || panelPoint.x < 0 || panelPoint.y < 0
            || panelPoint.x > folderSurface.width || panelPoint.y > folderSurface.height) {
            exporting = true;
            exportMoved(pointerPosition);
            return;
        }
        const point = source.mapToItem(folderGrid.contentItem, x, y);
        const row = Math.max(0, Math.floor((point.y - folderGrid.originY) / folderGrid.cellHeight));
        const column = Math.max(0, Math.min(3, Math.floor(point.x / folderGrid.cellWidth)));
        const slot = Math.min(items.length - 1, row * 4 + column);
        const index = items.findIndex((item, index) => item.key !== draggedKey
            && visualIndex(index) === slot);
        if (index >= 0)
            insertionIndex = index + (point.x % folderGrid.cellWidth >= folderGrid.cellWidth / 2 ? 1 : 0);
    }

    function finishDrag(source, x, y) {
        updateDrag(source, x, y);
        const point = source.mapToItem(folderSurface, x, y);
        const key = draggedKey;
        const destination = insertionIndex;
        const position = pointerPosition;
        const outside = exporting || point.x < 0 || point.y < 0
            || point.x > folderSurface.width || point.y > folderSurface.height;
        Qt.callLater(() => {
            const scrollY = folderGrid.contentY;
            draggedKey = "";
            landingKey = key;
            if (outside)
                exported(key, position);
            else
                AppLauncherService.moveFolderItem(folderId, key, destination, false);
            folderGrid.forceLayout();
            folderGrid.contentY = scrollY;
            folderGrid.returnToBounds();
            landingTimer.restart();
        });
    }

    Timer {
        id: landingTimer
        interval: Metrics.spring.durationMs
        onTriggered: folderWindow.landingKey = ""
    }

    signal dismissed()
    signal applicationLaunched()

    screen: targetScreen
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    color: Theme.transparentColor
    visible: open
    focusable: true
    WlrLayershell.layer: WlrLayer.Overlay
    // Панель, fullscreen overlay и тень имеют независимые contour-маски.
    WlrLayershell.namespace: "aerix:app-launcher-folder"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    BackgroundEffect.blurRegion: Region {
        item: folderWindow.panelOpen ? folderSurface : null
        radius: Metrics.panelRadius
    }

    Behavior on reveal {
        NumberAnimation {
            duration: Metrics.spring.durationMs
            easing.type: Metrics.spring.easingType
            easing.bezierCurve: Metrics.spring.bezierCurve
        }
    }

    // Перехватывает колесо за пределами папки, но не hover её плиток.
    MouseArea {
        anchors.fill: parent
        z: 1.5
        acceptedButtons: Qt.NoButton
        hoverEnabled: true
        scrollGestureEnabled: true
        cursorShape: Qt.ArrowCursor
        onWheel: event => {
            event.accepted = true;
            if (folderWindow.exporting)
                folderWindow.exportWheel(event);
            else {
                const rawDelta = event.pixelDelta.y || event.angleDelta.y / 120
                    * folderGrid.cellHeight;
                const delta = rawDelta * Metrics.appLauncherWheelScrollRows;
                folderGrid.contentY = Math.max(folderGrid.originY,
                    Math.min(Math.max(folderGrid.originY, folderGrid.originY
                        + folderGrid.contentHeight - folderGrid.height), folderGrid.contentY - delta));
                event.accepted = true;
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        z: 1
        onClicked: folderWindow.dismissed()
    }

    Rectangle {
        id: folderSurface
        readonly property real side: Math.min(folderWindow.appsSurface?.width ?? 0,
            folderWindow.appsSurface?.height ?? 0) * 0.5
        readonly property real iconSize: Math.max(1, Math.min(
            Metrics.appLauncherIconSize, width / 4))
        readonly property real labelExtra: 4 + folderLabelMetrics.height
        readonly property real gridGap: Math.max(labelExtra,
            (width - 4 * iconSize) / 4)
        readonly property real gridStep: iconSize + gridGap
        readonly property real iconOffset: Math.max(0,
            (gridGap - labelExtra) / 2)
        readonly property real gridWidth: 4 * gridStep
        readonly property real gridHeight: gridWidth
        // opacity сохраняет MouseArea и grab до release при выносе наружу.
        opacity: folderWindow.panelOpen ? 1 : 0
        anchors.horizontalCenter: parent.horizontalCenter
        y: (folderWindow.layoutItem?.y ?? 0)
            + (folderWindow.appsSurface?.y ?? 0)
            + ((folderWindow.appsSurface?.height ?? 0) - height) / 2
        width: side
        height: width
        radius: Metrics.panelRadius
        color: Theme.backgroundColor
        border.width: 1
        border.color: Theme.borderColor
        z: 2
        scale: Metrics.spring.startScale
            + (1 - Metrics.spring.startScale) * folderWindow.reveal
        transformOrigin: Item.Center

        GridView {
            id: folderGrid
            x: (parent.width - width) / 2
            y: (parent.height - height) / 2
            width: folderSurface.gridWidth
            height: folderSurface.gridHeight
            clip: true
            cellWidth: folderSurface.gridStep
            cellHeight: folderSurface.gridStep
            interactive: folderWindow.draggedKey === ""
            cacheBuffer: Math.max(0, folderWindow.draggedKey !== "" ? contentHeight : height)
            model: folderWindow.items

            FontMetrics {
                id: folderLabelMetrics
                font.pixelSize: Metrics.appLauncherFontSize
            }

            delegate: Item {
                id: folderTile

                required property var modelData
                required property int index
                width: folderGrid.cellWidth
                height: folderGrid.cellHeight
                readonly property bool isLanding:
                    folderWindow.landingKey === modelData.key
                property real landingProgress: 1
                readonly property int previewIndex: folderWindow.visualIndex(index)
                scale: Metrics.spring.startScale + (1
                    - Metrics.spring.startScale) * landingProgress
                transformOrigin: Item.Center
                onIsLandingChanged: {
                    if (isLanding) {
                        landingProgress = 0;
                        landingAnimation.restart();
                    }
                }
                transform: Translate {
                    x: ((folderTile.previewIndex % 4) - (folderTile.index % 4)) * folderGrid.cellWidth
                    y: (Math.floor(folderTile.previewIndex / 4) - Math.floor(folderTile.index / 4)) * folderGrid.cellHeight
                    Behavior on x { Metrics.ProfileAnimation {} }
                    Behavior on y { Metrics.ProfileAnimation {} }
                }
                readonly property string iconName: String(modelData?.entry?.icon ?? "")
                readonly property string iconSource: iconName.startsWith("/")
                    ? "file://" + iconName
                    : iconName && Quickshell.hasThemeIcon(iconName)
                      ? Quickshell.iconPath(iconName) : ""

                Shared.IconWidget {
                    id: appIcon
                    anchors.left: parent.left
                    anchors.leftMargin: folderSurface.gridGap / 2
                    anchors.top: parent.top
                    anchors.topMargin: folderSurface.iconOffset
                    height: folderSurface.iconSize
                    iconSource: folderTile.iconSource
                    tinted: false
                    devicePixelRatio: folderWindow.devicePixelRatio
                    opacity: folderWindow.draggedKey === folderTile.modelData.key ? 0 : 1
                }

                NumberAnimation {
                    id: landingAnimation
                    target: folderTile
                    property: "landingProgress"
                    to: 1
                    duration: Metrics.spring.durationMs
                    easing.type: Metrics.spring.easingType
                    easing.bezierCurve: Metrics.spring.bezierCurve
                }

                Text {
                    anchors.top: appIcon.bottom
                    anchors.topMargin: 4
                    anchors.horizontalCenter: appIcon.horizontalCenter
                    width: appIcon.width
                    height: folderLabelMetrics.height
                    text: String(folderTile.modelData?.entry?.name ?? "")
                    color: Theme.foregroundColor
                    font.pixelSize: Metrics.appLauncherFontSize
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                    opacity: appIcon.opacity * (folderTile.isLanding ? 0 : 1)
                    Behavior on opacity { NumberAnimation { duration: Metrics.quickDurationMs } }
                }

                LauncherDragSurface {
                    id: folderPointer
                    anchors.horizontalCenter: appIcon.horizontalCenter
                    anchors.top: appIcon.top
                    anchors.topMargin: -Metrics.appLauncherIconSafeZone
                    width: appIcon.width + 2 * Metrics.appLauncherIconSafeZone
                    height: appIcon.height + 2 * Metrics.appLauncherIconSafeZone
                    onTapped: {
                        folderTile.modelData.entry?.execute();
                        folderWindow.applicationLaunched();
                    }
                    onDragStarted: (x, y) => {
                        folderWindow.draggedKey = folderTile.modelData.key;
                        folderWindow.draggedSource = folderTile.iconSource;
                        folderWindow.insertionIndex = folderTile.index;
                        folderWindow.updateDrag(folderPointer, x, y);
                    }
                    onDragMoved: (x, y) => folderWindow.updateDrag(folderPointer, x, y)
                    onDragDropped: (x, y) => folderWindow.finishDrag(folderPointer, x, y)
                    onDragCanceled: {
                        folderWindow.draggedKey = "";
                        if (folderWindow.exporting)
                            folderWindow.dismissed();
                    }
                }
            }

        }

        TapHandler {
            target: null
            onTapped: eventPoint => {
                const point = folderSurface.mapToItem(folderGrid.contentItem,
                    eventPoint.position.x, eventPoint.position.y);
                if (folderGrid.indexAt(point.x, point.y) < 0)
                    folderWindow.dismissed();
            }
        }
    }

    TextInput {
        id: folderNameInput
        z: 3
        anchors.horizontalCenter: folderSurface.horizontalCenter
        y: folderSurface.y - height - 2 * Metrics.spacing
        width: folderSurface.width / 2
        height: font.pixelSize + 2 * Metrics.spacing
        opacity: folderWindow.panelOpen ? Math.max(0, Math.min(1, folderWindow.reveal)) : 0
        text: folderWindow.titleText
        color: Theme.foregroundColor
        font.pixelSize: Metrics.appLauncherFolderTitleFontSize
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        selectByMouse: true
        clip: true

        HoverHandler {
            cursorShape: Qt.IBeamCursor
        }

        onEditingFinished: {
            commitName();
        }

        function commitName() {
            const nextName = text.trim();
            if (nextName.length === 0) {
                text = folderWindow.titleText;
                return;
            }
            AppLauncherService.renameFolder(folderWindow.folderId, nextName);
        }

        onActiveFocusChanged: {
            if (!activeFocus)
                commitName();
        }

        Connections {
            target: folderWindow

            function onTitleTextChanged() {
                if (!folderNameInput.activeFocus)
                    folderNameInput.text = folderWindow.titleText;
            }
        }
    }

    Shared.IconWidget {
        visible: folderWindow.draggedKey !== ""
        // Preview должен оставаться над плитками открытой папки.
        z: 10
        x: folderWindow.pointerPosition.x - width / 2
        y: folderWindow.pointerPosition.y - height / 2
        height: Metrics.appLauncherIconSize
        iconSource: visible ? folderWindow.draggedSource : ""
        tinted: false
        devicePixelRatio: folderWindow.devicePixelRatio
    }
}
