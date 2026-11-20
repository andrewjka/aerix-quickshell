pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.Polkit
import Quickshell.Wayland
import "../../core"
import "../../services"
import "../shared" as Shared

// Нативный PolkitAgent ведёт D-Bus/PAM-разговор и очередь запросов. Этот
// компонент отвечает только за surface и никогда не хранит пароль вне TextInput.
Scope {
    id: dialog

    property var targetScreen: null
    property real reveal: agent.isActive ? 1 : 0
    readonly property var displayScreen: targetScreen ?? focusedScreen()
    readonly property var flow: agent.flow
    readonly property bool visible: agent.isActive || reveal > 0
    readonly property bool authenticationLocked: lockout.blocked
    readonly property bool canSubmit: (flow?.isResponseRequired ?? false)
        && !authenticationLocked
    readonly property color lockoutColor: "#ef5350"
    readonly property int revealTravel: 24
    readonly property int shadowMargin: Math.ceil(Metrics.panelShadowRadius) + 1
    readonly property int topMargin: shadowMargin + revealTravel
    readonly property int popupTop: Metrics.statusBarHeight + 2 * Metrics.spacing
    readonly property int renderMargin: shadowMargin
        + Math.ceil(frameWidth * Math.max(0, Metrics.spring.maximumScale - 1) / 2)
    readonly property int bottomMargin: shadowMargin
        + Math.ceil(authFrame.height * Math.max(0, Metrics.spring.maximumScale - 1))
        + Math.ceil(revealTravel * Math.max(0, Metrics.spring.maximumProgress - 1))

    LockoutMonitor {
        id: lockout
        active: agent.isActive
        user: dialog.flow?.selectedIdentity?.isGroup ? ""
            : String(dialog.flow?.selectedIdentity?.string ?? "")
        isRoot: dialog.flow?.selectedIdentity?.id === 0
    }
    readonly property int horizontalMargin: Math.max(Metrics.spacing * 2, 20)
    readonly property int preferredWidth: 380
    readonly property int frameWidth: Math.max(1, Math.min(preferredWidth,
        (displayScreen?.width ?? preferredWidth) - 2 * horizontalMargin))
    readonly property int iconSize: Metrics.statusBarWidgetIconSize + 10

    function focusedScreen() {
        const focusedMonitor = Hyprland.focusedMonitor;
        return Quickshell.screens.find(screen =>
            Hyprland.monitorFor(screen)?.name === focusedMonitor?.name)
            ?? Quickshell.screens[0] ?? null;
    }

    function cancel() {
        if (agent.flow && !agent.flow.isCompleted)
            agent.flow.cancelAuthenticationRequest();
    }

    function submit() {
        if (!canSubmit)
            return;
        const response = responseInput.text;
        responseInput.text = "";
        agent.flow.submit(response);
        lockout.known = false;
        lockout.refresh();
    }

    function focusResponse() {
        if (agent.flow?.isResponseRequired)
            Qt.callLater(() => responseInput.forceActiveFocus());
    }

    function observeKeyboardEvent(event) {
        if (event.key === Qt.Key_CapsLock && !event.isAutoRepeat)
            KeyboardService.noteCapsLockToggle();
    }

    // Accent в текущих темах может быть белым. Текст действия должен
    // контрастировать именно с его заливкой, а не наследовать foreground.
    function contrastTextColor(background) {
        const color = Qt.color(background);
        const luminance = 0.2126 * color.r + 0.7152 * color.g + 0.0722 * color.b;
        return luminance > 0.5 ? "#111111" : "#ffffff";
    }

    PolkitAgent {
        id: agent
        // Отдельный путь не конфликтует с другими конфигурациями Quickshell.
        path: "/org/aerix/Polkit"

        onAuthenticationRequestStarted: {
            dialog.targetScreen = dialog.focusedScreen();
            KeyboardService.refresh();
            dialog.focusResponse();
        }
    }

    onFlowChanged: {
        responseInput.text = "";
        focusResponse();
    }

    // PAM может запросить следующий фактор уже в пределах того же flow.
    // Возвращаем фокус полю ответа и в этом случае, а не только при старте.
    Connections {
        target: dialog.flow

        function onIsResponseRequiredChanged() {
            dialog.focusResponse();
        }
        function onAuthenticationFailed() {
            lockout.known = false;
            lockout.refresh();
        }
    }

    Behavior on reveal {
        NumberAnimation {
            duration: Metrics.spring.durationMs
            easing.type: Metrics.spring.easingType
            easing.bezierCurve: Metrics.spring.bezierCurve
        }
    }

    // У тени отдельный слой и пустая input-region: она не перехватывает ни
    // клавиатуру, ни мышь, а frame и его пружина повторяются точно.
    PanelWindow {
        id: shadowWindow
        screen: dialog.displayScreen
        anchors.top: true
        margins.top: authWindow.margins.top
        implicitWidth: authWindow.implicitWidth
        implicitHeight: authWindow.implicitHeight
        visible: dialog.visible
        exclusionMode: ExclusionMode.Ignore
        color: Theme.transparentColor
        focusable: false
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "aerix:polkit-shadow"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        mask: Region { width: 0; height: 0 }

        Item {
            x: authFrame.x
            y: authFrame.y
            width: authFrame.width
            height: authFrame.height
            scale: authFrame.scale
            transformOrigin: authFrame.transformOrigin
            opacity: authFrame.opacity

            Rectangle {
                id: shadowShape
                anchors.fill: parent
                radius: Metrics.panelRadius
                color: Theme.transparentColor
                antialiasing: true
            }

            PanelShadow { sourceItem: shadowShape }
        }
    }

    HyprlandFocusGrab {
        active: agent.isActive && authWindow.visible
        windows: [authWindow]
        onCleared: dialog.cancel()
    }

    PanelWindow {
        id: authWindow
        screen: dialog.displayScreen
        // Верхний anchor сохраняет горизонтальное центрирование layer-shell.
        anchors.top: true
        margins.top: dialog.popupTop - dialog.topMargin
        implicitWidth: dialog.frameWidth + 2 * dialog.renderMargin
        implicitHeight: authFrame.height + dialog.topMargin + dialog.bottomMargin
        visible: dialog.visible
        exclusionMode: ExclusionMode.Ignore
        color: Theme.transparentColor
        focusable: true
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "aerix:polkit"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        mask: Region { item: authFrame }
        BackgroundEffect.blurRegion: Region {
            item: authFrame
            radius: Metrics.panelRadius
        }

        FocusScope {
            anchors.fill: parent
            focus: true

            Keys.onPressed: event => {
                if (event.key === Qt.Key_Escape) {
                    dialog.cancel();
                    event.accepted = true;
                }
            }

            Rectangle {
                id: authFrame
                x: Math.round((authWindow.width - width) / 2)
                y: dialog.topMargin - dialog.revealTravel * (1 - dialog.reveal)
                width: dialog.frameWidth
                implicitHeight: contentColumn.implicitHeight + 2 * Metrics.spacing
                height: implicitHeight
                radius: Metrics.panelRadius
                color: Theme.backgroundColor
                border.width: 1
                border.color: Theme.borderColor
                antialiasing: true
                scale: Metrics.spring.startScale
                    + (1 - Metrics.spring.startScale) * dialog.reveal
                transformOrigin: Item.Top
                opacity: Math.max(0, Math.min(1, dialog.reveal))

                // Внутренняя область карточки принимает события мыши.
                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.AllButtons
                }

                Column {
                    id: contentColumn
                    x: Metrics.spacing
                    y: Metrics.spacing
                    width: parent.width - 2 * Metrics.spacing
                    spacing: Metrics.spacing

                    Item {
                        width: parent.width
                        height: Math.max(dialog.iconSize, titleLabel.implicitHeight
                            + subtitleLabel.implicitHeight + 2)

                        Shared.IconWidget {
                            id: actionIcon
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            height: dialog.iconSize
                            width: height
                            iconSource: Quickshell.hasThemeIcon(
                                dialog.flow?.iconName || "dialog-password")
                                ? Quickshell.iconPath(dialog.flow?.iconName
                                    || "dialog-password")
                                : Qt.resolvedUrl("../../assets/icons/Aerix-logo.svg")
                            tintColor: Theme.foregroundColor
                            whiteSource: true
                            devicePixelRatio: authWindow.devicePixelRatio
                        }

                        Text {
                            id: titleLabel
                            anchors.left: actionIcon.right
                            anchors.leftMargin: Metrics.spacing
                            anchors.right: parent.right
                            text: I18n.tr("polkit.title")
                            color: Theme.foregroundColor
                            font.pixelSize: Metrics.statusBarFontSize
                            font.weight: Font.DemiBold
                            elide: Text.ElideRight
                            textFormat: Text.PlainText
                        }

                        Text {
                            id: subtitleLabel
                            anchors.left: titleLabel.left
                            anchors.right: titleLabel.right
                            anchors.top: titleLabel.bottom
                            anchors.topMargin: 2
                            visible: dialog.flow?.actionId?.length > 0
                            text: dialog.flow?.actionId ?? ""
                            color: Theme.disabledForegroundColor
                            font.pixelSize: Math.max(11, Metrics.baseFontSize - 3)
                            elide: Text.ElideRight
                            textFormat: Text.PlainText
                        }
                    }

                    Text {
                        width: parent.width
                        text: dialog.flow?.message ?? ""
                        visible: text.length > 0
                        color: Theme.foregroundColor
                        font.pixelSize: Metrics.baseFontSize
                        wrapMode: Text.Wrap
                        maximumLineCount: 3
                        elide: Text.ElideRight
                        textFormat: Text.PlainText
                    }

                    Text {
                        width: parent.width
                        text: dialog.flow?.supplementaryMessage ?? ""
                        // PAM уже сообщает длительность блокировки выше поля.
                        // Оставляем для неё один счётчик в нижней части popup.
                        visible: text.length > 0 && !dialog.authenticationLocked
                        color: dialog.flow?.supplementaryIsError
                            ? Theme.accentColor : Theme.disabledForegroundColor
                        font.pixelSize: Math.max(12, Metrics.baseFontSize - 1)
                        wrapMode: Text.Wrap
                        maximumLineCount: 2
                        elide: Text.ElideRight
                        textFormat: Text.PlainText
                    }

                    Item {
                        width: parent.width
                        height: inputPrompt.height + responseInput.height
                            + (inputPrompt.visible ? 4 : 0)
                        visible: dialog.flow?.isResponseRequired ?? false

                        Text {
                            id: inputPrompt
                            width: parent.width
                            height: implicitHeight
                            visible: text.length > 0
                            text: dialog.flow?.inputPrompt ?? ""
                            color: Theme.disabledForegroundColor
                            font.pixelSize: Math.max(12, Metrics.baseFontSize - 1)
                            elide: Text.ElideRight
                            textFormat: Text.PlainText
                        }

                        Rectangle {
                            id: inputBackground
                            y: inputPrompt.visible ? inputPrompt.height + 4 : 0
                            width: parent.width
                            height: 36
                            radius: Metrics.panelRadius
                            color: Theme.overlayColor
                            border.width: 1
                            border.color: responseInput.activeFocus
                                ? Theme.accentColor : Theme.borderColor
                            antialiasing: true

                            TextInput {
                                id: responseInput
                                anchors.fill: parent
                                anchors.leftMargin: Metrics.spacing
                                anchors.rightMargin: Metrics.spacing
                                color: Theme.foregroundColor
                                font.pixelSize: Metrics.baseFontSize
                                verticalAlignment: TextInput.AlignVCenter
                                selectByMouse: true
                                echoMode: dialog.flow?.responseVisible
                                    ? TextInput.Normal : TextInput.Password
                                passwordCharacter: "•"
                                enabled: dialog.flow?.isResponseRequired ?? false
                                Keys.onPressed: event => dialog.observeKeyboardEvent(event)
                                onAccepted: dialog.submit()
                            }
                        }
                    }

                    Text {
                        width: parent.width
                        visible: dialog.authenticationLocked
                        text: lockout.readFailed ? I18n.tr("polkit.lockUnavailable")
                            : !lockout.known ? I18n.tr("polkit.lockChecking")
                            : lockout.remainingSeconds > 0
                            ? I18n.tr("polkit.lockedFor", {seconds: lockout.remainingSeconds})
                            : I18n.tr("polkit.locked")
                        color: dialog.lockoutColor
                        font.pixelSize: Math.max(12, Metrics.baseFontSize - 1)
                        wrapMode: Text.Wrap
                        textFormat: Text.PlainText
                    }

                    // Раскладка всегда видна до ввода, а Caps Lock явно
                    // показывает и включённое, и выключенное состояние.
                    Row {
                        width: parent.width
                        spacing: Metrics.spacing / 2

                        Rectangle {
                            width: languageIndicator.implicitWidth
                                + 2 * Metrics.spacing
                            height: 24
                            radius: Metrics.panelRadius
                            color: Theme.accentColor
                            antialiasing: true

                            Text {
                                id: languageIndicator
                                anchors.centerIn: parent
                                text: KeyboardService.activeLabel
                                color: dialog.contrastTextColor(Theme.accentColor)
                                font.pixelSize: Math.max(12, Metrics.baseFontSize - 1)
                                font.weight: Font.DemiBold
                            }
                        }

                        Rectangle {
                            width: capsLockIndicator.implicitWidth
                                + 2 * Metrics.spacing
                            height: 24
                            radius: Metrics.panelRadius
                            color: KeyboardService.capsLockEnabled
                                ? Theme.accentColor : Theme.transparentColor
                            border.width: 1
                            border.color: Theme.borderColor
                            antialiasing: true

                            Text {
                                id: capsLockIndicator
                                anchors.centerIn: parent
                                text: KeyboardService.capsLockEnabled
                                    ? I18n.tr("polkit.capsLockOn")
                                    : I18n.tr("polkit.capsLockOff")
                                color: KeyboardService.capsLockEnabled
                                    ? dialog.contrastTextColor(Theme.accentColor)
                                    : Theme.disabledForegroundColor
                                font.pixelSize: Math.max(12, Metrics.baseFontSize - 1)
                                font.weight: Font.Medium
                            }
                        }
                    }

                    Item {
                        width: parent.width
                        height: 32

                        Rectangle {
                            id: cancelButton
                            anchors.left: parent.left
                            width: 88
                            height: parent.height
                            radius: Metrics.panelRadius
                            color: cancelPointer.containsMouse
                                ? Theme.hoverColor : Theme.transparentColor
                            border.width: 1
                            border.color: Theme.borderColor
                            antialiasing: true

                            Text {
                                anchors.centerIn: parent
                                text: I18n.tr("polkit.cancel")
                                color: Theme.foregroundColor
                                font.pixelSize: Math.max(12, Metrics.baseFontSize - 1)
                                font.weight: Font.Medium
                            }
                            MouseArea {
                                id: cancelPointer
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: dialog.cancel()
                            }
                        }

                        Rectangle {
                            id: authenticateButton
                            anchors.right: parent.right
                            width: 116
                            height: parent.height
                            radius: Metrics.panelRadius
                            color: authenticatePointer.containsMouse
                                ? Theme.hoverColor : Theme.accentColor
                            enabled: dialog.canSubmit
                            opacity: enabled ? 1 : 0.32
                            antialiasing: true

                            Text {
                                anchors.centerIn: parent
                                text: I18n.tr("polkit.authenticate")
                                color: dialog.contrastTextColor(
                                    authenticatePointer.containsMouse
                                    ? Theme.hoverColor : Theme.accentColor)
                                font.pixelSize: Math.max(12, Metrics.baseFontSize - 1)
                                font.weight: Font.DemiBold
                            }
                            MouseArea {
                                id: authenticatePointer
                                anchors.fill: parent
                                enabled: dialog.canSubmit
                                hoverEnabled: enabled
                                cursorShape: Qt.PointingHandCursor
                                onClicked: dialog.submit()
                            }
                        }
                    }
                }
            }
        }
    }
}
