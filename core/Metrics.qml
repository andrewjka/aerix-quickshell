pragma Singleton

import QtQml

QtObject {
    // Базовые размеры Dock и его невидимой области активации.
    readonly property int panelHeight: 62
    readonly property int bottomMargin: 10
    readonly property int triggerHeight: 8
    readonly property int outerPad: 12
    readonly property int innerPad: 16
    readonly property int iconSlot: 46
    readonly property int collapsedStep: 22
    readonly property int hoverGap: 28
    readonly property int hoverPadding: 2
    readonly property int groupPad: 0
    readonly property int activeWorkspaceGap: 24
    readonly property int activeWorkspacePadding: 8

    // Геометрия лёгкого snapshot-превью окна.
    readonly property int previewWidth: 440
    readonly property int previewHeight: 248
    readonly property int previewTitleHeight: 30

    readonly property real capsuleRadius: 8
    readonly property real previewRadius: 12
    // Цвет хранится как var: QtQml не предоставляет отдельный тип color.
    readonly property var panelColor: Qt.rgba(0, 0, 0, 0.6)
}
