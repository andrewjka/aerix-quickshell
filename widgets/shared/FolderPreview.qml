pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import "../../core"

// Четыре миниатюры папки: фиксированные ячейки сохраняют сетку даже у
// неквадратных иконок. Иконка внутри ячейки задаётся только по высоте.
Item {
    id: preview
    required property var entries
    property real devicePixelRatio: 1
    property real rasterIconHeight: 0
    readonly property real gap: Metrics.spacing / 2

    Repeater {
        model: preview.entries.slice(0, 4)
        delegate: Item {
            id: cell
            required property int index
            required property var modelData
            width: (preview.width - preview.gap) / 2
            height: (preview.height - preview.gap) / 2
            x: (index % 2) * (width + preview.gap)
            y: Math.floor(index / 2) * (height + preview.gap)

            IconWidget {
                anchors.centerIn: parent
                height: parent.height
                readonly property string iconName: String(cell.modelData?.icon ?? "")
                iconSource: iconName.startsWith("/") ? "file://" + iconName
                    : iconName && Quickshell.hasThemeIcon(iconName)
                        ? Quickshell.iconPath(iconName) : ""
                tinted: false
                asynchronous: true
                devicePixelRatio: preview.devicePixelRatio
                // При анимации surface можно держать постоянный размер текстуры.
                rasterScale: preview.rasterIconHeight > 0
                    ? preview.rasterIconHeight / Math.max(1, height) : 1
            }
        }
    }
}
