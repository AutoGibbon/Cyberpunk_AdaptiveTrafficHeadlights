module AdaptiveHeadlights

import RedWindows.*

// Live RedWindows editor for all scalar settings, the headlight color
// palette, and per-weather-state on/off times. Driven from
// ATH_LightController's editor tick (ATH_EditorTickCallback), which only
// redraws this at ~30Hz while the RedWindows overlay is open.
public abstract class ATH_EditorWindow {

  // Registers/shows the window once (called from ATH_LightController.OnPlayerAttach)
  // so it's already known to RWManager and appears with no delay when the player
  // opens the overlay - the tab content itself is only (re)drawn while the overlay
  // is open (ATH_LightController.OnEditorTick).
  public static func EnsureWindow(gi: GameInstance) -> ref<RWWindow> {
    let win: ref<RWWindow> = RedWindowsAPI.Window(gi, n"AdaptiveHeadlights.Editor", "Adaptive Traffic Headlights");
    if !IsDefined(win) {
      return null;
    }
    win.minW = 520.0;
    // Config/tuning UI, not a permanent HUD element - only rendered while the
    // overlay is open (default F7), same as VehicleNavigationSystem's
    // "VNS.Tuner" window. Without this it would sit on screen at all times.
    win.SetOverlayOnly(true);
    if !win.IsVisible() {
      win.Show();
    }
    return win;
  }

