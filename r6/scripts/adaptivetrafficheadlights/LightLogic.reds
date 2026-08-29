module AdaptiveTrafficHeadlights

// Recurring ~10s tick, replacing the old Lua mod's Cron.Every(10.0, ...).
// Re-registers itself every call, same pattern documented in this repo's CLAUDE.md.
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

// Separate, much faster recurring tick dedicated to the RedWindows editor panel
// (ColorEditorWindow.reds) - decoupled from the 10s light-decision tick above so
// slider drags etc. don't wait up to 10s to be read back and persisted. RedWindows
// itself is retained-mode and documented as cheap to update every frame; 0.0333s
// (~30Hz) - VehicleNavigationSystem uses the identical self-rescheduling pattern
// at ~60Hz for its own RedWindows panel, 30Hz is plenty for slider/checkbox edits.
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

// Core light-decision state machine, replacing the Lua mod's `S` globals table
// and its CalculateLightState/UpdateStreetLights/TryGetWeatherData/Update
// functions. Ported near-verbatim - same math, same branching.
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
  private let m_currentTime: Float;
  private let m_lastUpdateTime: Float;

  private let m_state: String;
  private let m_lastState: String;
  private let m_weatherChanged: Bool;
  private let m_timeWasSkipped: Bool;

  private let m_lightsShouldBeOn: Bool;
  private let m_lightTransitionFactor: Float;
  private let m_lastLightDecisionTime: Float;

  private let m_streetLightsOn: Bool;
  private let m_streetLightsSetOnce: Bool;
  private let m_cls: wref<CityLightSystem>;

  // Empty = no override. Set from ColorEditorWindow.reds's per-color "Preview"
  // checkbox, mirroring the Lua mod's cetLightOverrideColor/Name.
  private let m_previewColorName: String;

  public static func GetInstance(gi: GameInstance) -> ref<ATH_LightController> {
    return GameInstance.GetScriptableSystemsContainer(gi).Get(n"AdaptiveTrafficHeadlights.ATH_LightController") as ATH_LightController;
  }

  // --- public accessors, used by VehicleLights.reds and ColorEditorWindow.reds ---

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
    return this.m_state;
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
      GameInstance.GetDelaySystem(gi).DelayCallback(ATH_TickCallback.Create(this), 10.0, false);
      GameInstance.GetDelaySystem(gi).DelayCallback(ATH_EditorTickCallback.Create(this), 0.0333, false);
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
  // gated on IsPreGame/IsGamePaused: editing settings while the overlay has
  // paused the game (RedWindows' own "Pause Game" option) is a legitimate use.
  public func OnEditorTick() -> Void {
    let gi: GameInstance = this.GetGameInstance();
    GameInstance.GetDelaySystem(gi).DelayCallback(ATH_EditorTickCallback.Create(this), 0.0333, false);
    if this.m_initialized {
      ATH_ColorEditorWindow.Update(gi, this);
    }
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

    // Same "is this a real, loaded environment" gate as the Lua mod: reject a
    // path containing "v002" (a placeholder/pregame environment) unless it also
    // contains "nova_city_master" (Nova City Weather Probability's own valid
    // environment happens to match "v002" too). worldEnvironmentDefinition
    // extends CResource, which carries its own resource path as a plain field
    // (CResource.path: ResRef); Codeware adds ResRef.ToString() to read it back.
    if !this.m_foundEnv {
      let pathStr: String = envDef.path.ToString();
      if StrLen(pathStr) > 0 {
        let pathLower: String = StrLower(pathStr);
        let hasV002: Bool = StrContains(pathLower, "v002");
        let hasNovaCity: Bool = StrContains(pathLower, "nova_city_master");
        if !hasV002 || hasNovaCity {
          this.m_foundEnv = true;
        } else {
          ATHLogWarn(s"Invalid/placeholder environment detected: \(pathStr)");
        }
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
    let gi: GameInstance = this.GetGameInstance();
    let gameTime: GameTime = GameInstance.GetTimeSystem(gi).GetGameTime();
    this.m_hours = Cast<Float>(GameTime.Hours(gameTime));
    this.m_minutes = Cast<Float>(GameTime.Minutes(gameTime));

    let weatherState: ref<worldWeatherState> = GameInstance.GetWeatherSystem(gi).GetWeatherState();
    let stateName: String = IsDefined(weatherState) ? NameToString(weatherState.name) : "";

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

  // Correct floored modulo for a positive divisor, used instead of the base
  // game's ModF() global (core/math/scalar.script), which returns 0 for any
  // non-positive input and would misbehave on the negative intermediate values
  // this logic legitimately produces (e.g. around the lastLightDecisionTime
  // sentinel of -1.0).
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
