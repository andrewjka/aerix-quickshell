import QtQuick

// Отличает короткий запуск от drag без Qt Quick Drag MIME-механизма: перенос
// остаётся целиком внутри сетки launcher и не создаёт внешнего drop protocol.
MouseArea {
    id: pointer

    acceptedButtons: Qt.LeftButton
    preventStealing: true
    hoverEnabled: true
    cursorShape: dragging ? Qt.ClosedHandCursor : Qt.PointingHandCursor
    property bool dragging: false
    property point pressPosition

    signal tapped()
    signal dragStarted(real pointerX, real pointerY)
    signal dragMoved(real pointerX, real pointerY)
    signal dragDropped(real pointerX, real pointerY)
    signal dragCanceled()

    onPressed: mouse => {
        pressPosition = Qt.point(mouse.x, mouse.y);
        dragging = false;
    }
    onPositionChanged: mouse => {
        if (!pressed)
            return;
        if (!dragging && Math.hypot(mouse.x - pressPosition.x,
            mouse.y - pressPosition.y) >= Qt.styleHints.startDragDistance) {
            dragging = true;
            dragStarted(mouse.x, mouse.y);
        }
        if (dragging)
            dragMoved(mouse.x, mouse.y);
    }
    onReleased: mouse => {
        if (dragging)
            dragDropped(mouse.x, mouse.y);
        else
            tapped();
        dragging = false;
    }
    onCanceled: {
        if (dragging)
            dragCanceled();
        dragging = false;
    }
}
