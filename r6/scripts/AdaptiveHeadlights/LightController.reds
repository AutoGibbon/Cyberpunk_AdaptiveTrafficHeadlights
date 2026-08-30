module AdaptiveHeadlights

import RedWindows.*

// Recurring ~10s tick. Re-registers itself every call, same pattern
// documented in this repo's CLAUDE.md.
public class ATH_TickCallback extends DelayCallback {
  public let handler: wref<ATH_LightController>;

  public static func Create(handler: ref<ATH_LightController>) -> ref<ATH_TickCallback> {
    let self: ref<ATH_TickCallback> = new ATH_TickCallback();
    self.handler = handler;
    return self;
  }

  public func Call() -> Void {
    if IsDefined(this.handler) {
      this.handler.OnTick();
    }
  }
}

// Separate, faster recurring tick dedicated to the RedWindows editor panel
// (EditorWindow.reds) - decoupled from the 10s light-decision tick so slider
// drags aren't read back and persisted with up to 10s of lag. RedWindows is
// retained-mode and cheap to update every frame; 0.0333s (~30Hz) matches
// VehicleNavigationSystem's identical self-rescheduling pattern for its own
// panel (~60Hz there - 30Hz is plenty for slider/checkbox edits). Only redraws
// while the overlay is open (ATH_LightController.OnEditorTick); otherwise it
// just polls RedWindowsAPI.IsOverlay() at EDITOR_TICK_IDLE so the panel wakes
// promptly without paying the 30Hz cost while nobody's looking.
public class ATH_EditorTickCallback extends DelayCallback {
  public let handler: wref<ATH_LightController>;

  public static func Create(handler: ref<ATH_LightController>) -> ref<ATH_EditorTickCallback> {
    let self: ref<ATH_EditorTickCallback> = new ATH_EditorTickCallback();
    self.handler = handler;
    return self;
  }

  public func Call() -> Void {
    if IsDefined(this.handler) {
      this.handler.OnEditorTick();
    }
  }
}

// Core light-decision state machine: tracks time-of-day and weather state,
// and decides when vehicle headlights and street lights should be on or off.
public class ATH_LightController extends ScriptableSystem {
  private let m_initialized: Bool;

  private let m_settings: ref<ATH_Settings>;
  private let m_colorData: ref<ATH_ColorData>;
  private let m_weatherData: ref<ATH_WeatherStateData>;

  private let m_gotWeatherStates: Bool;
  private let m_foundEnv: Bool;
  private let m_playerSpawned: Bool;

  private let m_hours: Float;
  private let m_minutes: Float;
  private let m_seconds: Float;
  private let m_currentTime: Float;
  private let m_lastUpdateTime: Float;

  private let m_state: String;
  private let m_lastState: String;
  private let m_weatherChanged: Bool;
  private let m_timeWasSkipped: Bool;

  // Display-only mirror of the weather state name, refreshed at editor-tick
  // cadence (see RefreshDisplayInfo) so the panel reads live without touching
  // m_state, which the slow tick alone must own for weather-change detection.
  private let m_displayWeatherState: String;

  private let m_lightsShouldBeOn: Bool;
  private let m_lightTransitionFactor: Float;
  private let m_lastLightDecisionTime: Float;

  private let m_streetLightsOn: Bool;
  private let m_streetLightsSetOnce: Bool;
  private let m_cls: wref<CityLightSystem>;

  // Empty = no override. Set from EditorWindow.reds's per-color "Preview" checkbox.
  private let m_previewColorName: String;

  // ~15Hz while the overlay is open; 1Hz poll otherwise (see ATH_EditorTickCallback).
  private const let EDITOR_TICK_ACTIVE: Float = 0.066;
  private const let EDITOR_TICK_IDLE: Float = 1.0;

  public static func GetInstance(gi: GameInstance) -> ref<ATH_LightController> {
    return GameInstance.GetScriptableSystemsContainer(gi).Get(n"AdaptiveHeadlights.ATH_LightController") as ATH_LightController;
  }

  // --- public accessors, used by VehicleLights.reds and EditorWindow.reds ---

  public func GetColorData() -> ref<ATH_ColorData> {
    return this.m_colorData;
  }

  public func GetWeatherData() -> ref<ATH_WeatherStateData> {
    return this.m_weatherData;
  }

  public func LightsShouldBeOn() -> Bool {
    return this.m_lightsShouldBeOn;
  }

