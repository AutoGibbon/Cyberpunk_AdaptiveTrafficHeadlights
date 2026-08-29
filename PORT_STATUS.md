# Redscript Port Status

Working notes on the redscript rewrite of AdaptiveTrafficHeadlights (originally a CET/Lua
mod, source kept for reference under `bin/`). Written to give a fresh session full context
without re-deriving it. See `CLAUDE.md` for build commands and conventions.

## What this is

A time-of-day/weather-aware headlight color system for crowd vehicles, plus optional street
light control, ported from CET Lua to native redscript now that five utility mods cover what
CET used to provide: RedscriptConfigFramework (DVRCF), RedWindows, RedLogger, RedFileSystem,
RedData. All five are treated as hard dependencies, alongside Codeware.

## Status: implemented, not yet compiled or tested

Every file below has been written and is internally consistent, but nothing has gone through
the actual redscript compiler or the game yet - no `deploy.js`/`launch.js` run so far. See
"Open items" below for the specific things most likely to need a fix once it does compile.

## File inventory (`r6/scripts/adaptivetrafficheadlights/`)

- **Logging.reds** - `ATHLog`/`ATHLogWarn`, thin wrappers around DVRCF's `RedLogger` facade.
- **Data.reds** - headlight color palette, category mappings, and the ~450-entry vehicle list,
  ported verbatim from the Lua's `settings.lua` defaults. Vehicle matching uses cached
  `TweakDBID` comparisons (`ATH_VehicleCategory.Matches`), not string comparison. Only
  `headlightColors` is persisted/user-editable (`colorData.json` via RedFileSystem+RedData);
  category mappings are fixed content data.
- **WeatherStateData.reds** - discovers weather states at runtime via Codeware's
  `WeatherSystem.GetWeatherState()`/`GetEnvironmentDefinition()` extensions, keeps a persisted
  on/off time per state (`weatherStates.json`).
- **Settings.reds** - scalar settings (`ATH_Settings`), owned by `ATH_SettingsSystem`. Loaded/
  saved via its own RedFileSystem+RedData JSON file (`settings.json`), same pattern as
  `ATH_ColorData`/`ATH_WeatherStateData`. No DVRCF involvement - edited live via the "Settings"
  tab in `ColorEditorWindow.reds`, including a "Reset to Defaults" button.
- **LightLogic.reds** - `ATH_LightController extends ScriptableSystem`, the core light-decision
  state machine (replaces the Lua `S` globals table and its CalculateLightState/
  UpdateStreetLights/TryGetWeatherData/Update functions - ported near-verbatim, same math).
  Also owns two independent self-rescheduling `DelayCallback` loops:
  - `ATH_TickCallback`, 10s - light-decision logic (`OnTick` → `Update`), replacing the Lua's
    `Cron.Every(10.0, ...)`.
  - `ATH_EditorTickCallback`, 0.0333s (~30Hz, VehicleNavigationSystem uses the identical
    pattern at ~60Hz for its own RedWindows panel) - drives the RedWindows editor panel refresh
    (`OnEditorTick`), decoupled from the slower light-decision tick so slider edits don't lag.
- **VehicleLights.reds** - applies headlight/brake/blinker/utility light state to a vehicle.
  Hooked via `@wrapMethod(VehicleComponent) private final func OnGameAttach()` (see "Hook
  choice" below), delayed 0.1s via `ATH_ApplyLightsCallback` (matches the Lua's
  `Cron.After(0.1, ...)`, giving other mods time to finish appearance-cycling first).
- **WeatherOverrides.reds** - `@wrapMethod` on `WeatherScriptListener`/`CLSWeatherListener`'s
  `OnRainIntensityChanged`/`OnRainIntensityTypeChanged`, suppressing the base game's rain-driven
  forced light reactions once our own logic has taken over. See "Open items" for what was
  deliberately *not* wrapped here.
- **ColorEditorWindow.reds** - the single RedWindows live editor for everything: a "Settings"
  tab (all scalar toggles/sliders from `ATH_Settings`, plus "Reset to Defaults"), a "Headlights"
  tab (R/G/B/A sliders + preview-on-new-vehicles checkbox per color), and a "Weather States" tab
  (per-state on/off time sliders, current state labeled).

