pragma Singleton

import QtQml

// Общее состояние анимации Dock для его видимой поверхности и отдельного слоя тени.
QtObject {
    property var openByScreen: ({})
    property var widthByScreen: ({})

    function isOpen(screenName) {
        return Boolean(openByScreen[screenName]);
    }

    function setOpen(screenName, open) {
        if (isOpen(screenName) === open)
            return;

        const updated = Object.assign({}, openByScreen);
        updated[screenName] = open;
        openByScreen = updated;
    }

    function widthFor(screenName, fallback) {
        const width = widthByScreen[screenName];
        return Number.isFinite(width) ? width : fallback;
    }

    function setWidth(screenName, width) {
        if (widthByScreen[screenName] === width)
            return;

        const updated = Object.assign({}, widthByScreen);
        updated[screenName] = width;
        widthByScreen = updated;
    }
}
