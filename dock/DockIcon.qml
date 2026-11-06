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
    property bool isHovered: false
    property real hoverOffsetTarget: 0
    property real baseX: 0
    property real hoverOffset: 0

    // Указатель используется DockPanel после выезда панели, чтобы понять,
    // находится ли курсор уже над иконкой, даже если entered произошёл раньше.
    readonly property var toplevel: modelData
    readonly property bool pointerInside: iconMouse.containsMouse
    readonly property string appClass: String(toplevel?.lastIpcObject?.class
                                               ?? toplevel?.wayland?.appId
                                               ?? "")
    readonly property string iconPath: {
        IconService.revision;
        return IconService.resolve(toplevel);
    }

    // События поднимаются наверх; бизнес-логика остаётся вне делегата.
    signal hoverEntered(var toplevel)
    signal hoverExited(var toplevel)
    signal activated(var toplevel)

    width: iconSlot
    height: 46
    x: baseX + hoverOffset
    z: iconMouse.containsMouse ? 1000 : index

    Behavior on hoverOffset {
        StandardAnimation {}
    }

    onHoverOffsetTargetChanged: hoverOffset = hoverOffsetTarget

    // Внутренний слот масштабируется целиком, поэтому увеличение не меняет
    // занимаемую моделью ширину и не ломает плотную раскладку.
    Item {
        x: (parent.width - width) / 2
        y: 3
        width: 38
        height: 38
        scale: iconRoot.isHovered ? 1.5 : 1
        transformOrigin: Item.Center

        Behavior on scale {
            StandardAnimation {}
        }

        // sourceSize ограничивает bitmap-кэш двумя пикселями на экранный пиксель.
        Image {
            id: appImage
            anchors.fill: parent
            source: iconRoot.iconPath
            cache: true
            // Keep two physical pixels per displayed pixel without retaining
            // unnecessarily large desktop icon bitmaps in the image cache.
            sourceSize: Qt.size(Math.ceil(width * 2), Math.ceil(height * 2))
            fillMode: Image.PreserveAspectFit
            smooth: true
            visible: iconRoot.iconPath !== "" && status === Image.Ready
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

    // Небольшая зона безопасности вокруг визуальной иконки предотвращает
    // дрожание hover при движении курсора по плотной раскладке.
    MouseArea {
        id: iconMouse
        x: -Metrics.hoverPadding
        y: -Metrics.hoverPadding
        width: parent.width + 2 * Metrics.hoverPadding
        height: parent.height + 2 * Metrics.hoverPadding
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor

        onEntered: iconRoot.hoverEntered(iconRoot.toplevel)
        onExited: iconRoot.hoverExited(iconRoot.toplevel)
        onClicked: iconRoot.activated(iconRoot.toplevel)
    }
}
