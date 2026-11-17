pragma Singleton

import QtQml
import Quickshell
import Quickshell.Hyprland
import "." as Services

// OSD хранит только краткоживущее состояние показа. Значения остаются
// источником истины в AudioService и BrightnessService.
QtObject {
    id: service

    property string mode: ""
    // В отличие от mode, не очищается до следующего показа: выходная
    // анимация должна сохранить тип только что показанного индикатора.
    property string displayedMode: ""
    property var targetScreen: null
    property int requestSequence: 0
    property bool brightnessPopupOpen: false
    property bool volumePopupOpen: false

    function focusedScreen() {
        const focusedMonitor = Hyprland.focusedMonitor;
        return Quickshell.screens.find(screen =>
            Hyprland.monitorFor(screen)?.name === focusedMonitor?.name)
            ?? Quickshell.screens[0] ?? null;
    }

    function showBrightness(screen) {
        show("brightness", screen);
    }

    function showVolume(screen) {
        show("volume", screen);
    }

    function show(nextMode, screen) {
        if (!screen)
            return;
        mode = nextMode;
        displayedMode = nextMode;
        targetScreen = screen;
        requestSequence++;
    }

    function hide() {
        mode = "";
        targetScreen = null;
    }

    property Connections audioChanges: Connections {
        target: Services.AudioService

        function onVolumePercentChanged() {
            if (!service.volumePopupOpen)
                service.showVolume(service.focusedScreen());
        }

        function onMutedChanged() {
            if (!service.volumePopupOpen)
                service.showVolume(service.focusedScreen());
        }
    }

    property Connections brightnessChanges: Connections {
        target: Services.BrightnessService

        function onBrightnessPercentChanged() {
            if (!service.brightnessPopupOpen)
                service.showBrightness(service.focusedScreen());
        }
    }
}
