# Project: «Шагающий дом» (Walking House) 2D Godot 4 Showcase Game

## Architecture
- **Engine**: Godot 4.7.2 stable (`gl_compatibility` renderer, viewport 1280x720, resizable canvas_items).
- **Core Pattern**: Decoupled Model-View-Controller architecture.
  - **Model (`scripts/core/SimulationLogic.gd`, `scripts/core/BalanceConfig.gd`)**: Pure static methods, deterministic math formulas, state machines, and progression rules. Zero node dependencies, 100% headlessly testable.
  - **State Store (`scripts/autoload/GameState.gd`)**: Global reactive singleton managing game runtime state (resources, house durability, temperatures, player health, upgrades, distance, weather).
  - **Event Bus (`scripts/autoload/EventBus.gd`)**: Global decoupled signal dispatch (resource_collected, house_moved, stove_toggled, blizzard_warning, blizzard_started, blizzard_ended, upgrade_purchased, player_embarked, player_disembarked, deadlock_detected, game_won, game_over).
  - **Audio Engine (`scripts/autoload/SoundManager.gd`)**: Pure procedural 16-bit PCM waveform synthesis (`AudioStreamWAV`) for ambient wind, steps, engine, stove, UI, and alarms without external audio files.
  - **Entities & World**: `WalkingHouse.gd` (procedural vector cabin, hydraulic legs with inverse kinematics, hull sway, lights, particles), `Player.gd` (outside locomotion, cold exposure, interaction detection), `BiomeManager.gd` (5 distinct biomes, POI container, deterministic resource placement), `ParallaxBackground` (4 procedural parallax layers).
  - **UI Layer (`scripts/ui/`)**: Russian-localized HUD, MainMenu, PauseMenu, UpgradePanel, GameOverScreen, VictoryScreen, TutorialOverlay.