  public static func Update(gi: GameInstance, controller: ref<ATH_LightController>) -> Void {
    if !IsDefined(controller) {
      return;
    }
    let win: ref<RWWindow> = ATH_EditorWindow.EnsureWindow(gi);
    if !IsDefined(win) {
      return;
    }

    let tabLabels: array<String> = ["Settings", "Headlights", "Weather States"];
    let tab: Int32 = win.TabBar(n"tabs", tabLabels);
    if tab == 0 {
      ATH_EditorWindow.DrawSettings(win, gi);
    } else if tab == 1 {
      ATH_EditorWindow.DrawHeadlights(win, controller);
    } else {
      ATH_EditorWindow.DrawWeatherStates(win, controller);
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

  // Master/detail layout, same rationale as DrawWeatherStates below: one
  // ListBox plus a single reused set of sliders/checkbox, refreshed via
  // SetValueF()/SetBoolValue() on selection change - not a full
  // header+sliders+checkbox subtree per color.
  private static func DrawHeadlights(win: ref<RWWindow>, controller: ref<ATH_LightController>) -> Void {
    let colorData: ref<ATH_ColorData> = controller.GetColorData();
    if ArraySize(colorData.colors) == 0 {
      win.Text(n"color_empty", "No headlight colors defined.");
      return;
    }
    let previewName: String = controller.GetPreviewColorName();

    let labels: array<String> = [];
    let i: Int32 = 0;
    while i < ArraySize(colorData.colors) {
      ArrayPush(labels, colorData.colors[i].name);
      i += 1;
    }

    let sel: Int32 = win.ListBox(n"color_list", labels, 0, 12);
    if sel < 0 || sel >= ArraySize(colorData.colors) {
      return;
    }
    let c: ref<ATH_HeadlightColor> = colorData.colors[sel];
    let listChanged: Bool = win.Changed(n"color_list");

    win.Header(n"color_detail_header", c.name);

    if listChanged {
      win.SetValueF(n"color_detail_r", Cast<Float>(c.red));
      win.SetValueF(n"color_detail_g", Cast<Float>(c.green));
      win.SetValueF(n"color_detail_b", Cast<Float>(c.blue));
      win.SetValueF(n"color_detail_a", Cast<Float>(c.alpha));
      win.SetBoolValue(n"color_detail_preview", Equals(previewName, c.name));
    }

    let red: Float = win.SliderF(n"color_detail_r", "Red", 0.0, 255.0, Cast<Float>(c.red), 1.0);
    let changed: Bool = win.Changed(n"color_detail_r");

    let green: Float = win.SliderF(n"color_detail_g", "Green", 0.0, 255.0, Cast<Float>(c.green), 1.0);
    changed = win.Changed(n"color_detail_g") || changed;

    let blue: Float = win.SliderF(n"color_detail_b", "Blue", 0.0, 255.0, Cast<Float>(c.blue), 1.0);
    changed = win.Changed(n"color_detail_b") || changed;

    let alpha: Float = win.SliderF(n"color_detail_a", "Brightness (alpha)", 0.0, 255.0, Cast<Float>(c.alpha), 1.0);
    changed = win.Changed(n"color_detail_a") || changed;

    // One swatch polygon, created once (guarded by ShapeCount). Alpha bakes
    // into RGB as a brightness multiplier (matching how alpha drives emissive
    // intensity on actual vehicle lights) rather than shape opacity - opacity
    // blends toward whatever's behind the swatch, reading as "washing out to
    // white" at low alpha instead of "dimmer".
    win.Shapes(n"color_preview", 2);
    let shapesFresh: Bool = win.ShapeCount(n"color_preview") == 0;
    if shapesFresh {
      let swatch: array<Vector2>;
      ArrayPush(swatch, Vector2(0.05, 0.15));
      ArrayPush(swatch, Vector2(0.95, 0.15));
      ArrayPush(swatch, Vector2(0.95, 0.85));
      ArrayPush(swatch, Vector2(0.05, 0.85));
      win.SetShape(n"color_preview", n"swatch", swatch);
      win.SetShapeBorder(n"color_preview", n"swatch", HDRColor(1.0, 1.0, 1.0, 0.4), 1.0);
    }
    if shapesFresh || listChanged || changed {
      win.SetShapeColor(n"color_preview", n"swatch", HDRColor((red / 255.0), (green / 255.0), (blue / 255.0), 1.0));
    }

    if changed {
      c.red = Cast<Int32>(red);
      c.green = Cast<Int32>(green);
      c.blue = Cast<Int32>(blue);
      c.alpha = Cast<Int32>(alpha);
      colorData.Save();
    }

    let isChecked: Bool = win.Checkbox(n"color_detail_preview", "Preview on new vehicles", Equals(previewName, c.name));
    if win.Changed(n"color_detail_preview") {
      if isChecked {
        controller.SetPreviewColorName(c.name);
      } else if Equals(previewName, c.name) {
        controller.SetPreviewColorName("");
      }
    }
  }

  // Master/detail layout instead of one CollapsingHeader+2 sliders per state:
  // RedWindows builds a full ink widget subtree the first time it sees a
  // widget id, so a header-per-item loop would mean N subtrees on first
  // render. Here there's one ListBox (which only builds nodes for its
  // visible rows) plus a single reused pair of sliders, refreshed via
  // SetValueF() on selection change.
  private static func DrawWeatherStates(win: ref<RWWindow>, controller: ref<ATH_LightController>) -> Void {
    let weatherData: ref<ATH_WeatherStateData> = controller.GetWeatherData();
    if ArraySize(weatherData.states) == 0 {
      win.Text(n"ws_empty", "No weather states discovered yet - load a save first.");
      return;
    }
    let currentState: String = controller.CurrentWeatherStateName();

    let labels: array<String> = [];
    let i: Int32 = 0;
    while i < ArraySize(weatherData.states) {
      let state: ref<ATH_WeatherStateTime> = weatherData.states[i];
      ArrayPush(labels, Equals(currentState, state.name) ? s"\(state.name) (current)" : state.name);
      i += 1;
    }

    let sel: Int32 = win.ListBox(n"ws_list", labels, 0, 16);
    if sel < 0 || sel >= ArraySize(weatherData.states) {
      return;
    }
    let state: ref<ATH_WeatherStateTime> = weatherData.states[sel];

    win.Header(n"ws_detail_header", state.name);

    if win.Changed(n"ws_list") {
      win.SetValueF(n"ws_detail_on", state.turnOnTime);
      win.SetValueF(n"ws_detail_off", state.turnOffTime);
    }

    let onTime: Float = win.SliderF(n"ws_detail_on", "Turn On Time", 12.0, 20.0, state.turnOnTime, 0.5);
    if win.Changed(n"ws_detail_on") {
      state.turnOnTime = onTime;
      weatherData.Save();
    }

    let offTime: Float = win.SliderF(n"ws_detail_off", "Turn Off Time", 5.0, 12.0, state.turnOffTime, 0.5);
    if win.Changed(n"ws_detail_off") {
      state.turnOffTime = offTime;
      weatherData.Save();
    }
  }
}
