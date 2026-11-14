pragma Singleton

import QtQml
import Quickshell
import Quickshell.Hyprland

// Состояние launcher отделено от visual surface, как и workspace overview.
QtObject {
    id: service

    property bool open: false
    property var targetScreen: null

    function openOnFocusedScreen() {
        const focusedMonitor = Hyprland.focusedMonitor;
        targetScreen = Quickshell.screens.find(screen =>
            Hyprland.monitorFor(screen)?.name === focusedMonitor?.name)
            ?? Quickshell.screens[0] ?? null;
        open = targetScreen !== null;
    }

    function toggle() {
        if (open)
            close();
        else
            openOnFocusedScreen();
    }

    function close() {
        open = false;
    }
}
