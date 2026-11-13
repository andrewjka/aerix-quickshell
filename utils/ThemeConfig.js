// Ограниченный INI-подобный формат: строки цветов и числовая секция opacity.
// Никакого eval: неизвестные, повторные и неполные настройки отклоняются.
var colorKeys = ["background", "foreground", "accent", "hover", "border", "shadow",
                 "overlay"];
var opacityKeys = ["background", "foreground", "accent", "hover", "border", "shadow",
                   "overlay", "disabled"];

function parse(text) {
    var result = { values: {}, opacity: {} };
    var section = result.values;
    var seenOpacity = false;
    text.split(/\r?\n/).forEach(function(line, index) {
        line = line.trim();
        if (!line || /^[#;]/.test(line))
            return;
        if (line === "[opacity]") {
            if (seenOpacity) throw new Error("Duplicate opacity section");
            seenOpacity = true;
            section = result.opacity;
            return;
        }
        var match = /^([A-Za-z][A-Za-z0-9]*)\s*=\s*("(?:[^"\\])*"|[0-9]+(?:\.[0-9]+)?)\s*(?:[#;].*)?$/.exec(line);
        if (!match) throw new Error("Invalid syntax on line " + (index + 1));
        var key = match[1];
        if (Object.prototype.hasOwnProperty.call(section, key))
            throw new Error("Duplicate key: " + key);
        section[key] = match[2][0] === '"' ? match[2].slice(1, -1) : Number(match[2]);
    });
    return result;
}

function requireKeys(values, keys) {
    if (Object.keys(values).length !== keys.length
        || keys.some(function(key) { return !Object.prototype.hasOwnProperty.call(values, key); }))
        throw new Error("Expected fields: " + keys.join(", "));
}

function parseSelection(text) {
    var config = parse(text);
    requireKeys(config.values, ["theme"]);
    requireKeys(config.opacity, []);
    var path = config.values.theme;
    if (typeof path !== "string" || !path.trim())
        throw new Error("theme must contain a file path");
    return /\.conf$/.test(path) ? path : path + ".conf";
}

function parsePalette(text) {
    var config = parse(text);
    requireKeys(config.values, colorKeys);
    requireKeys(config.opacity, opacityKeys);
    colorKeys.forEach(function(key) {
        if (typeof config.values[key] !== "string" || !/^#[0-9a-fA-F]{6}$/.test(config.values[key]))
            throw new Error(key + ": expected a #RRGGBB color");
    });
    opacityKeys.forEach(function(key) {
        var value = config.opacity[key];
        if (typeof value !== "number" || !isFinite(value) || value < 0 || value > 1)
            throw new Error(key + ": expected a number from 0 to 1");
    });
    return config;
}
