pragma ComponentBehavior: Bound

import QtQuick
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Wayland
import "../../core"
import "../../services"

// Hyprglass обрабатывает blur только на layer-shell surface. Snapshot и его
// lifecycle остаются прежними, но контейнером служит отдельный PanelWindow.
PanelWindow {
    id: preview

    // Popup создаётся LazyLoader только при наведении. Внутри используется
    // один snapshot кадр, а не постоянный ScreencopyView live-поток.
    required property var panelWindow
    required property var toplevel
    required property Item iconItem
    required property real panelTop
    property real surfaceX: 0
    property real surfaceY: 0

    // Размер сохраняет пропорции исходного окна, ограничиваясь базовым 16:9.
    readonly property real contentAspect: previewImage.hasContent
        && previewImage.sourceSize.width > 0
        && previewImage.sourceSize.height > 0
        ? previewImage.sourceSize.width / previewImage.sourceSize.height
        : Metrics.previewWidth / Metrics.previewHeight
    readonly property int surfaceWidth: contentAspect >= Metrics.previewWidth / Metrics.previewHeight
        ? Metrics.previewWidth
        : Metrics.previewHeight * contentAspect
    readonly property int surfaceHeight: surfaceWidth / contentAspect
        + Metrics.previewTitleHeight
    // transformOrigin снизу: spring растит preview в стороны и вверх.
    // Внешняя layer-surface оставляет запас ровно под максимальный overshoot.
    readonly property real springScaleOverflow: Math.max(0,
        Motion.spring.maximumScale - 1)
    readonly property int horizontalRenderMargin: Math.ceil(
        surfaceWidth * springScaleOverflow / 2) + 1
    readonly property int topRenderMargin: Math.ceil(
        surfaceHeight * springScaleOverflow) + 1

    screen: panelWindow?.screen ?? null
    anchors { top: true; left: true }
    margins.left: surfaceX
    margins.top: surfaceY
    implicitWidth: surfaceWidth + 2 * horizontalRenderMargin
    implicitHeight: surfaceHeight + topRenderMargin
    color: Theme.transparentColor
    visible: toplevel !== null && iconItem !== null
    exclusionMode: ExclusionMode.Ignore
    focusable: false
    WlrLayershell.namespace: "aerix:dock-window-preview"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    mask: Region { item: previewFrame }
    // Тот же protocol-запрос, что у карточек overview и popup раскладки.
    BackgroundEffect.blurRegion: Region {
        item: previewFrame
        radius: Metrics.panelRadius
    }

    /** Пересчитывает геометрию layer-surface по прежнему якорю Dock. */
    function updateAnchor() {
        if (!iconItem || !panelWindow?.contentItem || !panelWindow.screen)
            return;

        const iconPosition = iconItem.mapToItem(panelWindow.contentItem, 0, 0);
        // DockPanel закреплён снизу и центрирован по горизонтали. Wayland
        // не предоставляет его глобальную позицию через mapToGlobal().
        // Восстанавливаем начало Dock из тех же anchors и размеров output.
        const screenWidth = panelWindow.screen.width;
        const screenHeight = panelWindow.screen.height;
        const dockX = (screenWidth - panelWindow.width) / 2;
        const dockY = screenHeight - panelWindow.height;
        const desiredX = dockX + iconPosition.x
            + iconItem.width / 2 - surfaceWidth / 2 - horizontalRenderMargin;
        surfaceX = Math.round(Math.max(0, Math.min(desiredX,
            Math.max(0, screenWidth - implicitWidth))));
        const desiredY = dockY + panelTop
            - surfaceHeight - Metrics.spacing - topRenderMargin;
        surfaceY = Math.round(Math.max(0, Math.min(desiredY,
            Math.max(0, screenHeight - implicitHeight))));
    }

    /** Начинает появление карточки от нижней центральной точки. */
    function reveal() {
        if (!toplevel || !previewFrame)
            return;
        revealAnimation.restart();
    }

    onToplevelChanged: reveal()
    onVisibleChanged: placementTimer.restart()
    onScreenChanged: placementTimer.restart()
    Component.onCompleted: {
        // Повторяем расчёт после инициализации размеров и дочерних элементов.
        // Timer уничтожается вместе с preview при закрытии LazyLoader.
        placementTimer.start();
        reveal();
    }

    Timer {
        id: placementTimer
        interval: 0
        onTriggered: preview.updateAnchor()
    }

    // Позиция делегата может стать доступной после создания popup. Размер
    // меняется после первого кадра ScreencopyView, поэтому также центрируем
    // уже открытую карточку относительно иконки повторно.
    onIconItemChanged: updateAnchor()
    onPanelTopChanged: updateAnchor()
    onImplicitWidthChanged: updateAnchor()
    onImplicitHeightChanged: updateAnchor()

    // DockIcon движется внутри DockGroup, сама группа — внутри Row, а ряд —
    // внутри Flickable contentItem. Все четыре уровня участвуют в mapToItem;
    // подписываемся лишь пока preview создан LazyLoader'ом.
    readonly property Item iconGroup: iconItem?.parent ?? null
    readonly property Item iconRow: iconGroup?.parent ?? null
    readonly property Item iconContent: iconRow?.parent ?? null

    Connections {
        target: preview.iconItem

        function onXChanged() { preview.updateAnchor(); }
        function onYChanged() { preview.updateAnchor(); }
        function onWidthChanged() { preview.updateAnchor(); }
        function onHeightChanged() { preview.updateAnchor(); }
        function onParentChanged() { preview.updateAnchor(); }
    }

    Connections {
        target: preview.iconGroup

        function onXChanged() { preview.updateAnchor(); }
        function onYChanged() { preview.updateAnchor(); }
        function onParentChanged() { preview.updateAnchor(); }
    }

    Connections {
        target: preview.iconRow

        function onXChanged() { preview.updateAnchor(); }
        function onYChanged() { preview.updateAnchor(); }
        function onParentChanged() { preview.updateAnchor(); }
    }

    Connections {
        target: preview.iconContent

        function onXChanged() { preview.updateAnchor(); }
        function onYChanged() { preview.updateAnchor(); }
    }

    // Изменение ширины Dock сдвигает его левый край относительно центра output.
    Connections {
        target: preview.panelWindow

        function onWidthChanged() { preview.updateAnchor(); }
        function onHeightChanged() { preview.updateAnchor(); }
    }

    Connections {
        target: preview.screen
        function onGeometryChanged() { preview.updateAnchor(); }
    }

    // Один общий transition для opacity и scale; 512 мс — согласованное время
    // движения превью.
    ParallelAnimation {
        id: revealAnimation

        Motion.ProfileAnimation {
            target: previewFrame
            property: "scale"
            from: 0.12
            to: 1
            duration: Motion.durationMs
        }
        Motion.ProfileAnimation {
            target: previewFrame
            property: "opacity"
            from: 0
            to: 1
            duration: Motion.durationMs
        }
    }

    Rectangle {
        id: previewFrame
        x: preview.horizontalRenderMargin
        y: preview.topRenderMargin
        width: preview.surfaceWidth
        height: preview.surfaceHeight
        radius: Metrics.panelRadius
        color: Theme.backgroundColor
        clip: true
        transformOrigin: Item.Bottom

        // Область snapshot ниже status bar.
        Item {
            x: 0
            y: Metrics.previewTitleHeight
            width: parent.width
            height: preview.surfaceWidth / preview.contentAspect

            ScreencopyView {
                id: previewImage
                anchors.fill: parent
                captureSource: preview.toplevel?.wayland ?? null
                // Public API не сообщает о готовности recording context,
                // поэтому captureFrame() нельзя безопасно вызвать сразу после
                // смены source. Краткий live-захват создаёт контекст, а первый
                // полученный кадр снова останавливает поток.
                live: false
                paintCursor: false
                onCaptureSourceChanged: {
                    // При смене окна нужен новый снимок даже у готового popup.
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
                        radius: Metrics.panelRadius
                    }
                }
            }
        }

        // Заголовок лежит прямо на размытом фоне preview без отдельной заливки.
        Item {
            x: 0
            y: 0
            width: parent.width
            height: Metrics.previewTitleHeight

            Image {
                id: previewIcon
                x: 10
                y: (parent.height - height) / 2
                width: 16
                height: 16
                source: preview.toplevel ? IconService.resolveIcon(preview.toplevel) : ""
                cache: true
                sourceSize: Qt.size(
                    Math.ceil(width * Math.max(1, preview.devicePixelRatio)),
                    Math.ceil(height * Math.max(1, preview.devicePixelRatio)))
                fillMode: Image.PreserveAspectFit
                smooth: true
            }

            Text {
                anchors.left: previewIcon.right
                anchors.leftMargin: 8
                anchors.right: parent.right
                anchors.rightMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                text: String(preview.toplevel?.title
                             ?? preview.toplevel?.lastIpcObject?.title
                             ?? I18n.tr("dock.previewFallbackTitle"))
                color: Theme.foregroundColor
                font.pixelSize: 12
                elide: Text.ElideRight
            }
        }
    }

    Rectangle {
        x: previewFrame.x
        y: previewFrame.y
        width: previewFrame.width
        height: previewFrame.height
        radius: Metrics.panelRadius
        color: Theme.transparentColor
        border.width: 1
        border.color: Theme.borderColor
        scale: previewFrame.scale
        opacity: previewFrame.opacity
        transformOrigin: Item.Bottom
    }
}
