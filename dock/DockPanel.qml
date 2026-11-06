pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland

PanelWindow {
    id: win

    required property var modelData

    readonly property int panelHeight: 62
    readonly property int bottomMargin: 10
    readonly property int triggerHeight: 8
    readonly property int outerPad: 12
    readonly property int innerPad: 16
    readonly property int iconSlot: 46
    readonly property int collapsedStep: 22
    readonly property int hoverGap: 28
    readonly property int animationDuration: 768
    readonly property int workspaceSlideDuration: 512
    readonly property var animationCurve: [0.05, 0.9, 0.1, 1.05, 1, 1]
    readonly property int groupGap: collapsedStep - iconSlot
    readonly property int groupPad: 0
    readonly property int activeWorkspaceGap: 24
    readonly property int activeWorkspacePadding: 8
    readonly property int maxPanelWidth: Math.floor(modelData.width * 0.65)

    property bool open: false
    property string hoveredAddress: ""

    component StandardAnimation: NumberAnimation {
        duration: win.animationDuration
        easing.type: Easing.BezierSpline
        easing.bezierCurve: win.animationCurve
    }

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
    readonly property int previewWidth: 320
    readonly property int previewHeight: 200

    readonly property var hoveredToplevel: {
        const address = win.hoveredAddress;
        if (!address) return null;
        for (const group of win.groups) {
            const toplevel = group.windows.find(tl => String(tl.address) === address);
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

    function iconFor(tl) {
        const ipc = tl?.lastIpcObject;
        const names = [String(tl?.wayland?.appId ?? ""), String(ipc?.class ?? ""), String(ipc?.initialClass ?? "")];

        // Try desktop entries first
        for (const name of names) {
            if (!name)
                continue;
            const entry = DesktopEntries.byId(name) ?? DesktopEntries.heuristicLookup(name);
            const iconName = String(entry?.icon ?? "");
            if (!iconName)
                continue;
            if (iconName.startsWith("/"))
                return "file://" + iconName;
            const path = Quickshell.iconPath(iconName, true);
            if (path)
                return path;
        }

        // Fallback to direct icon lookup
        for (const name of names) {
            if (!name)
                continue;
            const path = Quickshell.iconPath(name, true);
            if (path)
                return path;
        }
        return "";
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

    PopupWindow {
        id: windowPreview
        anchor.window: win
        anchor.rect.x: Math.round((win.width - width) / 2)
        anchor.rect.y: Math.round(capsule.y - height - 12)
        width: win.previewWidth
        height: win.previewHeight
        color: "transparent"
        visible: win.open && win.hoveredToplevel !== null

        Rectangle {
            id: previewFrame
            anchors.fill: parent
            radius: 12
            color: "#e61b2431"
            border.width: 1
            border.color: "#66ffffff"
            clip: true

            ScreencopyView {
                anchors.fill: parent
                captureSource: win.hoveredToplevel?.wayland ?? null
                live: true
                paintCursor: false
                visible: hasContent
            }
        }
    }

    Rectangle {
        id: capsule
        x: win.outerPad
        y: win.open ? win.height - height - win.bottomMargin : win.height
        width: win.panelWidth
        height: win.panelHeight
        radius: 8
        color: Qt.rgba(0 / 255, 0 / 255, 0 / 255, 0.6)

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
                        readonly property int hoveredIndex: modelData.windows.findIndex(tl => String(tl.address) === win.hoveredAddress)

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
                                model: groupCapsule.modelData.windows

                                delegate: Item {
                                    required property var modelData
                                    required property int index

                                    readonly property var toplevel: modelData
                                    readonly property string appClass: String(toplevel?.lastIpcObject?.class ?? toplevel?.wayland?.appId ?? "")
                                    readonly property string iconPath: win.iconFor(toplevel)
                                    readonly property bool isHovered: win.hoveredAddress === String(toplevel.address)
                                    readonly property real hoverOffsetTarget: {
                                        if (groupCapsule.hoveredIndex < 0)
                                            return 0;
                                        if (index < groupCapsule.hoveredIndex)
                                            return -win.hoverGap;
                                        if (index > groupCapsule.hoveredIndex)
                                            return win.hoverGap;
                                        return 0;
                                    }

                                    property real hoverOffset: 0

                                    Behavior on hoverOffset {
                                        StandardAnimation {}
                                    }

                                    width: win.iconSlot
                                    height: 46
                                    x: win.groupPad + groupCapsule.leftWorkspaceGap + groupCapsule.workspacePadding + groupCapsule.leftHoverExpansion + index * win.collapsedStep + hoverOffset
                                    z: iconMouse.containsMouse ? 1000 : index

                                    onHoverOffsetTargetChanged: hoverOffset = hoverOffsetTarget

                                    Item {
                                        x: (parent.width - width) / 2
                                        y: 3
                                        width: 38
                                        height: 38
                                        scale: isHovered ? 1.5 : 1
                                        transformOrigin: Item.Center

                                        Behavior on scale {
                                            StandardAnimation {}
                                        }

                                        Image {
                                            id: appImage
                                            anchors.fill: parent
                                            source: iconPath
                                            fillMode: Image.PreserveAspectFit
                                            smooth: true
                                            visible: iconPath !== "" && status === Image.Ready
                                        }

                                        Rectangle {
                                            anchors.fill: parent
                                            visible: !appImage.visible
                                            radius: 16
                                            color: "#46586a"

                                            Text {
                                                anchors.centerIn: parent
                                                text: appClass.slice(0, 1).toUpperCase() || "?"
                                                color: "white"
                                                font.pixelSize: 18
                                                font.weight: Font.DemiBold
                                            }
                                        }
                                    }

                                    MouseArea {
                                        id: iconMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onEntered: win.hoveredAddress = String(toplevel.address)
                                        onExited: {
                                            if (isHovered)
                                                win.hoveredAddress = "";
                                        }
                                        onClicked: {
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
                radius: 8
                color: "transparent"
                border.width: 0.5
                border.pixelAligned: false
                antialiasing: true
                border.color: "#e8ffffff"
                z: 0

                SequentialAnimation {
                    id: capsuleTransition

                    ParallelAnimation {
                        NumberAnimation {
                            target: activeOutline
                            property: "verticalExpansion"
                            from: 0
                            to: 20
                            duration: 512
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: win.animationCurve
                        }

                        NumberAnimation {
                            id: slideAnimation
                            target: activeOutline
                            property: "slideProgress"
                            from: 0
                            to: 1
                            duration: win.workspaceSlideDuration
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: win.animationCurve
                        }
                    }

                    NumberAnimation {
                        target: activeOutline
                        property: "verticalExpansion"
                        from: 20
                        to: 0
                        duration: 512
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: win.animationCurve
                    }
                }
            }
        }
    }
}
