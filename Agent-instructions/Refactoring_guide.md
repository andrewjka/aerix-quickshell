# Aerix Quickshell Refactoring Guide

## Методичка по архитектуре, производительности и рефакторингу оболочки

**Проект:** Aerix  
**Область:** Quickshell / QML / QtQuick  
**Цель:** получить одну цельную, модульную и экономную оболочку без лишних процессов, дублирования сервисов и постоянного потребления ресурсов невидимыми компонентами.

---

# 1. Главная архитектурная идея

Aerix Shell должен запускаться как **один экземпляр Quickshell**.

Не нужно запускать:

- отдельный Quickshell для Dock;
- отдельный Quickshell для Bar;
- отдельный Quickshell для OSD;
- отдельный Quickshell для Launcher;
- отдельный Quickshell для Notifications.

Все эти элементы являются частями одного Shell.

Предпочтительная модель:

```text
quickshell
└── shell.qml
    ├── Bar
    ├── Dock
    ├── OSD
    ├── Notifications
    ├── Launcher
    ├── QuickSettings
    ├── Services
    └── Shared Components
```

Количество `.qml`-файлов практически не является проблемой само по себе.

Проблема начинается тогда, когда создаётся слишком много **живых QML-объектов**, процессов, таймеров, изображений и подписок.

---

# 2. Цели рефакторинга

После рефакторинга Aerix Shell должен соответствовать следующим принципам.

### Один Shell

Один Quickshell-процесс обслуживает всю оболочку.

### Один источник данных

Один системный источник не должен опрашиваться несколькими независимыми компонентами.

Например:

```text
НЕПРАВИЛЬНО

Bar
└── Battery Process

Quick Settings
└── Battery Process

OSD
└── Battery Process
```

Вместо этого:

```text
BatteryService
       │
       ├── Bar
       ├── QuickSettings
       └── OSD
```

### UI создаётся только тогда, когда нужен

Редко используемые интерфейсы не должны постоянно жить в памяти.

### События лучше polling

Если данные можно получать через сигнал, IPC или DBus, не нужно запускать команду каждые несколько сотен миллисекунд.

### Multi-monitor не означает multi-service

На каждом мониторе может быть своё окно Bar или Dock, но системные сервисы должны оставаться общими.

---

# 3. Этап 1 — инвентаризация текущего Shell

До изменения архитектуры необходимо понять, что сейчас существует.

Составить список:

```text
Windows:
- Dock
- Bar
- OSD
- Launcher
- Notifications
- Quick Settings
...

Services:
- Hyprland
- Audio
- Network
- Battery
- Brightness
- Media
...

Background tasks:
- Process
- Timer
- DBus connections
- IPC connections
...

Heavy resources:
- Images
- SVG
- Wallpapers
- Graphs
- Models
...
```

Для каждого компонента ответить на четыре вопроса:

1. Нужен ли он постоянно?
2. Создаёт ли он процессы?
3. Использует ли Timer?
4. Может ли он существовать только при открытии?

---

# 4. Этап 2 — измерить baseline

Рефакторинг производительности бессмыслен без исходных измерений.

Перед изменениями записать:

```bash
ps -C quickshell -o pid,rss,vsz,etime,cmd
```

Нас в первую очередь интересует `RSS`.

Но желательно также использовать:

```bash
smem -P quickshell
```

Для анализа особенно полезен **PSS**, потому что он корректнее распределяет shared memory Qt и системных библиотек.

Записываем:

```text
Aerix baseline

Startup RSS:
Startup PSS:

After 10 min:
After 1 h:

Idle CPU:

Number of Quickshell processes:

External child processes:

Open UI:
- launcher:
- quick settings:
- notification center:
```

После рефакторинга сравниваем результаты.

---

# 5. Целевой memory budget

Это не строгие системные требования, а инженерные ориентиры.

Для Aerix Shell:

```text
70–120 MiB PSS      отлично
120–200 MiB         нормальная цель
200–300 MiB         допустимо
300–500 MiB         требуется анализ
>500 MiB            необходимо профилирование
```

Главный показатель — не только абсолютная цифра.

Особенно важно, чтобы память не росла постоянно.

Хороший сценарий:

```text
startup     145 MiB
1 hour      150 MiB
4 hours     153 MiB
8 hours     154 MiB
```

Плохой:

```text
startup     130 MiB
30 min      250 MiB
2 hours     600 MiB
8 hours     1.5 GiB
```

Во втором случае нужно искать retained objects или leak.

---

# 6. Этап 3 — один entry point

Должен существовать один главный:

```text
shell.qml
```

Он отвечает только за композицию Shell.

Например:

```qml
ShellRoot {
    CoreServices {}

    BarManager {}
    DockManager {}

    OsdLoader {}
    LauncherLoader {}
    NotificationManager {}
}
```

