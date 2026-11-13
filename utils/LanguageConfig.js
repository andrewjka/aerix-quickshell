.pragma library

// Строгий плоский формат языковых пакетов: ключ = "строка".
// Пакет en.conf задаёт полный контракт ключей для всех переводов.
function parseAssignments(text) {
    var values = {};
    text.split(/\r?\n/).forEach(function(line, index) {
        line = line.trim();
        if (!line || /^[#;]/.test(line))
            return;
        var match = /^([a-z][a-z0-9]*(?:\.[a-z][a-z0-9]*)*)\s*=\s*"((?:[^"\\]|\\["\\n])*)"\s*(?:[#;].*)?$/i.exec(line);
        if (!match)
            throw new Error("Invalid syntax on line " + (index + 1));
        var key = match[1];
        if (Object.prototype.hasOwnProperty.call(values, key))
            throw new Error("Duplicate key: " + key);
        values[key] = match[2].replace(/\\(["\\n])/g, function(_, character) {
            return character === "n" ? "\n" : character;
        });
    });
    return values;
}

function parseSelection(text) {
    var values = parseAssignments(text);
    var keys = Object.keys(values);
    if (keys.length !== 1 || !Object.prototype.hasOwnProperty.call(values, "language"))
        throw new Error("Expected exactly one field: language");
    var path = values.language.trim();
    if (!path)
        throw new Error("language must contain a file path");
    return /\.conf$/.test(path) ? path : path + ".conf";
}

function parsePack(text) {
    var values = parseAssignments(text);
    if (Object.keys(values).length === 0)
        throw new Error("Language pack must contain at least one key");
    return values;
}

function validatePack(values, baseline) {
    var keys = Object.keys(values);
    var baselineKeys = Object.keys(baseline);
    var unexpected = keys.find(function(key) {
        return !Object.prototype.hasOwnProperty.call(baseline, key);
    });
    if (unexpected)
        throw new Error("Unknown translation key: " + unexpected);
    var missing = baselineKeys.find(function(key) {
        return !Object.prototype.hasOwnProperty.call(values, key);
    });
    if (missing)
        throw new Error("Missing translation key: " + missing);
    return values;
}
