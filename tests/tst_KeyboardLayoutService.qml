import QtTest
import "../services/KeyboardLayoutParser.js" as KeyboardLayoutParser

TestCase {
    name: "KeyboardLayoutService"
    when: true

    function validDevices() {
        return JSON.stringify({
            keyboards: [
                {
                    name: "secondary keyboard",
                    layout: "us",
                    variant: "",
                    active_layout_index: 0,
                    main: false
                },
                {
                    address: "main-keyboard-address",
                    name: " main keyboard ",
                    layout: "us, ru",
                    variant: ",phonetic",
                    active_layout_index: 1,
                    main: true
                }
            ]
        });
    }

    function test_parseDevicesAcceptsCompleteSnapshot() {
        const result = KeyboardLayoutParser.parseDevices(validDevices());

        verify(result.ok, result.error);
        compare(result.value.deviceName, "main keyboard");
        compare(result.value.deviceId, "main-keyboard-address");
        compare(result.value.activeIndex, 1);
        compare(result.value.layouts.length, 2);
        compare(result.value.layouts[0].layout, "us");
        compare(result.value.layouts[1].layout, "ru");
        compare(result.value.layouts[1].variant, "phonetic");
    }

    function test_parseDevicesRejectsMalformedSnapshots() {
        const invalidSnapshots = [
            "{",
            "null",
            JSON.stringify({}),
            JSON.stringify({ keyboards: [] }),
            JSON.stringify({ keyboards: [{ name: "main", layout: "us", variant: "", active_layout_index: null }] }),
            JSON.stringify({ keyboards: [{ name: "main", layout: "us", variant: "", active_layout_index: 0.5 }] }),
            JSON.stringify({ keyboards: [{ name: "main", layout: "us", variant: "", active_layout_index: 1 }] }),
            JSON.stringify({ keyboards: [{ name: "", layout: "us", variant: "", active_layout_index: 0 }] }),
            JSON.stringify({ keyboards: [{ name: "main", layout: "us,,ru", variant: "", active_layout_index: 0 }] }),
            JSON.stringify({ keyboards: [{ name: "main", layout: "us", active_layout_index: 0 }] })
        ];

        for (const json of invalidSnapshots) {
            const result = KeyboardLayoutParser.parseDevices(json);
            verify(!result.ok, json);
            verify(result.error.length > 0, json);
        }
    }

}
