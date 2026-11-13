import QtQml
import Quickshell.Io
import "../core"

// Живёт вместе с overview. awww задаёт фон output, общий для его workspace.
// Фон запрашивается один раз при создании; смена обоев при открытом overview
// редкость, поэтому постоянного опроса нет. Вызови refresh(), если нужно
// перечитать состояние вручную.
QtObject {
    id: source
    property var outputs: ({})
    // Пустые outputs после успешного запроса означают, что awww ничего не
    // отдаёт; ошибка запуска/выхода фиксируется отдельно.
    property bool failed: false

    function backgroundFor(monitorName) {
        return outputs[monitorName] ?? { image: "", color: Theme.transparentColor };
    }

    function refresh() {
        if (!query.running)
            query.running = true;
    }

    Component.onCompleted: refresh()

    property Process query: Process {
        command: ["awww", "query", "-j"]
        stdout: StdioCollector { id: output; waitForEnd: true }
        onExited: (code, status) => {
            if (code !== 0) {
                // Предупреждаем один раз, а не при каждой попытке.
                if (!source.failed)
                    console.warn("awww query failed: exit code", code);
                source.failed = true;
                return;
            }
            source.failed = false;
            try {
                const data = JSON.parse(output.text);
                const next = {};
                for (const monitor of data[""] ?? []) {
                    const displaying = monitor.displaying ?? {};
                    next[monitor.name] = {
                        image: displaying.image ? "file://" + encodeURI(displaying.image).replace(/#/g, "%23").replace(/\?/g, "%3F") : "",
                        color: displaying.color ? "#" + String(displaying.color).replace(/^#/, "")
                            : Theme.transparentColor
                    };
                }
                if (JSON.stringify(next) !== JSON.stringify(source.outputs))
                    source.outputs = next;
            } catch (error) {
                console.warn("Wallpaper query:", error);
            }
        }
    }
}
