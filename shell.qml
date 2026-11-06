import Quickshell
import "dock"

ShellRoot {
    // Один процесс Quickshell обслуживает все экраны; Variants создаёт только
    // лёгкое окно Dock на каждый монитор, не дублируя системные сервисы.
    Variants {
        model: Quickshell.screens
        DockPanel {}
    }
}
