module AdaptiveHeadlights

import RedFileSystem.*
import RedData.Json.*

// Scalar settings. autoResize/lockWindow/themeDisabled are dropped - they
// only existed to manage a custom ImGui window, now owned by RedWindows.
// Edited live via the "Settings" tab in EditorWindow.reds, persisted via
// RedFileSystem+RedData - same pattern as ATH_ColorData/ATH_WeatherStateData.
public class ATH_Settings {
  public let useNaturalMode: Bool;
  public let enableStreetLightControl: Bool;
  public let lightsOffBrightnessMultiplier: Float;
  public let turnOffBrakeLights: Bool;
  public let turnOffBlinkers: Bool;
  public let turnOffUtilityLights: Bool;
  public let adjustAllWeatherStates: Bool;
  public let allOnTime: Float;
  public let allOffTime: Float;

  public func CopyFrom(other: ref<ATH_Settings>) -> Void {
    this.useNaturalMode = other.useNaturalMode;
    this.enableStreetLightControl = other.enableStreetLightControl;
    this.lightsOffBrightnessMultiplier = other.lightsOffBrightnessMultiplier;
    this.turnOffBrakeLights = other.turnOffBrakeLights;
    this.turnOffBlinkers = other.turnOffBlinkers;
    this.turnOffUtilityLights = other.turnOffUtilityLights;
    this.adjustAllWeatherStates = other.adjustAllWeatherStates;
    this.allOnTime = other.allOnTime;
    this.allOffTime = other.allOffTime;
  }

  public static func Defaults() -> ref<ATH_Settings> {
    let s: ref<ATH_Settings> = new ATH_Settings();
    s.useNaturalMode = true;
    s.enableStreetLightControl = true;
    s.lightsOffBrightnessMultiplier = 0.0;
    s.turnOffBrakeLights = true;
    s.turnOffBlinkers = true;
    s.turnOffUtilityLights = true;
    s.adjustAllWeatherStates = false;
    s.allOnTime = 17.0;
    s.allOffTime = 7.0;
    return s;
  }

  // Only overwrites fields present in the file - a truncated/hand-edited
  // file can't reset fields it omits.
  public func Load() -> Void {
    let storage: ref<FileSystemStorage> = ATH_StorageService.Get();
    if !IsDefined(storage) || !Equals(storage.Exists("settings.json"), FileSystemStatus.True) {
      return;
    }
    let root: ref<JsonVariant> = storage.GetFile("settings.json").ReadAsJson();
    if !IsDefined(root) || !root.IsObject() {
      ATHLogWarn("settings.json exists but is not a JSON object, ignoring");
      return;
    }
    let obj: ref<JsonObject> = root as JsonObject;
    if obj.HasKey("useNaturalMode") { this.useNaturalMode = obj.GetKeyBool("useNaturalMode"); }
    if obj.HasKey("enableStreetLightControl") { this.enableStreetLightControl = obj.GetKeyBool("enableStreetLightControl"); }
    if obj.HasKey("lightsOffBrightnessMultiplier") { this.lightsOffBrightnessMultiplier = Cast<Float>(obj.GetKeyDouble("lightsOffBrightnessMultiplier")); }
    if obj.HasKey("turnOffBrakeLights") { this.turnOffBrakeLights = obj.GetKeyBool("turnOffBrakeLights"); }
    if obj.HasKey("turnOffBlinkers") { this.turnOffBlinkers = obj.GetKeyBool("turnOffBlinkers"); }
    if obj.HasKey("turnOffUtilityLights") { this.turnOffUtilityLights = obj.GetKeyBool("turnOffUtilityLights"); }
    if obj.HasKey("adjustAllWeatherStates") { this.adjustAllWeatherStates = obj.GetKeyBool("adjustAllWeatherStates"); }
    if obj.HasKey("allOnTime") { this.allOnTime = Cast<Float>(obj.GetKeyDouble("allOnTime")); }
    if obj.HasKey("allOffTime") { this.allOffTime = Cast<Float>(obj.GetKeyDouble("allOffTime")); }
    ATHLog("Loaded settings from settings.json");
  }

  public func Save() -> Void {
    let storage: ref<FileSystemStorage> = ATH_StorageService.Get();
    if !IsDefined(storage) {
      return;
    }
    let root: ref<JsonObject> = new JsonObject();
    root.SetKeyBool("useNaturalMode", this.useNaturalMode);
    root.SetKeyBool("enableStreetLightControl", this.enableStreetLightControl);
    root.SetKeyDouble("lightsOffBrightnessMultiplier", Cast<Double>(this.lightsOffBrightnessMultiplier));
    root.SetKeyBool("turnOffBrakeLights", this.turnOffBrakeLights);
    root.SetKeyBool("turnOffBlinkers", this.turnOffBlinkers);
    root.SetKeyBool("turnOffUtilityLights", this.turnOffUtilityLights);
    root.SetKeyBool("adjustAllWeatherStates", this.adjustAllWeatherStates);
    root.SetKeyDouble("allOnTime", Cast<Double>(this.allOnTime));
    root.SetKeyDouble("allOffTime", Cast<Double>(this.allOffTime));
    storage.GetFile("settings.json").WriteJson(root, "  ");
  }
}

public class ATH_SettingsSystem extends ScriptableSystem {
  private let m_settings: ref<ATH_Settings>;

  public static func GetInstance(gi: GameInstance) -> ref<ATH_SettingsSystem> {
    return GameInstance.GetScriptableSystemsContainer(gi).Get(n"AdaptiveHeadlights.ATH_SettingsSystem") as ATH_SettingsSystem;
  }

  public func GetSettings() -> ref<ATH_Settings> {
    return this.m_settings;
  }

  // Defaults assigned immediately so GetSettings() is never null; the saved
  // file merges in at Session/Ready (same timing as the old DVRCF registration),
  // keeping disk I/O off the earlier OnAttach point - same deferral
  // ATH_ColorData/ATH_WeatherStateData use.
  public func OnAttach() -> Void {
    this.m_settings = ATH_Settings.Defaults();
    GameInstance.GetCallbackSystem()
      .RegisterCallback(n"Session/Ready", this, n"OnSessionReady")
      .SetLifetime(CallbackLifetime.Forever);
  }

  protected cb func OnSessionReady(event: ref<GameSessionEvent>) -> Void {
    this.m_settings.Load();
  }
}