`shell.qml` не должен превращаться в файл на 5000 строк.

Он является **точкой сборки**, а не местом реализации всего DE.

---

# 7. Предлагаемая структура Aerix Shell

Пример:

```text
shell/
├── shell.qml
│
├── core/
│   ├── Theme.qml
│   ├── Animation.qml
│   └── Config.qml
│
├── services/
│   ├── HyprlandService.qml
│   ├── AudioService.qml
│   ├── NetworkService.qml
│   ├── BatteryService.qml
│   ├── BrightnessService.qml
│   └── MediaService.qml
│
├── bar/
│   ├── Bar.qml
│   ├── WorkspaceWidget.qml
│   └── StatusArea.qml
│
├── dock/
│   ├── Dock.qml
│   ├── DockGroup.qml
│   └── DockIcon.qml
│
├── osd/
│   ├── Osd.qml
│   └── OsdController.qml
│
├── launcher/
│   ├── Launcher.qml
│   └── AppEntry.qml
│
├── notifications/
│   ├── NotificationPopup.qml
│   ├── NotificationCenter.qml
│   └── NotificationItem.qml
│
├── quicksettings/
│   ├── QuickSettings.qml
│   └── ...
│
└── components/
    ├── IconButton.qml
    ├── Popup.qml
    ├── Separator.qml
    └── ...
```

Это ориентир, а не обязательная структура.

Не нужно дробить компонент на десять файлов, если он прекрасно читается в одном.

---

# 8. Services должны быть singleton-like

Сервис представляет **состояние системы**, а не визуальный элемент.

Например:

```text
AudioService

volume
muted
defaultSink
devices
```

Bar только читает:

```text
AudioService.volume
```

Quick Settings читает те же данные.

OSD тоже.

Нельзя создавать три независимых механизма получения громкости.

---

# 9. Multi-monitor

Это особенно важный пункт.

Допускается:

```text
Monitor 1
└── BarWindow

Monitor 2
└── BarWindow
```

Но нельзя:

```text
Monitor 1
└── Bar
    └── AudioService

Monitor 2
└── Bar
    └── AudioService
```

Правильно:

```text
              AudioService
                 │
       ┌─────────┴─────────┐
       ↓                   ↓
Monitor 1 Bar         Monitor 2 Bar
```

Общие сервисы должны создаваться **выше уровня monitor variants**.

---

# 10. Lazy loading

Один из главных способов экономии RAM.

Постоянно должны существовать только элементы, которыми пользователь действительно пользуется постоянно.

Например:

```text
ALWAYS LOADED

Bar
Dock
Notification receiver
OSD controller
Hyprland service
Audio service
```

А такие вещи можно создавать лениво:

```text
LAZY

Launcher UI
Quick Settings
Settings
Bluetooth device list
Wi-Fi network list
Emoji picker
Wallpaper selector
Clipboard manager UI
Large notification history UI
```

То есть закрытый Launcher не должен означать:

> огромный Launcher существует, но `visible: false`.

Лучше, чтобы тяжёлая часть вообще не была создана.

Пример концепции:

```qml
Loader {
    active: launcherController.open
    sourceComponent: Launcher {}
}
```

После закрытия необходимо решить, нужно ли уничтожать UI сразу или держать короткое время для быстрого повторного открытия.

---

# 11. `visible: false` — не lazy loading

Это важная ошибка.

Если написано:

```qml
Launcher {
    visible: false
}
```

Launcher всё равно:

- создан;
- занимает память;
- содержит модели;
- может иметь timers;
- может подписываться на сервисы;
- может загружать изображения.

`visible: false` лишь означает, что его не рисуют.

Поэтому тяжёлые компоненты следует создавать через Loader или другую управляемую lifecycle-модель.

---

# 12. Минимизировать внешние Process

Quickshell умеет запускать команды.

Это удобно, но легко злоупотребить.

Плохо:

```text
каждые 500 ms:
    exec("wpctl get-volume")

каждую секунду:
    exec("hyprctl activewindow")

каждые две секунды:
    exec("cat /sys/...")
```

Это создаёт процессы снова и снова.

Лучше использовать:

```text
PipeWire API
Hyprland IPC
DBus
/sys event-based интерфейс
Quickshell native API
```

`Process` использовать там, где нет нормального событийного интерфейса или операция выполняется редко.

---

# 13. Timer audit

Для каждого `Timer` необходимо задать вопрос:

> Почему он существует?

Timer оправдан для:

- часов;
- debounce;
- задержки скрытия;
- animation state;
- редкой проверки ресурса без событийного API.

Timer подозрителен для:

- аудио;
- окон Hyprland;
- сети;
- workspace;
- media state;
- notifications.

Если источник способен присылать события, polling обычно не нужен.

---

# 14. Timer должен выключаться

Если polling всё-таки необходим:

