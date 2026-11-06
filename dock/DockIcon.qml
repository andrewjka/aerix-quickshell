pragma ComponentBehavior: Bound

import QtQuick
import "../core"
import "../services"

Item {
    id: iconRoot

    required property var modelData
    required property int index
    required property int iconSlot
    required property bool isHovered
    required property real hoverOffsetTarget
    property real baseX: 0
    property real hoverOffset: 0

    readonly property var toplevel: modelData
    readonly property bool pointerInside: iconMouse.containsMouse
    readonly property string appClass: String(toplevel?.lastIpcObject?.class
                                               ?? toplevel?.wayland?.appId
                                               ?? "")
    readonly property string iconPath: {
        IconService.revision;
        return IconService.resolve(toplevel);
    }

    signal hoverEntered
    signal hoverExited
    signal activated

    width: iconSlot
    height: 46
    x: baseX + hoverOffset
    z: iconMouse.containsMouse ? 1000 : index

    Behavior on hoverOffset {
        StandardAnimation {}
    }

    onHoverOffsetTargetChanged: hoverOffset = hoverOffsetTarget

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

    MouseArea {
        id: iconMouse
        x: -Metrics.hoverPadding
        y: -Metrics.hoverPadding
        width: parent.width + 2 * Metrics.hoverPadding
        height: parent.height + 2 * Metrics.hoverPadding
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor

        onEntered: iconRoot.hoverEntered()
        onExited: iconRoot.hoverExited()
        onClicked: iconRoot.activated()
    }
}
