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
            if (seenOpacity) throw new Error("Повторная секция opacity");
            seenOpacity = true;
            section = result.opacity;
            return;
        }
        var match = /^([A-Za-z][A-Za-z0-9]*)\s*=\s*("(?:[^"\\])*"|[0-9]+(?:\.[0-9]+)?)\s*(?:[#;].*)?$/.exec(line);
        if (!match) throw new Error("Неверный синтаксис, строка " + (index + 1));
        var key = match[1];
        if (Object.prototype.hasOwnProperty.call(section, key))
            throw new Error("Повторный ключ: " + key);
        section[key] = match[2][0] === '"' ? match[2].slice(1, -1) : Number(match[2]);
    });
    return result;
}

function requireKeys(values, keys) {
    if (Object.keys(values).length !== keys.length
        || keys.some(function(key) { return !Object.prototype.hasOwnProperty.call(values, key); }))
        throw new Error("Ожидаемые поля: " + keys.join(", "));
}

function parseSelection(text) {
    var config = parse(text);
    requireKeys(config.values, ["theme"]);
    requireKeys(config.opacity, []);
    var path = config.values.theme;
    if (typeof path !== "string" || !path.trim())
        throw new Error("theme должен содержать путь к файлу");
    return /\.conf$/.test(path) ? path : path + ".conf";
}

function parsePalette(text) {
    var config = parse(text);
    requireKeys(config.values, colorKeys);
    requireKeys(config.opacity, opacityKeys);
    colorKeys.forEach(function(key) {
        if (typeof config.values[key] !== "string" || !/^#[0-9a-fA-F]{6}$/.test(config.values[key]))
            throw new Error(key + ": ожидается цвет #RRGGBB");
    });
    opacityKeys.forEach(function(key) {
        var value = config.opacity[key];
        if (typeof value !== "number" || !isFinite(value) || value < 0 || value > 1)
            throw new Error(key + ": ожидается число от 0 до 1");
    });
    return config;
}