  public func LightTransitionFactor() -> Float {
    return this.m_lightTransitionFactor;
  }

  public func CurrentWeatherStateName() -> String {
    return this.m_displayWeatherState;
  }

  // "HH:MM:SS", zero-padded. Reflects RefreshDisplayInfo()'s last read when the
  // overlay is open, falling back to Update()'s slow-tick value otherwise.
  public func CurrentTimeLabel() -> String {
    let h: Int32 = Cast<Int32>(this.m_hours);
    let m: Int32 = Cast<Int32>(this.m_minutes);
    let sec: Int32 = Cast<Int32>(this.m_seconds);
    let hStr: String = h < 10 ? s"0\(h)" : s"\(h)";
    let mStr: String = m < 10 ? s"0\(m)" : s"\(m)";
    let sStr: String = sec < 10 ? s"0\(sec)" : s"\(sec)";
    return s"\(hStr):\(mStr):\(sStr)";
  }

  public func IsReady() -> Bool {
    return this.m_gotWeatherStates && this.m_playerSpawned;
  }

  public func GetPreviewColorName() -> String {
    return this.m_previewColorName;
  }

  public func SetPreviewColorName(colorName: String) -> Void {
    this.m_previewColorName = colorName;
  }

  // --- lifecycle ---

  public func OnAttach() -> Void {
    this.m_state = "none";
    this.m_lastState = "none";
    this.m_displayWeatherState = "none";
    this.m_lastLightDecisionTime = -1.0;
    this.m_lightTransitionFactor = 1.0;
  }

  public final func OnPlayerAttach(request: ref<PlayerAttachRequest>) -> Void {
    let gi: GameInstance = this.GetGameInstance();
    if !this.m_initialized {
      this.m_initialized = true;
      this.m_colorData = ATH_ColorData.LoadOrDefault();
      this.m_weatherData = ATH_WeatherStateData.LoadOrEmpty();
      let settingsSystem: ref<ATH_SettingsSystem> = ATH_SettingsSystem.GetInstance(gi);
      if IsDefined(settingsSystem) {
        this.m_settings = settingsSystem.GetSettings();
      } else {
        ATHLogWarn("ATH_SettingsSystem not available on attach, falling back to defaults");
        this.m_settings = ATH_Settings.Defaults();
      }
      ATH_EditorWindow.EnsureWindow(gi);
      GameInstance.GetDelaySystem(gi).DelayCallback(ATH_TickCallback.Create(this), 10.0, false);
      GameInstance.GetDelaySystem(gi).DelayCallback(ATH_EditorTickCallback.Create(this), this.EDITOR_TICK_IDLE, false);
    }
    this.ResetSessionState();
    this.TryGetWeatherData();
    this.TryFirstUpdate();
  }

  private func ResetSessionState() -> Void {
    this.m_playerSpawned = false;
    this.m_streetLightsSetOnce = false;
    this.m_streetLightsOn = false;
    this.m_weatherChanged = false;
    this.m_timeWasSkipped = false;
    this.m_lastLightDecisionTime = -1.0;
    this.m_cls = null;
  }

  public func OnTick() -> Void {
    let gi: GameInstance = this.GetGameInstance();
    GameInstance.GetDelaySystem(gi).DelayCallback(ATH_TickCallback.Create(this), 10.0, false);
    if GameInstance.GetSystemRequestsHandler().IsPreGame() || GameInstance.GetSystemRequestsHandler().IsGamePaused() {
      return;
    }
    if this.m_gotWeatherStates && this.m_playerSpawned {
      this.Update();
    }
  }

  // Runs independently of OnTick() above - see ATH_EditorTickCallback. Not
  // gated on IsPreGame/IsGamePaused: editing settings while RedWindows has
  // paused the game (its own "Pause Game" option) is legitimate. Redraws
  // only while the overlay is open; otherwise just polls IsOverlay().
  public func OnEditorTick() -> Void {
    let gi: GameInstance = this.GetGameInstance();
    let overlayOpen: Bool = RedWindowsAPI.IsOverlay(gi);
    GameInstance.GetDelaySystem(gi).DelayCallback(ATH_EditorTickCallback.Create(this), overlayOpen ? this.EDITOR_TICK_ACTIVE : this.EDITOR_TICK_IDLE, false);
    if this.m_initialized && overlayOpen {
      this.RefreshDisplayInfo();
      ATH_EditorWindow.Update(gi, this);
    }
  }

