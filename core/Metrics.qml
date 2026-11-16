pragma Singleton

import QtQml
import QtQuick
import Quickshell
import Quickshell.Io
import "../utils/MetricsConfig.js" as Config

// Единый набор размеров, параметров поведения и профиля движения. Конфигурация
// применится только после полной проверки, поэтому правка metrics.conf безопасна
// для live reload.
QtObject {
    id: metrics

    component ProfileAnimation: NumberAnimation {
        duration: Metrics.durationMs
        easing.type: Easing.BezierSpline
        easing.bezierCurve: Metrics.bezierCurve
    }

    property var configuration: ({
        spacing: 10, baseFontSize: 16, panelRadius: 8, panelShadowRadius: 4,
        groupHeight: 48, panelHeight: 48, bottomMargin: 20, triggerHeight: 8,
        panelHorizontalMargin: 12, panelPadding: 0, iconSlotSize: 46,
        iconSize: 44, iconSpacing: 22, hoverSpacing: 33, iconPressOffset: 8,
        iconTopOverflow: 16, iconBottomOverflow: 16, activeWorkspaceGap: 33,
        activeWorkspacePadding: 12, iconHoverScale: 1.5,
        iconRasterOversample: 1.1, statusBarHeight: 40,
        statusBarHorizontalMargin: 10, statusBarWidgetSpacing: 10,
        statusBarFontSize: 16, statusBarWidgetIconSize: 20, popupRowSpacing: 8,
        appLauncherColumns: 8, appLauncherVisibleRows: 4,
        appLauncherIconSize: 64, appLauncherIconSafeZone: 10,
        appLauncherFontSize: 14, appLauncherSearchCascadeDelayMs: 32,
        appLauncherFolderTitleFontSize: 18, appLauncherScrollFadeStrength: 0.64,
        appLauncherScrollFadeRadius: 48, appLauncherWheelScrollRows: 2,
        appLauncherDragAutoScrollRowsPerSecond: 6,
        appLauncherOverscrollDistance: 128, previewWidth: 440,
        previewHeight: 248, previewTitleHeight: 30, durationMs: 512,
        quickDurationMs: 256, springStartScale: 0.08, springOvershoot: 0.16,
        dockCloseDelayMs: 1128,
        bezierCurve: [0.05, 0.9, 0.1, 1.05, 1, 1]
    })

    // Группы повторяют секции metrics.conf. Плоские свойства ниже оставлены
    // алиасами, чтобы виджеты продолжали работать во время поэтапной миграции.
    readonly property var common: QtObject {
        readonly property int spacing: metrics.configuration.spacing
        readonly property int baseFontSize: metrics.configuration.baseFontSize
        readonly property real panelRadius: metrics.configuration.panelRadius
        readonly property int panelShadowRadius: metrics.configuration.panelShadowRadius
    }
    readonly property var dock: QtObject {
        readonly property int groupHeight: metrics.configuration.groupHeight
        readonly property int panelHeight: metrics.configuration.panelHeight
        readonly property int bottomMargin: metrics.configuration.bottomMargin
        readonly property int triggerHeight: metrics.configuration.triggerHeight
        readonly property int panelHorizontalMargin: metrics.configuration.panelHorizontalMargin
        readonly property int panelPadding: metrics.configuration.panelPadding
        readonly property int iconSlotSize: metrics.configuration.iconSlotSize
        readonly property int iconSize: metrics.configuration.iconSize
        readonly property int iconSpacing: metrics.configuration.iconSpacing
        readonly property int hoverSpacing: metrics.configuration.hoverSpacing
        readonly property int iconPressOffset: metrics.configuration.iconPressOffset
        readonly property int iconTopOverflow: metrics.configuration.iconTopOverflow
        readonly property int iconBottomOverflow: metrics.configuration.iconBottomOverflow
        readonly property int activeWorkspaceGap: metrics.configuration.activeWorkspaceGap
        readonly property int activeWorkspacePadding: metrics.configuration.activeWorkspacePadding
        readonly property real iconHoverScale: metrics.configuration.iconHoverScale
        readonly property real iconRasterOversample: metrics.configuration.iconRasterOversample
        readonly property int closeDelayMs: metrics.configuration.dockCloseDelayMs
    }
    readonly property var statusBar: QtObject {
        readonly property int height: metrics.configuration.statusBarHeight
        readonly property int horizontalMargin: metrics.configuration.statusBarHorizontalMargin
        readonly property int widgetSpacing: metrics.configuration.statusBarWidgetSpacing
        readonly property int fontSize: metrics.configuration.statusBarFontSize
        readonly property int widgetIconSize: metrics.configuration.statusBarWidgetIconSize
    }
    readonly property var popup: QtObject {
        readonly property int rowSpacing: metrics.configuration.popupRowSpacing
    }
    readonly property var appLauncher: QtObject {
        readonly property int columns: metrics.configuration.appLauncherColumns
        readonly property int visibleRows: metrics.configuration.appLauncherVisibleRows
        readonly property int iconSize: metrics.configuration.appLauncherIconSize
        readonly property int iconSafeZone: metrics.configuration.appLauncherIconSafeZone
        readonly property int fontSize: metrics.configuration.appLauncherFontSize
        readonly property int searchCascadeDelayMs: metrics.configuration.appLauncherSearchCascadeDelayMs
        readonly property int folderTitleFontSize: metrics.configuration.appLauncherFolderTitleFontSize
        readonly property real scrollFadeStrength: metrics.configuration.appLauncherScrollFadeStrength
        readonly property int scrollFadeRadius: metrics.configuration.appLauncherScrollFadeRadius
        readonly property real wheelScrollRows: metrics.configuration.appLauncherWheelScrollRows
        readonly property real dragAutoScrollRowsPerSecond: metrics.configuration.appLauncherDragAutoScrollRowsPerSecond
        readonly property int overscrollDistance: metrics.configuration.appLauncherOverscrollDistance
    }
    readonly property var preview: QtObject {
        readonly property int width: metrics.configuration.previewWidth
        readonly property int height: metrics.configuration.previewHeight
        readonly property int titleHeight: metrics.configuration.previewTitleHeight
    }
    readonly property var motion: QtObject {
        readonly property int durationMs: metrics.configuration.durationMs
        readonly property int quickDurationMs: metrics.configuration.quickDurationMs
        readonly property real springStartScale: metrics.configuration.springStartScale
        readonly property real springOvershoot: metrics.configuration.springOvershoot
        readonly property var bezierCurve: metrics.configuration.bezierCurve
        readonly property var spring: QtObject {
            readonly property int durationMs: metrics.configuration.durationMs
            readonly property real startScale: metrics.configuration.springStartScale
            readonly property int easingType: Easing.BezierSpline
            readonly property var bezierCurve: metrics.springBezierCurve(
                metrics.configuration.springOvershoot)
            readonly property real maximumProgress: Math.max(1,
                metrics.configuration.bezierCurve[1],
                1 + metrics.configuration.springOvershoot)
            readonly property real maximumScale: startScale
                + (1 - startScale) * maximumProgress
        }
    }

    readonly property int spacing: configuration.spacing
    readonly property int baseFontSize: configuration.baseFontSize
    readonly property real panelRadius: configuration.panelRadius
    readonly property int panelShadowRadius: configuration.panelShadowRadius
    readonly property int groupHeight: configuration.groupHeight
    readonly property int panelHeight: configuration.panelHeight
    readonly property int bottomMargin: configuration.bottomMargin
    readonly property int triggerHeight: configuration.triggerHeight
    readonly property int panelHorizontalMargin: configuration.panelHorizontalMargin
    readonly property int panelPadding: configuration.panelPadding
    readonly property int iconSlotSize: configuration.iconSlotSize
    readonly property int iconSize: configuration.iconSize
    readonly property int iconSpacing: configuration.iconSpacing
    readonly property int hoverSpacing: configuration.hoverSpacing
    readonly property int iconPressOffset: configuration.iconPressOffset
    readonly property int iconTopOverflow: configuration.iconTopOverflow
    readonly property int iconBottomOverflow: configuration.iconBottomOverflow
    readonly property int activeWorkspaceGap: configuration.activeWorkspaceGap
    readonly property int activeWorkspacePadding: configuration.activeWorkspacePadding
    readonly property real iconHoverScale: configuration.iconHoverScale
    readonly property real iconRasterOversample: configuration.iconRasterOversample
    readonly property int statusBarHeight: configuration.statusBarHeight
    readonly property int statusBarHorizontalMargin: configuration.statusBarHorizontalMargin
    readonly property int statusBarWidgetSpacing: configuration.statusBarWidgetSpacing
    readonly property int statusBarFontSize: configuration.statusBarFontSize
    readonly property int statusBarWidgetIconSize: configuration.statusBarWidgetIconSize
    readonly property int popupRowSpacing: configuration.popupRowSpacing
    readonly property int appLauncherColumns: configuration.appLauncherColumns
    readonly property int appLauncherVisibleRows: configuration.appLauncherVisibleRows
    readonly property int appLauncherIconSize: configuration.appLauncherIconSize
    readonly property int appLauncherIconSafeZone: configuration.appLauncherIconSafeZone
    readonly property int appLauncherFontSize: configuration.appLauncherFontSize
    readonly property int appLauncherSearchCascadeDelayMs: configuration.appLauncherSearchCascadeDelayMs
    readonly property int appLauncherFolderTitleFontSize: configuration.appLauncherFolderTitleFontSize
    readonly property real appLauncherScrollFadeStrength: configuration.appLauncherScrollFadeStrength
    readonly property int appLauncherScrollFadeRadius: configuration.appLauncherScrollFadeRadius
    readonly property real appLauncherWheelScrollRows: configuration.appLauncherWheelScrollRows
    readonly property real appLauncherDragAutoScrollRowsPerSecond: configuration.appLauncherDragAutoScrollRowsPerSecond
    readonly property int appLauncherOverscrollDistance: configuration.appLauncherOverscrollDistance
    readonly property int previewWidth: configuration.previewWidth
    readonly property int previewHeight: configuration.previewHeight
    readonly property int previewTitleHeight: configuration.previewTitleHeight
    readonly property int durationMs: configuration.durationMs
    readonly property int quickDurationMs: configuration.quickDurationMs
    readonly property real springStartScale: configuration.springStartScale
    readonly property real springOvershoot: configuration.springOvershoot
    readonly property int dockCloseDelayMs: configuration.dockCloseDelayMs
    readonly property var bezierCurve: configuration.bezierCurve

    readonly property var spring: motion.spring

    function springBezierCurve(overshoot) {
        return [bezierCurve[0], bezierCurve[1], bezierCurve[2], 1 + overshoot, 1, 1];
    }

    function loadConfiguration(text) {
        try {
            configuration = Config.parse(text);
        } catch (error) {
            console.warn("configs/metrics.conf: " + error.message);
        }
    }

    property FileView metricsConfigFile: FileView {
        id: metricsFile
        path: Quickshell.shellPath("configs/metrics.conf")
        preload: true
        watchChanges: true
        blockWrites: true
        onLoaded: metrics.loadConfiguration(text())
        onFileChanged: reload()
    }

    Component.onCompleted: {
        if (metricsFile.loaded)
            loadConfiguration(metricsFile.text());
    }
}
