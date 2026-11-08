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
    property int pendingSelectionToken: 0
    property int selectedTestIndex: -1
    // Курсор клавиатуры не является подтверждённой системной раскладкой.
    // Он живёт только пока popup открыт и управляет Up/Down/Enter.
    property int navigationIndex: -1
    property bool expanded: false
    property real reveal: expanded ? 1 : 0
    readonly property var entries: KeyboardLayoutService.layouts.concat(
        Array.from({ length: testLayoutCount }, (_, i) => ({
            index: -1, label: String(i + 1), name: "", test: true
        })))
    readonly property int rowHeight: 32
    readonly property int revealTravel: 24
    readonly property real springScaleOverflow: Math.max(0,
        Motion.panelSpring.maximumScale - 1)
    readonly property real springProgressOverflow: Math.max(0,
        Motion.panelSpring.maximumProgress - 1)
    readonly property int shadowMargin: Math.ceil(Metrics.panelShadowRadius) + 1
    // transformOrigin равен Top: масштаб растит content целиком вниз, а не
    // поровну в обе стороны. Начальная фаза раскрытия, напротив, уходит вверх.
    readonly property int topRenderMargin: shadowMargin + revealTravel
    readonly property int bottomSpringOverflow: Math.ceil(
        revealTravel * springProgressOverflow)
    readonly property int bottomRenderMargin: shadowMargin + bottomSpringOverflow
        + Math.ceil(surfaceHeight * springScaleOverflow)
    readonly property int horizontalRenderMargin: shadowMargin + Math.ceil(
        surfaceWidth * springScaleOverflow / 2)
    readonly property int popupTop: barWindow.height + 2 * Metrics.spacing
    // Максимальная высота content выводится из полного пути: reveal может
    // сместить окно вниз, а spring scale увеличивает его от верхней границы.
    // Это сохраняет конечный нижний отступ и не полагается на clipping shell.
    // qmllint disable missing-property
    readonly property int maximumSurfaceHeight: Math.max(0, Math.floor(
        (screen.height - popupTop - shadowMargin - bottomSpringOverflow)
        / (1 + springScaleOverflow)))
    // qmllint enable missing-property
    readonly property int maximumErrorHeight: Math.max(0,
        maximumSurfaceHeight - 2 * Metrics.spacing - rowHeight - Metrics.popupRowSpacing)
    readonly property int errorHeight: errorLabel.visible
        ? Math.min(errorLabel.implicitHeight, maximumErrorHeight) : 0
    readonly property int availableListHeight: Math.max(0, maximumSurfaceHeight
        - 2 * Metrics.spacing - (errorLabel.visible
            ? errorHeight + Metrics.spacing : 0))
    readonly property int visibleRowCount: entries.length === 0 ? 0 : Math.min(5,
        entries.length, Math.max(0, Math.floor((availableListHeight - 2
            + Metrics.popupRowSpacing) / (rowHeight + Metrics.popupRowSpacing))))
    // По пикселю внутри viewport для сглаженного края обводки.
    readonly property int listHeight: visibleRowCount * rowHeight
        + Math.max(0, visibleRowCount - 1) * Metrics.popupRowSpacing + 2
    // qmllint disable missing-property
    readonly property int surfaceWidth: Math.min(196,
        screen.width - 2 * Metrics.statusBarHorizontalMargin)
    // qmllint enable missing-property
    readonly property int surfaceHeight: listHeight + 2 * Metrics.spacing
        + (errorLabel.visible ? errorHeight + Metrics.spacing : 0)
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
    margins.left: surfaceX - horizontalRenderMargin
    margins.top: popupTop - topRenderMargin
    implicitWidth: surfaceWidth + 2 * horizontalRenderMargin
    implicitHeight: surfaceHeight + topRenderMargin + bottomRenderMargin
    color: "transparent"
    WlrLayershell.namespace: "aerix:keyboard-layout"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: expanded ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    mask: Region { item: popupFrame }

    // Одна прерываемая анимация: повторный клик меняет цель от текущего значения.
    Behavior on reveal {
        NumberAnimation {
            duration: Motion.panelSpring.duration
            easing.type: Motion.panelSpring.easingType
            easing.bezierCurve: Motion.panelSpring.curve
            onRunningChanged: {
                if (!running && !popup.expanded && popup.reveal === 0)
                    popup.dismissed();
            }
        }
    }

    function dismiss() {
        pendingSelectionToken = 0;
        expanded = false;
    }
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
            pendingSelectionToken = KeyboardLayoutService.pendingSelectionToken;
        }
    }

    function moveSelection(step) {
        if (entries.length === 0)
            return;
        navigationIndex = Math.max(0,
            Math.min(entries.length - 1, navigationIndex + step));
        positionNavigation();
    }

    function initializeNavigation() {
        if (entries.length === 0) {
            navigationIndex = -1;
            return;
        }
        navigationIndex = Math.max(0, Math.min(entries.length - 1,
            KeyboardLayoutService.activeIndex));
        positionNavigation();
    }

    function clampNavigation() {
        if (entries.length === 0) {
            navigationIndex = -1;
            return;
        }
        navigationIndex = Math.max(0, Math.min(entries.length - 1,
            navigationIndex < 0 ? KeyboardLayoutService.activeIndex : navigationIndex));
        positionNavigation();
    }

    function positionNavigation() {
        if (navigationIndex >= 0 && layoutList)
            layoutList.positionViewAtIndex(navigationIndex, ListView.Contain);
    }

    Component.onCompleted: expanded = true
    onExpandedChanged: {
        focusGrab.active = expanded;
        if (expanded)
            initializeNavigation();
    }
    onEntriesChanged: clampNavigation()

    HyprlandFocusGrab {
        id: focusGrab
        // FocusGrab пропускает ввод только к whitelist поверхностям. Bar нужен
        // здесь для повторного клика по trigger: иначе compositor сначала
        // очистит grab как при внешнем клике, а потом тот же жест попробует
        // открыть/закрыть popup второй раз. Пустая зона Bar закрывается его
        // нижним MouseArea, поэтому whitelist не превращает Bar в исключение.
        windows: [popup, popup.barWindow]
        onCleared: popup.dismiss()
    }

    Connections {
        target: KeyboardLayoutService
        function onLayoutSelectionResolved(token, confirmed) {
            if (popup.pendingSelectionToken !== token)
                return;
            popup.pendingSelectionToken = 0;
            if (confirmed)
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
        x: popup.horizontalRenderMargin
        // y, scale и opacity следуют одному анимируемому reveal. При быстром
        // повторном клике пружина продолжает путь от текущего кадра, а не
        // получает независимую новую y-анимацию.
        y: popup.topRenderMargin - popup.revealTravel * (1 - popup.reveal)
        width: popup.surfaceWidth
        height: popup.surfaceHeight
        radius: Metrics.panelRadius
        color: Metrics.panelColor
        antialiasing: true
        scale: Motion.panelSpring.initialScale
            + (1 - Motion.panelSpring.initialScale) * popup.reveal
        transformOrigin: Item.Top
        opacity: Math.max(0, Math.min(1, popup.reveal))

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
                    popup.selectLayout(popup.navigationIndex);
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
                currentIndex: popup.navigationIndex
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
                    readonly property bool navigationCurrent: index === popup.navigationIndex
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

                    // Keyboard cursor остаётся отдельным от системного selected:
                    // Up/Down не выдают подтверждение смены раскладки.
                    Rectangle {
                        anchors.fill: parent
                        anchors.leftMargin: 1
                        anchors.rightMargin: 1
                        radius: Metrics.panelRadius - 2
                        color: row.navigationCurrent ? "#26ffffff" : "transparent"
                        border.width: row.navigationCurrent && !row.selected ? 0.5 : 0
                        border.pixelAligned: false
                        border.color: "#99ffffff"
                        antialiasing: true

                        Behavior on color {
                            ColorAnimation { duration: Motion.defaultDuration }
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
                            || !KeyboardLayoutService.selectionBlocked)
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            popup.navigationIndex = row.index;
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
                maximumLineCount: 2
                height: popup.errorHeight
                clip: true
            }
        }
    }
}