  // Display-only refresh, run at editor-tick cadence while the overlay is open
  // (up to ~30Hz) so the time/weather readout feels live. Deliberately reads
  // straight from the game systems instead of calling Update()/CalculateLightState -
  // the actual light-decision logic must stay on its own slow tick (see OnTick),
  // so this never touches m_state, m_currentTime, or any of the light-decision fields.
  private func RefreshDisplayInfo() -> Void {
    this.ReadGameTime();
    this.m_displayWeatherState = this.ReadWeatherStateName();
  }

  private func ReadGameTime() -> Void {
    let gameTime: GameTime = GameInstance.GetTimeSystem(this.GetGameInstance()).GetGameTime();
    this.m_hours = Cast<Float>(GameTime.Hours(gameTime));
    this.m_minutes = Cast<Float>(GameTime.Minutes(gameTime));
    this.m_seconds = Cast<Float>(GameTime.Seconds(gameTime));
  }

  private func ReadWeatherStateName() -> String {
    let weatherState: ref<worldWeatherState> = GameInstance.GetWeatherSystem(this.GetGameInstance()).GetWeatherState();
    return IsDefined(weatherState) ? NameToString(weatherState.name) : "";
  }

  // --- weather data readiness ---

  public func TryGetWeatherData() -> Void {
    if this.m_gotWeatherStates {
      return;
    }
    if GameInstance.GetSystemRequestsHandler().IsPreGame() || GameInstance.GetSystemRequestsHandler().IsGamePaused() {
      return;
    }
    let gi: GameInstance = this.GetGameInstance();
    let weatherSys: ref<WeatherSystem> = GameInstance.GetWeatherSystem(gi);
    if !IsDefined(weatherSys) {
      return;
    }
    let envDef: ref<worldEnvironmentDefinition> = weatherSys.GetEnvironmentDefinition();
    if !IsDefined(envDef) {
      return;
    }

    // OnPlayerAttach only fires once a real game session has attached a player, so a
    // non-null envDef with populated weatherStates already means a loaded, real
    // environment - no need to filter out placeholder/pregame environments.
    if !this.m_foundEnv {
      if ArraySize(envDef.weatherStates) > 0 {
        this.m_foundEnv = true;
      }
    }

    if this.m_foundEnv && !this.m_gotWeatherStates {
      if this.m_weatherData.DiscoverFrom(gi) {
        this.m_weatherData.Save();
      }
      this.m_gotWeatherStates = true;
      ATHLog("Weather data loaded");
    }
  }

  public func TryFirstUpdate() -> Void {
    if this.m_playerSpawned || !this.m_gotWeatherStates {
      return;
    }
    if GameInstance.GetSystemRequestsHandler().IsPreGame() || GameInstance.GetSystemRequestsHandler().IsGamePaused() {
      return;
    }
    this.Update();
  }

  // --- core update ---

  public func Update() -> Void {
    if !this.m_gotWeatherStates {
      return;
    }
    this.ReadGameTime();

    let stateName: String = this.ReadWeatherStateName();
    this.m_displayWeatherState = stateName;

    if !Equals(this.m_state, stateName) {
      if Equals(this.m_lastState, "none") {
        this.m_lastState = stateName;
      } else {
        this.m_weatherChanged = true;
        this.m_lastState = this.m_state;
      }
      this.m_state = stateName;
    }

    if !this.m_settings.adjustAllWeatherStates {
      let found: ref<ATH_WeatherStateTime> = this.m_weatherData.FindState(this.m_state);
      if IsDefined(found) {
        this.CalculateLightState(found.turnOnTime, found.turnOffTime);
      }
    } else {
      this.CalculateLightState(this.m_settings.allOnTime, this.m_settings.allOffTime);
    }

    this.m_playerSpawned = true;
  }

  // Floored modulo for a positive divisor, used instead of the base game's
  // ModF() global (core/math/scalar.script), which returns 0 for non-positive
  // input and would misbehave on the negative intermediate values this logic
  // produces (e.g. around the lastLightDecisionTime sentinel of -1.0).
  private func Wrap24(value: Float) -> Float {
    let m: Float = value - Cast<Float>(FloorF(value / 24.0)) * 24.0;
    if m < 0.0 {
      m += 24.0;
    }
    return m;
  }