## Key design decisions

- **Everything through RedWindows, nothing through DVRCF**: originally scalar toggles/sliders
  went through a DVRCF schema+provider (`ATH_SettingsProvider`) while the headlight palette and
  per-weather-state times - dynamic/tabular data DVRCF's static schema can't express - got a
  hand-built RedWindows panel. Consolidated onto a single RedWindows "Settings" tab instead, so
  every setting lives in one place with one persistence pattern (`ATH_Settings.Load()/Save()`,
  same shape as `ATH_ColorData`/`ATH_WeatherStateData`). DVRCF remains a hard dependency only
  because RedWindows itself hard-requires it - this mod's own code no longer calls into DVRCF at
  all (`ATH_SettingsProvider`/`DVRCF.Register` removed from `Settings.reds`).
- **Hook choice - `VehicleComponent.OnGameAttach`, not `VehicleObject.OnGameAttached`**: the
  Lua mod hooked a CET-reflection-only class (`vehicleBaseObject`) that doesn't exist in
  redscript. Initially ported to `VehicleObject.OnGameAttached` (the closest public API), but
  corrected after comparing against two real, shipped mods doing the identical job for crowd
  vehicles - **Enhanced Vehicle System** and **NightCityTrafficOverhaul**'s
  `NCTOvehicleLights.reds` - both of which wrap `VehicleComponent.OnGameAttach` instead.
  `VehicleObject.OnGameAttached` fires at the entity's top-level attach point, which can precede
  the vehicle's own `VehicleComponent` (and its light controller) being ready;
  `VehicleComponent.OnGameAttach` is guaranteed to fire once that component itself has attached.
  This also empirically confirmed `@wrapMethod` works fine on a `private final func` (both real
  mods wrap exactly that), which had been a source of caution elsewhere (see Open items).
- **Environment readiness check**: the Lua mod gated on the environment resource path not
  containing "v002" (unless it also contains "nova_city_master", a fix already present in the
  live deployed Lua copy at `Z:\...\AdaptiveTrafficHeadlights\init.lua` but *not* in the stale
  project-source copy under `bin/` that the initial port was read from). That path-string check
  turned out to be inaccessible in redscript (`CResource.path` is not `public` - see Open items)
  and, on reflection, unnecessary here: it existed only because CET's Lua `onUpdate` hook runs
  even at the main menu with no real session loaded, so the Lua mod had no other way to tell a
  placeholder/pregame environment from a real one. This port's `OnPlayerAttach` hook only fires
  once a real game session has attached a player, so `LightLogic.reds` instead gates on
  `ArraySize(envDef.weatherStates) > 0`, which is both accessible and sufficient.
- **Custom `Wrap24` modulo helper**: the base game's native `ModF()` (core/math/scalar.script)
  returns 0 for any non-positive input, which would misbehave on the negative intermediate
  values this logic legitimately produces (e.g. around the `lastLightDecisionTime` sentinel of
  -1.0). `LightLogic.reds` implements its own floored modulo instead of using `ModF()`.
- **Everything is a hard dependency** - no `@if(ModuleExists(...))` guards, matching how DVRCF
  and RedWindows already hard-require each other and Codeware.

## Fixed by first in-game test (2026-08-29)

