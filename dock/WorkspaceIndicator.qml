import QtQuick
import "../core"

// Обводка активного workspace: скольжение между группами, расширение по
// вертикали и короткое покачивание при попытке выйти за край списка workspace.
Rectangle {
    id: indicator

    required property DockGroup targetGroup
    required property Item groupsRow

    property DockGroup displayedGroup: null
    property real slideProgress: 1
    property real slideStartX: 0
    property real slideStartWidth: 0
    property real verticalExpansion: 0
    property real nudgeProgress: 0
    property int nudgeDirection: 1

    readonly property real nudgeOffset: nudgeDirection * 8
        * Math.sin(Math.PI * Math.max(0, Math.min(1, nudgeProgress)))
    readonly property real destinationX: displayedGroup
        ? groupsRow.x + displayedGroup.x + displayedGroup.leftWorkspaceGap + 2
        : 0
    readonly property real destinationWidth: displayedGroup
        ? displayedGroup.width - displayedGroup.leftWorkspaceGap - displayedGroup.rightWorkspaceGap - 4
        : 0

    /** Показывает, что в выбранном направлении больше нет рабочих пространств. */
    function nudge(direction) {
        nudgeDirection = direction < 0 ? -1 : 1;
        nudgeAnimation.restart();
    }

    onTargetGroupChanged: {
        const shouldSlide = displayedGroup !== null && targetGroup !== null;
        workspaceTransition.stop();
        // nudge — отдельный добавочный эффект. Он продолжает идти во время
        // переключения workspace, поэтому из snapshot основной траектории
        // исключаем уже видимое nudge-смещение.
        slideStartX = x - nudgeOffset;
        slideStartWidth = width;
        slideProgress = shouldSlide ? 0 : 1;
        displayedGroup = targetGroup;
        if (shouldSlide)
            workspaceTransition.start();
        else
            verticalExpansion = 0;
    }

    visible: displayedGroup !== null
    x: slideStartX + (destinationX - slideStartX) * slideProgress + nudgeOffset
    y: groupsRow.y + 11 - verticalExpansion / 2
    width: slideStartWidth + (destinationWidth - slideStartWidth) * slideProgress
    height: 26 + verticalExpansion
    radius: Metrics.panelRadius
    color: Theme.transparentColor
    border.width: 0.5
    border.pixelAligned: false
    // Активный workspace использует тот же цвет рамки, но без общей alpha.
    border.color: Theme.withOpacity("border", 1)
    antialiasing: true

    // Сначала переносим и расширяем обводку, затем возвращаем её высоту.
    SequentialAnimation {
        id: workspaceTransition

        ParallelAnimation {
            StandardAnimation {
                target: indicator
                property: "verticalExpansion"
                // Без from анимация продолжает текущую высоту после
                // прерывания, вместо мгновенного возврата к нулю.
                to: 20
                duration: Motion.durationMs
            }
            StandardAnimation {
                target: indicator
                property: "slideProgress"
                from: 0
                to: 1
                duration: Motion.durationMs
            }
        }
        StandardAnimation {
            target: indicator
            property: "verticalExpansion"
            to: 0
            duration: Motion.durationMs
        }
    }

    // Синус превращает один прогресс в движение к краю и обратно.
    StandardAnimation {
        id: nudgeAnimation
        target: indicator
        property: "nudgeProgress"
        from: 0
        to: 1
        duration: Motion.durationMs
    }
}
