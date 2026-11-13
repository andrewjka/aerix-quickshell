pragma ComponentBehavior: Bound
pragma Singleton

import QtQml
import QtQuick
import Quickshell
import Quickshell.Io
import "../utils/MotionConfig.js" as Config

// Motion загружает и проверяет единый плоский профиль из motion.conf.
QtObject {
    id: motion

    // Значения сохраняют интерфейс рабочим до первого успешного чтения.
    property var motionConfiguration: ({
        durationMs: 512,
        springStartScale: 0.16,
        springOvershoot: 0.16,
        dockCloseDelayMs: 1128,
        bezierCurve: [0.05, 0.9, 0.1, 1.05, 1, 1]
    })

    readonly property int durationMs: motionConfiguration.durationMs
    readonly property real springStartScale: motionConfiguration.springStartScale
    readonly property real springOvershoot: motionConfiguration.springOvershoot
    readonly property int dockCloseDelayMs: motionConfiguration.dockCloseDelayMs
    readonly property var bezierCurve: motionConfiguration.bezierCurve

    readonly property var spring: QtObject {
        readonly property int durationMs: motion.durationMs
        readonly property real startScale: motion.springStartScale
        readonly property int easingType: Easing.BezierSpline
        readonly property var bezierCurve: motion.springBezierCurve(
            motion.springOvershoot)
        readonly property real maximumProgress: Math.max(
            1, motion.bezierCurve[1], 1 + motion.springOvershoot)
        readonly property real maximumScale: startScale
            + (1 - startScale) * maximumProgress
    }

    function springBezierCurve(overshoot) {
        return [bezierCurve[0], bezierCurve[1],
            bezierCurve[2], 1 + overshoot, 1, 1];
    }

    // Некорректный файл не заменяет уже применённый профиль.
    function loadConfiguration(text) {
        try {
            motionConfiguration = Config.parse(text);
        } catch (error) {
            console.warn("motion.conf: " + error.message);
        }
    }

    property FileView motionConfigFile: FileView {
        id: motionFile
        path: Quickshell.shellPath("motion.conf")
        preload: true
        watchChanges: true
        blockWrites: true
        onLoaded: motion.loadConfiguration(text())
        onFileChanged: reload()
    }

    Component.onCompleted: {
        if (motionFile.loaded)
            loadConfiguration(motionFile.text());
    }
}
