import QtQuick
import Quickshell
import Quickshell.Wayland

// Базовая input-прозрачная layer-surface для тени панели. Геометрию и
// расположение источника задаёт конкретная панель, чтобы не смешивать Bar и Dock.
PanelWindow {
    id: shadowWindow

    // Экран передаёт обёртка после создания компонента; required здесь дал бы
    // ложное предупреждение до вычисления её binding.
    property var targetScreen: null
    required property Rectangle shadowSource
    required property string shadowNamespace
    property bool shadowVisible: true
    property real shadowOpacity: 1

    screen: targetScreen
    color: Theme.transparentColor
    focusable: false
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: shadowNamespace

    // Тень не участвует в hit testing: события получает видимая панель.
    mask: Region {
        width: 0
        height: 0
    }

    PanelShadow {
        sourceItem: shadowWindow.shadowSource
        visible: shadowWindow.shadowVisible
        opacity: shadowWindow.shadowOpacity
    }
}
