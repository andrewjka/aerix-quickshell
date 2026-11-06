pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import "../core"
import "../services"

PanelWindow {
    id: win

    required property var modelData

    // Локальные aliases делают геометрию ниже читаемой и оставляют все tokens
    // в одном singleton Metrics.
    readonly property int panelHeight: Metrics.panelHeight
    readonly property int bottomMargin: Metrics.bottomMargin
    readonly property int triggerHeight: Metrics.triggerHeight
    readonly property int outerPad: Metrics.outerPad
    readonly property int innerPad: Metrics.innerPad
    readonly property int iconSlot: Metrics.iconSlot
    readonly property int collapsedStep: Metrics.collapsedStep
    readonly property int hoverGap: Metrics.hoverGap
    readonly property int groupPad: Metrics.groupPad
    readonly property int activeWorkspaceGap: Metrics.activeWorkspaceGap
    readonly property int activeWorkspacePadding: Metrics.activeWorkspacePadding
    readonly property int maxPanelWidth: Math.floor(modelData.width * 0.75)

    property bool open: false
    property string hoveredAddress: ""

    readonly property real openY: height - capsule.height - bottomMargin
    readonly property bool panelFullyOpen: open && Math.abs(capsule.y - openY) < 0.5

    onPanelFullyOpenChanged: {
        if (!panelFullyOpen) {
            hoveredAddress = "";
            return;
        }

        for (let i = 0; i < groupRepeater.count; i++) {
            const group = groupRepeater.itemAt(i);
            const address = group?.pointerAddressUnderCursor() ?? "";
            if (address) {
                hoveredAddress = address;
                return;
            }
        }
    }

    // Одна панель получает уже сгруппированный snapshot из общего сервиса.
    // Модель окон панели: сервис читает Hyprland IPC, а DockPanel отвечает
    // только за layout текущего монитора.
    readonly property var groups: {
        DockService.toplevelSnapshot;
        return DockService.groupsForScreen(modelData.name);
    }

    readonly property int totalWindowCount: {
        let count = 0;
        for (const group of groups)
            count += group.windows.length;
        return count;
    }

    // При переполнении шаг автоматически уменьшается, но боковой hover-buffer
    // остаётся зарезервированным, чтобы расширение не ломало края Dock.
    readonly property real layoutHoverBuffer: hoverGap
    readonly property real layoutHoverGap: hoverGap
    readonly property real layoutCollapsedStep: {
        if (groups.length === 0 || totalWindowCount <= 1)
            return collapsedStep;

        const fixedWidth = 2 * groupPad * groups.length
                           + iconSlot
                           + 2 * activeWorkspacePadding
                           + Math.min(2, groups.length - 1) * activeWorkspaceGap
                           + 2 * layoutHoverBuffer;
        const available = maxPanelWidth - 2 * innerPad - fixedWidth;
        const slots = totalWindowCount - 1;
        return Math.max(8, Math.min(collapsedStep, available / slots));
    }
    readonly property real groupGap: layoutCollapsedStep - iconSlot

    function groupWidth(count) {
        return 2 * groupPad + iconSlot + Math.max(0, count - 1) * layoutCollapsedStep;
    }

    readonly property real contentWidth: {
        if (groups.length === 0)
            return 0;
        let width = Math.max(0, groups.length - 1) * groupGap;
        for (const group of groups)
            width += groupWidth(group.windows.length);
        const edgeGroups = Math.min(2, groups.length - 1);
        return width + 2 * activeWorkspacePadding + edgeGroups * activeWorkspaceGap + 2 * layoutHoverBuffer;
    }

    // Панель занимает не больше 75% ширины монитора, даже при большом числе окон.
    readonly property real panelWidth: Math.min(maxPanelWidth, Math.max(136, contentWidth + 2 * innerPad))

    readonly property string activeWorkspaceKey: String(groups[0]?.monitor?.activeWorkspace?.name ?? "")
    readonly property real hoveredIconCenterX: {
        for (let i = 0; i < groupRepeater.count; i++) {
            const group = groupRepeater.itemAt(i);
            if (group && group.hoveredIndex >= 0)
                return group.hoveredIconCenterX;
        }
        return panelWidth / 2;
    }
    readonly property var hoveredToplevel: {
        DockService.toplevelSnapshot;
        return DockService.findByAddress(win.groups, win.hoveredAddress);
    }

    screen: modelData
    anchors {
        bottom: true
    }
    implicitWidth: Math.ceil(capsule.width) + 2 * outerPad
    implicitHeight: 92
    color: "transparent"
    focusable: false
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "aerix:dock-panel"

    // Капсула полностью скрыта за нижним краем. Невидимая полоса у края
    // вызывает её появление; область ввода следует за движущейся капсулой.
    mask: Region {
        x: 0
        y: Math.min(win.height - win.triggerHeight, Math.max(0, capsule.y - win.triggerHeight))
        width: win.width
        height: win.height - y
    }

    // Закрытие сбрасывает адрес до начала движения, чтобы preview не ехал
    // вниз вместе с капсулой.
    function closePanel() {
        win.open = false;
        win.hoveredAddress = "";
    }

    Timer {
        id: clickHoldTimer
        interval: 1128
        onTriggered: {
            if (!panelHover.hovered)
                closePanel();
        }
    }

    // Все операции фокусировки собраны в DockService; DockPanel остаётся UI.
    HoverHandler {
        id: panelHover
        onHoveredChanged: {
            if (hovered) {
                win.open = true;
            } else {
                win.hoveredAddress = "";
                if (!clickHoldTimer.running)
                    closePanel();
            }
        }
    }

    // Preview создаётся только при реальном наведении. После закрытия панели
    // тяжёлый ScreencopyView уничтожается вместе с PopupWindow.
    LazyLoader {
        id: previewLoader
        active: win.open && win.hoveredToplevel !== null

        component: WindowPreview {
            panelWindow: win
            hoveredToplevel: win.hoveredToplevel
            panelOpen: win.open
            capsuleY: capsule.y
        }
    }

    // Основная поверхность Dock. Shadow включается только во время показа,
    // поэтому скрытая капсула не оставляет дорогой эффект на сцене.
    Rectangle {
        id: capsule
        x: win.outerPad
        y: win.open ? win.height - height - win.bottomMargin : win.height
        width: win.panelWidth
        height: win.panelHeight
        radius: Metrics.capsuleRadius
        color: Metrics.panelColor

        // Hyprland applies decoration.shadow to normal windows, but not to
        // layer-shell surfaces. Keep the same shadow visually in the panel.
        layer.enabled: win.open
        layer.effect: MultiEffect {
            shadowEnabled: win.open
            // Approximation of Hyprland's range = 8, render_power = 4.
            shadowBlur: 0.6
            shadowColor: Qt.rgba(26 / 255, 26 / 255, 26 / 255, 0.48)
            shadowOpacity: 1
            shadowHorizontalOffset: 0
            shadowVerticalOffset: 0
        }

        Behavior on y {
            StandardAnimation {}
        }
        Behavior on width {
            StandardAnimation {}
        }

        Text {
            anchors.centerIn: parent
            visible: win.groups.length === 0
            text: "Aeris"
            color: "#e6ffffff"
            font.pixelSize: 16
            font.weight: Font.Medium
        }

        // Flickable клипует плотную раскладку и даёт горизонтальное перемещение
        // только когда количество окон действительно не помещается.
        Flickable {
            x: win.innerPad - win.layoutHoverBuffer
            y: -20
            width: parent.width - 2 * win.innerPad + 2 * win.layoutHoverBuffer
            height: parent.height + 20
            visible: win.groups.length > 0
            clip: true
            contentWidth: groupsRow.width + 2 * win.layoutHoverBuffer
            contentHeight: height
            flickableDirection: Flickable.HorizontalFlick
            boundsBehavior: Flickable.StopAtBounds

            Row {
                id: groupsRow
                x: win.layoutHoverBuffer + Math.max(0, (capsule.width - 2 * win.innerPad - width) / 2)
                y: 26
                spacing: win.groupGap
                height: 50
                z: 1

                Repeater {
                    id: groupRepeater
                    model: win.groups

                    delegate: DockGroup {
                        groupCount: win.groups.length
                        hoveredAddress: win.hoveredAddress
                        activeWorkspaceKey: win.activeWorkspaceKey
                        iconSlot: win.iconSlot
                        layoutCollapsedStep: win.layoutCollapsedStep
                        layoutHoverGap: win.layoutHoverGap
                        groupPad: win.groupPad
                        activeWorkspaceGap: win.activeWorkspaceGap
                        activeWorkspacePadding: win.activeWorkspacePadding
                        activeOnHoveredLeft: !isCurrent && hoveredIndex === 0
                                              && index > 0
                                              && win.groups[index - 1].key === win.activeWorkspaceKey
                        activeOnHoveredRight: !isCurrent
                                               && hoveredIndex === modelData.windows.length - 1
                                               && index < win.groups.length - 1
                                               && win.groups[index + 1].key === win.activeWorkspaceKey

                        onHoverEntered: function(toplevel) {
                            if (win.panelFullyOpen)
                                win.hoveredAddress = String(toplevel?.address ?? "");
                        }
                        onHoverExited: function(toplevel) {
                            if (win.hoveredAddress === String(toplevel?.address ?? ""))
                                win.hoveredAddress = "";
                        }
                        onActivated: function(toplevel) {
                            if (!win.panelFullyOpen)
                                return;
                            if (!isCurrent) {
                                win.open = true;
                                clickHoldTimer.restart();
                            }
                            DockService.focusWindow(toplevel);
                        }
                    }
                }
            }

            // Активная workspace-капсула переезжает между группами отдельно от
            // иконок, что сохраняет плавный переход при смене workspace.
            Rectangle {
                id: activeOutline

                readonly property var targetGroup: {
                    const key = win.activeWorkspaceKey;
                    for (let i = 0; i < groupRepeater.count; i++) {
                        const item = groupRepeater.itemAt(i);
                        if (item?.groupData.key === key)
                            return item;
                    }
                    return null;
                }

                property var displayedGroup: null
                property real slideProgress: 1
                property real slideFromX: 0
                property real slideFromWidth: 0
                property real verticalExpansion: 0

                readonly property real destinationX: displayedGroup ? groupsRow.x + displayedGroup.x + displayedGroup.leftWorkspaceGap + 2 : 0
                readonly property real destinationWidth: displayedGroup ? displayedGroup.width - displayedGroup.leftWorkspaceGap - displayedGroup.rightWorkspaceGap - 4 : 0

                onTargetGroupChanged: {
                    const shouldSlide = displayedGroup !== null && targetGroup !== null;
                    capsuleTransition.stop();
                    slideAnimation.stop();
                    slideFromX = x;
                    slideFromWidth = width;
                    slideProgress = shouldSlide ? 0 : 1;
                    displayedGroup = targetGroup;
                    if (shouldSlide)
                        capsuleTransition.start();
                    else
                        verticalExpansion = 0;
                }

                visible: displayedGroup !== null
                x: slideFromX + (destinationX - slideFromX) * slideProgress
                y: groupsRow.y + 11 - verticalExpansion / 2
                width: slideFromWidth + (destinationWidth - slideFromWidth) * slideProgress
                height: 26 + verticalExpansion
                radius: Metrics.capsuleRadius
                color: "transparent"
                border.width: 0.5
                border.pixelAligned: false
                antialiasing: true
                border.color: "#e8ffffff"
                z: 0

                SequentialAnimation {
                    id: capsuleTransition

                    ParallelAnimation {
                        StandardAnimation {
                            target: activeOutline
                            property: "verticalExpansion"
                            from: 0
                            to: 20
                            duration: Motion.workspaceSlideDuration
                        }

                        StandardAnimation {
                            id: slideAnimation
                            target: activeOutline
                            property: "slideProgress"
                            from: 0
                            to: 1
                            duration: Motion.workspaceSlideDuration
                        }
                    }

                    StandardAnimation {
                        target: activeOutline
                        property: "verticalExpansion"
                        from: 20
                        to: 0
                        duration: Motion.workspaceSlideDuration
                    }
                }
            }
        }
    }
}
