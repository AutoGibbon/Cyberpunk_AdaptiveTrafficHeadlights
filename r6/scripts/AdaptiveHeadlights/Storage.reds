module AdaptiveHeadlights

import RedFileSystem.*

// RedFileSystem revokes a storage handle after the first fetch each session, so
// GetStorage() must be called once and cached - same pattern as
// DVRCF_StoreService/DVItemDatabaseService. Shared here so ATH_Settings/
// ATH_ColorData/ATH_WeatherStateData don't each fetch their own.
public class ATH_StorageService extends ScriptableService {
  private let m_storage: ref<FileSystemStorage>;

  private cb func OnLoad() -> Void {
    this.m_storage = FileSystem.GetStorage("AdaptiveHeadlights");
  }

  public static func Get() -> ref<FileSystemStorage> {
    let svc: ref<ATH_StorageService> = GameInstance.GetScriptableServiceContainer().GetService(n"AdaptiveHeadlights.ATH_StorageService") as ATH_StorageService;
    if !IsDefined(svc) {
      return null;
    }
    return svc.m_storage;
  }
}
