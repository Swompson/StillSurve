# Android performance

Ветка `codex/android`, релиз **StillSurve 0.0.2 preAlpha android**. ПК-ветка `main` не меняется. Название приложения и package ID сохранены: StillSurve, `org.stillsurve.game`.

## Выбор отрисовщика

Redmi Note 10S (Android 13) сообщает `android.hardware.vulkan.version=4198400`, то есть Vulkan 1.1.0. Godot Mobile использует RenderingDevice и по требованиям текущего движка рассчитан на Vulkan 1.2. На этом телефоне оставлен Compatibility / OpenGL ES, также используемый редактором Android-ветки. Это обоснование совместимости, а не сравнительный замер Mobile против Compatibility.

- https://docs.godotengine.org/en/stable/tutorials/rendering/renderers.html
- https://docs.godotengine.org/en/stable/about/system_requirements.html

## Изменения

- Viewport stretch вместо canvas_items: основная высота рендера 720, пропорции экрана сохраняются через expand. На экране 2400×1080 внутренний кадр получается примерно 1600×720: на 56% меньше пикселей. Это снижение нагрузки на GPU, а не обещание такого же прироста FPS. Интерфейс масштабируется вместе с кадром.
- Текстура теней светильников на Android создаётся сразу в RHalf, который поддерживается GPU. Убрана выявленная на устройстве автоматическая конверсия RFloat → RHalf; геометрия и общий звуковой тракт сохранены.
- На Android лимитер FPS использует события приложения (pause/resume, focus-out/focus-in), а не опрос фокуса настольных окон. Касание также возвращает обычный лимит, чтобы игра не оставалась на фоновых 15 FPS после потери фокуса.
- Публикуемая APK собирается с `tools/build_android.ps1 -Release`, без отладочного движка. Для обновления на устройстве сохраняется прежний локальный тестовый сертификат.

## Проверка

Пройдены android_frame_budget_regression, frame_limit_regression, mobile_layout_settings_regression, patrol_mobile_regression, pause_settings_regression, gameplay_smoke и mounted_fixture_strategies_regression.

`tests/mobile_renderer_benchmark.tscn` воспроизводит фиксированную сцену и печатает медиану и p95 времени кадра для native_canvas и viewport_720. Для запуска на телефоне временно укажите её главной сценой и уберите исключение tests из диагностического профиля экспорта. После замера восстановите обычную главную сцену и исключения. Сравнение требует открытой игры на разблокированном телефоне; фоновые измерения недействительны. Пока завершённого замера на устройстве нет, прирост FPS количественно не подтверждён.
