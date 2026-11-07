# Внешняя тень прозрачных панелей

`core/PanelShadow.qml` использует штатные `QtQuick.Effects.RectangularShadow`
и `Qt5Compat.GraphicalEffects.OpacityMask` с `invert: true`. Собственных
шейдеров и отдельного шага сборки нет. Нужен Qt >= 6.11 для раздельных
радиусов углов `RectangularShadow` (локально установлен Qt 6.12).

`RectangularShadow` рисует плавную тень, а инвертированная маска вырезает
силуэт панели, оставляя внутреннюю область полностью прозрачной.
Форма берётся из геометрии и четырёх радиусов `sourceItem`; текст, иконки,
альфа заливки и рамки не влияют на тень. Источник и маска скрыты от сцены,
но используются эффектом как текстуры. Их буферы имеют одинаковый запас
`panelShadowRadius + 1` вокруг панели; маска сглаживает края силуэта.

Цвет и ширина затухания задаются `Metrics.panelShadowColor` и
`Metrics.panelShadowRadius` (свойство `blur` у `RectangularShadow`). Форма
затухания определяется Qt и не идентична Hyprland render_power.

Тени вынесены в отдельные layer-surface: `bar/StatusBarShadow.qml` и
`dock/DockShadow.qml`. Видимые `StatusBar` и `DockPanel` содержат только
интерфейс и получают HyprGlass как обычно. В локальном
`~/.config/hypr/plugins/hyprglass.lua` namespace `aerix:status-bar-shadow` и
`aerix:dock-shadow` исключены из HyprGlass, поэтому он не размывает уже
нарисованную Qt-тень. Shadow-окна не имеют input region и не резервируют
рабочую область.

`DockPresentation` хранит состояние открытия по экрану, а `DockLayout`
рассчитывает общую ширину Dock. Благодаря этому Dock и его тень начинают
анимацию одновременно, имеют одинаковую ширину и остаются центрированными при
изменении состава окон. У края физического экрана тень обрезается; Dock не
поднимается ради её размещения.

Проверка 2026-11-07 после перехода на штатные эффекты: отдельный OpenGL-рендер
Qt через Xvfb подтвердил белую заливку с alpha 20/255, красную внешнюю тень
с alpha 59/255 в точке на 10 px ниже панели и alpha 0 вдали от панели.
`qmllint core/PanelShadow.qml` и `git diff --check` прошли без замечаний;
рабочий Quickshell успешно перезагрузил конфигурацию. Интерактивные сценарии
Dock и несколько мониторов в этой проверке не тестировались.

Документация Qt: https://doc.qt.io/qt-6/qml-qtquick-effects-rectangularshadow.html
