# TEST_READY.md — Сводный отчёт готовности тестовой инфраструктуры
**Проект**: «Шагающий дом» (Walking House) 2D Godot 4 Showcase Game  
**Статус**: COMPLETE (Все тестовые наборы и раннер верифицированы и пройдены на 100%)  
**Дата верификации**: 2026-11-04  
**Исполняемая среда**: Godot 4.7.2 stable (`godot --headless`)  
**Рабочая директория**: `E:\project\`

---

## 1. Сводка архитектуры тестирования

В проекте развёрнута двухуровневая архитектура автоматизированного тестирования (Dual Track: Category-Partition, BVA, Pairwise, Adversarial & Forensic Analysis):

### Track 1: Основной E2E-раннер (`test_runner.gd`)
* **10 тестовых сьютов**, **93 автоматических теста** (100% PASS).
* Покрывает кинематику дома, расход топлива, износ ног, термодинамику печи, смену биомов, сбор ресурсов, логику дедлоков, верстак улучшений и жизненный цикл UI.

| # | Сьют | Описание | Результат |
|---|---|---|---|
| 1 | `test_locomotion.gd` | Движение дома, расход топлива, износ ног, IK-кинематика шасси | 13/13 PASS |
| 2 | `test_exploration.gd` | Скорость исследователя, 45м радиус, гипотермия, буран | 7/7 PASS |
| 3 | `test_economy_repairs.gd` | Ремонт за металлолом, проверка стоимости и покупка улучшений | 9/9 PASS |
| 4 | `test_thermodynamics_weather.gd` | Остывание кабины, прогрев печью, расход топлива, автоотключение | 8/8 PASS |
| 5 | `test_deadlock_detection.gd` | Детекция дедлока, отсутствие ложных срабатываний, гистерезис | 8/8 PASS |
| 6 | `test_full_progression.gd` | Полные сценарии забегов: базовый (5000м), с улучшениями, кризис | 5/5 PASS |
| 7 | `test_challenger_adversarial.gd` | Стресс-тестирование границ, численные инварианты, сброс состояния | 8/8 PASS |
| 8 | `test_m3_player_world.gd` | Сущность игрока, посадка/высадка, 5 биомов, 30 детерминированных узлов | 12/12 PASS |
| 9 | `test_m4_thermo_weather_upgrades.gd` | Суточный цикл, модуляция освещения, предупреждение бурана | 13/13 PASS |
| 10 | `test_m5_menus_lifecycle.gd` | Главное меню, пауза, экран победы/поражения, интеграция мира | 10/10 PASS |

### Track 2: Standalone Adversarial & Forensic Suites (14 сьютов)
* 14 специализированных тестовых точек входа, проверяющих граничные условия и устойчивость:
  - `test_simulation_math.gd` (10 тестов: чистые математические модели симуляции)
  - `test_adversarial_stress.gd` (числовой стресс-тест)
  - `test_adversarial_gamestate_reactivity.gd` (реактивность шины и состояния)
  - `test_adversarial_m2_challenger.gd` (кинематика ходьбы и деградация)
  - `test_adversarial_m3_biome_interpolation.gd` (гладкая Hermite-интерполяция биомов)
  - `test_adversarial_m3_challenger_r2.gd` (граничные тесты сбора ресурсов)
  - `test_adversarial_m3_challenger.gd` (14 тестов, 126 ассертов: физический трос 50м, блокировка выхода)
  - `test_adversarial_m3_r2.gd` (палитра и освещение)
  - `test_adversarial_thermo_deadlock.gd` (тепловые дедлоки)
  - `test_balance_sound.gd` (проверка синтезатора звука и баланса)
  - `test_forensic_m3_auditor.gd` (аудит сцен и коллизий мира)
  - `test_m2_challenger_adversarial.gd` (деградация опор и стоп-факторы)
  - `test_m2_locomotion_hud.gd` (интеграция приборов HUD с движением)
  - `test_m3_challenger_adversarial.gd` (баланс 30 точек POI и детерминизм)

---

## 2. Команды запуска

### Полный прогон всех тестов (Track 1 + Track 2)
```powershell
pwsh -File tests/run_tests.ps1
```

### Запуск Track 1 через Godot Headless
```powershell
godot --headless --path . -s res://tests/test_runner.gd
```

### Результат прогона
```
==========================================================================
  TEST RUN SUMMARY: 15 PASSED, 0 FAILED
==========================================================================
```
Все тесты (10 сьютов Track 1 + 14 сьютов Track 2) завершаются с кодом возврата 0.
