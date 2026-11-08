// Строгий плоский формат motion.conf без overrides и вложенных секций.
var keys = ["standardDurationMs", "extendedDurationMs", "surfaceSpringStartScale",
            "surfaceSpringOvershoot", "dockCloseDelayMs", "standardBezierCurve"];

function isFiniteNumber(value) {
    return typeof value === "number" && isFinite(value);
}

function parseNumber(value, key) {
    if (!/^(?:0|[1-9][0-9]*)(?:\.[0-9]+)?$/.test(value))
        throw new Error(key + ": ожидается неотрицательное число");
    return Number(value);
}

function parseCurve(value) {
    var points = value.split(",").map(function(point) {
        return parseNumber(point.trim(), "standardBezierCurve");
    });
    if (points.length !== 6)
        throw new Error("standardBezierCurve: ожидается шесть чисел");
    return points;
}

function parse(text) {
    var values = {};
    text.split(/\r?\n/).forEach(function(line, index) {
        line = line.trim();
        if (!line || /^[#;]/.test(line))
            return;
        var match = /^([A-Za-z][A-Za-z0-9]*)\s*=\s*([^#;\s].*?)\s*(?:[#;].*)?$/.exec(line);
        if (!match)
            throw new Error("Неверный синтаксис, строка " + (index + 1));
        var key = match[1];
        if (keys.indexOf(key) < 0)
            throw new Error("Неизвестный ключ: " + key);
        if (Object.prototype.hasOwnProperty.call(values, key))
            throw new Error("Повторный ключ: " + key);
        values[key] = key === "standardBezierCurve"
            ? parseCurve(match[2]) : parseNumber(match[2], key);
    });

    if (Object.keys(values).length !== keys.length
        || keys.some(function(key) { return !Object.prototype.hasOwnProperty.call(values, key); }))
        throw new Error("Ожидаемые поля: " + keys.join(", "));

    if (!Number.isInteger(values.standardDurationMs)
        || !Number.isInteger(values.extendedDurationMs)
        || !Number.isInteger(values.dockCloseDelayMs))
        throw new Error("Длительности должны быть целыми миллисекундами");
    if (values.surfaceSpringStartScale > 1 || values.surfaceSpringOvershoot > 1)
        throw new Error("Параметры spring должны быть от 0 до 1");
    if (!values.standardBezierCurve.every(isFiniteNumber))
        throw new Error("standardBezierCurve содержит неверное число");
    return values;
}
