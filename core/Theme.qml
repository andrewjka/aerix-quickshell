pragma ComponentBehavior: Bound
pragma Singleton
import QtQml
import Quickshell
import Quickshell.Io
import "../services/ThemeConfig.js" as Config

// Выбор файла и палитра обновляются независимо через наблюдение FileView.
// Парсер находится в services, отдельно от визуальных токенов.
QtObject {
    id: theme
    property string selectedThemePath: "themes/dark.conf"
    readonly property string resolvedThemePath: selectedThemePath.startsWith("/")
        ? selectedThemePath : Quickshell.shellPath(selectedThemePath)
    property string activeThemePath: ""
    // Читаемая аварийная палитра до первого успешного чтения.
    property var palette: ({
        values: { background: "#192B39", surface: "#000000",
            surfaceElevated: "#344D60", text: "#EAF5FC", surfaceText: "#FFFFFF",
            hover: "#FFFFFF", outline: "#FFFFFF", shadow: "#10191F", error: "#F29B9B" },
        opacity: { background: 1, surface: 0.08, shadow: 0.48, hover: 0.20,
            outline: 0.92, previewTitle: 0.88, textEnabled: 0.90, textDisabled: 0.50 }
    })
    readonly property string transparentColor: "transparent"
    readonly property string shadowMaskColor: "#FFFFFF"
    readonly property var primaryTextColor: palette.values.text
    readonly property var glassTextColor: palette.values.surfaceText
    readonly property var errorColor: palette.values.error
    readonly property var elevatedSurfaceColor: palette.values.surfaceElevated
    readonly property var statusBarBackgroundColor: withOpacity("background", "background")
    readonly property var floatingSurfaceBackgroundColor: withOpacity("surface", "surface")
    readonly property var panelShadowColor: withOpacity("shadow", "shadow")
    readonly property var hoverOverlayColor: withOpacity("hover", "hover")
    readonly property var selectionOutlineColor: withOpacity("outline", "outline")
    readonly property var windowPreviewTitleBackgroundColor:
        withOpacity("surfaceElevated", "previewTitle")
    readonly property var enabledTextColor: withOpacity("text", "textEnabled")
    readonly property var disabledTextColor: withOpacity("text", "textDisabled")

    function withOpacity(colorKey, opacityKey) {
        const color = Qt.color(palette.values[colorKey]);
        return Qt.rgba(color.r, color.g, color.b, palette.opacity[opacityKey]);
    }
    function loadSelection(text) {
        try {
            selectedThemePath = Config.parseSelection(text);
        } catch (error) {
            console.warn("theme.conf: " + error.message);
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
        path: Quickshell.shellPath("theme.conf")
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
