// Строгий секционный формат configs/metrics.conf. Ссылки разрешены только на
// уже объявленные числовые метрики: $section.key.
var sections = {
    common: ["spacing", "baseFontSize", "panelRadius", "panelShadowRadius"],
    dock: ["groupHeight", "panelHeight", "bottomMargin", "triggerHeight",
           "panelHorizontalMargin", "panelPadding", "iconSlotSize", "iconSize",
           "iconSpacing", "hoverSpacing", "iconPressOffset", "iconTopOverflow",
           "iconBottomOverflow", "activeWorkspaceGap", "activeWorkspacePadding",
           "iconHoverScale", "iconRasterOversample"],
    statusBar: ["statusBarHeight", "statusBarLogoHeight", "statusBarHorizontalMargin",
                "statusBarWidgetSpacing", "statusBarFontSize",
                "statusBarWidgetIconSize"],
    popup: ["popupRowSpacing"],
    osd: ["osdWidth", "osdHeight"],
    appLauncher: ["appLauncherColumns", "appLauncherVisibleRows",
                  "appLauncherIconSize", "appLauncherIconSafeZone",
                  "appLauncherFontSize", "appLauncherSearchCascadeDelayMs",
                  "appLauncherFolderTitleFontSize",
                  "appLauncherScrollFadeStrength", "appLauncherScrollFadeRadius",
                  "appLauncherWheelScrollRows",
                  "appLauncherDragAutoScrollRowsPerSecond",
                  "appLauncherOverscrollDistance"],
    preview: ["previewWidth", "previewHeight", "previewTitleHeight"],
    motion: ["durationMs", "quickDurationMs", "springStartScale", "longHoldDelayMs",
             "springOvershoot", "bezierCurve"]
};
var integerKeys = [
    "spacing", "baseFontSize", "panelRadius", "panelShadowRadius",
    "groupHeight", "panelHeight", "bottomMargin", "triggerHeight",
    "panelHorizontalMargin", "panelPadding", "iconSlotSize", "iconSize",
    "iconSpacing", "hoverSpacing", "iconPressOffset", "iconTopOverflow",
    "iconBottomOverflow", "activeWorkspaceGap", "activeWorkspacePadding",
    "statusBarHeight", "statusBarLogoHeight", "statusBarHorizontalMargin", "statusBarWidgetSpacing",
    "statusBarFontSize", "statusBarWidgetIconSize", "popupRowSpacing",
    "osdWidth", "osdHeight",
    "appLauncherColumns", "appLauncherVisibleRows", "appLauncherIconSize",
    "appLauncherIconSafeZone", "appLauncherFontSize",
    "appLauncherSearchCascadeDelayMs", "appLauncherFolderTitleFontSize",
    "appLauncherScrollFadeRadius", "appLauncherOverscrollDistance",
    "previewWidth", "previewHeight", "previewTitleHeight", "durationMs",
    "quickDurationMs", "longHoldDelayMs"
];
var curveKey = "bezierCurve";
var keys = Object.keys(sections).reduce(function(result, section) {
    return result.concat(sections[section]);
}, []);

function parseNumber(value, key) {
    if (!/^(?:0|[1-9][0-9]*)(?:\.[0-9]+)?$/.test(value))
        throw new Error(key + ": expected a non-negative number");
    return Number(value);
}

function parseCurve(value) {
    var points = value.split(",").map(function(point) {
        return parseNumber(point.trim(), curveKey);
    });
    if (points.length !== 6)
        throw new Error(curveKey + ": expected six numbers");
    return points;
}

function parseValue(value, key, values) {
    var reference = /^\$([A-Za-z][A-Za-z0-9]*)\.([A-Za-z][A-Za-z0-9]*)$/.exec(value);
    if (reference) {
        var section = reference[1];
        var field = reference[2];
        if (!sections[section] || sections[section].indexOf(field) < 0)
            throw new Error(key + ": unknown reference " + value);
        if (!Object.prototype.hasOwnProperty.call(values, field))
            throw new Error(key + ": reference must be declared earlier: " + value);
        return values[field];
    }
    return key === curveKey ? parseCurve(value) : parseNumber(value, key);
}

function parse(text) {
    var values = {};
    var currentSection = "";
    var seenSections = {};
    text.split(/\r?\n/).forEach(function(line, index) {
        line = line.trim();
        if (!line || /^[#;]/.test(line))
            return;
        var sectionMatch = /^\[([A-Za-z][A-Za-z0-9]*)\]$/.exec(line);
        if (sectionMatch) {
            currentSection = sectionMatch[1];
            if (!sections[currentSection])
                throw new Error("Unknown section on line " + (index + 1));
            if (seenSections[currentSection])
                throw new Error("Duplicate section: " + currentSection);
            seenSections[currentSection] = true;
            return;
        }
        var match = /^([A-Za-z][A-Za-z0-9]*)\s*=\s*([^#;\s].*?)\s*(?:[#;].*)?$/.exec(line);
        if (!match || !currentSection)
            throw new Error("Invalid syntax on line " + (index + 1));
        var key = match[1];
        if (sections[currentSection].indexOf(key) < 0)
            throw new Error("Unknown key in [" + currentSection + "]: " + key);
        if (Object.prototype.hasOwnProperty.call(values, key))
            throw new Error("Duplicate key: " + key);
        values[key] = parseValue(match[2], key, values);
    });

    if (Object.keys(values).length !== keys.length
            || keys.some(function(key) {
                return !Object.prototype.hasOwnProperty.call(values, key);
            }))
        throw new Error("Expected fields: " + keys.join(", "));
    if (integerKeys.some(function(key) { return !Number.isInteger(values[key]); }))
        throw new Error("Integer metrics must be whole numbers");
    if (values.springStartScale > 1 || values.springOvershoot > 1)
        throw new Error("Spring parameters must be between 0 and 1");
    return values;
}
