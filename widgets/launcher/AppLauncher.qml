pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import "../../core"
import "../../services"

// Overlay и стеклянная панель разделены на surface, чтобы blur работал у обоих.
Scope {
    id: launcher

    required property var targetScreen
    property real reveal: 0
    property var testEntries: []

    signal dismissed()

    function close() {
        dismissed();
    }

    // Временный тестовый набор намеренно повторяет первое доступное приложение.
    function reloadTestEntries() {
        const entry = DesktopEntries.applications.values[0] ?? null;
        testEntries = entry ? Array(200).fill(entry) : [];
    }

    Component.onCompleted: {
        reloadTestEntries();
        revealAnimation.start();
        launcherFocus.forceActiveFocus();
    }

    Connections {
        target: DesktopEntries

        function onApplicationsChanged() {
            launcher.reloadTestEntries();
        }
    }

    NumberAnimation {
        id: revealAnimation
        target: launcher
        property: "reveal"
        from: 0
        to: 1
        duration: Motion.spring.durationMs
        easing.type: Motion.spring.easingType
        easing.bezierCurve: Motion.spring.bezierCurve
    }

    PanelWindow {
        id: backdropWindow

        screen: launcher.targetScreen
        anchors { top: true; bottom: true; left: true; right: true }
        exclusionMode: ExclusionMode.Ignore
        color: Theme.transparentColor
        focusable: false
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.namespace: "aerix:app-launcher"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        BackgroundEffect.blurRegion: Region { item: backdropWindow.contentItem }

        Rectangle {
            anchors.fill: parent
            color: Theme.overlayColor
            opacity: Math.max(0, Math.min(1, launcher.reveal))
        }
    }

    PanelWindow {
        id: launcherWindow

        screen: launcher.targetScreen
        anchors { top: true; bottom: true; left: true; right: true }
        exclusionMode: ExclusionMode.Ignore
        color: Theme.transparentColor
        focusable: true
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "aerix:app-launcher"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        BackgroundEffect.blurRegion: Region {
            item: launcherSurface
            radius: Metrics.panelRadius
        }

        MouseArea {
            anchors.fill: parent
            onClicked: launcher.close()
        }

        FocusScope {
            id: launcherFocus
            anchors.fill: parent
            focus: true

            Keys.onPressed: event => {
                if (event.key !== Qt.Key_Escape)
                    return;
                launcher.close();
                event.accepted = true;
            }

            Rectangle {
                id: launcherSurface
                anchors.centerIn: parent
                width: parent.width / 2
                height: parent.height * 0.7
                radius: Metrics.panelRadius
                color: Theme.backgroundColor
                border.width: 1
                border.color: Theme.borderColor
                clip: true
                scale: Motion.spring.startScale
                    + (1 - Motion.spring.startScale) * launcher.reveal
                opacity: Math.max(0, Math.min(1, launcher.reveal))

                GridView {
                    id: appGrid
                    anchors.fill: parent
                    anchors.margins: Metrics.spacing
                    clip: true
                    cellWidth: width / 8
                    cellHeight: height / 8
                    model: launcher.testEntries

                    delegate: Item {
                        id: appTile

                        required property var modelData
                        required property int index
                        width: appGrid.cellWidth
                        height: appGrid.cellHeight

                        readonly property string iconName: String(modelData?.icon ?? "")
                        readonly property string iconSource: iconName.startsWith("/")
                            ? "file://" + iconName
                            : Quickshell.hasThemeIcon(iconName)
                              ? Quickshell.iconPath(iconName) : ""

                        Image {
                            id: appIcon
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.top: parent.top
                            anchors.topMargin: Metrics.spacing
                            width: Math.min(parent.width * 0.56, parent.height * 0.56)
                            height: width
                            source: appTile.iconSource
                            sourceSize: Qt.size(Math.ceil(width * launcherWindow.devicePixelRatio),
                                Math.ceil(height * launcherWindow.devicePixelRatio))
                            fillMode: Image.PreserveAspectFit
                            smooth: true
                        }

                        Text {
                            anchors.top: appIcon.bottom
                            anchors.topMargin: 4
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.margins: 4
                            text: String(appTile.modelData?.name ?? "")
                            color: Theme.foregroundColor
                            font.pixelSize: Math.max(10, Metrics.statusBarFontSize - 4)
                            elide: Text.ElideRight
                            horizontalAlignment: Text.AlignHCenter
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                appTile.modelData?.execute();
                                launcher.close();
                            }
                        }
                    }
                }

                Text {
                    anchors.centerIn: parent
                    visible: launcher.testEntries.length === 0
                    text: "No desktop applications"
                    color: Theme.disabledForegroundColor
                    font.pixelSize: Metrics.statusBarFontSize
                }
            }
        }
    }
}
