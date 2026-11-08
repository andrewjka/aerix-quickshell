# E0: исходное состояние перед архитектурным рефакторингом

Дата: 2026-11-08. Основание: [этап E0 плана](qml_architecture_refactoring_plan.md#e0-зафиксировать-воспроизводимый-baseline).
Выполнены инвентаризация, lint и наблюдение работающей сессии. Исходники,
конфигурация, зависимости и состояние интерфейса намеренно не изменялись;
Quickshell не перезапускался. Этот документ не является результатом оптимизации.

## 1. Идентичность исходников

- Commit: `075842e20fdab4d996921b0f841f0e5a145cebfd`.
- До E0 tracked diff отсутствовал; единственный untracked-файл —
  `Agent-instructions/qml_architecture_refactoring_plan.md`, результат предыдущего аудита.
- 23 QML-файла и 2 `qmldir`, отдельных JS-файлов нет.
- SHA-256 отсортированного манифеста этих 25 файлов:
  `c729a74c0a379a44463115b256eded037e04b52779c1133847c64683f46f4ca5`.

Воспроизведение из корня проекта, без записи файлов:

```bash
python3 - <<'PY'
from pathlib import Path
import hashlib
files = sorted(p for p in Path('.').rglob('*') if p.is_file()
               and (p.suffix in ('.qml', '.js') or p.name == 'qmldir'))
manifest = ''.join(str(p) + ' ' + hashlib.sha256(p.read_bytes()).hexdigest()
                   + '\n' for p in files)
print(len(files), hashlib.sha256(manifest.encode()).hexdigest())
PY
```

## 2. Сессия и аппаратное окружение

| Параметр | Наблюдение |
| --- | --- |
| Quickshell | Пакет 0.3.2-1; instance `nqz9wnk5ot`, PID 466223, Wayland `wayland-1` |
| Запуск | 2026-11-08 01:19:08 по локальному времени; возраст в начале CPU-замера 5729,47 с |
| Qt | qt6-base 6.12.0-3, qt6-declarative 6.12.0-4, qt6-5compat 6.12.0-1; загружена libQt6Quick.so.6.12.0 |
| Hyprland | runtime 0.57.0, commit `0aa6745f705f2c4b0a5004eb019ef76e5bbdb426`, dirty=false; пакет 0.57.0-3 |
| Плагины | Загружены HyprGlass 1.1.1 и HyprCapture 0.6.0; факт загрузки не подтверждает параметры каждого эффекта |
| CPU | AMD Ryzen 5 5600 6-Core Processor |
| GPU | card1, amdgpu, PCI vendor/device `0x1002:0x73ff`; точное маркетинговое название и версия драйвера N/A |
| Монитор | Один DP-2, Xiaomi P27QBA-RX, 2560×1440, 165.002 Hz, scale 1.25, transform 0 |
| Логическая геометрия | 2048×1152, начало (0,0), reserved [0,40,0,0], активен workspace 4 |
| Вывод | DRM, XRGB8888, VRR=false, DPMS=true |
| Qt backend/render loop | N/A: загружены EGL/GLX, но это не доказательство конкретного RHI и render loop |
| Диагностические env | В окружении процесса не найдены QSG_RHI_BACKEND, QSG_RENDER_LOOP, QT_QPA_PLATFORM, QSG_INFO, QSG_RENDER_TIMING, WAYLAND_DEBUG |
| Условия | Рабочая прогретая сессия; история reload, позиция курсора, профиль питания и динамика фона не контролировались |

Данные получены read-only через `quickshell list`, `pacman -Q`,
`hyprctl -j version`, `hyprctl -j monitors`, `hyprctl -j layers`,
`hyprctl -j clients`, `hyprctl -j plugin list`, `/proc` и `/sys`.
Host PID недоступен внутри sandbox `/proc`; чтение на host разрешило измерение.
Пути runtime-инстанса не используются как import paths в командах проверки.

Набор окон: семь mapped Wayland-окон на monitor 0, без fullscreen и XWayland.
Ghostty на workspace 1 и 2, zen на 3, code-oss на 4 и 5, hyprfm на 6 —
по 2028×1092, tiled; kitty на 7 — 800×703, floating. Заголовки окон не сохранялись.

## 3. Контракт интерфейса и поверхности

Снимок `layers` показывает четыре поверхности Aerix на Top; popup в снимке нет:

| Namespace | x,y | width×height |
| --- | --- | --- |
| aerix:status-bar-shadow | 0,0 | 2048×45 |
| aerix:status-bar | 0,0 | 2048×40 |
| aerix:dock-shadow | 853,1060 | 342×92 |
| aerix:dock-panel | 853,1060 | 342×92 |

Все относятся к PID 466223, compositor alpha=1. Это не доказывает видимость
содержимого Dock: прозрачная поверхность и внутреннее состояние анимации — разные вещи.
Дополнительно на Background есть awww-daemon; он не входит в CPU/RAM Quickshell.

Контракт по текущему коду, **не результат ручной визуальной приёмки**:

- [Metrics](../core/Metrics.qml): spacing=10, Dock padding=10, нижний отступ=20,
  Bar height=40, боковые отступы Bar=10, popupRowSpacing=8, radius=8,
  panel alpha=0.08, shadow radius=4, shadow alpha=0.48.
- [Motion](../core/Motion.qml): defaultDuration=512 мс, longDuration=768 мс,
  panelCloseDelay=1128 мс. Сохранять значения в следующих этапах.
- [KeyboardLayoutWidget](../bar/KeyboardLayoutWidget.qml): 32 тестовые строки включены.
  [Popup](../bar/KeyboardLayoutPopup.qml) показывает до пяти строк, остальные
  прокручиваются; реальный список layouts добавляется перед тестовыми строками.
- Popup namespace `aerix:keyboard-layout`, Overlay; отступ от Bar в конечном
  положении 2×spacing=20. Выбор тестовой строки не отправляет IPC.
  Появление/скрытие включает reveal, scale/opacity и OutBack/InBack для смещения.
- [WindowPreview](../dock/WindowPreview.qml) пока использует отступ spacing=10.
  Это текущий baseline, а не повод незаметно менять UX в E0.
- Имена Dock и Bar сохраняются в соответствии с [правилами](Project_rules.md).

Матрица R01–R24 из §16 плана остаётся **не выполненной в E0**: автоматических
кликов, переключений workspace/layout, reload, hotplug и capture не было.
Для R20 зафиксирован только один DPR=1.25; для R22 — только текущие surfaces и
минутное наблюдение. Эти частичные данные не являются прохождением сценариев.
Описанные в каталоге F01–F23 дефекты сохраняются как исходные риски.

## 4. Воспроизводимый lint baseline

Команда из корня проекта; использует установленный SDK и локальные qmldir:

```bash
mapfile -t qml_files < <(rg --files -g '*.qml' | sort)
/usr/lib/qt6/bin/qmllint --ignore-settings -I . -I /usr/lib/qt6/qml \
  -i core/qmldir -i services/qmldir "${qml_files[@]}"
```

Результат: exit code 0, **18 предупреждений**: missing-property=14,
uncreatable-type=3, unqualified=1. Exit code 0 не означает отсутствие warnings.
Без двух `-i` получается 23: добавляются пять предупреждений singleton
Metrics, Motion, ClockService, DockPresentation, KeyboardLayoutService.
Явная загрузка qmldir убирает эти пять без изменения исходников.

| Файл | Строка | Диагностика |
| --- | ---: | --- |
| bar/KeyboardLayoutPopup.qml | 12 | PanelWindow not creatable |
| bar/KeyboardLayoutPopup.qml | 52 | margins.left: property left not found |
| bar/KeyboardLayoutPopup.qml | 53 | margins.top: property top not found |
| bar/KeyboardLayoutPopup.qml | 128 | property left not found |
| bar/KeyboardLayoutPopup.qml | 129 | property top not found |
| bar/KeyboardLayoutPopup.qml | 32 | QuickshellScreenInfo.width not found |
| bar/KeyboardLayoutPopup.qml | 128 | Margins.left member not found |
| bar/KeyboardLayoutPopup.qml | 129 | Margins.top member not found |
| bar/StatusBar.qml | 7 | PanelWindow not creatable |
| core/PanelShadowWindow.qml | 7 | PanelWindow not creatable |
| dock/WindowPreview.qml | 42 | onAnchoring: no matching signal |
| dock/WindowPreview.qml | 29 | anchor.window property not found |
| dock/WindowPreview.qml | 30 | anchor.edges property not found |
| dock/WindowPreview.qml | 31 | anchor.gravity property not found |
| dock/WindowPreview.qml | 32 | anchor.adjustment property not found |
| dock/WindowPreview.qml | 66 | PopupAnchor.updateAnchor not found |
| dock/WindowPreview.qml | 47 | PopupAnchor.rect member not found |
| dock/WindowPreview.qml | 50 | PopupAnchor.rect member not found |

В `/usr/lib/qt6/qml/Quickshell/quickshell-core.qmltypes` найдены полноценные
Margins, PopupAnchor и QuickshellScreenInfo с соответствующими свойствами.
В `_Window/quickshell-window.qmltypes:813–816` одновременно присутствуют
opaque-декларации этих имён. Это указывает на проблему разрешения метаданных,
но не доказывает безвредность любого будущего предупреждения.
PanelWindowInterface в `_Window` экспортирован как PanelWindow с isCreatable=false;
при этом реальные Bar/Dock surfaces созданы работающим runtime.
В E0 runtime-регистрация backend-типа полностью не трассировалась.

Не подавлять категории lint глобально и не править корректные singleton ради
обхода tooling. После каждого шага сравнивать файл, компонент, свойство и текст
диагностики; сдвиг номеров строк учитывать отдельно. Одного совпадения количества
недостаточно: исчезновение старого предупреждения может скрыть появление нового.

Последний фрагмент `quickshell log -t 24` содержит исторические
`qt.qpa.wayland.textinput ... disableSurface ... but 0x0 is focused` и
`Configuration Loaded`. Их причина не установлена; E0 не доказывает отсутствие
runtime warnings и не провоцировал новые открытия popup.

## 5. Минутное наблюдение CPU/RAM

Начало: 2026-11-07 23:54:37 UTC (2026-11-08 02:54:37 MSK).
Продолжительность 60,012874 с, один процесс PID 466223. CPU sampled раз в секунду
по `/proc/PID/stat`, utime+stime; SC_CLK_TCK=100, starttime проверялся на каждом
отсчёте. Использовано monotonic time; нормировка на одно логическое ядро.

| Метрика | Результат |
| --- | ---: |
| CPU ticks за весь интервал | 1 (0,01 CPU-секунды) |
| Средний CPU одного ядра | 0,016663% |
| Минимальный / максимальный секундный sample | 0 / 0,99979% |
| RSS начало → конец, KiB | 378908 → 378916 |
| PSS начало → конец, KiB | 296623 → 296631 |
| Private_Clean начало → конец, KiB | 8368 → 8368 |
| Private_Dirty начало → конец, KiB | 263648 → 263656 |
| Swap начало → конец, KiB | 0 → 0 |
| Дочерние процессы в конечном снимке | 0 |

Память прочитана из `smaps_rollup`. PSS в конце ≈289,7 MiB.
CPU одного короткого интервала имеет грубую дискретность: нельзя обещать постоянный
CPU 0,017% или использовать число как порог будущих регрессий.
Конечный список children не исключает короткоживущих процессов внутри интервала.
Изменение памяти на 8 KiB не доказывает утечку или стабильность после циклов UI.

Воспроизведение метода: взять starttime, utime+stime и monotonic time в начале,
повторять чтение 60 раз с шагом 1 с, проверить неизменность starttime; вычислить
`100 * delta(utime+stime) / SC_CLK_TCK / elapsed_seconds`. В начале/конце прочитать
`/proc/PID/smaps_rollup` и состав окон. Выбрать актуальный PID через `quickshell list`,
не переиспользовать PID из этого отчёта. Сравнительные runs выполнять по §17 плана.

## 6. Что остаётся неизмеренным

| Критерий | Статус и следующий способ проверки |
| --- | --- |
| M1 idle | Частично: только наблюдение выше. Нужны статичный фон, закрытый Dock/menu, одинаковый прогрев, три новых процесса, 60 с и 10 мин |
| M2 динамический фон | N/A: контролируемое видео не запускалось; отдельно измерить Qt CPU/commits и compositor GPU |
| M3 Dock/workspaces | N/A: серия действий и нагрузка 10/50/100 окон не создавались; QML Profiler и frame timings на 30 проходах |
| M4 layouts | N/A: 32 тестовые записи включены кодом, но 30 открытий/100 циклов не выполнялись; считать IPC, delegates, surfaces и input latency |
| M5 capture | N/A: preview не открывался; нужен статичный/движущийся источник, 30 открытий/100 циклов и проверка idle после закрытия |
| GPU, VRAM, passes | N/A: данные amdgpu/RenderDoc и compositor отдельно от Qt, после проверки поддержки установленным runtime |
| Объекты, bindings, IPC rate | N/A: нет включённого profiler или счётчиков; snapshot surfaces не заменяет счётчики QML-объектов |
| Backend/render loop | N/A: в отдельном диагностическом запуске QSG_INFO, затем чистый run без диагностики |
| Hotplug/несколько экранов | N/A: подключён один монитор; повторить R20/R21/R24 и M7 на подходящем оборудовании |
| Долгий прогон | N/A: выполнить M8; текущий возраст процесса не заменяет воспроизводимую историю нагрузки |

В доступном PATH не найдены pidstat, perf, qtcreator, qmlprofiler, renderdoccmd,
intel_gpu_top, amdgpu_top, nvidia-smi, strace. Ничего не устанавливалось.
Полный profiler run требует отдельной подготовленной диагностической сессии;
краткий read-only замер не заменяет M1–M5. Порядок, инструменты и ограничения —
[§17 основного плана](qml_architecture_refactoring_plan.md#17-план-измерения-эффективности).

## 7. Приёмка E0 и следующий шаг

- E0.1: снимок записан; неизвестные параметры явно отмечены N/A.
- E0.2: воспроизводимая команда и полный список lint сохранены; причины
  singleton проверены, ограничения метаданных и runtime разделены.
- E0.3: выполнено частично; контрольные M1–M5 и profiler остаются открытыми.
- Предварительный gate E0 закрыт с указанными ограничениями согласно условию
  завершения в плане. Это разрешает корректностный E1, но не заявления об ускорении.
- Следующий небольшой шаг — **E1.1**, валидация ответа о раскладках;
  сначала прочитать актуальную реализацию сервиса и требования приёмки E1.
  Остальные этапы в этой итерации не начинались.
