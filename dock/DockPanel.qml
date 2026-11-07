pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import "../core"
import "../services"

PanelWindow {
    id: panel

    required property var modelData

    property bool isOpen: false
    property string hoveredAddress: ""

    readonly property real openY: height - Metrics.panelHeight - Metrics.bottomMargin
    readonly property bool interactionEnabled: isOpen && Math.abs(panelSurface.y - openY) < 0.5
    readonly property int maxPanelWidth: Math.floor(modelData.width * 0.75)
    // Только размер прозрачного буфера; положение панели и input region прежние.
    readonly property int renderMargin: Math.max(Metrics.panelHorizontalMargin,
        Math.ceil(Metrics.panelShadowRadius) + 1)

    // Общий сервис читает Hyprland, панель рассчитывает раскладку своего экрана.
    readonly property var groups: DockService.groupsForScreen(modelData.name)
    readonly property string activeWorkspaceKey: String(
        DockService.monitorForScreen(modelData.name)?.activeWorkspace?.name ?? "")
    readonly property int windowCount: groups.reduce((count, group) => count + group.windows.length, 0)

    // Неподвижная часть ширины: первый слот, отступы активного workspace и
    // боковой запас для hover. Остальные окна добавляют только шаг раскладки.
    readonly property real fixedContentWidth: groups.length === 0 ? 0
        : Metrics.iconSlotSize + 2 * Metrics.activeWorkspacePadding
          + Math.min(2, groups.length - 1) * Metrics.activeWorkspaceGap
          + 2 * Metrics.hoverSpacing
    readonly property real iconSpacing: windowCount <= 1 ? Metrics.iconSpacing
        : Math.max(8, Math.min(Metrics.iconSpacing,
            (maxPanelWidth - 2 * Metrics.panelPadding - fixedContentWidth) / (windowCount - 1)))
    readonly property real contentWidth: fixedContentWidth + Math.max(0, windowCount - 1) * iconSpacing
    readonly property real panelWidth: Math.min(maxPanelWidth, Math.max(136, contentWidth + 2 * Metrics.panelPadding))

    // Иконка уже содержит окно: дополнительный поиск по всем группам не нужен.
    readonly property DockIcon hoveredIcon: {
        for (let i = 0; i < groupRepeater.count; i++) {
            const group = groupRepeater.itemAt(i) as DockGroup;
            if (group?.hoveredIcon)
                return group.hoveredIcon;
        }
        return null;
    }

    screen: modelData
    anchors.bottom: true
    implicitWidth: Math.ceil(panelSurface.width) + 2 * renderMargin
    implicitHeight: Math.max(92, Metrics.panelHeight + Metrics.bottomMargin
        + Math.ceil(Metrics.panelShadowRadius) + 1)
    color: "transparent"
    focusable: false
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "aerix:dock-panel"

    // Протокол ext-background-effect ограничивает glass прямоугольником Dock;
    // внешняя Qt-тень не попадает в область размытия HyprGlass.
    BackgroundEffect.blurRegion: Region {
        item: panelSurface
        topLeftRadius: panelSurface.topLeftRadius
        topRightRadius: panelSurface.topRightRadius
        bottomLeftRadius: panelSurface.bottomLeftRadius
        bottomRightRadius: panelSurface.bottomRightRadius
    }

    // Область ввода следует за выезжающей панелью. В скрытом состоянии
    // остаётся только невидимая полоса активации у нижнего края экрана.
    mask: Region {
        x: panel.renderMargin - Metrics.panelHorizontalMargin
        y: Math.min(panel.height - Metrics.triggerHeight, Math.max(0, panelSurface.y - Metrics.triggerHeight))
        width: Math.ceil(panelSurface.width) + 2 * Metrics.panelHorizontalMargin
        height: panel.height - y
    }

    /** Сбрасывает preview до начала закрывающей анимации панели. */
    function closePanel() {
        hoveredAddress = "";
        isOpen = false;
    }

    /** Восстанавливает hover, если курсор попал на иконку ещё во время выезда. */
    function restoreHover() {
        hoveredAddress = "";
        if (!interactionEnabled)
            return;
        for (let i = 0; i < groupRepeater.count; i++) {
            const group = groupRepeater.itemAt(i) as DockGroup;
            const address = group?.addressUnderPointer() ?? "";
            if (address) {
                hoveredAddress = address;
                return;
            }
        }
    }

    /** Переключает workspace или запускает обратную связь на краю списка. */
    function switchWorkspace(direction) {
        if (!DockService.switchWorkspace(modelData.name, direction))
            workspaceIndicator.nudge(direction);
    }

    onInteractionEnabledChanged: restoreHover()

    Timer {
        id: closeDelay
        interval: Motion.panelCloseDelay
        onTriggered: {
            if (!panelHover.hovered)
                panel.closePanel();
        }
    }

    HoverHandler {
        id: panelHover
        onHoveredChanged: {
            if (hovered) {
                panel.isOpen = true;
            } else {
                panel.hoveredAddress = "";
                if (!closeDelay.running)
                    panel.closePanel();
            }
        }
    }

    // Popup и захват кадра существуют только во время наведения.
    LazyLoader {
        active: panel.isOpen && panel.hoveredIcon !== null

        component: WindowPreview {
            panelWindow: panel
            toplevel: panel.hoveredIcon?.toplevel ?? null
            iconItem: panel.hoveredIcon
            panelTop: panelSurface.y
        }
    }

    // Поверхность Dock и анимации её появления и изменения ширины.
    PanelShadow {
        sourceItem: panelSurface
        visible: panelSurface.y < panel.height
    }

    Rectangle {
        id: panelSurface
        x: panel.renderMargin
        y: panel.isOpen ? panel.openY : panel.height
        width: panel.panelWidth
        height: Metrics.panelHeight
        radius: Metrics.panelRadius
        color: Metrics.panelColor

        Behavior on y {
            StandardAnimation {}
        }
        Behavior on width {
            StandardAnimation {}
        }
    }

    // Контент следует за анимированной поверхностью отдельным слоем.
    Item {
        id: panelContent
        x: panelSurface.x
        y: panelSurface.y
        width: panelSurface.width
        height: panelSurface.height

        Text {
            anchors.centerIn: parent
            visible: panel.groups.length === 0
            text: "Aeris"
            color: "#e6ffffff"
            font.pixelSize: 16
            font.weight: Font.Medium
        }

        // При переполнении ряд прокручивается горизонтально. Верхний и нижний
        // запас оставляет место увеличенной иконке и смещению при нажатии.
        Flickable {
            x: Metrics.panelPadding - Metrics.hoverSpacing
            y: -Metrics.iconTopOverflow
            width: parent.width - 2 * Metrics.panelPadding + 2 * Metrics.hoverSpacing
            height: parent.height + Metrics.iconTopOverflow + Metrics.iconBottomOverflow
            visible: panel.groups.length > 0
            clip: true
            contentWidth: workspaceRow.width + 2 * Metrics.hoverSpacing
            contentHeight: height
            flickableDirection: Flickable.HorizontalFlick
            boundsBehavior: Flickable.StopAtBounds

            // Обработчик находится в том же дереве ввода, что и иконки, и
            // перехватывает колесо у Flickable для переключения workspace.
            WheelHandler {
                acceptedButtons: Qt.NoButton
                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                orientation: Qt.Vertical
                blocking: true
                property int wheelDelta: 0

                onWheel: wheel => {
                    if (!panel.interactionEnabled)
                        return;
                    wheelDelta += wheel.angleDelta.y;
                    while (Math.abs(wheelDelta) >= 120) {
                        const direction = Math.sign(wheelDelta);
                        wheelDelta -= direction * 120;
                        // Колесо вверх выбирает следующий workspace.
                        panel.switchWorkspace(direction);
                    }
                }
            }

            // Порядок объявления рисует обводку под иконками без ручных z.
            WorkspaceIndicator {
                id: workspaceIndicator
                groupsRow: workspaceRow
                targetGroup: {
                    for (let i = 0; i < groupRepeater.count; i++) {
                        const group = groupRepeater.itemAt(i) as DockGroup;
                        if (group?.isActiveWorkspace)
                            return group;
                    }
                    return null;
                }
            }

            Row {
                id: workspaceRow
                x: Metrics.hoverSpacing + Math.max(0, (panelSurface.width - 2 * Metrics.panelPadding - width) / 2)
                // Ряд центрируется по высоте поверхности, а верхний overflow
                // Flickable компенсируется отдельным отступом.
                y: Metrics.iconTopOverflow
                   + Math.max(0, (panelSurface.height - Metrics.groupHeight) / 2)
                spacing: panel.iconSpacing - Metrics.iconSlotSize
                height: Metrics.groupHeight

                Repeater {
                    id: groupRepeater
                    model: panel.groups

                    delegate: DockGroup {
                        groupCount: panel.groups.length
                        hoveredAddress: panel.hoveredAddress
                        activeWorkspaceKey: panel.activeWorkspaceKey
                        interactionEnabled: panel.interactionEnabled
                        iconSpacing: panel.iconSpacing
                        activeWorkspaceOnLeft: !isActiveWorkspace && index > 0
                            && panel.groups[index - 1].key === panel.activeWorkspaceKey
                        activeWorkspaceOnRight: !isActiveWorkspace && index < panel.groups.length - 1
                            && panel.groups[index + 1].key === panel.activeWorkspaceKey

                        onHoverEntered: toplevel => {
                            if (panel.interactionEnabled)
                                panel.hoveredAddress = String(toplevel?.address ?? "");
                        }
                        onHoverExited: toplevel => {
                            if (panel.hoveredAddress === String(toplevel?.address ?? ""))
                                panel.hoveredAddress = "";
                        }
                        onActivated: toplevel => {
                            if (!panel.interactionEnabled)
                                return;
                            if (!isActiveWorkspace)
                                closeDelay.restart();
                            DockService.focusWindow(toplevel);
                        }
                    }
                }
            }
        }
    }
}