## Feature Inventory
| # | Feature | Description | Milestone | Source |
|---|---------|-------------|-----------|--------|
| 1 | Главное меню (Main Menu) | Стартовый экран с кнопками начала игры, инструкций и выхода | M5 | spec_miner F01 |
| 2 | Сброс состояния при перезапуске (State Reset) | Очистка всех параметров GameState при начале новой игры | M1, M5 | spec_miner F02 |
| 3 | Меню паузы (Pause Menu) | Приостановка физики и таймеров игры с меню настроек и возврата (Esc) | M5 | spec_miner F03 |
| 4 | Экран победы (Victory Screen) | Экран завершения при достижении конечной станции (5000 м) со статистикой | M5 | spec_miner F04 |
| 5 | Экран поражения от переохлаждения (Freeze Defeat) | Экран окончания игры при падении здоровья персонажа до 0 | M4, M5 | spec_miner F05 |
| 6 | Экран поражения от тупика (Deadlock Defeat) | Экран поражения при полной невозможности продолжить путь | M4, M5 | spec_miner F06 |
| 7 | Экран итоговой статистики (Stats Screen) | Сводные метрики забега: время, собранные ресурсы, расход, ремонт | M5 | spec_miner F07 |
| 8 | Управление домом (House Movement A/D) | Перемещение дома влево и вправо по горизонтальной оси | M2 | spec_miner F08 |
| 9 | Расход топлива при движении (Locomotive Fuel Burn) | Сжигание топлива пропорционально времени активного перемещения | M1, M2 | spec_miner F09 |
| 10 | Механический износ ног (Leg Wear) | Постепенная потеря прочности механических опор при ходьбе | M1, M2 | spec_miner F10 |
| 11 | Кривая деградации скорости (Speed Degradation) | Снижение максимальной скорости передвижения по мере износа ног | M1, M2 | spec_miner F11 |
| 12 | Критическая остановка при поломке (Critical Leg Failure) | Полная блокировка движения дома при разрушении ног (0% прочности) | M1, M2 | spec_miner F12 |
| 13 | Визуальное покачивание корпуса (Hull Sway Animation) | Процедурное колебание кабины и суставов ног при ходьбе | M2 | spec_miner F13 |
| 14 | Частицы снега из-под ног (Footstep Snow Particles) | Выброс снежной пыли при касании опорой поверхности земли | M2 | spec_miner F14 |
| 15 | Следы ног на снегу (Footstep Snow Tracks) | Оставление следов/вмятин в снегу в точках опоры ног | M2 | spec_miner F15 |
| 16 | Индикатор пройденной дистанции (Traversed Distance HUD) | Отображение текущего пройденного расстояния от старта | M2, M5 | spec_miner F16 |
| 17 | Индикатор дистанции до станции (Distance to Station HUD) | Отображение оставшегося расстояния до конечной станции | M2, M5 | spec_miner F17 |
| 18 | Выход наружу / Посадка (Embark/Disembark) | Переключение активного режима между домом и персонажем (клавиша E) | M3 | spec_miner F18 |
| 19 | Блокировка выхода на ходу (Exit Lockout while Moving) | Невозможность покинуть дом, пока он продолжает движение | M3 | spec_miner F19 |
| 20 | Управление персонажем снаружи (Outside Locomotion) | Перемещение персонажа пешком влево/вправо по снегу | M3 | spec_miner F20 |
| 21 | Детекция интерактивных объектов (Proximity Detection) | Обнаружение близлежащих ящиков, механизмов и лагерей через Area2D | M3 | spec_miner F21 |
| 22 | Контекстные подсказки взаимодействия (Context Prompts) | Текстовые подсказки на русском над интерактивными объектами | M3 | spec_miner F22 |
| 23 | Урон от сильного холода снаружи (Outside Freezing Damage) | Постепенное снижение здоровья при длительном нахождении на морозе | M1, M3 | spec_miner F23 |
| 24 | Безопасный радиус удаления (Safe Tether Radius) | Ограничение или предупреждение о критическом удалении от дома (45 м) | M3 | spec_miner F24 |
| 25 | Возвращение в дом (Re-entering House) | Вход персонажа обратно в кабину шагающего дома | M3 | spec_miner F25 |
| 26 | Сбор топлива (Fuel Collection) | Пополнение запаса топлива при обыске канистр и цистерн | M1, M3 | spec_miner F26 |
| 27 | Сбор металлолома (Scrap Metal Collection) | Пополнение запаса металлолома при разборе техники | M1, M3 | spec_miner F27 |
| 28 | Сбор припасов (Supplies Collection) | Пополнение запаса припасов из палаток и ящиков | M1, M3 | spec_miner F28 |
| 29 | Интерактивный ящик (Crate Object) | Деревянный/металлический контейнер с ресурсами | M3 | spec_miner F29 |
| 30 | Брошенная техника (Abandoned Machinery) | Остатки снегоходов, тягачей и генераторов | M3 | spec_miner F30 |
| 31 | Остатки лагеря (Camp Remnants) | Брошенные палатки, бочки и кострища исследователей | M3 | spec_miner F31 |
| 32 | Ремонт ног за металлолом (Leg Repair Station) | Расходование металлолома для восстановления опор дома | M1, M4 | spec_miner F32 |
| 33 | Улучшение: Утепление (Insulation Upgrade) | Снижение скорости естественного остывания кабины дома на 35% | M1, M4 | spec_miner F33 |
| 34 | Улучшение: Экономичный двигатель (Efficient Engine) | Снижение расхода топлива двигателем при ходьбе на 25% | M1, M4 | spec_miner F34 |
| 35 | Улучшение: Усиленные ноги (Reinforced Legs) | Замедление механического износа ног при перемещении на 30% | M1, M4 | spec_miner F35 |
| 36 | Интерфейс улучшений (Upgrade UI) | Панель в кабине: список улучшений, цена, эффект, статус покупки | M4, M5 | spec_miner F36 |
| 37 | Детерминированный баланс маршрута (Deterministic Route) | Расчетное размещение ресурсов гарантирует прохождение без RNG | M1, M3 | spec_miner F37 |
| 38 | Внутренняя температура кабины (Cabin Temperature) | Термодинамическая модель температуры воздуха внутри дома | M1, M4 | spec_miner F38 |
| 39 | Переключатель печи (Stove Toggle On/Off) | Ручное включение и выключение отопительной печи (клавиша F / UI) | M1, M4 | spec_miner F39 |
| 40 | Расход топлива печью (Stove Fuel Consumption) | Сжигание топлива при активной печи | M1, M4 | spec_miner F40 |
| 41 | Автоматическое отключение печи (Stove Auto-Cutoff) | Затухание печи при падении запаса топлива до 0 | M1, M4 | spec_miner F41 |
| 42 | Смена дня и ночи (Day/Night Cycle) | Циклическое изменение освещения мира и внешней температуры | M4 | spec_miner F42 |
| 43 | Динамическая метель (Dynamic Blizzard Event) | Периодическое ухудшение погоды: ветер, падение температуры, рост теплопотерь | M4 | spec_miner F43 |
| 44 | Предварительное предупреждение о метели (Blizzard Warning) | Сигнал игроку о приближающейся метели за 20 секунд | M4 | spec_miner F44 |
| 45 | Урон персонажу от переохлаждения в кабине (Cabin Freezing Damage) | Потеря здоровья при падении температуры кабины ниже 0°C | M1, M4 | spec_miner F45 |
| 46 | Восстановление здоровья в тепле (Warmth Health Recovery) | Стабилизация и медленное лечение персонажа в теплой кабине | M1, M4 | spec_miner F46 |
| 47 | Детектор безвыходного тупика (Deadlock Detection Engine) | Проверка невозможности движения при 0 ресурсов рядом (без ложных тревог) | M1, M4 | spec_miner F47 |
| 48 | 5 различимых биомов (5 Distinct Biomes) | Равнина, Лагерь, Техника, Лес, Станция (по 1000 м каждый) | M3 | spec_miner F48 |
| 49 | Параллакс-фон (Parallax Background) | 4-слойный процедурный скроллинг неба, гор, леса и дюн | M3 | spec_miner F49 |
| 50 | Встроенная стилизация без внешних ассетов (Godot-Native Art) | Процедурная векторная графика, полигоны, градиенты, StyleBox | M2, M3 | spec_miner F50 |
| 51 | Освещение и свечение (Window/Stove Glow) | Мягкое свечение окон дома и топки печи через PointLight2D | M2, M4 | spec_miner F51 |
| 52 | Синтезированный звук и громкость (Audio Engine & Sliders) | Процедурный PCM-звук шагов, ветра, печи, сирены и регуляторы в меню | M1, M5 | spec_miner F52 |
| 53 | Полный русский интерфейс и приборная панель (Russian HUD) | Приборы и надписи на 100% русском языке | M2, M5 | spec_miner F53 |
| 54 | Стартовое обучение (Tutorial Overlay) | Информационная панель с базовым управлением при старте игры | M5 | spec_miner F54 |
| 55 | Автоматизированный скрипт верификации (Headless Verifier) | Набор тестов формул и логики игры через godot --headless | M1, M6 | spec_miner F55 |

