pragma Singleton

import QtQml
import Quickshell.Services.Pipewire

// Единый интерфейс звука: визуальные компоненты не знают о PipeWire-графе
// и работают только с текущим output и нормализованными процентами.
QtObject {
    id: service

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property bool available: Pipewire.ready && sink !== null
        && sink.ready && sink.audio !== null
    readonly property bool muted: available ? sink.audio.muted : true
    readonly property real volume: available ? sink.audio.volume : 0
    readonly property int volumePercent: Math.round(Math.max(0,
        Math.min(1, volume)) * 100)
    readonly property string iconName: muted || volumePercent === 0
        ? "volume-mute.svg"
        : volumePercent <= 33 ? "volume-min.svg"
        : volumePercent <= 66 ? "volume-medium.svg"
        : "volume-loud.svg"
    readonly property var outputDevices: {
        const nodes = Pipewire.nodes?.values ?? [];
        return nodes.filter(node => node && node.audio
            && node.isSink && !node.isStream).sort((first, second) =>
                deviceLabel(first).localeCompare(deviceLabel(second)));
    }

    // Volume доступен только у bound-узла. Трекер повторно привязывается при
    // смене default sink, сохраняя реактивные изменения от системы.
    property PwObjectTracker sinkTracker: PwObjectTracker {
        objects: [service.sink]
    }

    function deviceLabel(device) {
        if (!device)
            return "";
        return device.description || device.nickname || device.name;
    }

    function setVolumePercent(percent) {
        if (!available || !Number.isFinite(percent))
            return false;
        sink.audio.volume = Math.max(0, Math.min(100, Math.round(percent))) / 100;
        return true;
    }

    function adjustVolume(deltaPercent) {
        if (!Number.isFinite(deltaPercent))
            return false;
        return setVolumePercent(volumePercent + deltaPercent);
    }

    function setMuted(nextMuted) {
        if (!available)
            return false;
        sink.audio.muted = nextMuted;
        return true;
    }

    function selectDevice(device) {
        if (!device || !device.audio || !device.isSink || device.isStream)
            return false;
        Pipewire.preferredDefaultAudioSink = device;
        return true;
    }

    function isSelectedDevice(device) {
        return device === sink;
    }
}
