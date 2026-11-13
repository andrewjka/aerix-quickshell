import QtQml
import "../../core"
import "../../services"

// Общая геометрия видимой панели и отдельной поверхности тени.
QtObject {
    required property var targetScreen

    readonly property int maxPanelWidth: Math.floor(targetScreen.width * 0.75)
    // Снимок принадлежит конкретному экранному DockLayout и освобождается
    // вместе с ним. Вложенное поле намеренно изменяется без reassignment
    // QML-свойства: groups binding зависит от системной модели, а не от
    // собственного кэша, поэтому не возникает binding loop.
    readonly property var groupSnapshotState: ({ groups: [] })
    readonly property var groups: stabilizeGroups(DockService.groupsForScreen(targetScreen.name))
    readonly property string activeWorkspaceKey: String(
        DockService.monitorForScreen(targetScreen.name)?.activeWorkspace?.name ?? "")
    readonly property int windowCount: groups.reduce((count, group) => count + group.windows.length, 0)

    readonly property real fixedContentWidth: groups.length === 0 ? 0
        : Metrics.iconSlotSize + 2 * Metrics.activeWorkspacePadding
          + Math.min(2, groups.length - 1) * Metrics.activeWorkspaceGap
          + 2 * Metrics.hoverSpacing
    readonly property real iconSpacing: windowCount <= 1 ? Metrics.iconSpacing
        : Math.max(8, Math.min(Metrics.iconSpacing,
            (maxPanelWidth - 2 * Metrics.panelPadding - fixedContentWidth) / (windowCount - 1)))
    readonly property real contentWidth: fixedContentWidth + Math.max(0, windowCount - 1) * iconSpacing
    readonly property real panelWidth: Math.min(maxPanelWidth,
        Math.max(136, contentWidth + 2 * Metrics.panelPadding))

    function sameGroup(left, right) {
        if (!left || !right || left.key !== right.key
                || left.workspace !== right.workspace
                || left.windows.length !== right.windows.length)
            return false;

        for (let i = 0; i < left.windows.length; i++) {
            // address намеренно не используется: новый QObject с тем же
            // адресом должен получить новый delegate и свежие bindings.
            if (left.windows[i] !== right.windows[i])
                return false;
        }
        return true;
    }

    function stabilizeGroups(nextGroups) {
        const previousGroups = groupSnapshotState.groups;
        if (previousGroups.length === nextGroups.length) {
            let unchanged = true;
            for (let i = 0; i < nextGroups.length; i++) {
                if (!sameGroup(previousGroups[i], nextGroups[i])) {
                    unchanged = false;
                    break;
                }
            }
            if (unchanged)
                return previousGroups;
        }

        // Неизменная группа удерживает прежние object и windows array. При
        // изменении соседней группы icon Repeater этой группы не получает
        // новую модель только из-за свежего внешнего snapshot.
        const stabilizedGroups = nextGroups.map((nextGroup, index) =>
            sameGroup(previousGroups[index], nextGroup)
                ? previousGroups[index]
                : nextGroup);
        groupSnapshotState.groups = stabilizedGroups;
        return stabilizedGroups;
    }
}
