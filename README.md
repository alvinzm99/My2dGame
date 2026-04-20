# Last Camp Regions

Godot 4.6.2 top-down survival, building, and night-defense prototype.

The player builds a camp in one region, survives escalating night attacks, completes the region's construction and resource objectives, then moves to the next region for a stronger survival challenge.

## Controls

- `WASD`: move the camera
- Hold left mouse and drag: pan the camera
- Mouse wheel: zoom camera
- Left click survivor/building: select it
- Right click ground/resource/enemy: command selected survivor
- `1`: place wall
- `2`: place watchtower
- `3`: place shelter
- `H`: use food to heal the selected survivor
- Left click while placing: build if resources are available
- `Escape`: cancel building placement
- `N`: travel to the next region after objectives are complete

## Prototype Loop

Daytime is for gathering, building, healing, and expanding the camp inside the marked build area. Each region starts with a small walled camp and a basic watchtower, then the player expands from there. Wild zombies roam outside during the day and only attack when they get close to the camp, buildings, or survivors. Nighttime spawns larger zombie waves from all sides, with strength increasing by region and night. Towers rotate toward nearby zombies and fire automatically. Survivors use bows at range, switch to blades in melee, and can be commanded with right click.

## Code Structure

- `scripts/main.gd`: scene orchestration, current gameplay loop, UI, rendering, and command flow.
- `scripts/core/game_config.gd`: shared tuning values, building definitions, region goals, and resource colors.
- `scripts/core/entity_factory.gd`: creates survivor, zombie, building, and starting camp data.
- `scripts/systems/spatial_queries.gd`: selection hit tests and nearest-target queries.

This is the first refactor pass out of the single-script prototype. The next good split is moving survivor AI, zombie AI, building/tower logic, wave spawning, and HUD rendering into their own systems.

## Asset Credits

Zombie and survivor placeholder portraits are from [OpenMoji](https://openmoji.org/) and are licensed under [CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/). They are temporary prototype art and can be replaced later by original project assets.

## Git Notes

Godot executables are intentionally ignored. Commit the project files, scripts, and source assets only.