  private func CalculateLightState(turnOnTime: Float, turnOffTime: Float) -> Void {
    this.m_currentTime = this.m_hours + this.m_minutes / 60.0;
    let timeDelta: Float = this.Wrap24(this.m_currentTime - this.m_lastUpdateTime + 24.0);

    if this.m_lastUpdateTime > 0.0 && timeDelta > 2.0 && timeDelta < 23.5 {
      this.m_timeWasSkipped = true;
      ATHLog(s"Time jump detected: \(timeDelta) hours, lights will be updated immediately");
    }

    if this.m_currentTime >= turnOnTime || this.m_currentTime < turnOffTime {
      if !this.m_timeWasSkipped && (!this.m_lightsShouldBeOn || this.m_lastLightDecisionTime == -1.0) {
        this.m_lastLightDecisionTime = this.m_currentTime;
      }
      this.m_lightsShouldBeOn = true;
    } else if this.m_currentTime < turnOnTime && this.m_currentTime >= turnOffTime {
      if !this.m_timeWasSkipped && (this.m_lightsShouldBeOn || this.m_lastLightDecisionTime == -1.0) {
        this.m_lastLightDecisionTime = this.m_currentTime;
      }
      this.m_lightsShouldBeOn = false;
    }

    let timeToOn: Float = this.Wrap24(turnOnTime - this.m_currentTime + 24.0);
    let timeToOff: Float = this.Wrap24(turnOffTime - this.m_currentTime + 24.0);
    let timeSinceLastDecision: Float = this.Wrap24(this.m_lastLightDecisionTime - this.m_currentTime + 24.0);

    if timeSinceLastDecision <= 1.0 || timeSinceLastDecision >= 23.0 {
      let distance: Float = MinF(timeSinceLastDecision, 24.0 - timeSinceLastDecision);
      this.m_lightTransitionFactor = 0.5 + (distance / 2.0);
    } else if timeToOn <= 1.0 || timeToOn >= 23.0 {
      let distance: Float = MinF(timeToOn, 24.0 - timeToOn);
      this.m_lightTransitionFactor = 0.5 + (distance / 2.0);
    } else if timeToOff <= 1.0 || timeToOff >= 23.0 {
      let distance: Float = MinF(timeToOff, 24.0 - timeToOff);
      this.m_lightTransitionFactor = 0.5 + (distance / 2.0);
    } else {
      this.m_lightTransitionFactor = 1.0;
    }

    this.UpdateStreetLights();
    this.m_timeWasSkipped = false;
    this.m_lastUpdateTime = this.m_currentTime;
  }

  private func UpdateStreetLights() -> Void {
    if !this.m_settings.enableStreetLightControl {
      return;
    }
    if !IsDefined(this.m_cls) {
      this.m_cls = GameInstance.GetScriptableSystemsContainer(this.GetGameInstance()).Get(n"CityLightSystem") as CityLightSystem;
    }
    if !IsDefined(this.m_cls) {
      return;
    }

    let shouldUpdateLights: Bool = false;

    if this.m_lightsShouldBeOn && (!this.m_streetLightsOn || !this.m_streetLightsSetOnce) {
      if !this.m_streetLightsSetOnce || this.m_timeWasSkipped || !(this.m_settings.useNaturalMode && this.m_weatherChanged && this.m_lightTransitionFactor <= 0.75) {
        shouldUpdateLights = true;
      }
    } else if !this.m_lightsShouldBeOn && (this.m_streetLightsOn || !this.m_streetLightsSetOnce) {
      if !this.m_streetLightsSetOnce || this.m_timeWasSkipped || !(this.m_settings.useNaturalMode && this.m_weatherChanged && this.m_lightTransitionFactor <= 0.75) {
        shouldUpdateLights = true;
      }
    }

    if shouldUpdateLights {
      let request: ref<ForceCLSStateRequest> = new ForceCLSStateRequest();
      request.sourceName = n"PlayerPuppet";
      request.priority = EPriority.Absolute;
      request.removePreviousRequests = true;
      request.savable = false;
      if this.m_lightsShouldBeOn {
        request.state = ECLSForcedState.ForcedON;
        ATHLog("street lights on");
      } else {
        request.state = ECLSForcedState.ForcedOFF;
        ATHLog("street lights off");
      }
      this.m_cls.QueueRequest(request);
      this.m_streetLightsOn = this.m_lightsShouldBeOn;
      this.m_streetLightsSetOnce = true;
      this.m_weatherChanged = false;
    }
  }
}
