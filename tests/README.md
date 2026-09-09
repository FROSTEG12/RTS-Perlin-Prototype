# Автоматические проверки

Это регрессионные проверки систем, не режимы игры. Одноразовые визуальные
диагностики, старые модельные проверки и боевые стресс-стенды удалены.

Запуск из корня, где GODOT — путь к исполняемому файлу Godot:

```
GODOT --headless --editor --import --quit
GODOT --headless --path . --script tests/world_smoke_test.gd
GODOT --headless --path . --script tests/weather_model_test.gd
```

Остальные сохранённые проверки: weather_frequency, forest_generation,
trail_wear, waterfall_boundary, camera_bounds, knight_gait_phase, knight_resources.
Каждая запускается аналогично с суффиксом `_test.gd`.
Ищите маркер PASS, а не только нулевой код возврата: ошибка assert в SceneTree
может оставить процесс живым. World smoke проверяет 10 рыцарей, движение,
выделение, пересоздание карты и отсутствие тестовых боевых/строительных узлов.
