import QtQuick

// Один владелец mouse grab от нажатия до отпускания, включая выход за границы.
MouseArea {
    id: pointer
    acceptedButtons: Qt.LeftButton
    preventStealing: true
    hoverEnabled: true
    cursorShape: dragging ? Qt.ClosedHandCursor : Qt.OpenHandCursor
    property bool dragging: false
    property point pressPosition
    signal started()
    signal moved(real pointerX, real pointerY)
    signal dropped(real pointerX, real pointerY)
    signal canceledDrag()
    signal tapped()
    signal interactionChanged(bool held)

    onPressed: mouse => {
        pressPosition = Qt.point(mouse.x, mouse.y);
        dragging = false;
        interactionChanged(true);
    }
    onPositionChanged: mouse => {
        if (!pressed)
            return;
        if (!dragging && Math.hypot(mouse.x - pressPosition.x,
            mouse.y - pressPosition.y) >= Qt.styleHints.startDragDistance) {
            dragging = true;
            started();
        }
        if (dragging)
            moved(mouse.x, mouse.y);
    }
    onReleased: mouse => {
        if (dragging)
            dropped(mouse.x, mouse.y);
        else
            tapped();
        dragging = false;
        interactionChanged(false);
    }
    onCanceled: {
        dragging = false;
        canceledDrag();
        interactionChanged(false);
    }
}
