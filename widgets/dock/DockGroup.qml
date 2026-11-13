pragma ComponentBehavior: Bound

import QtQuick
import "../../core"

// Группа рабочего пространства управляет раскладкой иконок и раздвижением
// при наведении. Фокусировку окон и открытие панели обрабатывает DockPanel.
Item {
    id: group

    required property var modelData
    required property int index
    required property int groupCount
    required property string hoveredAddress
    required property string activeWorkspaceKey
    required property bool interactionEnabled
    required property real iconSpacing
    required property bool activeWorkspaceOnLeft
    required property bool activeWorkspaceOnRight

    // Внешние потребители сопоставляют живой delegate по этому ключу, а не
    // по временному индексу Repeater.
    readonly property string workspaceKey: String(modelData.key ?? "")
    readonly property var windows: modelData.windows
    readonly property bool isActiveWorkspace: workspaceKey === activeWorkspaceKey
    readonly property int hoveredIndex: hoveredAddress
        ? windows.findIndex(toplevel => String(toplevel?.address ?? "") === hoveredAddress)
        : -1
    // Repeater может заменить делегат, сохранив его индекс. Ссылку обновляют
    // также itemAdded/itemRemoved, чтобы preview не удерживал старую иконку.
    property DockIcon hoveredIcon: null
    readonly property real iconOriginX: leftWorkspaceGap + workspacePadding + leftHoverExpansion

    signal hoverEntered(var toplevel)
    signal hoverExited(var toplevel)
    signal activated(var toplevel)
    signal identityChanged()

    onWorkspaceKeyChanged: identityChanged()

    /** Восстанавливает hover после выезда панели, когда onEntered уже прошёл. */
    function addressUnderPointer() {
        for (let i = 0; i < iconRepeater.count; i++) {
            const icon = iconRepeater.itemAt(i) as DockIcon;
            if (icon?.pointerInside)
                return String(icon.toplevel?.address ?? "");
        }
        return "";
    }

    /** Передаёт геометрию без bindings к уничтожаемому родителю делегата. */
    function updateIconLayout(icon: DockIcon, iconIndex: int) {
        if (!icon)
            return;
        icon.interactionEnabled = interactionEnabled;
        icon.hoverOffset = hoveredIndex < 0 ? 0 : Math.sign(iconIndex - hoveredIndex) * Metrics.hoverSpacing;
        icon.baseX = iconOriginX + iconIndex * iconSpacing;
    }

    function updateIconLayouts() {
        for (let i = 0; i < iconRepeater.count; i++)
            updateIconLayout(iconRepeater.itemAt(i) as DockIcon, i);
    }

    // Следим за вычисленным индексом: адрес может измениться раньше него.
    onHoveredIndexChanged: {
        hoveredIcon = iconRepeater.itemAt(hoveredIndex) as DockIcon;
        updateIconLayouts();
    }
    onInteractionEnabledChanged: updateIconLayouts()
    onIconSpacingChanged: updateIconLayouts()
    onIconOriginXChanged: updateIconLayouts()

    /** Общая формула расширения для левого и правого края группы. */
    function hoverExpansion(leftEdge) {
        if (hoveredIndex < 0)
            return 0;

        const edgeIcon = hoveredIndex === (leftEdge ? 0 : windows.length - 1);
        const edgeGroup = index === (leftEdge ? 0 : groupCount - 1);
        const besideActiveLeft = activeWorkspaceOnLeft && hoveredIndex === 0;
        const besideActiveRight = activeWorkspaceOnRight && hoveredIndex === windows.length - 1;
        const shouldExpand = isActiveWorkspace
            ? !edgeIcon
            : !(edgeGroup && edgeIcon) || besideActiveLeft || besideActiveRight;
        const besideActive = leftEdge ? besideActiveLeft : besideActiveRight;
        return shouldExpand
            ? Math.max(0, Metrics.hoverSpacing - (besideActive ? Metrics.activeWorkspaceGap : 0))
            : 0;
    }

    // Отступы рабочего пространства и расширения анимируются независимо.
    property real workspacePadding: isActiveWorkspace ? Metrics.activeWorkspacePadding : 0
    property real leftWorkspaceGap: isActiveWorkspace && index > 0 ? Metrics.activeWorkspaceGap : 0
    property real rightWorkspaceGap: isActiveWorkspace && index < groupCount - 1 ? Metrics.activeWorkspaceGap : 0
    property real leftHoverExpansion: hoverExpansion(true)
    property real rightHoverExpansion: hoverExpansion(false)

    width: Metrics.iconSlotSize
           + Math.max(0, windows.length - 1) * iconSpacing
           + leftHoverExpansion + rightHoverExpansion
           + leftWorkspaceGap + rightWorkspaceGap
           + 2 * workspacePadding
    height: Metrics.groupHeight

    Behavior on workspacePadding {
        Motion.ProfileAnimation {}
    }
    Behavior on leftWorkspaceGap {
        Motion.ProfileAnimation {}
    }
    Behavior on rightWorkspaceGap {
        Motion.ProfileAnimation {}
    }
    Behavior on leftHoverExpansion {
        Motion.ProfileAnimation { duration: Motion.durationMs }
    }
    Behavior on rightHoverExpansion {
        Motion.ProfileAnimation { duration: Motion.durationMs }
    }

    Repeater {
        id: iconRepeater
        model: group.windows

        // Новый делегат настраивается один раз, без обхода уже созданных иконок.
        onItemAdded: (index, item) => {
            group.updateIconLayout(item as DockIcon, index);
            if (index === group.hoveredIndex)
                group.hoveredIcon = item as DockIcon;
        }
        onItemRemoved: (index, item) => {
            if (group.hoveredIcon === item)
                group.hoveredIcon = null;
        }

        delegate: DockIcon {
            required property var modelData
            toplevel: modelData
            y: 2

            onHoverEntered: toplevel => group.hoverEntered(toplevel)
            onHoverExited: toplevel => group.hoverExited(toplevel)
            onActivated: toplevel => group.activated(toplevel)
        }
    }
}
