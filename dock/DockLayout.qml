import QtQml
import "../core"
import "../services"

// Общая геометрия видимой панели и отдельной поверхности тени.
QtObject {
    required property var targetScreen

    readonly property int maxPanelWidth: Math.floor(targetScreen.width * 0.75)
    readonly property var groups: DockService.groupsForScreen(targetScreen.name)
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
}
