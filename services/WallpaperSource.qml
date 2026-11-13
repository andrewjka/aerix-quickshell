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
    property var resolutionQueue: []
    property var resolvingOutputs: ({})
    property string resolvingMonitor: ""
    property string resolvingPath: ""
    // Пустые outputs после успешного запроса означают, что awww ничего не
    // отдаёт; ошибка запуска/выхода фиксируется отдельно.
    property bool failed: false

    function backgroundFor(monitorName) {
        return outputs[monitorName] ?? { image: "", color: Theme.transparentColor };
    }

    function fileUrl(path) {
        return "file://" + encodeURI(path).replace(/#/g, "%23").replace(/\?/g, "%3F");
    }

    function homeDirectory(path) {
        const parts = path.split("/");
        return parts.length > 2 && parts[1] === "home" ? "/home/" + parts[2] : "";
    }

    function setResolvedPath(path) {
        const next = Object.assign({}, resolvingOutputs);
        next[resolvingMonitor] = {
            image: path.length > 0 ? fileUrl(path) : "",
            color: next[resolvingMonitor].color
        };
        resolvingOutputs = next;
    }

    function resolveNext() {
        if (resolutionQueue.length === 0) {
            if (JSON.stringify(resolvingOutputs) !== JSON.stringify(outputs))
                outputs = resolvingOutputs;
            return;
        }

        const entry = resolutionQueue.shift();
        resolutionQueue = resolutionQueue;
        resolvingMonitor = entry.monitor;
        resolvingPath = entry.path;
        pathCheck.command = ["test", "-r", resolvingPath];
        pathCheck.running = true;
    }

    function findMovedPath() {
        const home = homeDirectory(resolvingPath);
        const fileName = resolvingPath.slice(resolvingPath.lastIndexOf("/") + 1);
        if (home.length === 0 || fileName.length === 0) {
            setResolvedPath("");
            resolveNext();
            return;
        }

        // awww запоминает абсолютный путь. После переноса репозитория ищем
        // только одноимённый файл в пользовательских каталогах Wallpapers.
        movedPathFinder.command = ["find", home, "-maxdepth", "5", "-type", "f",
            "-path", "*/Wallpapers/" + fileName, "-print", "-quit"];
        movedPathFinder.running = true;
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
                const queue = [];
                for (const monitor of data[""] ?? []) {
                    const displaying = monitor.displaying ?? {};
                    const imagePath = String(displaying.image ?? "");
                    next[monitor.name] = {
                        // Не передаём Image неподтверждённый путь: awww мог
                        // сохранить его до переноса каталога с обоями.
                        image: "",
                        color: displaying.color ? "#" + String(displaying.color).replace(/^#/, "")
                            : Theme.transparentColor
                    };
                    if (imagePath.length > 0)
                        queue.push({ monitor: monitor.name, path: imagePath });
                }
                source.resolvingOutputs = next;
                source.resolutionQueue = queue;
                source.resolveNext();
            } catch (error) {
                console.warn("Wallpaper query:", error);
            }
        }
    }

    property Process pathCheck: Process {
        onExited: (code, status) => {
            if (code === 0) {
                source.setResolvedPath(source.resolvingPath);
                source.resolveNext();
            } else {
                source.findMovedPath();
            }
        }
    }

    property Process movedPathFinder: Process {
        stdout: StdioCollector { id: movedPath; waitForEnd: true }
        onExited: (code, status) => {
            const resolved = code === 0 ? movedPath.text.trim() : "";
            source.setResolvedPath(resolved);
            source.resolveNext();
        }
    }
}
