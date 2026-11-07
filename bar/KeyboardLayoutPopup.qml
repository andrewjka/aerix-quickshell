pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import "../core"
import "../services"

// Временный слой меню и отдельная input-прозрачная поверхность общей тени.
PanelWindow {
    id: popup

    required property var barWindow
    required property Item anchorItem
    property int testLayoutCount: 0
    property int pendingIndex: -1
    property int selectedTestIndex: -1
    property bool expanded: false
    property real reveal: expanded ? 1 : 0
    readonly property var entries: KeyboardLayoutService.layouts.concat(
        Array.from({ length: testLayoutCount }, (_, i) => ({
            index: -1, label: String(i + 1), name: "", test: true
        })))
    readonly property int rowHeight: 32
    // По пикселю внутри viewport для сглаженного края обводки.
    readonly property int listHeight: Math.min(5, Math.max(1, entries.length)) * rowHeight
        + Math.max(0, Math.min(5, entries.length) - 1) * Metrics.popupRowSpacing + 2
    readonly property int renderMargin: Math.ceil(Metrics.panelShadowRadius) + 9
    readonly property int surfaceWidth: Math.min(196,
        screen.width - 2 * Metrics.statusBarHorizontalMargin)
    readonly property int surfaceHeight: listHeight + 2 * Metrics.spacing
        + (errorLabel.visible ? errorLabel.implicitHeight + Metrics.spacing : 0)
    readonly property real surfaceX: {
        const barWidth = barWindow.width;
        // mapToItem не подписывает binding на перемещения якоря.
        const itemX = anchorItem.x;
        const itemWidth = anchorItem.width;
        const position = anchorItem.mapToItem(barWindow.contentItem, 0, 0);
        return Math.round(Math.max(Metrics.statusBarHorizontalMargin,
            Math.min(position.x + itemWidth / 2 - surfaceWidth / 2,
                barWidth - Metrics.statusBarHorizontalMargin - surfaceWidth)));
    }

    signal dismissed()

    screen: barWindow.screen
    anchors { top: true; left: true }
    // Ignore исключает reserved area Bar из расчёта позиции: y задан от экрана.
    exclusionMode: ExclusionMode.Ignore
    margins.left: surfaceX - renderMargin
    margins.top: barWindow.height + 2 * Metrics.spacing - renderMargin
    implicitWidth: surfaceWidth + 2 * renderMargin
    implicitHeight: surfaceHeight + 2 * renderMargin
    color: "transparent"
    WlrLayershell.namespace: "aerix:keyboard-layout"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: expanded ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    mask: Region { item: popupFrame }

    // Одна прерываемая анимация: повторный клик меняет цель от текущего значения.
    Behavior on reveal {
        StandardAnimation {
            duration: Motion.defaultDuration
            onRunningChanged: {
                if (!running && !popup.expanded && popup.reveal === 0)
                    popup.dismissed();
            }
        }
    }

    function dismiss() { expanded = false; }
    function toggle() { expanded = !expanded; }

    function selectLayout(row) {
        const entry = entries[row];
        if (!entry || !expanded)
            return;
        if (entry.test) {
            selectedTestIndex = row;
            return; // Тестовые карточки меняют только выделение, без Hyprland IPC.
        }
        if (entry.index === KeyboardLayoutService.activeIndex) {
            dismiss();
        } else if (KeyboardLayoutService.select(entry.index)) {
            pendingIndex = entry.index;
        }
    }

    function moveSelection(step) {
        layoutList.currentIndex = Math.max(0,
            Math.min(entries.length - 1, layoutList.currentIndex + step));
        layoutList.positionViewAtIndex(layoutList.currentIndex, ListView.Contain);
    }

    Component.onCompleted: expanded = true
    onExpandedChanged: focusGrab.active = expanded

    HyprlandFocusGrab {
        id: focusGrab
        windows: [popup]
        onCleared: popup.dismiss()
    }

    Connections {
        target: KeyboardLayoutService
        function onActiveIndexChanged() {
            if (popup.pendingIndex >= 0
                    && popup.pendingIndex === KeyboardLayoutService.activeIndex
                    && !KeyboardLayoutService.commandPending)
                popup.dismiss();
        }
        function onCommandPendingChanged() {
            if (popup.pendingIndex >= 0 && !KeyboardLayoutService.commandPending
                    && popup.pendingIndex === KeyboardLayoutService.activeIndex)
                popup.dismiss();
        }
    }

    PanelShadowWindow {
        targetScreen: popup.screen
        shadowSource: shadowSurface
        shadowNamespace: "aerix:keyboard-layout-shadow"
        shadowOpacity: popupFrame.opacity
        WlrLayershell.layer: WlrLayer.Overlay
        anchors { top: true; left: true }
        margins.left: popup.margins.left
        margins.top: popup.margins.top
        implicitWidth: popup.width
        implicitHeight: popup.height

        Rectangle {
            id: shadowSurface
            x: popupFrame.x
            y: popupFrame.y
            width: popupFrame.width
            height: popupFrame.height
            radius: popupFrame.radius
            scale: popupFrame.scale
            transformOrigin: popupFrame.transformOrigin
            color: "transparent"
            antialiasing: true
        }
    }

    Rectangle {
        id: popupFrame
        x: popup.renderMargin
        y: popup.renderMargin + (popup.expanded ? 0 : -24)
        width: popup.surfaceWidth
        height: popup.surfaceHeight
        radius: Metrics.panelRadius
        color: Metrics.panelColor
        antialiasing: true
        scale: 0.12 + 0.88 * popup.reveal
        transformOrigin: Item.Top
        opacity: Math.max(0, Math.min(1, popup.reveal))

        // Небольшой пролёт ниже конечной позиции; тень следует за popupFrame.y.
        Behavior on y {
            NumberAnimation {
                duration: Motion.defaultDuration
                easing.type: popup.expanded ? Easing.OutBack : Easing.InBack
                easing.overshoot: 1.5
            }
        }

        FocusScope {
            anchors.fill: parent
            focus: true
            Keys.onPressed: event => {
                if (event.key === Qt.Key_Escape)
                    popup.dismiss();
                else if (event.key === Qt.Key_Down)
                    popup.moveSelection(1);
                else if (event.key === Qt.Key_Up)
                    popup.moveSelection(-1);
                else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter)
                    popup.selectLayout(layoutList.currentIndex);
                else
                    return;
                event.accepted = true;
            }

            ListView {
                id: layoutList
                x: Metrics.spacing
                y: Metrics.spacing
                width: parent.width - 2 * Metrics.spacing
                height: popup.listHeight
                clip: true
                topMargin: 1
                bottomMargin: 1
                spacing: Metrics.popupRowSpacing
                boundsBehavior: Flickable.StopAtBounds
                model: popup.entries
                currentIndex: Math.max(0, KeyboardLayoutService.activeIndex)
                highlightMoveDuration: 0
                ScrollBar.vertical: ScrollBar {
                    // Полоса занимает внешний padding, а не ширину строк.
                    parent: layoutList.parent
                    x: layoutList.x + layoutList.width + 2
                    y: layoutList.y
                    height: layoutList.height
                    width: 4
                    policy: ScrollBar.AsNeeded
                }

                delegate: Item {
                    id: row
                    required property var modelData
                    required property int index
                    readonly property bool selected: modelData.test
                        ? popup.selectedTestIndex === index
                        : modelData.index === KeyboardLayoutService.activeIndex
                    width: layoutList.width
                    height: popup.rowHeight

                    // ListView управляет позицией делегата. Отступ для AA
                    // задаётся его дочерней поверхности, одинаково с двух сторон.
                    Rectangle {
                        anchors.fill: parent
                        anchors.leftMargin: 1
                        anchors.rightMargin: 1
                        radius: Metrics.panelRadius - 2
                        color: "#1fffffff"
                        opacity: rowMouse.containsMouse ? 1 : 0
                        antialiasing: true

                        Behavior on opacity {
                            StandardAnimation {
                                duration: Motion.defaultDuration
                            }
                        }
                    }

                    // Выбранная раскладка видна независимо от hover-прозрачности.
                    Rectangle {
                        anchors.fill: parent
                        anchors.leftMargin: 1
                        anchors.rightMargin: 1
                        radius: Metrics.panelRadius - 2
                        color: "transparent"
                        border.width: row.selected ? 0.5 : 0
                        border.pixelAligned: false
                        border.color: "#e8ffffff"
                        antialiasing: true
                    }

                    Text {
                        id: label
                        anchors.left: parent.left
                        anchors.leftMargin: Metrics.spacing
                        anchors.verticalCenter: parent.verticalCenter
                        text: row.modelData.label
                        color: "#f2ffffff"
                        font.pixelSize: Metrics.statusBarFontSize
                        font.weight: row.selected ? Font.DemiBold : Font.Medium
                    }
                    Text {
                        anchors.left: label.right
                        anchors.leftMargin: Metrics.spacing
                        anchors.right: parent.right
                        anchors.rightMargin: Metrics.spacing
                        anchors.verticalCenter: parent.verticalCenter
                        horizontalAlignment: Text.AlignRight
                        elide: Text.ElideRight
                        text: row.modelData.name
                        color: "#b3ffffff"
                        font.pixelSize: 13
                    }
                    MouseArea {
                        id: rowMouse
                        anchors.fill: parent
                        enabled: popup.expanded && (row.modelData.test
                            || !KeyboardLayoutService.commandPending)
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            layoutList.currentIndex = row.index;
                            popup.selectLayout(row.index);
                        }
                    }
                }
            }

            Text {
                id: errorLabel
                x: Metrics.spacing
                y: layoutList.y + layoutList.height + Metrics.spacing
                width: layoutList.width
                visible: KeyboardLayoutService.error.length > 0
                text: KeyboardLayoutService.error
                color: "#f0b2b2"
                font.pixelSize: 12
                wrapMode: Text.WordWrap
            }
        }
    }
}
