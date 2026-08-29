module AdaptiveHeadlights

// Delays the actual light application by 0.1s after attach - gives other
// mods time to finish cycling vehicle appearances first, for compatibility.
public class ATH_ApplyLightsCallback extends DelayCallback {
  public let vehicle: wref<VehicleObject>;

  public static func Create(vehicle: wref<VehicleObject>) -> ref<ATH_ApplyLightsCallback> {
    let self: ref<ATH_ApplyLightsCallback> = new ATH_ApplyLightsCallback();
    self.vehicle = vehicle;
    return self;
  }

  public func Call() -> Void {
    if IsDefined(this.vehicle) {
      ATH_VehicleLights.ApplyToVehicle(this.vehicle);
    }
  }
}

public abstract class ATH_VehicleLights {

  public static func ApplyToVehicle(vehicle: wref<VehicleObject>) -> Void {
    if !IsDefined(vehicle) {
      return;
    }
    let vc: ref<vehicleController> = vehicle.GetAccessoryController();
    if !IsDefined(vc) {
      return;
    }

    let gi: GameInstance = vehicle.GetGame();
    let controller: ref<ATH_LightController> = ATH_LightController.GetInstance(gi);
    let settingsSystem: ref<ATH_SettingsSystem> = ATH_SettingsSystem.GetInstance(gi);
    if !IsDefined(controller) || !IsDefined(settingsSystem) {
      return;
    }
    let settings: ref<ATH_Settings> = settingsSystem.GetSettings();
    let colorData: ref<ATH_ColorData> = controller.GetColorData();
    if !IsDefined(settings) || !IsDefined(colorData) {
      return;
    }

    // Using the transition factor here lets vehicles have a delayed response
    // to weather/time state changes, turning on/off a bit earlier or later
    // than the exact threshold rather than snapping instantly.
    let lightsShouldBeOn: Bool = controller.LightsShouldBeOn();
    let transitionFactor: Float = controller.LightTransitionFactor();
    if settings.useNaturalMode && transitionFactor < 1.0 && RandF() > transitionFactor {
      lightsShouldBeOn = !lightsShouldBeOn;
    }

    let colorName: String = controller.GetPreviewColorName();
    if StrLen(colorName) == 0 {
      colorName = ATH_VehicleLights.PickColorName(vehicle.GetRecordID(), colorData);
    }
    let colorProfile: ref<ATH_HeadlightColor> = colorData.GetColor(colorName);
    if !IsDefined(colorProfile) {
      return;
    }

    let multiplier: Float = lightsShouldBeOn ? 1.0 : MaxF(0.0, MinF(settings.lightsOffBrightnessMultiplier, 1.0));
    let applyColor: Color = ATH_VehicleLights.AdjustBrightness(colorProfile, multiplier);

    vc.SetLightColor(vehicleELightType.Head, applyColor, 0.0);
    vc.SetLightParameters(vehicleELightType.Head, multiplier, applyColor, 0.0);
    vc.SetLightStrength(vehicleELightType.Head, multiplier, 0.0);
    if multiplier == 0.0 {
      vc.ToggleLights(false, vehicleELightType.Head);
    }

    if lightsShouldBeOn {
      vc.ToggleLights(true);
      return;
    }

    let off: Color = Color(Cast<Uint8>(0), Cast<Uint8>(0), Cast<Uint8>(0), Cast<Uint8>(255));
    if settings.turnOffBrakeLights {
      vc.SetLightColor(vehicleELightType.Brake, off, 0.0);
      vc.SetLightParameters(vehicleELightType.Brake, 0.0, off, 0.0);
      vc.SetLightStrength(vehicleELightType.Brake, 0.0, 0.0);
      vc.ToggleLights(false, vehicleELightType.Brake);
    }
    if settings.turnOffBlinkers {
      vc.SetLightColor(vehicleELightType.Blinkers, off, 0.0);
      vc.SetLightParameters(vehicleELightType.Blinkers, 0.0, off, 0.0);
      vc.SetLightStrength(vehicleELightType.Blinkers, 0.0, 0.0);
      vc.ToggleLights(false, vehicleELightType.Blinkers);
    }
    if settings.turnOffUtilityLights {
      vc.SetLightColor(vehicleELightType.Utility, off, 0.0);
      vc.SetLightParameters(vehicleELightType.Utility, 0.0, off, 0.0);
      vc.SetLightStrength(vehicleELightType.Utility, 0.0, 0.0);
      vc.ToggleLights(false, vehicleELightType.Utility);
    }
  }

  private static func PickColorName(recordID: TweakDBID, colorData: ref<ATH_ColorData>) -> String {
    let category: String = colorData.FindCategoryForVehicle(recordID);
    if StrLen(category) > 0 {
      let names: array<String> = colorData.GetColorNamesForCategory(category);
      if ArraySize(names) > 0 {
        return names[RandRange(0, ArraySize(names) - 1)];
      }
    }
    if ArraySize(colorData.colors) > 0 {
      return colorData.colors[RandRange(0, ArraySize(colorData.colors) - 1)].name;
    }
    return "";
  }

  private static func AdjustBrightness(colorProfile: ref<ATH_HeadlightColor>, multiplier: Float) -> Color {
    let alpha: Int32 = colorProfile.alpha;
    if multiplier == 0.0 {
      alpha = 255;
    }
    let r: Int32 = Clamp(RoundF(Cast<Float>(colorProfile.red) * multiplier), 0, 255);
    let g: Int32 = Clamp(RoundF(Cast<Float>(colorProfile.green) * multiplier), 0, 255);
    let b: Int32 = Clamp(RoundF(Cast<Float>(colorProfile.blue) * multiplier), 0, 255);
    return Color(Cast<Uint8>(r), Cast<Uint8>(g), Cast<Uint8>(b), Cast<Uint8>(alpha));
  }
}

// Only fires for non-player crowd vehicles that aren't abandoned.
//
// Hooked at VehicleComponent.OnGameAttach (not VehicleObject.OnGameAttached) -
// confirmed against two real, shipped mods doing this exact job for crowd
// vehicles (NightCityTrafficOverhaul's NCTOvehicleLights.reds and Enhanced
// Vehicle System both wrap VehicleComponent.OnGameAttach for post-attach vehicle
// setup). VehicleObject.OnGameAttached fires at the top-level entity's attach
// point, which can precede the vehicle's own VehicleComponent - and therefore
// its light controller - actually being ready; VehicleComponent.OnGameAttach is
// guaranteed to fire once that component itself has finished attaching.
@wrapMethod(VehicleComponent)
private final func OnGameAttach() -> Void {
  wrappedMethod();
  let vehicle: wref<VehicleObject> = this.GetVehicle();
  if !IsDefined(vehicle) {
    return;
  }
  if vehicle.IsVehicle() && !vehicle.IsPlayerVehicle() && vehicle.IsCrowdVehicle() && !vehicle.IsAbandoned() {
    GameInstance.GetDelaySystem(vehicle.GetGame()).DelayCallback(ATH_ApplyLightsCallback.Create(vehicle), 0.1, false);
  }
}
