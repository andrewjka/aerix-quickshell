import QtQuick
import Quickshell.Io

// Локальный pam_faillock: читаем только tally выбранной учётной записи.
// Опрос существует лишь пока открыт запрос; пароли процессу не передаются.
QtObject {
    id: monitor
    property bool active: false
    property string user: ""
    property bool isRoot: false
    property bool known: false
    property bool readFailed: false
    property bool locked: false
    property int remainingSeconds: 0
    property string queriedUser: ""
    property bool querying: false
    readonly property bool blocked: !known || locked

    function option(name, fallback) {
        const match = config.text().match(new RegExp("^\\s*" + name
            + "\\s*=\\s*(\\d+)\\s*(?:#.*)?$", "m"));
        return match ? Number(match[1]) : fallback;
    }

    function refresh() {
        if (!active || !user || querying) return;
        querying = true;
        queriedUser = user;
        query.exec(["env", "LC_ALL=C", "faillock", "--user", user]);
    }

    function reset() {
        known = false;
        readFailed = false;
        locked = false;
        remainingSeconds = 0;
        refresh();
    }

    function accept(text) {
        const times = [];
        for (const line of text.split(/\r?\n/)) {
            const match = line.match(/^(\d{4})-(\d{2})-(\d{2})\s+(\d{2}):(\d{2}):(\d{2})\s+.*\sV\s*$/);
            if (match) times.push(new Date(Number(match[1]), Number(match[2]) - 1,
                Number(match[3]), Number(match[4]), Number(match[5]), Number(match[6])).getTime() / 1000);
        }
        const latest = times.length ? Math.max(...times) : 0;
        const failures = times.filter(time => latest - time < option("fail_interval", 900)).length;
        const deny = option("deny", 3);
        const timeout = isRoot ? option("root_unlock_time", option("unlock_time", 600))
            : option("unlock_time", 600);
        const rootExempt = isRoot && !/^\s*even_deny_root\s*(?:#.*)?$/m.test(config.text());
        remainingSeconds = Math.max(0, Math.ceil(latest + timeout - Date.now() / 1000));
        locked = !rootExempt && deny > 0 && failures >= deny
            && (timeout === 0 || remainingSeconds > 0);
        known = true;
        readFailed = false;
    }

    onActiveChanged: reset()
    onUserChanged: reset()

    property FileView config: FileView {
        path: "/etc/security/faillock.conf"
        preload: true
        blockLoading: true
        blockWrites: true
    }
    property Timer polling: Timer {
        interval: 2000
        repeat: true
        running: monitor.active
        onTriggered: monitor.refresh()
    }
    property Process query: Process {
        stdout: StdioCollector { id: output; waitForEnd: true }
        onExited: (code, status) => {
            monitor.querying = false;
            if (!monitor.active) return;
            if (monitor.queriedUser !== monitor.user) { monitor.refresh(); return; }
            if (code === 0) monitor.accept(output.text);
            else {
                monitor.known = false;
                monitor.readFailed = true;
            }
        }
    }
}