```qml
Timer {
    running: componentVisible
}
```

а не:

```qml
Timer {
    running: true
}
```

24 часа в сутки.

Если окно закрыто, его вспомогательные polling-задачи должны останавливаться.

---

# 15. Изображения

Изображения легко начинают потреблять большое количество памяти.

Например, PNG:

```text
3840 × 2160 × 4 bytes
≈ 31 MiB
```

Даже если на экране изображение показывается размером 64×64.

Поэтому:

- не загружать огромные изображения без необходимости;
- использовать SVG для иконок там, где возможно;
- задавать подходящие source size;
- кешировать разумно;
- не создавать десятки невидимых копий;
- не конвертировать SVG в PNG без причины.

Для Dock:

> оригинальная иконка должна сохранять исходное качество.

Не надо заранее пережимать её в маленький bitmap.

---

# 16. ListView вместо огромных Repeater

Для больших динамических списков:

- приложения;
- процессы;
- Wi-Fi сети;
- Bluetooth устройства;
- история уведомлений;

предпочтительно использовать виртуализируемые представления.

Если список содержит 1000 элементов, не обязательно создавать 1000 полноценных delegate одновременно.

Использовать `ListView` там, где это логично.

---

# 17. Избегать лишних object trees

Если:

```text
Popup
└── Rectangle
    └── Item
        └── Item
            └── Item
                └── Rectangle
```

и большая часть уровней ничего не делает — это лишняя сложность.

Упрощать QML hierarchy.

Но не заниматься микрооптимизацией в ущерб читаемости.

---

# 18. Общие компоненты

Повторяющийся UI следует выносить.

Например:

```text
AerixIconButton
AerixPopup
AerixSeparator
AerixTooltip
AerixSurface
```

Это уменьшает дублирование кода и позволяет централизованно менять дизайн.

---

# 19. Единая система motion

В Aerix используется фирменная кривая:

```text
cubic-bezier(0.05, 0.9, 0.1, 1.05)
```

Её нельзя дублировать вручную в каждом компоненте.

Нужно сделать общий источник:

```text
Animation.qml
```

или эквивалентный singleton.

Например:

```text
Motion.standardDuration
Motion.fastDuration
Motion.standardCurve
```

Таким образом Dock, Launcher, OSD и Quick Settings получают одинаковый характер движения.

---

# 20. Единые design tokens

То же относится к:

- размерам;
- radius;
- spacing;
- opacity;
- shadows;
- colours;
- typography.

Например:

```text
Theme.surface
Theme.surfaceElevated
Theme.textPrimary
Theme.textSecondary

Metrics.radiusMedium
Metrics.spacingSmall
Metrics.iconMedium
```

Это значительно упростит будущий Aerix Theme Engine.

---

# 21. Разделить UI и business logic

Нельзя заставлять `DockIcon.qml` самому:

- искать `.desktop`;
- читать Hyprland IPC;
- выбирать icon theme;
- переключать workspace;
- вычислять активное окно;
- запускать shell command;
- рисовать UI.

Его задача должна быть примерно:

```text
получить данные
→ показать иконку
→ сообщить о клике
```

А логика должна находиться выше.

---

# 22. Жизненный цикл popup

Для каждого popup определить:

```text
Closed
Opening
Open
Closing
Destroyed / Cached
```

Это важно для:

- Launcher;
- Quick Settings;
- Calendar;
- Notification Center.

Иначе легко получить скрытые UI-деревья, которые продолжают работать.

---

# 23. Notification system

История уведомлений потенциально может расти бесконечно.

Необходимо установить лимит.

Например:

```text
maximum retained notifications: 100–300
```

Старые записи удаляются или сохраняются отдельно.

Нельзя бесконечно держать QML-объекты уведомлений в памяти.

---

# 24. Icon cache

Для Aerix в будущем имеет смысл сделать единый resolver иконок.

Не нужно каждому компоненту заново выполнять:

```text
window class
→ DesktopEntry
→ icon
→ Quickshell.iconPath
```

Желательно централизовать эту логику.

Позже её можно интегрировать с потенциальным `aerix-icon`.

---

# 25. Logging

Вместо случайного:

```qml
console.log(...)
```

по всему проекту лучше иметь уровни:

```text
DEBUG
INFO
WARN
ERROR
```

В production не нужно постоянно генерировать огромный поток debug-логов.

---

# 26. Performance rule

Каждый новый постоянный компонент Aerix должен пройти три вопроса:

### CPU

Работает ли что-нибудь постоянно, когда пользователь ничего не делает?

### Memory

Какие объекты этот компонент удерживает?

### Processes

Запускает ли он дополнительные процессы?

Если ответ нельзя объяснить — компонент требует ревизии.

---

# 27. Idle-state как главный benchmark

Shell большую часть жизни находится в idle.

Поэтому наша главная оптимизация:

