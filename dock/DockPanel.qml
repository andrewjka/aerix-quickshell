pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import "../core"
import "../services"

PanelWindow {
    id: win

    required property var modelData

    readonly property int panelHeight: Metrics.panelHeight
    readonly property int bottomMargin: Metrics.bottomMargin
    readonly property int triggerHeight: Metrics.triggerHeight
    readonly property int outerPad: Metrics.outerPad
    readonly property int innerPad: Metrics.innerPad
    readonly property int iconSlot: Metrics.iconSlot
    readonly property int collapsedStep: Metrics.collapsedStep
    readonly property int hoverGap: Metrics.hoverGap
    readonly property int groupGap: collapsedStep - iconSlot
    readonly property int groupPad: Metrics.groupPad
    readonly property int activeWorkspaceGap: Metrics.activeWorkspaceGap
    readonly property int activeWorkspacePadding: Metrics.activeWorkspacePadding
    readonly property int maxPanelWidth: Math.floor(modelData.width * 0.65)

    property bool open: false
    property string hoveredAddress: ""

    readonly property var groups: {
        const result = [];
        const screenName = modelData.name;
        const toplevels = Hyprland.toplevels.values;
        for (const tl of toplevels) {
            const monitor = tl.monitor ?? tl.workspace?.monitor;
            if (!tl.address || (monitor && monitor.name !== screenName))
                continue;
            const key = String(tl.workspace?.name ?? tl.workspace?.id ?? "other");
            let group = result.find(item => item.key === key);
            if (!group) {
                group = {
                    key: key,
                    id: tl.workspace?.id ?? 0,
                    monitor: monitor,
                    windows: []
                };
                result.push(group);
            }
            group.windows.push(tl);
        }
        result.sort((a, b) => a.id - b.id);
        return result;
    }

    function groupWidth(count) {
        return 2 * groupPad + iconSlot + Math.max(0, count - 1) * collapsedStep;
    }

    readonly property real contentWidth: {
        if (groups.length === 0)
            return 0;
        let width = Math.max(0, groups.length - 1) * groupGap;
        for (const group of groups) {
            width += groupWidth(group.windows.length);
        }
        const edgeGroups = Math.min(2, groups.length - 1);
        return width + 2 * activeWorkspacePadding + edgeGroups * activeWorkspaceGap + 2 * hoverGap;
    }

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
        const address = win.hoveredAddress;
        if (!address) return null;
        for (const group of win.groups) {
            const toplevel = group.windows.find(tl => String(tl?.address ?? "") === address);
            if (toplevel) return toplevel;
        }
        return null;
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

    function focusWindow(tl) {
        if (tl?.wayland) {
            tl.wayland.activate();
            return;
        }
        const address = String(tl?.address ?? "").replace(/^0x/, "");
        if (!/^[0-9a-fA-F]+$/.test(address))
            return;

        const selector = "address:0x" + address;
        const command = Hyprland.usingLua ? `hl.dsp.focus({ window = "${selector}" })` : `focuswindow ${selector}`;
        Hyprland.dispatch(command);
    }

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

        Flickable {
            x: win.innerPad - win.hoverGap
            y: -20
            width: parent.width - 2 * win.innerPad + 2 * win.hoverGap
            height: parent.height + 20
            visible: win.groups.length > 0
            clip: true
            contentWidth: groupsRow.width + 2 * win.hoverGap
            contentHeight: height
            flickableDirection: Flickable.HorizontalFlick
            boundsBehavior: Flickable.StopAtBounds

            Row {
                id: groupsRow
                x: win.hoverGap + Math.max(0, (capsule.width - 2 * win.innerPad - width) / 2)
                y: 26
                spacing: win.groupGap
                height: 50
                z: 1

                Repeater {
                    id: groupRepeater
                    model: win.groups

                    delegate: Item {
                        id: groupCapsule
                        required property var modelData
                        required property int index

                        readonly property bool isCurrent: modelData.key === win.activeWorkspaceKey
                        readonly property int hoveredIndex: modelData.windows.findIndex(tl => String(tl?.address ?? "") === win.hoveredAddress)
                        readonly property real hoveredIconCenterX: {
                            const icon = iconRepeater.itemAt(hoveredIndex);
                            return icon
                                ? groupsRow.x + groupCapsule.x + icon.x + icon.width / 2
                                : 0;
                        }

                        // Workspace spacing
                        property real workspacePadding: isCurrent ? win.activeWorkspacePadding : 0
                        property real leftWorkspaceGap: (isCurrent && index > 0) ? win.activeWorkspaceGap : 0
                        property real rightWorkspaceGap: (isCurrent && index < win.groups.length - 1) ? win.activeWorkspaceGap : 0

                        // Hover expansion logic
                        readonly property bool activeOnHoveredLeft: !isCurrent && hoveredIndex === 0 && index > 0 && win.groups[index - 1].key === win.activeWorkspaceKey
                        readonly property bool activeOnHoveredRight: !isCurrent && hoveredIndex === modelData.windows.length - 1 && index < win.groups.length - 1 && win.groups[index + 1].key === win.activeWorkspaceKey

                        property real leftHoverExpansion: {
                            if (hoveredIndex < 0)
                                return 0;
                            const shouldExpand = isCurrent ? hoveredIndex > 0 : !(index === 0 && hoveredIndex === 0) || activeOnHoveredLeft || activeOnHoveredRight;
                            if (!shouldExpand)
                                return 0;
                            return Math.max(0, win.hoverGap - (activeOnHoveredLeft ? win.activeWorkspaceGap : 0));
                        }

                        property real rightHoverExpansion: {
                            if (hoveredIndex < 0)
                                return 0;
                            const isLastWindow = hoveredIndex === modelData.windows.length - 1;
                            const isLastGroup = index === win.groups.length - 1;
                            const shouldExpand = isCurrent ? !isLastWindow : !(isLastGroup && isLastWindow) || activeOnHoveredLeft || activeOnHoveredRight;
                            if (!shouldExpand)
                                return 0;
                            return Math.max(0, win.hoverGap - (activeOnHoveredRight ? win.activeWorkspaceGap : 0));
                        }

                        width: win.groupWidth(modelData.windows.length) + leftHoverExpansion + rightHoverExpansion + leftWorkspaceGap + rightWorkspaceGap + 2 * workspacePadding
                        height: 50
                        z: hoveredIndex >= 0 ? 10 : 0

                        Behavior on workspacePadding {
                            StandardAnimation {}
                        }
                        Behavior on leftWorkspaceGap {
                            StandardAnimation {}
                        }
                        Behavior on rightWorkspaceGap {
                            StandardAnimation {}
                        }
                        Behavior on leftHoverExpansion {
                            StandardAnimation {}
                        }
                        Behavior on rightHoverExpansion {
                            StandardAnimation {}
                        }

                        Item {
                            x: 0
                            y: 2
                            width: parent.width
                            height: 46

                            Repeater {
                                id: iconRepeater
                                model: groupCapsule.modelData.windows

                                delegate: DockIcon {
                                    id: dockIcon

                                    iconSlot: win.iconSlot
                                    isHovered: win.hoveredAddress === String(toplevel?.address ?? "")
                                    hoverOffsetTarget: {
                                        if (groupCapsule.hoveredIndex < 0)
                                            return 0;
                                        if (index < groupCapsule.hoveredIndex)
                                            return -win.hoverGap;
                                        if (index > groupCapsule.hoveredIndex)
                                            return win.hoverGap;
                                        return 0;
                                    }
                                    baseX: win.groupPad
                                           + groupCapsule.leftWorkspaceGap
                                           + groupCapsule.workspacePadding
                                           + groupCapsule.leftHoverExpansion
                                           + index * win.collapsedStep

                                    onHoverEntered: win.hoveredAddress = String(toplevel?.address ?? "")
                                    onHoverExited: {
                                        if (isHovered)
                                            win.hoveredAddress = "";
                                    }
                                    onActivated: {
                                        if (!groupCapsule.isCurrent) {
                                            win.open = true;
                                            clickHoldTimer.restart();
                                        }
                                        win.focusWindow(toplevel);
                                    }
                                }
                            }
                        }
                    }
                }
            }

            Rectangle {
                id: activeOutline

                readonly property var targetGroup: {
                    const key = win.activeWorkspaceKey;
                    for (let i = 0; i < groupRepeater.count; i++) {
                        const item = groupRepeater.itemAt(i);
                        if (item?.modelData.key === key)
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
