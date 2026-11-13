pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import "../../core"
import "../../services"

PanelWindow {
    id: panel

    required property var modelData

    property string hoveredAddress: ""
    // Открытость принадлежит конкретной panel surface. Shadow получает её
    // фактическую геометрию напрямую, поэтому глобальная карта экранов больше
    // не нужна.
    property bool isOpen: false
    // Ссылка обновляется по lifecycle Repeater, а не строится из itemAt() в
    // binding. Это исключает чтение старого delegate при замене модели с тем
    // же количеством рабочих пространств.
    property DockGroup activeGroupDelegate: null
    // Одна непрерывная величина управляет выездом, scale и opacity. При
    // повторном наведении до завершения закрытия движение разворачивается с
    // текущего кадра, как у KeyboardLayoutPopup.
    property real reveal: isOpen ? 1 : 0

    readonly property real openY: height - Metrics.panelHeight - Metrics.bottomMargin
    readonly property bool interactionEnabled: isOpen && Math.abs(panelSurface.y - openY) < 0.5
    readonly property real revealScale: Motion.spring.startScale
        + (1 - Motion.spring.startScale) * reveal
    readonly property real revealOpacity: Math.max(0, Math.min(1, reveal))

    DockLayout {
        id: layout
        targetScreen: panel.modelData
    }

    // Сохраняем интерфейс свойств панели для её делегатов.
    readonly property var groups: layout.groups
    readonly property string activeWorkspaceKey: layout.activeWorkspaceKey
    readonly property real iconSpacing: layout.iconSpacing
    readonly property real panelWidth: layout.panelWidth
    // Shadow reads the actual animated surface instead of rebuilding Dock
    // geometry from a second layout owner.
    readonly property Rectangle dockSurface: panelSurface

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
    implicitWidth: Math.ceil(panelSurface.width) + 2 * Metrics.panelHorizontalMargin
    // Верхний запас сохраняет область для увеличения иконок при hover.
    implicitHeight: Metrics.panelHeight + Metrics.bottomMargin
        + Metrics.iconTopOverflow
    color: Theme.transparentColor
    focusable: false
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "aerix:dock-panel"

    // Область ввода следует за выезжающей панелью. В скрытом состоянии
    // остаётся только невидимая полоса активации у нижнего края экрана.
    mask: Region {
        y: Math.min(panel.height - Metrics.triggerHeight, Math.max(0, panelSurface.y - Metrics.triggerHeight))
        width: panel.width
        height: panel.height - y
    }

    /** Сбрасывает preview до начала закрывающей анимации панели. */
    function closePanel() {
        hoveredAddress = "";
        isOpen = false;
    }

    Connections {
        target: OverviewService

        function onOpenChanged() {
            if (OverviewService.open)
                panel.closePanel();
        }
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

    /** Переключает wheel-пачку одной командой или nudge-ит реальный край. */
    function switchWorkspace(offset) {
        const result = DockService.switchWorkspace(modelData.name, offset);
        if (result.atBoundary)
            workspaceIndicator.nudge(result.boundaryDirection);
    }

    function resolveActiveGroupDelegate() {
        let resolved = null;
        for (let i = 0; i < groupRepeater.count; i++) {
            const candidate = groupRepeater.itemAt(i) as DockGroup;
            if (candidate?.workspaceKey === activeWorkspaceKey) {
                resolved = candidate;
                break;
            }
        }
        if (activeGroupDelegate !== resolved)
            activeGroupDelegate = resolved;
    }

    onActiveWorkspaceKeyChanged: resolveActiveGroupDelegate()
    Component.onCompleted: resolveActiveGroupDelegate()

    Behavior on reveal {
        NumberAnimation {
            duration: Motion.spring.durationMs
            easing.type: Motion.spring.easingType
            easing.bezierCurve: Motion.spring.bezierCurve
        }
    }

    onInteractionEnabledChanged: restoreHover()

    Timer {
        id: closeDelay
        interval: Motion.dockCloseDelayMs
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
    Rectangle {
        id: panelSurface
        x: Metrics.panelHorizontalMargin
        y: panel.height - (panel.height - panel.openY) * panel.reveal
        width: panel.panelWidth
        height: Metrics.panelHeight
        radius: Metrics.panelRadius
        color: Theme.backgroundColor
        scale: panel.revealScale
        opacity: panel.revealOpacity
        transformOrigin: Item.Bottom
        Behavior on width {
            Motion.ProfileAnimation {}
        }
    }

    // Контент следует за анимированной поверхностью отдельным слоем.
    Item {
        id: panelContent
        x: panelSurface.x
        y: panelSurface.y
        width: panelSurface.width
        height: panelSurface.height
        scale: panel.revealScale
        opacity: panel.revealOpacity
        transformOrigin: Item.Bottom

        Text {
            anchors.centerIn: parent
            visible: panel.groups.length === 0
            text: I18n.tr("dock.emptyLabel")
            color: Theme.foregroundColor
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
                    const workspaceOffset = Math.trunc(wheelDelta / 120);
                    if (workspaceOffset === 0)
                        return;
                    wheelDelta -= workspaceOffset * 120;
                    // Колесо вверх выбирает следующий workspace. Даже большой
                    // delta вычисляет один target из одного snapshot и выдаёт
                    // один IPC dispatch вместо цикла со старым active state.
                    panel.switchWorkspace(workspaceOffset);
                }
            }

            // Порядок объявления рисует обводку под иконками без ручных z.
            WorkspaceIndicator {
                id: workspaceIndicator
                groupsRow: workspaceRow
                targetGroup: panel.activeGroupDelegate
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

                    onItemAdded: (index, item) => panel.resolveActiveGroupDelegate()
                    onItemRemoved: (index, item) => {
                        if (panel.activeGroupDelegate === item)
                            panel.activeGroupDelegate = null;
                        panel.resolveActiveGroupDelegate();
                    }

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

                        onIdentityChanged: panel.resolveActiveGroupDelegate()

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
