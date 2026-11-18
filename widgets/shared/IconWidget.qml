pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects

// Высота задаётся потребителем; обычные icon-темы используют квадратное поле.
// Явный aspectRatio позволяет редким неквадратным ресурсам сохранить форму,
// при этом sourceSize не зависит от ещё незагруженного Image.
Item {
    id: root
    required property url iconSource
    property color tintColor: "white"
    property bool tinted: true
    property bool whiteSource: false
    property real devicePixelRatio: 1
    property bool asynchronous: false
    property real aspectRatio: 1
    // Дополнительная плотность нужна для иконок, которые временно растут при
    // hover: текстура остаётся чёткой и при анимированном масштабе.
    property real rasterScale: 1
    // Наружным контейнерам нужен статус загрузки для fallback-содержимого.
    readonly property int status: sourceImage.status
    readonly property bool directImage: !tinted || (whiteSource
        && tintColor.r === 1 && tintColor.g === 1 && tintColor.b === 1)
    implicitWidth: height * aspectRatio
    width: implicitWidth

    Image {
        id: sourceImage
        anchors.fill: parent
        source: root.iconSource
        asynchronous: root.asynchronous
        // Icon theme выбирает вариант по обоим измерениям. При sourceSize.width
        // равном -1 он часто отдавал малую 32px версию и растягивал её в launcher.
        sourceSize.width: Math.max(1, Math.ceil(root.width * root.devicePixelRatio
            * root.rasterScale))
        sourceSize.height: Math.max(1, Math.ceil(root.height * root.devicePixelRatio
            * root.rasterScale))
        fillMode: Image.PreserveAspectFit
        smooth: true
        visible: root.directImage
        opacity: root.tinted && root.directImage ? root.tintColor.a : 1
    }

    // Белые SVG и цветные иконки идут напрямую; эффект создаётся только для tint.
    Loader {
        anchors.fill: parent
        active: !root.directImage
        sourceComponent: MultiEffect {
            source: sourceImage
            autoPaddingEnabled: false
            colorization: 1
            colorizationColor: root.tintColor
        }
    }
}
