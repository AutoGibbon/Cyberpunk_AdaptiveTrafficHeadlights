module AdaptiveTrafficHeadlights

import RedWindows.*

// Live RedWindows editor for all scalar settings, the headlight color
// palette, and per-weather-state on/off times - replacing both the DVRCF
// "Main" settings panel and the CET ImGui "Headlights"/per-state list tabs.
// Driven from ATH_LightController's ~10s tick - RedWindows is retained-mode,
// so redrawing this rarely is fine.
public abstract class ATH_ColorEditorWindow {

  // StringToName takes its argument by script_ref, which needs a named local -
  // routes every dynamic id through here rather than passing a string literal/
  // interpolation result inline.
  private static func NameFrom(str: String) -> CName {
    let local: String = str;
    return StringToName(local);
  }

  public static func Update(gi: GameInstance, controller: ref<ATH_LightController>) -> Void {
    if !IsDefined(controller) {
      return;
    }
    let win: ref<RWWindow> = RedWindowsAPI.Window(gi, n"AdaptiveTrafficHeadlights.Editor", "Adaptive Traffic Headlights");
    if !IsDefined(win) {
      return;
    }
    win.minW = 520.0;
    // Config/tuning UI, not a permanent HUD element - only rendered while the
    // player has the RedWindows overlay open (default F7), same as e.g.
    // VehicleNavigationSystem's "VNS.Tuner" settings window. Without this the
    // window (and its live values) would sit on screen at all times.
    win.SetOverlayOnly(true);
    if !win.IsVisible() {
      win.Show();
    }

    let tabLabels: array<String> = ["Settings", "Headlights", "Weather States"];
    let tab: Int32 = win.TabBar(n"tabs", tabLabels);
    if tab == 0 {
      ATH_ColorEditorWindow.DrawSettings(win, gi);
    } else if tab == 1 {
      ATH_ColorEditorWindow.DrawHeadlights(win, controller);
    } else {
      ATH_ColorEditorWindow.DrawWeatherStates(win, controller);
    }
  }

  private static func DrawSettings(win: ref<RWWindow>, gi: GameInstance) -> Void {
    let settingsSystem: ref<ATH_SettingsSystem> = ATH_SettingsSystem.GetInstance(gi);
    if !IsDefined(settingsSystem) {
      return;
    }
    let settings: ref<ATH_Settings> = settingsSystem.GetSettings();
    if !IsDefined(settings) {
      return;
    }

    win.Header(n"settings_behavior", "Behavior");

    let natId: CName = n"settings_naturalMode";
    let natural: Bool = win.Checkbox(natId, "Use Natural Mode", settings.useNaturalMode);
    win.Tip(natId, "Enables realistic lighting behavior: vehicles anticipate transitions and respond gradually, while street lights delay after weather changes");
    if win.Changed(natId) {
      settings.useNaturalMode = natural;
      settings.Save();
    }

    let streetId: CName = n"settings_streetLights";
    let streetLights: Bool = win.Checkbox(streetId, "Enable street light control", settings.enableStreetLightControl);
    if win.Changed(streetId) {
      settings.enableStreetLightControl = streetLights;
      settings.Save();
    }

    let brightId: CName = n"settings_offBrightness";
    let brightness: Float = win.SliderF(brightId, "Headlights 'Off' brightness (1.0 = full on)", 0.0, 1.0, settings.lightsOffBrightnessMultiplier, 0.05);
    if win.Changed(brightId) {
      settings.lightsOffBrightnessMultiplier = brightness;
      settings.Save();
    }

    let brakeId: CName = n"settings_brakeLights";
    let brake: Bool = win.Checkbox(brakeId, "Turn off brake lights", settings.turnOffBrakeLights);
    if win.Changed(brakeId) {
      settings.turnOffBrakeLights = brake;
      settings.Save();
    }

    let blinkId: CName = n"settings_blinkers";
    let blinkers: Bool = win.Checkbox(blinkId, "Turn off blinkers", settings.turnOffBlinkers);
    if win.Changed(blinkId) {
      settings.turnOffBlinkers = blinkers;
      settings.Save();
    }

    let utilId: CName = n"settings_utilityLights";
    let utility: Bool = win.Checkbox(utilId, "Turn off utility lights (neons, rims, etc)", settings.turnOffUtilityLights);
    if win.Changed(utilId) {
      settings.turnOffUtilityLights = utility;
      settings.Save();
    }

    win.Separator(n"settings_sep1");
    win.Header(n"settings_weatherTiming", "Weather State Timing");

    let adjustId: CName = n"settings_adjustAll";
    let adjustAll: Bool = win.Checkbox(adjustId, "Use same times for all weather states", settings.adjustAllWeatherStates);
    win.Tip(adjustId, "Per-state times can still be seen/edited in the Weather States tab; this overrides them with a single on/off time.");
    if win.Changed(adjustId) {
      settings.adjustAllWeatherStates = adjustAll;
      settings.Save();
    }

    let onId: CName = n"settings_allOn";
    let onTime: Float = win.SliderF(onId, "All States Turn On Time", 12.0, 20.0, settings.allOnTime, 0.5);
    if win.Changed(onId) {
      settings.allOnTime = onTime;
      settings.Save();
    }

    let offId: CName = n"settings_allOff";
    let offTime: Float = win.SliderF(offId, "All States Turn Off Time", 5.0, 12.0, settings.allOffTime, 0.5);
    if win.Changed(offId) {
      settings.allOffTime = offTime;
      settings.Save();
    }

    win.Separator(n"settings_sep2");
    if win.Button(n"settings_reset", "Reset to Defaults") {
      settings.CopyFrom(ATH_Settings.Defaults());
      settings.Save();
    }
  }

