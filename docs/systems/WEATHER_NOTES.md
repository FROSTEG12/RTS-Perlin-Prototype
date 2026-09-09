> Технические заметки предыдущих этапов. Игровые тестовые режимы удалены;
> текущее состояние описано в README.md и docs/ARCHITECTURE.md проекта.

# Weather prototype, 2026-09-07

## Safe baseline

Accepted pre-weather appearance is committed as `3c2d0b6`, tag
`checkpoint-waterfalls-before-weather-20260907`. The weather stage is separate
from that checkpoint. No automatic rollback or reset is performed.

## Reference and implementation

The supplied Project Zomboid image was used for low, uneven banks, readable
treetops/roofs, drifting wisps and a soft player-centered clearing. This is an
original implementation for our orthographic 3D world, not PZ source code.

Sources consulted:

- PZ's developer description of the constant player visibility radius:
  https://projectzomboid.com/blog/news/2018/07/zombies-in-the-mist/
- PZ's documented fog controls (height, second layer, alpha circle):
  https://www.projectzomboid.com/modding/zombie/iso/weather/fog/ImprovedFog.html
- Godot GPU rain and roof/terrain collision:
  https://docs.godotengine.org/en/stable/classes/class_gpuparticlescollisionheightfield3d.html
  https://docs.godotengine.org/en/stable/classes/class_particleprocessmaterial.html
- Godot inverse-projection depth reconstruction:
  https://docs.godotengine.org/en/stable/tutorials/shaders/advanced_postprocessing.html
- NWS: wet ground, overnight cooling and light winds favor radiation fog;
  rain does not guarantee fog the following morning:
  https://www.weather.gov/safety/fog-radiation
  https://www.weather.gov/source/zhu/ZHU_Training_Page/fog_stuff/forecasting_fog/RADIATION_ADVECTION_FOG.html

## Controls

- **Автопогода**: seeded clear/clouding/rain/clearing fronts. Storms are not tied
  to a day/night gate. Durations use game hours, not wall-clock hours.
  Front arrivals are sampled once: clear gaps are 18–42 game hours in a dry
  period and 3–9 hours in a wet period, followed by clouding/rain/clearing.
  Dry regimes last 24–72 hours and wet regimes 24–60 hours. Rain lasts 1.5–4
  hours (45–120 real seconds at normal speed). These are art-directed gameplay
  durations, not measured real-world climate data. Endless failed chance rolls
  and the mandatory 18–36 hour dry startup have been removed.
  Reset warms up 6–12 simulated days, including moisture/cloud/rain values,
  before exposing the climate. A new session can already be rainy, cloudy,
  clearing or dry. No special forced first rain; identical seeds remain
  deterministic. Fog uses the selected starting solar hour (default 08:00).
- **Дождь**: manual on/off; disables automatic fronts. Lighting and rainfall
  ease over several seconds, with clouds appearing before rain.
- **Туман: тест**: preview dense fog at any time, with a smooth transition.
  Turning this off restores the natural moisture/time/wind calculation.
- **К юниту**: center the view on the existing yellow test unit. Left click
  still moves it using the existing pathfinder. The fog clearing follows it.
- The time slider changes solar time, not elapsed storm duration or moisture.
  Its tooltip explicitly labels this as a lighting preview. The date is now
  shown as `День N`, beginning at 1 and advancing at natural midnight.
  `Время ×1/×3/×6` accelerates solar time, day rollover and weather clocks
  together, not unit movement or particle animation. Visual transitions still
  ease in real seconds. This is a prototype/test time control, not save support.
  To test naturally occurring post-rain fog, run rain, switch it off, move time
  to about 05:00–07:00, then allow the transition to settle.

## Technical boundaries

- `weather_model.gd`: simplified moisture/cooling model, not a temperature,
  pressure or dew-point simulation. Moisture persists after rain, wind and
  cloud cover suppress radiation fog, sunshine dissipates it. Midnight is
  continuous. Natural weather state currently lives in the running session.
- `weather_effects.gd`: multiplicative overcast applied AFTER resetting the
  original day/night lighting each frame. Original light orbit stays intact.
- `weather_fog.gdshader`: 20-sample low-height fog integration through the
  opaque scene depth. World-anchored noise; roofs/treetops naturally remain
  above banks. Fixed world-radius 4 + 3.2 feather reveal around the test unit.
  The inner radius is completely fog-free (no residual 8% density).
  This is a readability aid, not gameplay line-of-sight or fog of war. It
  does not reveal objects behind opaque walls. Forward+ reverse-Z path.
- `rain.gdshader`: narrow GPU drop ribbons, camera-area emission in world
  coordinates, depth tested, clipped below water and outside the map. A
  1024 heightfield stops drops at terrain/roofs; refreshes on world generation
  and house placement. Heightfields are not a cave/interior simulation.
- The accepted abyss mist and waterfalls remain unchanged. Weather banks
  fade softly beyond the map rim rather than replacing the abyss mist.
- No sound, puddle accumulation, lightning, seasons, snow or wet-material
  pass yet. No separate optimization phase or performance guarantee; bounded
  particles and a static collision map are implementation choices. Future
  moving roofs/terrain will need explicit heightfield invalidation.

## Verification

- `tests/weather_model_test.gd`: 20 deterministic days, bounds, rain at day
  and night, post-rain dawn fog, dry/windy suppression, midday burn-off,
  midnight continuity and test/manual overrides.
- `tests/weather_frequency_test.gd`: 2160 days, mean 0.7883 days/rain
  (~9.46 real minutes), 15.37% completely dry days, maximum start-to-start
  gap 47 game hours. Of 500 reset seeds, 74 already have visible rain and
  205 see rain within 3 real minutes. Median first-rain wait 3.875 minutes,
  p90 13.75, maximum 20.125. Long dry stretches remain possible, but there is
  no universal initial waiting period. Large/small front steps stay identical.
- `tests/weather_startup_clock_test.gd`: ×6 advances weather and date together,
  midnight rollover, lighting slider isolation, manual override freezes front
  scheduling, naturally rainy reset is immediately reflected in UI/particles.
- `tests/weather_visual_test.gd`: clear/rain/fog day/night captures, moving
  unit + pan/zoom, UI toggles, exact restoration of clear-day light energy.
  `-- --preview` leaves a playable rain preview open.
- Existing day/night orbit and camera bounds regression tests retained.

Generated screenshots/logs are in the current Codex task's `work` directory,
not in the game asset tree. Visual appearance still awaits user review.
