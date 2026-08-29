module AdaptiveTrafficHeadlights

import RedFileSystem.*
import RedData.Json.*

public class ATH_WeatherStateTime {
  public let name: String;
  public let turnOnTime: Float;
  public let turnOffTime: Float;
}

// Discovers the game's weather states at runtime (via Codeware's WeatherSystem
// extensions) and keeps a persisted on/off time per state, mirroring the old
// Lua mod's weatherStateSettings.json. Default on/off time for a newly
// discovered state is 19:00 / 7:00, same as the Lua version.
public class ATH_WeatherStateData {
  public let states: array<ref<ATH_WeatherStateTime>>;

  public func FindState(stateName: String) -> ref<ATH_WeatherStateTime> {
    let i: Int32 = 0;
    while i < ArraySize(this.states) {
      if Equals(this.states[i].name, stateName) {
        return this.states[i];
      }
      i += 1;
    }
    return null;
  }

  // Adds an entry (default 19/7) for any weather state not already known.
  // Returns true if the list changed (caller should persist).
  public func DiscoverFrom(gi: GameInstance) -> Bool {
    let weatherSys: ref<WeatherSystem> = GameInstance.GetWeatherSystem(gi);
    if !IsDefined(weatherSys) {
      return false;
    }
    let envDef: ref<worldEnvironmentDefinition> = weatherSys.GetEnvironmentDefinition();
    if !IsDefined(envDef) {
      return false;
    }
    let added: Int32 = 0;
    let i: Int32 = 0;
    let count: Int32 = ArraySize(envDef.weatherStates);
    while i < count {
      if IsDefined(envDef.weatherStates[i]) {
        let stateName: String = NameToString(envDef.weatherStates[i].name);
        if StrLen(stateName) > 0 && !IsDefined(this.FindState(stateName)) {
          let newState: ref<ATH_WeatherStateTime> = new ATH_WeatherStateTime();
          newState.name = stateName;
          newState.turnOnTime = 19.0;
          newState.turnOffTime = 7.0;
          ArrayPush(this.states, newState);
          added += 1;
        }
      }
      i += 1;
    }
    if added > 0 {
      ATHLog(s"Discovered \(added) new weather state(s)");
    }
    return added > 0;
  }

  private static func GetStorage() -> ref<FileSystemStorage> {
    return FileSystem.GetStorage("AdaptiveTrafficHeadlights");
  }

  public func Load() -> Void {
    let storage: ref<FileSystemStorage> = ATH_WeatherStateData.GetStorage();
    if !Equals(storage.Exists("weatherStates.json"), FileSystemStatus.True) {
      return;
    }
    let root: ref<JsonVariant> = storage.GetFile("weatherStates.json").ReadAsJson();
    if !IsDefined(root) || !root.IsArray() {
      ATHLogWarn("weatherStates.json exists but is not a JSON array, ignoring");
      return;
    }
    let arr: ref<JsonArray> = root as JsonArray;
    let count: Int32 = Cast<Int32>(arr.GetSize());
    let applied: Int32 = 0;
    let i: Int32 = 0;
    while i < count {
      let entry: ref<JsonObject> = arr.GetItem(Cast<Uint32>(i)) as JsonObject;
      if IsDefined(entry) {
        let stateName: String = entry.GetKeyString("name");
        let existing: ref<ATH_WeatherStateTime> = this.FindState(stateName);
        if !IsDefined(existing) {
          existing = new ATH_WeatherStateTime();
          existing.name = stateName;
          ArrayPush(this.states, existing);
        }
        existing.turnOnTime = Cast<Float>(entry.GetKeyDouble("turnOnTime"));
        existing.turnOffTime = Cast<Float>(entry.GetKeyDouble("turnOffTime"));
        applied += 1;
      }
      i += 1;
    }
    ATHLog(s"Loaded \(applied) weather state time(s) from weatherStates.json");
  }

  public func Save() -> Void {
    let arr: ref<JsonArray> = new JsonArray();
    let i: Int32 = 0;
    while i < ArraySize(this.states) {
      let entry: ref<JsonObject> = new JsonObject();
      entry.SetKeyString("name", this.states[i].name);
      entry.SetKeyDouble("turnOnTime", Cast<Double>(this.states[i].turnOnTime));
      entry.SetKeyDouble("turnOffTime", Cast<Double>(this.states[i].turnOffTime));
      arr.AddItem(entry);
      i += 1;
    }
    ATH_WeatherStateData.GetStorage().GetFile("weatherStates.json").WriteJson(arr, "  ");
  }

  public static func LoadOrEmpty() -> ref<ATH_WeatherStateData> {
    let d: ref<ATH_WeatherStateData> = new ATH_WeatherStateData();
    d.Load();
    return d;
  }
}
