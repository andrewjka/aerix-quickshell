pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Hyprland
// В установленной версии Quickshell GlobalShortcut зарегистрирован в
// отдельном подмодуле, хотя сам Hyprland импортирует его для runtime.
import Quickshell.Hyprland._GlobalShortcuts
import "bar"
import "dock"
import "overview"

ShellRoot {
    id: shellRoot


    property bool overviewOpen: false
    property bool overviewShortcutHeld: false
    property var overviewScreen: null

    function focusedScreen() {
        const focusedMonitor = Hyprland.focusedMonitor;
        return Quickshell.screens.find(screen =>
            Hyprland.monitorFor(screen)?.name === focusedMonitor?.name)
            ?? Quickshell.screens[0] ?? null;
    }

    function toggleOverview() {
        if (overviewOpen) {
            overviewOpen = false;
            return;
        }
        openOverviewForScreen(focusedScreen());
    }

    function openOverviewForScreen(screen) {
        overviewScreen = screen;
        overviewOpen = overviewScreen !== null;
    }

    GlobalShortcut {
        appid: "aerix"
        name: "workspace-overview"
        description: "Open workspace overview"
        onPressed: {
            if (shellRoot.overviewShortcutHeld)
                return;
            shellRoot.overviewShortcutHeld = true;
            shellRoot.toggleOverview();
        }
        onReleased: shellRoot.overviewShortcutHeld = false
    }

    LazyLoader {
        active: shellRoot.overviewOpen

        component: WorkspaceOverview {
            targetScreen: shellRoot.overviewScreen
            onDismissed: shellRoot.overviewOpen = false
        }
    }

    // Один процесс обслуживает все экраны. Variants создаёт окна панелей,
    // а singleton-сервисы остаются общими для всех мониторов.
    Variants {
        model: Quickshell.screens
        StatusBarShadow {}
    }

    Variants {
        model: Quickshell.screens
        StatusBar {
            overviewOpen: shellRoot.overviewOpen
            onOverviewRequested: screen => shellRoot.openOverviewForScreen(screen)
        }
    }

    Variants {
        model: Quickshell.screens
        Scope {
            id: dockScope
            required property var modelData

            DockPanel {
                id: dockPanel
                modelData: dockScope.modelData
                overviewOpen: shellRoot.overviewOpen
            }
            DockShadow {
                modelData: dockScope.modelData
                sourcePanel: dockPanel
            }
        }
    }
}
