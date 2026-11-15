import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import "../../core"
import "../../services"

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
    onOpenChanged: {
        if (open)
            exporting = false;
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
        interval: Motion.spring.durationMs
        onTriggered: folderWindow.landingKey = ""
    }

    signal dismissed()

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
            duration: Motion.spring.durationMs
            easing.type: Motion.spring.easingType
            easing.bezierCurve: Motion.spring.bezierCurve
        }
    }

    // Overlay находится в отдельном окне ниже surface папки.
    MouseArea {
        anchors.fill: parent
        z: 100
        acceptedButtons: Qt.NoButton
        hoverEnabled: true
        scrollGestureEnabled: true
        cursorShape: mouseX >= folderSurface.x + folderSurface.width
            - Metrics.appLauncherPadding - 5
            && mouseX <= folderSurface.x + folderSurface.width
                - Metrics.appLauncherPadding
            && mouseY >= folderSurface.y && mouseY <= folderSurface.y + folderSurface.height
            ? Qt.PointingHandCursor : Qt.ArrowCursor
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
        // opacity сохраняет MouseArea и grab до release при выносе наружу.
        opacity: folderWindow.panelOpen ? 1 : 0
        anchors.horizontalCenter: parent.horizontalCenter
        y: (folderWindow.layoutItem?.y ?? 0)
            + (folderWindow.appsSurface?.y ?? 0)
            + ((folderWindow.appsSurface?.height ?? 0) - height) / 2
        width: (folderWindow.appsSurface?.width ?? 0) * 0.64
        height: (folderWindow.appsSurface?.height ?? 0) * 0.62
        radius: Metrics.panelRadius
        color: Theme.backgroundColor
        border.width: 1
        border.color: Theme.borderColor
        z: 2
        scale: Motion.spring.startScale
            + (1 - Motion.spring.startScale) * folderWindow.reveal
        transformOrigin: Item.Center

        GridView {
            id: folderGrid
            anchors.fill: parent
            anchors.margins: Metrics.appLauncherPadding
            clip: true
            cellWidth: width / 4
            cellHeight: height / 4
            interactive: folderWindow.draggedKey === ""
            cacheBuffer: Math.max(0, folderWindow.draggedKey !== "" ? contentHeight : height)
            model: folderWindow.items

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
                scale: Motion.spring.startScale + (1
                    - Motion.spring.startScale) * landingProgress
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
                    Behavior on x { Motion.ProfileAnimation {} }
                    Behavior on y { Motion.ProfileAnimation {} }
                }
                readonly property string iconName: String(modelData?.entry?.icon ?? "")
                readonly property string iconSource: iconName.startsWith("/")
                    ? "file://" + iconName
                    : iconName && Quickshell.hasThemeIcon(iconName)
                      ? Quickshell.iconPath(iconName) : ""

                Image {
                    id: appIcon
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: parent.top
                    width: Math.min(Metrics.appLauncherIconSize, parent.width,
                        Math.max(1, parent.height - Metrics.appLauncherFontSize - Metrics.spacing))
                    height: width
                    source: folderTile.iconSource
                    sourceSize: Qt.size(Math.ceil(width
                        * folderWindow.devicePixelRatio), Math.ceil(height
                        * folderWindow.devicePixelRatio))
                    fillMode: Image.PreserveAspectFit
                    smooth: true
                    opacity: folderWindow.draggedKey === folderTile.modelData.key ? 0 : 1
                }

                NumberAnimation {
                    id: landingAnimation
                    target: folderTile
                    property: "landingProgress"
                    to: 1
                    duration: Motion.spring.durationMs
                    easing.type: Motion.spring.easingType
                    easing.bezierCurve: Motion.spring.bezierCurve
                }

                Text {
                    anchors.top: appIcon.bottom
                    anchors.topMargin: 4
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.margins: 4
                    text: String(folderTile.modelData?.entry?.name ?? "")
                    color: Theme.foregroundColor
                    font.pixelSize: Metrics.appLauncherFontSize
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                    opacity: appIcon.opacity * (folderTile.isLanding ? 0 : 1)
                    Behavior on opacity { NumberAnimation { duration: Motion.quickDurationMs } }
                }

                LauncherDragSurface {
                    id: folderPointer
                    anchors.horizontalCenter: appIcon.horizontalCenter
                    anchors.top: appIcon.top
                    anchors.topMargin: -Metrics.appLauncherIconSafeZone
                    width: appIcon.width + 2 * Metrics.appLauncherIconSafeZone
                    height: appIcon.height + 2 * Metrics.appLauncherIconSafeZone
                    onTapped: folderTile.modelData.entry?.execute()
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

            ScrollBar.vertical: ScrollBar {
                parent: folderSurface
                x: folderSurface.width - Metrics.appLauncherPadding - width
                y: (folderSurface.height - height) / 2
                height: folderSurface.height * 2 / 3
                width: 5
                policy: ScrollBar.AsNeeded

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
        onEditingFinished: {
            if (text.trim().length === 0)
                text = folderWindow.titleText;
            else
                AppLauncherService.renameFolder(folderWindow.folderId, text);
        }
    }

    Image {
        visible: folderWindow.draggedKey !== ""
        x: folderWindow.pointerPosition.x - width / 2
        y: folderWindow.pointerPosition.y - height / 2
        width: Metrics.appLauncherIconSize
        height: width
        source: visible ? folderWindow.draggedSource : ""
        sourceSize: Qt.size(width * folderWindow.devicePixelRatio, height * folderWindow.devicePixelRatio)
        fillMode: Image.PreserveAspectFit
    }
}
