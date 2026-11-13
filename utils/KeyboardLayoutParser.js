.pragma library

/** Проверяет, что значение является объектом JSON, а не массивом или null. */
function isObject(value) {
    return value !== null && typeof value === "object" && !Array.isArray(value);
}

/**
 * Разбирает и валидирует ответ `hyprctl -j devices` без доступа к QML-состоянию.
 *
 * Успех всегда содержит полный raw-снимок выбранной клавиатуры. Ошибка не имеет
 * побочных эффектов, поэтому вызывающий код может сохранить последнее рабочее
 * состояние интерфейса.
 */
function parseDevices(json) {
    let devices;
    try {
        devices = JSON.parse(json);
    } catch (parseError) {
        return { ok: false, errorKey: "keyboard.invalidDeviceData" };
    }

    if (!isObject(devices))
        return { ok: false, errorKey: "keyboard.invalidDevicesObject" };

    if (!Array.isArray(devices.keyboards))
        return { ok: false, errorKey: "keyboard.missingKeyboards" };

    const keyboard = devices.keyboards.find(item => isObject(item) && item.main === true)
        ?? devices.keyboards.find(item => isObject(item));
    if (!keyboard)
        return { ok: false, errorKey: "keyboard.missingKeyboard" };

    if (typeof keyboard.name !== "string" || keyboard.name.trim().length === 0)
        return { ok: false, errorKey: "keyboard.missingKeyboardName" };

    if (typeof keyboard.layout !== "string")
        return { ok: false, errorKey: "keyboard.missingLayouts" };

    const codes = keyboard.layout.split(",").map(code => code.trim());
    if (codes.length === 0 || codes.some(code => code.length === 0))
        return { ok: false, errorKey: "keyboard.invalidLayouts" };

    if (typeof keyboard.variant !== "string")
        return { ok: false, errorKey: "keyboard.missingVariants" };

    const variants = keyboard.variant.split(",").map(variant => variant.trim());
    // Пустые хвостовые варианты не несут данных, но встречаются в XKB.
    while (variants.length > codes.length && variants[variants.length - 1].length === 0)
        variants.pop();
    if (variants.length > codes.length)
        return { ok: false, errorKey: "keyboard.extraVariants" };

    const index = keyboard.active_layout_index;
    if (typeof index !== "number" || !Number.isInteger(index)
            || index < 0 || index >= codes.length) {
        return { ok: false, errorKey: "keyboard.invalidActiveIndex" };
    }

    return {
        ok: true,
        value: {
            deviceName: keyboard.name.trim(),
            // address стабилен в пределах сессии и отличает замену устройства
            // с тем же отображаемым именем. Старые ответы могут не содержать его.
            deviceId: typeof keyboard.address === "string"
                && keyboard.address.trim().length > 0
                ? keyboard.address.trim()
                : keyboard.name.trim(),
            layouts: codes.map((layout, layoutIndex) => ({
                index: layoutIndex,
                layout: layout,
                variant: variants[layoutIndex] ?? ""
            })),
            activeIndex: index
        }
    };
}
