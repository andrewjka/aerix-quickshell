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

Прозрачный буфер layer-surface включает область отрисовки тени. Он не увеличивает
резерв рабочей области: у Dock остаётся `ExclusionMode.Ignore`, у Bar явно
`exclusiveZone: Metrics.statusBarHeight`. Видимая поверхность Bar сохраняет
высоту и боковые отступы; Dock сохраняет нижний отступ и центрирование.
Маски ввода исключают дополнительную область тени. У края физического экрана
тень обрезается; Dock не поднимается ради её размещения.

Параметры radius 40 и красный цвет принадлежат пользователю и оставлены
для тестирования.

## HyprGlass

`StatusBar.qml` и `DockPanel.qml` передают видимую поверхность панели в
`BackgroundEffect.blurRegion` (протокол `ext-background-effect-v1`). В локальном
`~/.config/hypr/plugins/hyprglass.lua` для namespace `aerix:status-bar` и
`aerix:dock-panel` установлен `mask_mode = "region"`. Поэтому HyprGlass
размывает только фон под скруглённой панелью; внешняя Qt-тень остаётся в том же
layer-surface, но не попадает в область glass-эффекта.

Этот способ не зависит от размера, позиции и анимации Dock: `Region` следует
за `panelSurface` и повторяет его четыре радиуса. Он требует Quickshell с
`BackgroundEffect` и compositor с `ext-background-effect-v1`; без поддержки
протокола интерфейс остаётся рабочим, но фон панели не будет размываться.

Проверка 2026-11-07 после перехода на штатные эффекты: отдельный OpenGL-рендер
Qt через Xvfb подтвердил белую заливку с alpha 20/255, красную внешнюю тень
с alpha 59/255 в точке на 10 px ниже панели и alpha 0 вдали от панели.
`qmllint core/PanelShadow.qml` и `git diff --check` прошли без замечаний;
рабочий Quickshell успешно перезагрузил конфигурацию. Интерактивные сценарии
Dock и несколько мониторов в этой проверке не тестировались.

Документация Qt: https://doc.qt.io/qt-6/qml-qtquick-effects-rectangularshadow.html
