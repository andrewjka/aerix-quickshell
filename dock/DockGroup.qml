pragma ComponentBehavior: Bound

import QtQuick
import "../core"

/**
 * Одна workspace-группа в Dock.
 *
 * Компонент отвечает только за геометрию группы, hover-раздвижение и создание
 * DockIcon. Решения о фокусировке окна и разрешении hover принимает DockPanel.
 */
Item {
    id: groupRoot

    required property var modelData
    required property int index
    required property int groupCount
    required property string hoveredAddress
    required property string activeWorkspaceKey
    required property int iconSlot
    required property bool interactionEnabled
    required property real layoutCollapsedStep
    required property real layoutHoverGap
    required property real groupPad
    required property real activeWorkspaceGap
    required property real activeWorkspacePadding
    required property bool activeOnHoveredLeft
    required property bool activeOnHoveredRight

    readonly property var groupData: modelData
    readonly property var windows: modelData.windows
    readonly property bool isCurrent: modelData.key === activeWorkspaceKey
    readonly property int hoveredIndex: windows.findIndex(item => String(item?.address ?? "") === hoveredAddress)
    readonly property var hoveredIcon: iconRepeater.itemAt(hoveredIndex)
    readonly property real hoveredIconCenterX: {
        const icon = hoveredIcon;
        return icon ? groupRoot.x + icon.x + icon.width / 2 : 0;
    }

    signal hoverEntered(var toplevel)
    signal hoverExited(var toplevel)
    signal activated(var toplevel)

    function pointerAddressUnderCursor() {
        for (let i = 0; i < iconRepeater.count; i++) {
            const icon = iconRepeater.itemAt(i);
            if (icon?.pointerInside)
                return String(icon.toplevel?.address ?? "");
        }
        return "";
    }

    // Synchronize delegate state imperatively. Repeater delegates can outlive
    // their group for one binding pass during model changes; avoiding a direct
    // groupRoot binding here removes the hoveredAddress null race completely.
    function syncIconLayout() {
        const hovered = hoveredIndex;
        for (let i = 0; i < iconRepeater.count; i++) {
            const icon = iconRepeater.itemAt(i);
            if (!icon)
                continue;

            icon.iconSlot = iconSlot;
            icon.interactionEnabled = interactionEnabled;
            icon.hoverOffsetTarget = hovered < 0
                ? 0
                : (i < hovered ? -layoutHoverGap : (i > hovered ? layoutHoverGap : 0));
            icon.baseX = groupPad
                        + leftWorkspaceGap
                        + workspacePadding
                        + leftHoverExpansion
                        + i * layoutCollapsedStep;
        }
    }

    onHoveredAddressChanged: syncIconLayout()
    onIconSlotChanged: syncIconLayout()
    onInteractionEnabledChanged: syncIconLayout()
    onLayoutCollapsedStepChanged: syncIconLayout()
    onLayoutHoverGapChanged: syncIconLayout()
    onGroupPadChanged: syncIconLayout()
    onWorkspacePaddingChanged: syncIconLayout()
    onLeftWorkspaceGapChanged: syncIconLayout()
    onLeftHoverExpansionChanged: syncIconLayout()

    // Геометрия workspace-отступов и hover-раздвижения.
    property real workspacePadding: isCurrent ? activeWorkspacePadding : 0
    property real leftWorkspaceGap: (isCurrent && index > 0) ? activeWorkspaceGap : 0
    property real rightWorkspaceGap: (isCurrent && index < groupCount - 1) ? activeWorkspaceGap : 0

    property real leftHoverExpansion: {
        if (hoveredIndex < 0)
            return 0;

        const shouldExpand = isCurrent
            ? hoveredIndex > 0
            : !(index === 0 && hoveredIndex === 0)
              || activeOnHoveredLeft || activeOnHoveredRight;
        if (!shouldExpand)
            return 0;
        return Math.max(0, layoutHoverGap - (activeOnHoveredLeft ? activeWorkspaceGap : 0));
    }

    property real rightHoverExpansion: {
        if (hoveredIndex < 0)
            return 0;

        const isLastWindow = hoveredIndex === windows.length - 1;
        const isLastGroup = index === groupCount - 1;
        const shouldExpand = isCurrent
            ? !isLastWindow
            : !(isLastGroup && isLastWindow)
              || activeOnHoveredLeft || activeOnHoveredRight;
        if (!shouldExpand)
            return 0;
        return Math.max(0, layoutHoverGap - (activeOnHoveredRight ? activeWorkspaceGap : 0));
    }

    width: 2 * groupPad
           + iconSlot
           + Math.max(0, windows.length - 1) * layoutCollapsedStep
           + leftHoverExpansion
           + rightHoverExpansion
           + leftWorkspaceGap
           + rightWorkspaceGap
           + 2 * workspacePadding
    height: 50

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
        StandardAnimation {
            duration: Motion.defaultDuration
        }
    }
    Behavior on rightHoverExpansion {
        StandardAnimation {
            duration: Motion.defaultDuration
        }
    }

    Item {
        x: 0
        y: 2
        width: parent.width
        height: 46

        Repeater {
            id: iconRepeater
            model: groupRoot.windows

            onItemAdded: groupRoot.syncIconLayout()

            delegate: DockIcon {
                onHoverEntered: function(toplevel) {
                    groupRoot.hoverEntered(toplevel);
                }
                onHoverExited: function(toplevel) {
                    groupRoot.hoverExited(toplevel);
                }
                onActivated: function(toplevel) {
                    groupRoot.activated(toplevel);
                }
            }
        }
    }

}
