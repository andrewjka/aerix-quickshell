pragma ComponentBehavior: Bound
pragma Singleton
import QtQml
import Quickshell
import Quickshell.Io
import "../utils/ThemeConfig.js" as Config

// Выбор файла и палитра обновляются независимо через наблюдение FileView.
// Парсер находится в utils, отдельно от визуальных токенов.
QtObject {
    id: theme
    property string selectedThemePath: "themes/dark.conf"
    readonly property string resolvedThemePath: selectedThemePath.startsWith("/")
        ? selectedThemePath : Quickshell.shellPath(selectedThemePath)
    property string activeThemePath: ""
    // Читаемая аварийная палитра до первого успешного чтения.
    property var palette: ({
        values: { background: "#1D2A36", foreground: "#E4F1F7",
            accent: "#5DBAE7", hover: "#98DDF5", border: "#47677D",
            shadow: "#0D151B", overlay: "#071017" },
        opacity: { background: 0.16, foreground: 0.94, accent: 0.96,
            hover: 0.22, border: 0.78, shadow: 0.52, overlay: 0.66,
            disabled: 0.52 }
    })
    readonly property string transparentColor: "transparent"
    readonly property string shadowMaskColor: "#FFFFFF"
    readonly property var foregroundColor: withOpacity("foreground", "foreground")
    readonly property var accentColor: withOpacity("accent", "accent")
    readonly property var backgroundColor: withOpacity("background", "background")
    readonly property var hoverColor: withOpacity("hover", "hover")
    readonly property var borderColor: withOpacity("border", "border")
    readonly property var shadowColor: withOpacity("shadow", "shadow")
    readonly property var overlayColor: withOpacity("overlay", "overlay")
    readonly property var disabledForegroundColor:
        withOpacity("foreground", "disabled")
    // Подложка workspace непрозрачна, чтобы не наследовать alpha панели.
    readonly property var desktopBackgroundColor: palette.values.background

    function withOpacity(colorKey, opacityKey) {
        const color = Qt.color(palette.values[colorKey]);
        const opacity = typeof opacityKey === "number"
            ? opacityKey : palette.opacity[opacityKey];
        return Qt.rgba(color.r, color.g, color.b, opacity);
    }
    function loadSelection(text) {
        try {
            selectedThemePath = Config.parseSelection(text);
        } catch (error) {
            console.warn("configs/theme.conf: " + error.message);
        }
    }
    function loadPalette(text) {
        try {
            const next = Config.parsePalette(text);
            palette = next;
            activeThemePath = resolvedThemePath;
        } catch (error) {
            console.warn(resolvedThemePath + ": " + error.message);
        }
    }
    property FileView selectionFile: FileView {
        path: Quickshell.shellPath("configs/theme.conf")
        preload: true
        watchChanges: true
        blockWrites: true
        onLoaded: theme.loadSelection(text())
        onFileChanged: reload()
    }
    // FileView переключает наблюдение при смене пути. Применяем только
    // полностью проверенную палитру, сохраняя предыдущую при ошибках.
    property FileView paletteFile: FileView {
        path: theme.resolvedThemePath
        preload: true
        watchChanges: true
        blockWrites: true
        onLoaded: theme.loadPalette(text())
        onFileChanged: reload()
    }
    Component.onCompleted: {
        if (selectionFile.loaded)
            loadSelection(selectionFile.text());
        if (paletteFile.loaded)
            loadPalette(paletteFile.text());
    }
}
