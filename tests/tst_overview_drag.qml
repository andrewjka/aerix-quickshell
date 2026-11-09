import QtQuick
import QtTest
import "../overview"

Item {
    width: 640
    height: 240
    property int starts: 0
    property int drops: 0
    property int taps: 0
    property real dropX: 0
    property int workspaceDrops: 0
    property int windowDrops: 0
    Item {
        id: card
        x: 150; width: 160; height: 160
        DragSurface {
            anchors.fill: parent
            onDropped: workspaceDrops++
        }
        Item {
            x: 10; y: 40; width: 140; height: 100
            DragSurface { anchors.fill: parent; onDropped: windowDrops++ }
        }
    }
    DragSurface {
        id: source
        width: 120; height: 100
        onStarted: starts++
        onDropped: (x, y) => { drops++; dropX = x; }
        onTapped: taps++
    }
    TestCase {
        name: "OverviewPointer"
        when: windowShown
        function init() { starts = 0; drops = 0; taps = 0; workspaceDrops = 0; windowDrops = 0; }
        function test_workspaceHeader() {
            mousePress(card, 20, 15);
            mouseMove(card, 250, 60);
            mouseRelease(card, 250, 60);
            compare(workspaceDrops, 1);
            compare(windowDrops, 0);
        }
        function test_windowAboveWorkspace() {
            mousePress(card, 20, 60);
            mouseMove(card, 250, 60);
            mouseRelease(card, 250, 60);
            compare(windowDrops, 1);
            compare(workspaceDrops, 0);
        }
        function test_hoverDoesNotDrag() {
            mouseMove(source, 15, 15);
            mouseMove(source, 90, 60);
            compare(starts, 0);
            compare(drops, 0);
        }
        function test_click() {
            mouseClick(source, 20, 20);
            compare(taps, 1);
            compare(starts, 0);
        }
        function test_dragOutsideSource() {
            mousePress(source, 20, 20);
            mouseMove(source, 70, 30);
            mouseMove(source, 400, 30);
            mouseRelease(source, 400, 30);
            compare(starts, 1);
            compare(drops, 1);
            compare(taps, 0);
            compare(dropX, 400);
        }
        function test_secondDrag() { test_dragOutsideSource(); }
    }
}