  private static func DrawHeadlights(win: ref<RWWindow>, controller: ref<ATH_LightController>) -> Void {
    let colorData: ref<ATH_ColorData> = controller.GetColorData();
    let previewName: String = controller.GetPreviewColorName();
    let i: Int32 = 0;
    while i < ArraySize(colorData.colors) {
      let c: ref<ATH_HeadlightColor> = colorData.colors[i];

      let headerId: CName = ATH_ColorEditorWindow.NameFrom(s"color_\(c.name)");
      win.Header(headerId, c.name);

      let redId: CName = ATH_ColorEditorWindow.NameFrom(s"color_\(c.name)_r");
      let red: Float = win.SliderF(redId, "Red", 0.0, 255.0, Cast<Float>(c.red), 1.0);
      let changed: Bool = win.Changed(redId);

      let greenId: CName = ATH_ColorEditorWindow.NameFrom(s"color_\(c.name)_g");
      let green: Float = win.SliderF(greenId, "Green", 0.0, 255.0, Cast<Float>(c.green), 1.0);
      changed = win.Changed(greenId) || changed;

      let blueId: CName = ATH_ColorEditorWindow.NameFrom(s"color_\(c.name)_b");
      let blue: Float = win.SliderF(blueId, "Blue", 0.0, 255.0, Cast<Float>(c.blue), 1.0);
      changed = win.Changed(blueId) || changed;

      let alphaId: CName = ATH_ColorEditorWindow.NameFrom(s"color_\(c.name)_a");
      let alpha: Float = win.SliderF(alphaId, "Brightness (alpha)", 0.0, 255.0, Cast<Float>(c.alpha), 1.0);
      changed = win.Changed(alphaId) || changed;

      if changed {
        c.red = Cast<Int32>(red);
        c.green = Cast<Int32>(green);
        c.blue = Cast<Int32>(blue);
        c.alpha = Cast<Int32>(alpha);
        colorData.Save();
      }

      let previewId: CName = ATH_ColorEditorWindow.NameFrom(s"color_\(c.name)_preview");
      let isChecked: Bool = win.Checkbox(previewId, "Preview on new vehicles", Equals(previewName, c.name));
      if win.Changed(previewId) {
        if isChecked {
          controller.SetPreviewColorName(c.name);
        } else if Equals(previewName, c.name) {
          controller.SetPreviewColorName("");
        }
      }
      win.Separator(ATH_ColorEditorWindow.NameFrom(s"color_\(c.name)_sep"));
      i += 1;
    }
  }

  private static func DrawWeatherStates(win: ref<RWWindow>, controller: ref<ATH_LightController>) -> Void {
    let weatherData: ref<ATH_WeatherStateData> = controller.GetWeatherData();
    if ArraySize(weatherData.states) == 0 {
      win.Text(n"ws_empty", "No weather states discovered yet - load a save first.");
      return;
    }
    let currentState: String = controller.CurrentWeatherStateName();
    let i: Int32 = 0;
    while i < ArraySize(weatherData.states) {
      let state: ref<ATH_WeatherStateTime> = weatherData.states[i];
      let headerId: CName = ATH_ColorEditorWindow.NameFrom(s"ws_\(state.name)");
      let isCurrent: Bool = Equals(currentState, state.name);
      let label: String = isCurrent ? s"\(state.name) (current)" : state.name;

      if win.CollapsingHeader(headerId, label) {
        win.Indent();

        let onId: CName = ATH_ColorEditorWindow.NameFrom(s"ws_\(state.name)_on");
        let onTime: Float = win.SliderF(onId, "Turn On Time", 12.0, 20.0, state.turnOnTime, 0.5);
        if win.Changed(onId) {
          state.turnOnTime = onTime;
          weatherData.Save();
        }

        let offId: CName = ATH_ColorEditorWindow.NameFrom(s"ws_\(state.name)_off");
        let offTime: Float = win.SliderF(offId, "Turn Off Time", 5.0, 12.0, state.turnOffTime, 0.5);
        if win.Changed(offId) {
          state.turnOffTime = offTime;
          weatherData.Save();
        }

        win.Unindent();
      }
      i += 1;
    }
  }
}