- **`FileSystem.GetStorage("AdaptiveTrafficHeadlights")` denied - wrong casing**: the very
  first real launch (after the `CResource.path` fix above let scripts compile) showed
  `Settings.reds`/`Data.reds`/`WeatherStateData.reds` all logging "exists but is not a JSON
  object/array" for files that don't actually exist on disk. `Z:\...\red4ext\logs\redfilesystem-*.log`
  had the real error: `Name of storage "AdaptiveTrafficHeadlights" is not allowed.` RedFileSystem
  validates the storage name against the mod's actual `r6/scripts/` folder name, case-sensitively
  (confirmed by comparing against `DigitalVixenCore`/`RedscriptConfigFramework`, both granted -
  their storage name strings match their PascalCase script folders exactly). At the time, this
  project's script folder was lowercase `adaptivetrafficheadlights` while all three
  `GetStorage()` calls passed `"AdaptiveTrafficHeadlights"`. Every storage call was therefore
  silently denied all session - `Exists()` came back as the enum's zero value
  (`FileSystemStatus.True`, a false positive), and `GetFile(...).ReadAsJson()`/`WriteJson(...)`
  on the denied handle came back undefined/no-op. Net effect: settings/color data were never
  read or written, and a hand-placed `weatherStates.json` in storages was never overwritten
  either (confirmed byte-for-byte intact via its unchanged mtime and a plain `JSON.parse`) even
  though the log claimed to discover and save 80 fresh states. Fixed by renaming the script
  folder itself to `r6/scripts/AdaptiveTrafficHeadlights` (PascalCase, matching every other
  mod's convention and the storage name already used in code) rather than lowercasing the
  storage name - see File Structure above. `Logging.reds`'s
  `RedLog.AppendLevel("AdaptiveTrafficHeadlights", ...)` calls needed no change - they already
  produced a working log file even before this fix, so RedLogger evidently doesn't enforce the
  same folder-name check.

## Open items (things worth a second look, not yet resolved by testing)

1. ~~**`CResource.path` field visibility**~~ - **Resolved**: confirmed at compile time that
   `path` is not accessible (bare `native let path: ResRef;` in Codeware's header, no `public`).
   `TryGetWeatherData` now gates readiness on `ArraySize(envDef.weatherStates) > 0` instead of
   the Lua mod's "v002"/"nova_city_master" path-string heuristic. That heuristic existed only
   because CET's `onUpdate` hook ran even at the main menu with no real session; this port's
   `OnPlayerAttach` hook only fires for a real, loaded game session, so a non-null envDef with
   populated weatherStates is already sufficient.
2. **`RandRange(min, max)` inclusivity** (`VehicleLights.reds`) - assumed inclusive on both
   ends for picking a random color/vehicle-category entry (no visible native body to confirm).
   If actually exclusive on the top end, the last item in a list just never gets picked - minor,
   not a crash risk.
3. **`CLSWeatherListener.TurnOnLights`/`TurnOffLights` not wrapped** (`WeatherOverrides.reds`) -
   the Lua mod wrapped these two `private final func` methods directly. We instead block their
   only caller (`OnRainIntensityTypeChanged`, confirmed via the decompiled source), reasoning
   that's equivalent. Now that `@wrapMethod` on `private final func` is confirmed safe (see Hook
   choice above), wrapping them directly is also a safe option if closer fidelity is wanted -
   just probably redundant.
4. **No live color swatch** in the Headlights editor tab - just sliders, no ColorEdit4-style
   preview box. RedWindows' `Shapes` API's rendering behavior for a plain 4-point square wasn't
   clear enough from the docs to trust (a 4-point shape is documented to render as a "bar along
   its spine", not necessarily a clean box).
5. **No teal highlight** on the current weather state in the Weather States tab - appends
   "(current)" to the label text instead, since there's no confirmed "reset to neutral" color
   for `RWPart.Fill` to un-highlight a state that's no longer current.
6. **No `OnRestored` callback** on `ATH_LightController` - session-reset relies solely on
   `OnPlayerAttach` (fires on every load/checkpoint). The sibling `Reinforcements_GangVsGang`
   project also implements `OnRestored` as a belt-and-suspenders fallback; worth adding if stale
   state is ever observed after loading a save without a fresh player spawn.
7. **No migration from the old CET JSON files** (`modsettings.json`, `weatherStateSettings.json`,
   `vehicleSettings.json`) - explicit non-goal, fresh defaults on first run.

## Not carried over from the Lua version (intentional)

- `TweakDB:SetFlat(...)` (writing the picked color back into the vehicle's TweakDB record) -
  not exposed anywhere in redscript's surface (base game or Codeware) that could be found.
  The visible light color/behavior is unaffected; this was a "make it stick" extra write.
- `autoResize`/`lockWindow`/`themeDisabled` settings - only existed to manage the old custom
  ImGui window, which the RedWindows editor now owns entirely.

## Next steps

1. `node deploy.js && node launch.js` to get a real compile pass and in-game test - not yet run
   (deliberately held off per explicit "no deploy or test yet" instruction).
2. Work through the Open items list above against whatever the compiler/game actually says.
