import Quickshell
import "bar"
import "dock"

ShellRoot {
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
