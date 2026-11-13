pragma ComponentBehavior: Bound
pragma Singleton

import QtQml
import Quickshell
import Quickshell.Io
import "../utils/LanguageConfig.js" as Config

// Английский пакет — неизменяемая базовая схема. Выбранный пакет применяется
// только после точной проверки его ключей относительно этой схемы.
QtObject {
    id: i18n

    property string selectedLanguagePath: "languages-pack/en.conf"
    readonly property string resolvedLanguagePath: selectedLanguagePath.startsWith("/")
        ? selectedLanguagePath : Quickshell.shellPath(selectedLanguagePath)
    readonly property string resolvedBaselinePath:
        Quickshell.shellPath("languages-pack/en.conf")
    property string activeLanguagePath: ""
    property var baselineMessages: ({})
    property var messages: ({})
    property var loadedLanguageText: null
    property bool baselineReady: false

    function tr(key, args) {
        var message = messages[key];
        if (typeof message !== "string")
            message = baselineMessages[key];
        if (typeof message !== "string")
            return key;
        var replacements = args ?? ({});
        return message.replace(/\{([a-zA-Z0-9_]+)\}/g, function(match, name) {
            return Object.prototype.hasOwnProperty.call(replacements, name)
                ? String(replacements[name]) : match;
        });
    }

    function loadSelection(text) {
        try {
            selectedLanguagePath = Config.parseSelection(text);
        } catch (error) {
            console.warn("language.conf: " + error.message);
        }
    }

    function loadBaseline(text) {
        try {
            baselineMessages = Config.parsePack(text);
            baselineReady = true;
            messages = baselineMessages;
            activeLanguagePath = Quickshell.shellPath("languages-pack/en.conf");
            if (loadedLanguageText !== null)
                loadLanguage(loadedLanguageText);
        } catch (error) {
            console.warn("languages-pack/en.conf: " + error.message);
        }
    }

    function loadLanguage(text) {
        loadedLanguageText = text;
        if (!baselineReady)
            return;
        // en.conf уже разобран baselineFile. Это исключает гонку двух FileView
        // при атомарной записи английского пакета.
        if (resolvedLanguagePath === resolvedBaselinePath)
            return;
        try {
            const candidate = Config.parsePack(text);
            messages = Config.validatePack(candidate, baselineMessages);
            activeLanguagePath = resolvedLanguagePath;
        } catch (error) {
            console.warn(resolvedLanguagePath + ": " + error.message);
        }
    }

    property FileView selectionFile: FileView {
        path: Quickshell.shellPath("language.conf")
        preload: true
        watchChanges: true
        blockWrites: true
        onLoaded: i18n.loadSelection(text())
        onFileChanged: reload()
    }

    property FileView baselineFile: FileView {
        path: i18n.resolvedBaselinePath
        preload: true
        watchChanges: true
        blockWrites: true
        onLoaded: i18n.loadBaseline(text())
        onFileChanged: reload()
    }

    property FileView languageFile: FileView {
        path: i18n.resolvedLanguagePath
        preload: true
        watchChanges: true
        blockWrites: true
        onLoaded: i18n.loadLanguage(text())
        onFileChanged: reload()
    }

    onSelectedLanguagePathChanged: loadedLanguageText = null

    Component.onCompleted: {
        if (selectionFile.loaded)
            loadSelection(selectionFile.text());
        if (baselineFile.loaded)
            loadBaseline(baselineFile.text());
        if (languageFile.loaded)
            loadLanguage(languageFile.text());
    }
}
