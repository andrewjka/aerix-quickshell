import QtQml
import Quickshell.Io

// Живёт вместе с overview. awww задаёт фон output, общий для его workspace.
QtObject {
    id: source
    property var outputs: ({})
    function backgroundFor(monitorName) {
        return outputs[monitorName] ?? { image: "", color: "transparent" };
    }
    function refresh() {
        if (!query.running) query.running = true;
    }
    Component.onCompleted: refresh()
    property Timer refreshTimer: Timer {
        interval: 5000; running: true; repeat: true
        onTriggered: source.refresh()
    }
    property Process query: Process {
        command: ["awww", "query", "-j"]
        stdout: StdioCollector { id: output; waitForEnd: true }
        onExited: (code, status) => {
            if (code !== 0) return;
            try {
                const data = JSON.parse(output.text);
                const next = {};
                for (const monitor of data[""] ?? []) {
                    const displaying = monitor.displaying ?? {};
                    next[monitor.name] = {
                        image: displaying.image ? "file://" + encodeURI(displaying.image).replace(/#/g, "%23").replace(/\?/g, "%3F") : "",
                        color: displaying.color ? "#" + String(displaying.color).replace(/^#/, "") : "transparent"
                    };
                }
                if (JSON.stringify(next) !== JSON.stringify(source.outputs)) source.outputs = next;
            } catch (error) {
                console.warn("Wallpaper query:", error);
            }
        }
    }
}
