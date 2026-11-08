pragma ComponentBehavior: Bound
pragma Singleton

import QtQml
import QtQuick
import Quickshell
import Quickshell.Io
import "../services/MotionConfig.js" as Config

// Motion загружает и проверяет единый плоский профиль из motion.conf.
QtObject {
    id: motion

    // Значения сохраняют интерфейс рабочим до первого успешного чтения.
    property var motionConfiguration: ({
        standardDurationMs: 512,
        extendedDurationMs: 768,
        surfaceSpringStartScale: 0.16,
        surfaceSpringOvershoot: 0.16,
        dockCloseDelayMs: 1128,
        standardBezierCurve: [0.05, 0.9, 0.1, 1.05, 1, 1]
    })

    readonly property int standardDurationMs: motionConfiguration.standardDurationMs
    readonly property int extendedDurationMs: motionConfiguration.extendedDurationMs
    readonly property real surfaceSpringStartScale:
        motionConfiguration.surfaceSpringStartScale
    readonly property real surfaceSpringOvershoot:
        motionConfiguration.surfaceSpringOvershoot
    readonly property int dockCloseDelayMs: motionConfiguration.dockCloseDelayMs
    readonly property var standardBezierCurve: motionConfiguration.standardBezierCurve

    readonly property var surfaceSpring: QtObject {
        readonly property int durationMs: motion.standardDurationMs
        readonly property real startScale: motion.surfaceSpringStartScale
        readonly property int easingType: Easing.BezierSpline
        readonly property var bezierCurve: motion.springBezierCurve(
            motion.surfaceSpringOvershoot)
        readonly property real maximumProgress: Math.max(
            1, motion.standardBezierCurve[1], 1 + motion.surfaceSpringOvershoot)
        readonly property real maximumScale: startScale
            + (1 - startScale) * maximumProgress
    }

    function springBezierCurve(overshoot) {
        return [standardBezierCurve[0], standardBezierCurve[1],
            standardBezierCurve[2], 1 + overshoot, 1, 1];
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
