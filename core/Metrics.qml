pragma Singleton

import QtQml

QtObject {
    // Базовая сетка интерфейса.
    readonly property int spacing: 10
    readonly property int baseFontSize: 16

    // Скругление и тень общих поверхностей Dock и status bar.
    readonly property real panelRadius: 8
    readonly property int panelShadowRadius: 4

    // Геометрия Dock и его невидимой области активации.
    readonly property int groupHeight: 48
    // Суммарный вертикальный padding равен общей spacing: по 5 px с каждой стороны.
    readonly property int panelHeight: groupHeight
    readonly property int bottomMargin: 2 * spacing
    readonly property int triggerHeight: 8
    readonly property int panelHorizontalMargin: 12
    // Горизонтальный отступ содержимого Dock следует общей сетке интерфейса.
    readonly property int panelPadding: 0

    // Размеры и поведение иконок Dock.
    readonly property int iconSlotSize: 46
    readonly property int iconSize: 44
    readonly property int iconSpacing: 22
    readonly property int hoverSpacing: 33
    readonly property int iconPressOffset: 8
    readonly property int iconTopOverflow: 16
    readonly property int iconBottomOverflow: 16
    readonly property int activeWorkspaceGap: 33
    readonly property int activeWorkspacePadding: 12
    // Максимальный визуальный масштаб и небольшой запас для растеризации
    // SVG перед увеличением. Фактический размер учитывает DPR монитора.
    readonly property real iconHoverScale: 1.5
    readonly property real iconRasterOversample: 1.1

    // Геометрия и содержимое постоянной верхней панели.
    readonly property int statusBarHeight: 40
    readonly property int statusBarHorizontalMargin: spacing
    readonly property int statusBarWidgetSpacing: spacing
    readonly property int statusBarFontSize: baseFontSize
    readonly property int statusBarWidgetIconSize: 20

    // Списки в popup status bar.
    readonly property int popupRowSpacing: 8

    // Сетка приложений в AppLauncher.
    readonly property int appLauncherColumns: 6
    readonly property int appLauncherVisibleRows: 5
    readonly property int appLauncherPadding: spacing * 4
    readonly property int appLauncherIconSize: 64
    readonly property int appLauncherIconSafeZone: spacing
    readonly property int appLauncherFontSize: 14
    // Размер редактируемого имени открытой папки.
    readonly property int appLauncherFolderTitleFontSize: baseFontSize
    readonly property real appLauncherScrollFadeStrength: 0.64
    readonly property int appLauncherScrollFadeRadius: 48
    // Множитель скорости wheel и число строк в секунду для автопрокрутки drag.
    readonly property real appLauncherWheelScrollRows: 2
    readonly property real appLauncherDragAutoScrollRowsPerSecond: 6
    // Максимальный выезд колесом за границу списка, в логических пикселях.
    readonly property int appLauncherOverscrollDistance: 128

    // Геометрия лёгкого snapshot-превью окна.
    readonly property int previewWidth: 440
    readonly property int previewHeight: 248
    readonly property int previewTitleHeight: 30
}
