pragma Singleton

import QtQml

QtObject {
    // Базовые размеры Dock и его невидимой области активации.
    readonly property int gaps: 10
    readonly property int panelHeight: 62
    readonly property int monitorMargin: gaps
    readonly property int bottomMargin: 2 * gaps
    readonly property int triggerHeight: 8
    readonly property int outerPad: 12
    readonly property int innerPad: 16
    readonly property int iconSlot: 46
    readonly property int iconSize: 44
    readonly property int collapsedStep: 22
    readonly property int hoverGap: 28
    readonly property int groupPad: 0
    readonly property int activeWorkspaceGap: 24
    readonly property int activeWorkspacePadding: 8
    // Максимальный визуальный масштаб и небольшой запас для растеризации
    // SVG перед увеличением. Фактический размер учитывает DPR монитора.
    readonly property real iconHoverScale: 1.5
    readonly property real iconRasterOversample: 1.1

    // Геометрия лёгкого snapshot-превью окна.
    readonly property int previewWidth: 440
    readonly property int previewHeight: 248
    readonly property int previewTitleHeight: 30
    readonly property int iconOverflow: 10

    readonly property real capsuleRadius: 8
    readonly property real previewRadius: 12
    // Цвет хранится как var: QtQml не предоставляет отдельный тип color.
    readonly property var panelColor: Qt.rgba(1, 1, 1, 0.08)
    readonly property int panelBorderWidth: 1
    readonly property var panelBorderColor: Qt.rgba(1, 1, 1, 0.64)
}
