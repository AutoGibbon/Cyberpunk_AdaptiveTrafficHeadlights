module AdaptiveTrafficHeadlights

// Suppresses the base game's rain-driven forced street-light/vehicle-light
// reactions once our own light logic has taken over (mirrors the Lua mod's
// four Override(...) calls). CLSWeatherListener declares its own override of
// both methods (it extends WeatherScriptListener), so each class needs its
// own wrap - wrapping only the base class would not intercept the subclass's
// override.
//
// The Lua mod additionally wrapped CLSWeatherListener's TurnOnLights/
// TurnOffLights (both `private final func(reason: CName)`). Unlike the four
// wraps above, these let the call through when reason == "PlayerPuppet" even
// once we're blocking - that's the gate that lets our own ForceCLSStateRequest
// (sourceName = n"PlayerPuppet") reach the game's logic while every other
// caller (e.g. rain-driven calls with reason "RAIN") stays blocked.

public abstract class ATH_WeatherOverrides {
  public static func ShouldBlock() -> Bool {
    let controller: ref<ATH_LightController> = ATH_LightController.GetInstance(GetGameInstance());
    return IsDefined(controller) && controller.IsReady();
  }
}

@wrapMethod(WeatherScriptListener)
public func OnRainIntensityChanged(rainIntensity: Float) -> Void {
  if !ATH_WeatherOverrides.ShouldBlock() {
    wrappedMethod(rainIntensity);
  }
}

@wrapMethod(WeatherScriptListener)
public func OnRainIntensityTypeChanged(rainIntensityType: worldRainIntensity) -> Void {
  if !ATH_WeatherOverrides.ShouldBlock() {
    wrappedMethod(rainIntensityType);
  }
}

@wrapMethod(CLSWeatherListener)
public func OnRainIntensityChanged(rainIntensity: Float) -> Void {
  if !ATH_WeatherOverrides.ShouldBlock() {
    wrappedMethod(rainIntensity);
  }
}

@wrapMethod(CLSWeatherListener)
public func OnRainIntensityTypeChanged(rainIntensityType: worldRainIntensity) -> Void {
  if !ATH_WeatherOverrides.ShouldBlock() {
    wrappedMethod(rainIntensityType);
  }
}

@wrapMethod(CLSWeatherListener)
private final func TurnOnLights(reason: CName) -> Void {
  if !ATH_WeatherOverrides.ShouldBlock() || Equals(reason, n"PlayerPuppet") {
    wrappedMethod(reason);
  }
}

@wrapMethod(CLSWeatherListener)
private final func TurnOffLights(reason: CName) -> Void {
  if !ATH_WeatherOverrides.ShouldBlock() || Equals(reason, n"PlayerPuppet") {
    wrappedMethod(reason);
  }
}
