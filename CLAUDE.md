# Cyberpunk 2077 RedScript Mod - Adaptive Traffic Headlights

## Project Overview

This is a Cyberpunk 2077 mod that gives crowd-vehicle headlights time-of-day and weather-aware colors and on/off behavior, and can optionally force city street lights on/off in sync. It is a redscript-native rewrite of the original CET (Cyber Engine Tweaks) Lua mod, whose source lives under `bin/x64/plugins/cyber_engine_tweaks/mods/AdaptiveTrafficHeadlights/` in this same repo (kept for reference only — not built or deployed by anything here).

The rewrite exists because five utility mods now cover everything CET/Lua used to provide for this mod: settings UI, JSON persistence, and logging. See Dependencies below.

## File Structure

- `r6/scripts/AdaptiveTrafficHeadlights/` - RedScript source files (module `AdaptiveTrafficHeadlights`, classes prefixed `ATH_`)
- `bin/` - the old CET Lua mod, reference only, not part of the build

## Dependencies (hard requirements)

- RED4ext, Redscript, Codeware
- RedFileSystem, RedData - JSON persistence for scalar settings / headlight colors / vehicle categories / weather-state times
- RedWindows - the in-game live editor for all settings: scalar toggles/sliders, the headlight color palette, and per-weather-state time list
- RedscriptConfigFramework (DVRCF) - not used directly by this mod's code; kept as a hard dependency only because RedWindows itself hard-requires it
- RedLogger - per-session log file, via the `ATHLog` wrapper in `Logging.reds`

All are treated as hard dependencies (no `@if(ModuleExists(...))` guards) - this mirrors how RedWindows and RedscriptConfigFramework already hard-require each other and Codeware, and keeps the code simple for what is a personal/small-audience mod.

Real source for these mods (read before assuming an API - do not guess):
- `Z:\GOG\Cyberpunk 2077\r6\scripts\RedWindows\*.reds`
- `Z:\GOG\Cyberpunk 2077\r6\scripts\RedLogger\RedLogger.reds`
- `Z:\GOG\Cyberpunk 2077\r6\scripts\RedFileSystem\RedFileSystem.reds`
- `Z:\GOG\Cyberpunk 2077\r6\scripts\RedData\RedData.Json.reds`
- `Z:\GOG\Cyberpunk 2077\r6\scripts\RedscriptConfigFramework\DVRCF_*.reds`
- `Z:\GOG\Cyberpunk 2077\r6\storages\RedscriptConfigFramework\*.docs.txt` - prose docs/changelog for each of the above
- `Z:\GOG\Cyberpunk 2077\red4ext\plugins\Codeware\Scripts\Codeware.Global.reds` - Codeware's `@addMethod` extensions to native classes, e.g. `WeatherSystem.GetWeatherState()`/`GetEnvironmentDefinition()`, which the base game's redscript surface does not expose on its own
- raw decompiled source dump for base-game API reference: `E:\Tools\mods\cp77\redscript\source`

## Code Style & Conventions

### RedScript (.reds files)

- Use PascalCase for class names and public methods
- Use camelCase for variables and private methods
- Use m_varName for private/protected class fields
- Follow RedScript naming conventions for game API calls
- raw source dumps for api reference: E:\Tools\mods\cp77\redscript\source

### Delay system

Same pattern as this repo's sibling project (`Reinforcements_GangVsGang`) - used to throttle or defer work, via the native `DelaySystem` class and `DelayCallback` handlers:

```
public class ATH_SomeCallback extends DelayCallback {
    let handler: wref<ATH_LightController>;

    public static func Create(handler: ref<ATH_LightController>) -> ref<ATH_SomeCallback> {
        let self: ref<ATH_SomeCallback> = new ATH_SomeCallback();
        self.handler = handler;
        return self;
    }

    public func Call() -> Void {
        this.handler.SomeCallback();
    }
}
```

```
let delay: Float = 10.0; // seconds
GameInstance.GetDelaySystem(gi).DelayCallback(ATH_SomeCallback.Create(this), delay, false);
```

A recurring tick (replacing the old Lua `Cron.Every`) is a `DelayCallback` whose `Call()` re-registers itself with the same delay.

### Logging

- Logging always uses the `ATHLog` function from `Logging.reds` (wraps `RedLogger.LogInfo`/`LogWarn`).
- Never prefix log call strings, this is already done by the wrapper function.
- Use string interpolation e.g. `ATHLog(s"my random log message \(someVar)")`

### Settings

All settings - scalar toggles/sliders (`Settings.reds`), the headlight color palette and per-weather-state on/off times (`Data.reds` / `WeatherStateData.reds`) - are edited live through the single `ColorEditorWindow.reds` RedWindows panel ("Settings" / "Headlights" / "Weather States" tabs) and persisted via RedFileSystem+RedData JSON. There is no DVRCF-driven UI in this mod; each settings class owns its own `Load()`/`Save()`/`Defaults()` following the same pattern (see `ATH_Settings` in `Settings.reds` or `ATH_ColorData` in `Data.reds`).

## Notes

- This mod modifies game behavior at runtime.
- Be careful with game API calls to avoid crashes.
- PERFORMANCE IS KING

## Deployment target

Z:\\GOG\\Cyberpunk 2077

- game root contains the r6 folder, where these files can be deposited without special steps.

## Command: "deploy and launch"

When the user says "deploy and launch" (or equivalent), run this immediately, with no confirmation prompt and no re-derivation of what it does — this is standing pre-authorization:

```
node deploy.js && node launch.js
```

- `deploy.js` deletes `r6/scripts/AdaptiveTrafficHeadlights` under the deployment target, then copies the entire local `./r6` folder over the target's `r6` folder (this also overwrites any non-mod files under the target's `r6/`, not just this mod's subfolders). It deliberately does NOT delete `r6/storages/AdaptiveTrafficHeadlights` — that holds persisted settings/color/weather-state JSON and must survive redeploys.
- `launch.js` starts Cyberpunk 2077 via its shortcut, fire-and-forget (no wait for the game to actually launch).
- Pre-authorization covers only this exact two-step command as documented here. Any variation (different target, different scope, force-push-style destructive ops elsewhere) still needs explicit confirmation per the general safety rules above.

## Command: "pack"

When the user says "pack" (or equivalent), run this immediately, with no confirmation prompt and no re-derivation of what it does — this is standing pre-authorization:

```
node pack.js
```

- Deletes the local `./r6.zip` if it exists, then zips the entire local `./r6` folder into `./r6.zip` via `7z`.
- Only touches the local `r6.zip` build artifact — does not touch the deployment target or the game.