## Milestones
| # | Name | Scope | Dependencies | Status |
|---|------|-------|-------------|--------|
| M1 | M1_CORE_SIMULATION_PROJECT | Project config (`project.godot`), input mapping, Autoloads (`GameState.gd`, `EventBus.gd`, `SoundManager.gd`), pure models (`SimulationLogic.gd`, `BalanceConfig.gd`), and initial headless verification test runner | none | DONE |
| M2 | M2_WALKING_HOUSE_LOCOMOTION | WalkingHouse entity (`WalkingHouse.tscn`), procedural vector drawing, hydraulic articulated legs, hull sway, snow particle footfalls, foot tracks, movement controls, fuel/durability consumption, speed degradation curve, critical stop, and core HUD gauges | M1 | DONE |
| M3 | M3_PLAYER_EXPLORATION_WORLD | World layout (5 biomes, 5000 m route, deterministic POIs), 4-layer parallax background, Player entity (`Player.tscn`), embark/disembark cycle, outside movement, interactable detection, context prompts, resource collection (fuel, scrap, supplies), safe tether radius, outside freezing damage | M1, M2 | PLANNED |
| M4 | M4_THERMODYNAMICS_WEATHER_UPGRADES_SURVIVAL | Stove toggle and fuel burn, cabin cooling thermodynamics, inside freezing damage & warming recovery, Day/Night cycle, dynamic Blizzard event with advance warning, Leg repair station, Upgrade system (Insulation, Efficient Engine, Reinforced Legs), and Deadlock Detection Engine (zero false positives) | M1, M2, M3 | PLANNED |
| M5 | M5_UI_AUDIO_GAMEPLAY_LOOP | Complete UI flow (MainMenu, PauseMenu, GameOver, Victory, TutorialOverlay, Settings with volume sliders), procedural PCM audio synthesis for all SFX and ambient loops, GameState clean reset on restart, 100% Russian localization review | M1, M2, M3, M4 | PLANNED |
| M6 | M6_FINAL_E2E_VERIFICATION_HARDENING | Phase 1: Pass 100% of E2E test suite published in TEST_READY.md. Phase 2: Adversarial coverage hardening with Challenger (Tier 5), README documentation, and final readiness audit | M1, M2, M3, M4, M5, E2E_TESTING_TRACK | PLANNED |