> Aerix ничего не делает, пока ничего не происходит.

Хороший Shell в idle:

```text
CPU: около 0%
GPU: минимальная активность
Process spawning: отсутствует
Polling: минимальный
Memory: стабильна
```

---

# 28. Performance targets Aerix

Предварительные ориентиры:

```text
Quickshell instances:
1

Idle CPU:
≈ 0%

Idle PSS:
желательно < 200 MiB

Memory growth:
≈ 0 MiB/hour

Background Process spawning:
0 в нормальном idle

Permanent polling:
минимум
```

Эти значения не являются обещанием пользователям.

Они являются инженерной целью.

---

# 29. Как проводить рефакторинг

Не переписывать весь Shell одновременно.

Использовать постепенный подход.

### Шаг 1

Зафиксировать baseline.

### Шаг 2

Собрать один Quickshell instance.

### Шаг 3

Вынести системные данные в services.

### Шаг 4

Убрать дублирующие Process и Timer.

### Шаг 5

Перевести тяжёлые UI на lazy loading.

### Шаг 6

Исправить multi-monitor lifecycle.

### Шаг 7

Оптимизировать изображения и большие модели.

### Шаг 8

Вынести Theme/Motion/Metrics.

### Шаг 9

Замерить память и CPU.

### Шаг 10

И только затем заниматься микрооптимизациями.

---

# 30. Нельзя оптимизировать вслепую

Не следует удалять хорошие архитектурные решения только потому, что «они наверное жрут RAM».

Сначала измерить.

Например:

```text
Launcher:
+35 MiB
```

значимый кандидат.

А:

```text
маленький separator:
+несколько KiB
```

не имеет значения.

Сначала оптимизировать крупные источники потребления.

---

# 31. Проверка memory leak

После каждого большого этапа:

```bash
ps -C quickshell -o pid,rss,etime,cmd
```

Записывать состояние:

```text
00:00  145 MiB
01:00  148 MiB
02:00  149 MiB
04:00  150 MiB
```

Затем провести stress test:

- открыть Launcher 100 раз;
- открыть Quick Settings 100 раз;
- переключить workspace много раз;
- создать/закрыть десятки окон;
- получить много уведомлений.

Память после завершения должна возвращаться примерно к стабильному уровню.

---

# 32. Definition of Done

Рефакторинг Shell считается успешным, когда:

- работает один Quickshell instance;
- нет дублирующихся системных сервисов;
- multi-monitor не создаёт лишние сервисы;
- редко используемый UI создаётся лениво;
- polling минимизирован;
- отсутствуют бесконечные timers без причины;
- idle CPU близок к нулю;
- memory usage стабильно;
- отсутствует постоянный рост RSS/PSS;
- структура проекта понятна;
- Theme/Motion централизованы;
- UI не связан напрямую с shell-командами без необходимости;
- визуальное поведение не ухудшилось;
- пользовательские функции сохранились.

---

# 33. Что не является целью

Рефакторинг не должен превращаться в соревнование:

> «кто сделает Shell на 20 MB».

QtQuick имеет собственную базовую стоимость.

Aerix должен быть лёгким, но не ценой:

- ужасного кода;
- отсутствия кеширования вообще;
- постоянной перезагрузки интерфейса;
- сломанных анимаций;
- задержек открытия;
- сложной поддержки.

Нам нужен баланс.

---

# 34. Принцип Aerix

Для каждого компонента:

> **Постоянно загружено только то, что постоянно необходимо.**

Для каждого системного источника:

> **Одно состояние — один источник истины.**

Для каждого фонового действия:

> **Событие лучше опроса.**

Для всей оболочки:

> **Один Shell, множество компонентов.**

И самое главное:

> **Idle должен действительно означать idle.**

---

# 35. Краткая инструкция агенту

При рефакторинге Aerix Shell:

1. Не запускай отдельный Quickshell для каждого виджета.
2. Сохраняй один главный instance.
3. Разноси интерфейс по QML-файлам.
4. Выноси системную логику в общие services.
5. Не создавай service внутри monitor delegate.
6. Используй lazy loading для тяжёлого UI.
7. Не считай `visible: false` lazy loading.
8. Минимизируй `Process`.
9. Используй event APIs вместо polling.
10. Проверяй каждый Timer.
11. Следи за lifecycle динамических объектов.
12. Не держи огромные изображения без причины.
13. Централизуй Theme, Metrics и Motion.
14. Измеряй RSS/PSS до и после изменений.
15. Проверяй стабильность памяти несколько часов.
16. Не заявляй об оптимизации без измерений.
17. Не усложняй архитектуру ради архитектуры.
18. Не ухудшай UX ради нескольких мегабайт RAM.

**Цель:** цельная, быстрая и стабильная оболочка, которая может работать сутками без деградации.

**Aerix — Effortlessly modern.**
