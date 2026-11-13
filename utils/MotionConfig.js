// Строгий плоский формат motion.conf без overrides и вложенных секций.
var keys = ["durationMs", "quickDurationMs", "springStartScale", "springOvershoot",
            "dockCloseDelayMs", "bezierCurve"];

function isFiniteNumber(value) {
    return typeof value === "number" && isFinite(value);
}

function parseNumber(value, key) {
    if (!/^(?:0|[1-9][0-9]*)(?:\.[0-9]+)?$/.test(value))
        throw new Error(key + ": expected a non-negative number");
    return Number(value);
}

function parseCurve(value) {
    var points = value.split(",").map(function(point) {
        return parseNumber(point.trim(), "bezierCurve");
    });
    if (points.length !== 6)
        throw new Error("bezierCurve: expected six numbers");
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
            throw new Error("Invalid syntax on line " + (index + 1));
        var key = match[1];
        if (keys.indexOf(key) < 0)
            throw new Error("Unknown key: " + key);
        if (Object.prototype.hasOwnProperty.call(values, key))
            throw new Error("Duplicate key: " + key);
        values[key] = key === "bezierCurve"
            ? parseCurve(match[2]) : parseNumber(match[2], key);
    });

    if (Object.keys(values).length !== keys.length
        || keys.some(function(key) { return !Object.prototype.hasOwnProperty.call(values, key); }))
        throw new Error("Expected fields: " + keys.join(", "));

    if (!Number.isInteger(values.durationMs)
        || !Number.isInteger(values.quickDurationMs)
        || !Number.isInteger(values.dockCloseDelayMs))
        throw new Error("Durations must be whole milliseconds");
    if (values.springStartScale > 1 || values.springOvershoot > 1)
        throw new Error("Spring parameters must be between 0 and 1");
    if (!values.bezierCurve.every(isFiniteNumber))
        throw new Error("bezierCurve contains an invalid number");
    return values;
}