## Interface Contracts

### SimulationLogic.gd ↔ GameState.gd
```gdscript
# Static pure functions in SimulationLogic:
static func calculate_speed(base_speed: float, durability: float, max_durability: float) -> float
static func calculate_fuel_consumption(is_moving: bool, has_engine_upgrade: bool, delta: float) -> float
static func calculate_leg_wear(is_moving: bool, has_legs_upgrade: bool, delta: float) -> float
static func calculate_cabin_temperature(current_temp: float, outside_temp: float, stove_on: bool, has_insulation: bool, is_blizzard: bool, delta: float) -> float
static func calculate_stove_fuel(stove_on: bool, delta: float) -> float
static func calculate_player_outside_exposure(delta: float, dist_from_house: float, safe_radius: float) -> float
static func check_deadlock_condition(fuel: float, leg_durability: float, scrap: float, min_repair_cost: float, reachable_fuel: float, reachable_scrap: float, is_player_outside: bool) -> bool
static func apply_repair(current_durability: float, scrap_available: float) -> Dictionary # {new_durability: float, scrap_spent: float}
static func can_afford_upgrade(upgrade_type: String, scrap: float, supplies: float) -> bool
```

### EventBus.gd ↔ Subsystems
```gdscript
signal house_moved(distance_delta: float, total_distance: float)
signal house_speed_changed(new_speed: float)
signal fuel_changed(current: float, max_val: float)
signal leg_durability_changed(current: float, max_val: float)
signal scrap_changed(current: float)
signal supplies_changed(current: float)
signal cabin_temperature_changed(temp: float)
signal player_health_changed(hp: float, max_hp: float)
signal stove_toggled(is_on: bool)
signal weather_changed(weather_state: int, ambient_temp: float)
signal blizzard_warning_triggered(seconds_left: float)
signal blizzard_started()
signal blizzard_ended()
signal player_embarked()
signal player_disembarked()
signal resource_looted(type: String, amount: float, world_pos: Vector2)
signal upgrade_unlocked(upgrade_id: String)
signal deadlock_detected()
signal victory_triggered(stats: Dictionary)
signal game_over_triggered(reason: String, stats: Dictionary)
```

### SoundManager.gd ↔ Game Systems
```gdscript
func play_sfx(sfx_name: String) # "step", "metal_clank", "loot", "stove_ignite", "stove_extinguish", "alarm", "click", "error"
func set_engine_hum(intensity: float) # 0.0 to 1.0
func set_wind_intensity(intensity: float) # 0.0 (calm) to 1.0 (blizzard)
func set_volume(bus_name: String, volume_linear: float)
```

## Code Layout
```
e:\project\
├── project.godot
├── README.md
├── scenes/
│   ├── Main.tscn
│   ├── world/
│   │   ├── World.tscn
│   │   ├── ParallaxBackground.tscn
│   │   └── POI.tscn
│   ├── entities/
│   │   ├── WalkingHouse.tscn
│   │   └── Player.tscn
│   └── ui/
│       ├── HUD.tscn
│       ├── MainMenu.tscn
│       ├── PauseMenu.tscn
│       ├── UpgradePanel.tscn
│       ├── GameOverScreen.tscn
│       └── VictoryScreen.tscn
├── scripts/
│   ├── autoload/
│   │   ├── GameState.gd
│   │   ├── EventBus.gd
│   │   └── SoundManager.gd
│   ├── core/
│   │   ├── SimulationLogic.gd
│   │   └── BalanceConfig.gd
│   ├── world/
│   │   ├── World.gd
│   │   ├── BiomeManager.gd
│   │   ├── WeatherManager.gd
│   │   └── POI.gd
│   ├── entities/
│   │   ├── WalkingHouse.gd
│   │   ├── HouseLegs.gd
│   │   └── Player.gd
│   └── ui/
│       ├── HUD.gd
│       ├── MainMenu.gd
│       ├── PauseMenu.gd
│       ├── UpgradePanel.gd
│       └── EndScreen.gd
└── tests/
    ├── test_runner.gd
    └── suites/
        ├── test_simulation_math.gd
        ├── test_thermodynamics.gd
        ├── test_upgrades_and_repairs.gd
        ├── test_deadlock_detection.gd
        ├── test_route_determinism.gd
        └── test_full_progression.gd
```
