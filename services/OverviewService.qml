pragma Singleton

import QtQml
import Quickshell
import Quickshell.Hyprland

// Общее состояние и публичные команды workspace overview. Сервис не создаёт
// visual surface: shell.qml лишь подписывается на open и отображает её.
QtObject {
    id: service

    property bool open: false
    property var targetScreen: null

    function focusedScreen() {
        const focusedMonitor = Hyprland.focusedMonitor;
        return Quickshell.screens.find(screen =>
            Hyprland.monitorFor(screen)?.name === focusedMonitor?.name)
            ?? Quickshell.screens[0] ?? null;
    }

    function openForScreen(screen) {
        if (!screen)
            return;
        targetScreen = screen;
        open = true;
    }

    function openOnFocusedScreen() {
        openForScreen(focusedScreen());
    }

    // Команда намеренно не идемпотентна: каждый вызов переключает overview.
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
