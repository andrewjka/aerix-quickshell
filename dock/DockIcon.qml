pragma ComponentBehavior: Bound

import QtQuick
import "../core"
import "../services"

Item {
    id: iconRoot

    // Данные окна и геометрические цели приходят от DockGroup. Компонент не
    // знает о Hyprland-командах и занимается только отображением и сигналами.
    required property var modelData
    required property int index
    // These are regular properties instead of bindings into DockGroup. The
    // group updates them explicitly, so delegate destruction cannot evaluate a
    // binding through a parent that has already become null.
    property int iconSlot: Metrics.iconSlot
    property bool interactionEnabled: false
    property real hoverOffsetTarget: 0
    property real baseX: 0
    property real hoverOffset: 0
    property real pressOffset: 0

    // Ссылка на окно используется для hover-сигналов, клика и предпросмотра.
    readonly property var toplevel: modelData
    // Фактическое наведение нужно панели и при завершении её выезда;
    // разрешение визуальной реакции проверяется отдельно в scale.
    readonly property bool pointerInside: iconMouse.containsMouse
    readonly property string appClass: String(toplevel?.lastIpcObject?.class
                                               ?? toplevel?.wayland?.appId
                                               ?? "")
    readonly property string iconPath: {
        IconService.revision;
        return IconService.resolve(toplevel);
    }
    signal hoverEntered(var toplevel)
    signal hoverExited(var toplevel)
    signal activated(var toplevel)

    width: iconSlot
    height: 46
    x: baseX + hoverOffset

    Behavior on hoverOffset {
        StandardAnimation {
            duration: Motion.defaultDuration
        }
    }

    onHoverOffsetTargetChanged: hoverOffset = hoverOffsetTarget

    // Масштабируется только изображение; слот и его MouseArea сохраняют размер.
    // Раздвижение соседних слотов рассчитывает DockGroup.
    Item {
        x: (parent.width - width) / 2
        y: (parent.height - height) / 2 + iconRoot.pressOffset
        width: Metrics.iconSize
        height: Metrics.iconSize
        scale: iconRoot.interactionEnabled && iconRoot.pointerInside
               ? Metrics.iconHoverScale : 1
        transformOrigin: Item.Center

        Behavior on scale {
            StandardAnimation {}
        }

        Behavior on y {
            StandardAnimation {
                duration: Motion.defaultDuration
            }
        }

        Image {
            id: appImage
            anchors.fill: parent
            source: iconRoot.iconPath
            cache: true
            // Image-провайдер темы сам выбирает SVG/PNG, а sourceSize задаёт
            // ему достаточно большой размер целевой текстуры.
            sourceSize: Qt.size(
                Math.ceil(width * Metrics.iconHoverScale
                          * Math.max(1, Screen.devicePixelRatio)
                          * Metrics.iconRasterOversample),
                Math.ceil(height * Metrics.iconHoverScale
                          * Math.max(1, Screen.devicePixelRatio)
                          * Metrics.iconRasterOversample))
            fillMode: Image.PreserveAspectFit
            smooth: true
            visible: iconRoot.iconPath !== ""
                     && status === Image.Ready
        }

        Rectangle {
            anchors.fill: parent
            visible: !appImage.visible
            radius: 16
            color: "#46586a"

            Text {
                anchors.centerIn: parent
                text: iconRoot.appClass.slice(0, 1).toUpperCase() || "?"
                color: "white"
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

        onPressed: iconRoot.pressOffset = 8
        onReleased: iconRoot.pressOffset = 0
        onCanceled: iconRoot.pressOffset = 0

        onEntered: iconRoot.hoverEntered(iconRoot.toplevel)
        onExited: iconRoot.hoverExited(iconRoot.toplevel)
        onClicked: iconRoot.activated(iconRoot.toplevel)
    }

}
