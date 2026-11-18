pragma ComponentBehavior: Bound

import QtQuick
import "../../core"
import "../../services"
import "../shared" as Shared

Item {
    id: icon

    // Данные окна и геометрические цели приходят от DockGroup. Компонент не
    // знает о Hyprland-командах и занимается только отображением и сигналами.
    required property var toplevel
    // Значения передаются явно: уничтожение группы не оставляет в делегате
    // bindings, обращающихся к уже удалённому родителю.
    property bool interactionEnabled: false
    property real baseX: 0
    property real hoverOffset: 0

    // Фактическое наведение нужно панели и при завершении её выезда;
    // разрешение визуальной реакции проверяется отдельно в scale.
    readonly property bool pointerInside: iconMouse.containsMouse
    readonly property string applicationName: String(toplevel?.lastIpcObject?.class
                                               ?? toplevel?.wayland?.appId
                                               ?? "")
    readonly property string iconSource: IconService.resolveIcon(toplevel)
    signal hoverEntered(var toplevel)
    signal hoverExited(var toplevel)
    signal activated(var toplevel)

    width: Metrics.iconSlotSize
    height: Metrics.iconSlotSize
    x: baseX + hoverOffset

    Behavior on hoverOffset {
        Metrics.ProfileAnimation {
            duration: Metrics.durationMs
        }
    }

    // Масштабируется только изображение; слот и его MouseArea сохраняют размер.
    // Раздвижение соседних слотов рассчитывает DockGroup.
    Item {
        x: (parent.width - width) / 2
        y: (parent.height - height) / 2 + (iconMouse.pressed ? Metrics.iconPressOffset : 0)
        width: Metrics.iconSize
        height: Metrics.iconSize
        scale: icon.interactionEnabled && icon.pointerInside
               ? Metrics.iconHoverScale : 1
        transformOrigin: Item.Center

        Behavior on scale {
            Metrics.ProfileAnimation {}
        }

        Behavior on y {
            Metrics.ProfileAnimation {
                duration: Metrics.durationMs
            }
        }

        Shared.IconWidget {
            id: appImage
            anchors.centerIn: parent
            height: parent.height
            iconSource: icon.iconSource
            tinted: false
            devicePixelRatio: Math.max(1, Screen.devicePixelRatio)
            rasterScale: Metrics.iconHoverScale * Metrics.iconRasterOversample
        }

        Rectangle {
            anchors.fill: parent
            visible: appImage.status !== Image.Ready
            radius: Metrics.panelRadius
            color: Theme.backgroundColor

            Text {
                anchors.centerIn: parent
                text: icon.applicationName.slice(0, 1).toUpperCase() || "?"
                color: Theme.foregroundColor
                font.pixelSize: 18
                font.weight: Font.DemiBold
            }
        }
    }

    // У каждого делегата своя MouseArea: она обрабатывает hover и клик
    // внутри слота без дополнительной safe zone и общей сетки hit-test.
    MouseArea {
        id: iconMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor

        onEntered: icon.hoverEntered(icon.toplevel)
        onExited: icon.hoverExited(icon.toplevel)
        onClicked: icon.activated(icon.toplevel)
    }
}
