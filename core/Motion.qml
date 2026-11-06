pragma Singleton

import QtQml

QtObject {
    readonly property int standardDuration: 768
    readonly property int workspaceSlideDuration: 512
    readonly property var standardCurve: [0.05, 0.9, 0.1, 1.05, 1, 1]
}
