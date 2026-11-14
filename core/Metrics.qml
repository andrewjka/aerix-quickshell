pragma Singleton

import QtQml

QtObject {
    // Базовые размеры Dock и его невидимой области активации.
    readonly property int spacing: 10
    readonly property int groupHeight: 50
    // Суммарный вертикальный padding равен общей spacing: по 5 px с каждой стороны.
    readonly property int panelHeight: groupHeight + spacing
    readonly property int bottomMargin: 2 * spacing
    readonly property int triggerHeight: 8
    readonly property int panelHorizontalMargin: 12
    // Горизонтальный отступ содержимого Dock следует общей сетке интерфейса.
    readonly property int panelPadding: spacing
    readonly property int iconSlotSize: 46
    readonly property int iconSize: 44
    readonly property int iconSpacing: 22
    readonly property int hoverSpacing: 28
    readonly property int iconPressOffset: 8
    readonly property int iconTopOverflow: 20
    readonly property int iconBottomOverflow: 10
    readonly property int activeWorkspaceGap: 24
    readonly property int activeWorkspacePadding: 8
    // Максимальный визуальный масштаб и небольшой запас для растеризации
    // SVG перед увеличением. Фактический размер учитывает DPR монитора.
    readonly property real iconHoverScale: 1.5
    readonly property real iconRasterOversample: 1.1

    // Постоянная верхняя панель использует общую сетку боковых отступов.
    readonly property int statusBarHeight: 40
    readonly property int statusBarHorizontalMargin: spacing
    readonly property int statusBarFontSize: 16
    readonly property int statusBarWidgetIconSize: 20
    readonly property int popupRowSpacing: 8

    // Геометрия лёгкого snapshot-превью окна.
    readonly property int previewWidth: 440
    readonly property int previewHeight: 248
    readonly property int previewTitleHeight: 30
    // Единое скругление всех поверхностей, миниатюр и состояний интерфейса.
    readonly property real panelRadius: 8
    // Единая тень поверхностей Dock и status-bar по параметрам Hyprland.
    readonly property int panelShadowRadius: 4
}
