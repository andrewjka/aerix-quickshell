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
    required property var toplevel
    required property Item iconItem
    required property real panelTop

    // Размер сохраняет пропорции исходного окна, ограничиваясь базовым 16:9.
    readonly property real contentAspect: previewImage.hasContent
        && previewImage.sourceSize.width > 0
        && previewImage.sourceSize.height > 0
        ? previewImage.sourceSize.width / previewImage.sourceSize.height
        : Metrics.previewWidth / Metrics.previewHeight

    // Popup привязан к окну панели; движущийся делегат служит только
    // источником координат. Связанные ниже geometry signals запрашивают
    // повторное закрепление, так как mapToItem() сам не создаёт QML binding.
    anchor.window: panelWindow
    anchor.edges: Edges.Top | Edges.Left
    anchor.gravity: Edges.Bottom | Edges.Right
    anchor.adjustment: PopupAdjustment.SlideX | PopupAdjustment.SlideY
    implicitWidth: contentAspect >= Metrics.previewWidth / Metrics.previewHeight
        ? Metrics.previewWidth
        : Metrics.previewHeight * contentAspect
    implicitHeight: implicitWidth / contentAspect + Metrics.previewTitleHeight
    color: "transparent"
    visible: toplevel !== null && iconItem !== null

    /** Пересчитывает popup anchor только при изменении его входной геометрии. */
    function updateAnchor() {
        if (visible)
            anchor.updateAnchor();
    }

    // Нижний край карточки закрепляется над поверхностью панели.
    // Координаты иконки переводятся в систему окна в момент показа.
    anchor.onAnchoring: {
        if (!iconItem || !panelWindow?.contentItem)
            return;

        const iconPosition = iconItem.mapToItem(panelWindow.contentItem, 0, 0);
        anchor.rect.x = Math.round(iconPosition.x
                                   + iconItem.width / 2
                                   - width / 2);
        anchor.rect.y = Math.round(panelTop - height - Metrics.spacing);
    }

    /** Начинает появление карточки от нижней центральной точки. */
    function reveal() {
        if (!toplevel || !previewFrame)
            return;
        revealAnimation.restart();
    }

    onToplevelChanged: reveal()
    Component.onCompleted: reveal()

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
            x: 0
            y: Metrics.previewTitleHeight
            width: parent.width
            height: preview.implicitWidth / preview.contentAspect

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
                        radius: Metrics.previewRadius
                    }
                }
            }
        }

        // Status bar находится поверх snapshot и содержит только лёгкие данные.
        Rectangle {
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
                             ?? "Preview")
                color: "#f2ffffff"
                font.pixelSize: 12
                elide: Text.ElideRight
            }
        }
    }

    Rectangle {
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
