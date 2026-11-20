pragma ComponentBehavior: Bound

import Quickshell
import QtQml
import "services"
import "widgets/bar"
import "widgets/bar/StatusBar"
import "widgets/dock"
import "widgets/overview"
import "widgets/launcher"
import "widgets/polkit"

ShellRoot {
    id: shellRoot

    // Регистрация IPC transport-а — единственная lifecycle-задача root. IPC не
    // связан с клавиатурными биндами: их задаёт конфигурация Hyprland.
    Component.onCompleted: IpcService.handler

    LazyLoader {
        active: OverviewService.open

        component: WorkspaceOverview {
            targetScreen: OverviewService.targetScreen
            onDismissed: OverviewService.close()
        }
    }

    LazyLoader {
        activeAsync: AppLauncherService.open

        component: AppLauncher {
            targetScreen: AppLauncherService.targetScreen
            onDismissed: AppLauncherService.close()
        }
    }

    // Агент должен существовать постоянно: polkit регистрирует его в D-Bus
    // при создании; компактный popup показывается только на время запроса.
    PolkitDialog {}

    // Один процесс обслуживает все экраны. Variants создаёт окна панелей,
    // а singleton-сервисы остаются общими для всех мониторов.
    Variants {
        model: Quickshell.screens
        StatusBarShadow {}
    }

    Variants {
        model: Quickshell.screens
        StatusBar {}
    }

    Variants {
        model: Quickshell.screens
        // OSD surface существует на каждом экране, но активируется сервисом
        // только на мониторе, где изменилось значение.
        Osd {}
    }

    Variants {
        model: Quickshell.screens
        Scope {
            id: dockScope
            required property var modelData

            DockPanel {
                id: dockPanel
                modelData: dockScope.modelData
            }
            DockShadow {
                modelData: dockScope.modelData
                sourcePanel: dockPanel
            }
        }
    }
}
