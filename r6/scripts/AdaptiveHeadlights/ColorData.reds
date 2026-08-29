module AdaptiveHeadlights

import RedFileSystem.*
import RedData.Json.*

public class ATH_HeadlightColor {
  public let name: String;
  public let red: Int32;
  public let green: Int32;
  public let blue: Int32;
  public let alpha: Int32;

  public static func Create(name: String, red: Int32, green: Int32, blue: Int32, alpha: Int32) -> ref<ATH_HeadlightColor> {
    let c: ref<ATH_HeadlightColor> = new ATH_HeadlightColor();
    c.name = name;
    c.red = red;
    c.green = green;
    c.blue = blue;
    c.alpha = alpha;
    return c;
  }
}

public class ATH_CategoryColorNames {
  public let category: String;
  public let colorNames: array<String>;

  public static func Create(category: String, colorNames: array<String>) -> ref<ATH_CategoryColorNames> {
    let c: ref<ATH_CategoryColorNames> = new ATH_CategoryColorNames();
    c.category = category;
    c.colorNames = colorNames;
    return c;
  }
}

public class ATH_VehicleCategory {
  public let category: String;
  public let vehicleNames: array<String>;

  // TweakDBID hashes of vehicleNames, built lazily and cached - avoids
  // re-hashing ~450 strings on every crowd vehicle spawn.
  private let m_ids: array<TweakDBID>;
  private let m_idsBuilt: Bool;

  public static func Create(category: String, vehicleNames: array<String>) -> ref<ATH_VehicleCategory> {
    let c: ref<ATH_VehicleCategory> = new ATH_VehicleCategory();
    c.category = category;
    c.vehicleNames = vehicleNames;
    return c;
  }

  public func Matches(recordID: TweakDBID) -> Bool {
    if !this.m_idsBuilt {
      let i: Int32 = 0;
      while i < ArraySize(this.vehicleNames) {
        ArrayPush(this.m_ids, TDBID.Create(this.vehicleNames[i]));
        i += 1;
      }
      this.m_idsBuilt = true;
    }
    let i: Int32 = 0;
    while i < ArraySize(this.m_ids) {
      if Equals(this.m_ids[i], recordID) {
        return true;
      }
      i += 1;
    }
    return false;
  }
}

// Live headlight palette + category mappings. Only headlightColors is
// user-editable in-game (via EditorWindow.reds) and persisted; the category
// mappings are fixed content data.
public class ATH_ColorData {
  public let colors: array<ref<ATH_HeadlightColor>>;
  public let headlightCategories: array<ref<ATH_CategoryColorNames>>;
  public let vehicleCategories: array<ref<ATH_VehicleCategory>>;

  public func GetColor(colorName: String) -> ref<ATH_HeadlightColor> {
    let i: Int32 = 0;
    while i < ArraySize(this.colors) {
      if Equals(this.colors[i].name, colorName) {
        return this.colors[i];
      }
      i += 1;
    }
    return null;
  }

  public func GetColorNamesForCategory(category: String) -> array<String> {
    let out: array<String>;
    let i: Int32 = 0;
    while i < ArraySize(this.headlightCategories) {
      if Equals(this.headlightCategories[i].category, category) {
        return this.headlightCategories[i].colorNames;
      }
      i += 1;
    }
    return out;
  }

  public func FindCategoryForVehicle(recordID: TweakDBID) -> String {
    let i: Int32 = 0;
    while i < ArraySize(this.vehicleCategories) {
      if this.vehicleCategories[i].Matches(recordID) {
        return this.vehicleCategories[i].category;
      }
      i += 1;
    }
    return "";
  }

  // Only overwrites colors present in the file - a truncated/hand-edited
  // file can't wipe colors it omits.
  public func Load() -> Void {
    let storage: ref<FileSystemStorage> = ATH_StorageService.Get();
    if !IsDefined(storage) || !Equals(storage.Exists("colorData.json"), FileSystemStatus.True) {
      return;
    }
    let root: ref<JsonVariant> = storage.GetFile("colorData.json").ReadAsJson();
    if !IsDefined(root) || !root.IsObject() {
      ATHLogWarn("colorData.json exists but is not a JSON object, ignoring");
      return;
    }
    let obj: ref<JsonObject> = root as JsonObject;
    if !obj.HasKey("headlightColors") {
      return;
    }
    let arr: ref<JsonArray> = obj.GetKey("headlightColors") as JsonArray;
    if !IsDefined(arr) {
      ATHLogWarn("colorData.json 'headlightColors' is not a JSON array, ignoring");
      return;
    }
    let count: Int32 = Cast<Int32>(arr.GetSize());
    let applied: Int32 = 0;
    let i: Int32 = 0;
    while i < count {
      let entry: ref<JsonObject> = arr.GetItem(Cast<Uint32>(i)) as JsonObject;
      if IsDefined(entry) {
        let existing: ref<ATH_HeadlightColor> = this.GetColor(entry.GetKeyString("name"));
        if IsDefined(existing) {
          existing.red = Cast<Int32>(entry.GetKeyInt64("red"));
          existing.green = Cast<Int32>(entry.GetKeyInt64("green"));
          existing.blue = Cast<Int32>(entry.GetKeyInt64("blue"));
          existing.alpha = Cast<Int32>(entry.GetKeyInt64("alpha"));
          applied += 1;
        }
      }
      i += 1;
    }
    ATHLog(s"Loaded \(applied) headlight color overrides from colorData.json");
  }

  public func Save() -> Void {
    let storage: ref<FileSystemStorage> = ATH_StorageService.Get();
    if !IsDefined(storage) {
      return;
    }
    let root: ref<JsonObject> = new JsonObject();
    let colorsArr: ref<JsonArray> = new JsonArray();
    let i: Int32 = 0;
    while i < ArraySize(this.colors) {
      let c: ref<JsonObject> = new JsonObject();
      c.SetKeyString("name", this.colors[i].name);
      c.SetKeyInt64("red", Cast<Int64>(this.colors[i].red));
      c.SetKeyInt64("green", Cast<Int64>(this.colors[i].green));
      c.SetKeyInt64("blue", Cast<Int64>(this.colors[i].blue));
      c.SetKeyInt64("alpha", Cast<Int64>(this.colors[i].alpha));
      colorsArr.AddItem(c);
      i += 1;
    }
    root.SetKey("headlightColors", colorsArr);
    storage.GetFile("colorData.json").WriteJson(root, "  ");
  }

  public static func LoadOrDefault() -> ref<ATH_ColorData> {
    let d: ref<ATH_ColorData> = ATH_ColorData.Defaults();
    d.Load();
    return d;
  }

  public static func Defaults() -> ref<ATH_ColorData> {
    let d: ref<ATH_ColorData> = new ATH_ColorData();

    ArrayPush(d.colors, ATH_HeadlightColor.Create("warmWhite", 255, 250, 225, 50));
    ArrayPush(d.colors, ATH_HeadlightColor.Create("warmGreen", 235, 245, 200, 75));
    ArrayPush(d.colors, ATH_HeadlightColor.Create("economy", 245, 230, 180, 50));
    ArrayPush(d.colors, ATH_HeadlightColor.Create("halogen", 255, 230, 150, 50));
    ArrayPush(d.colors, ATH_HeadlightColor.Create("pureWhite", 255, 255, 255, 50));
    ArrayPush(d.colors, ATH_HeadlightColor.Create("modernGreen", 210, 255, 210, 100));
    ArrayPush(d.colors, ATH_HeadlightColor.Create("blueWhite", 235, 235, 255, 50));
    ArrayPush(d.colors, ATH_HeadlightColor.Create("sportPink", 255, 220, 220, 50));
    ArrayPush(d.colors, ATH_HeadlightColor.Create("sportPurple", 235, 210, 255, 50));
    ArrayPush(d.colors, ATH_HeadlightColor.Create("racingAmber", 250, 180, 60, 50));
    ArrayPush(d.colors, ATH_HeadlightColor.Create("modernBlue", 210, 210, 255, 100));

    ArrayPush(d.headlightCategories, ATH_CategoryColorNames.Create("poor", ["economy", "halogen", "warmWhite"]));
    ArrayPush(d.headlightCategories, ATH_CategoryColorNames.Create("common", ["warmWhite", "pureWhite", "halogen", "economy", "modernBlue"]));
    ArrayPush(d.headlightCategories, ATH_CategoryColorNames.Create("rare", ["warmGreen", "modernGreen", "blueWhite", "modernBlue", "sportPink"]));
    ArrayPush(d.headlightCategories, ATH_CategoryColorNames.Create("exotic", ["sportPink", "sportPurple", "racingAmber", "modernGreen", "blueWhite"]));
    ArrayPush(d.headlightCategories, ATH_CategoryColorNames.Create("badlands", ["racingAmber", "sportPurple", "modernBlue"]));

    ArrayPush(d.vehicleCategories, ATH_VehicleCategory.Create("poor", [
      "Vehicle.v_standard2_archer_hella_getto",
      "Vehicle.v_standard2_archer_hella_poor",
      "Vehicle.v_standard2_archer_hella_poor_dogtown",
      "Vehicle.v_standard2_archer_quartz_poor",
      "Vehicle.v_standard2_chevalier_thrax_poor",
      "Vehicle.v_standard2_makigai_maimai_poor",
      "Vehicle.v_standard2_makigai_maimai_poor_dogtown",
      "Vehicle.v_standard2_mizutani_hozuki_poor",
      "Vehicle.v_standard2_mizutani_hozuki_poor_dogtown",
      "Vehicle.v_standard2_thorton_colby_gt",
      "Vehicle.v_standard2_thorton_colby_poor",
      "Vehicle.v_standard2_thorton_galena_poor_dogtown",
      "Vehicle.v_standard2_thorton_galena_poor",
      "Vehicle.v_standard25_mahir_supron_poor",
      "Vehicle.v_standard25_mahir_supron_poor_dogtown",
      "Vehicle.v_standard2_villefort_cortes_poor",
      "Vehicle.v_standard25_thorton_colby_pickup_poor",
      "Vehicle.v_standard25_thorton_merrimac_poor",
      "Vehicle.v_standard25_villefort_columbus_poor",
      "Vehicle.v_standard3_makigai_tanishi_poor_dogtown",
      "Vehicle.v_standard3_makigai_tanishi_poor",
      "Vehicle.v_standard3_thorton_mackinaw_country_poor",
      "Vehicle.v_standard3_thorton_mackinaw_poor",
      "Vehicle.v_utility4_chevalier_centurion_poor",
      "Vehicle.v_utility4_chevalier_centurion_poor_dogtown",
      "Vehicle.v_utility4_chevalier_centurion_flatbed_poor",
      "Vehicle.v_utility4_chevalier_centurion_flatbed_poor_dogtown",
      "Vehicle.v_sport2_mizutani_shion_poor",
      "Vehicle.v_sport2_quadra_type66_poor",
      "Vehicle.v_sport2_villefort_alvarado_hearse_poor",
      "Vehicle.v_sport2_villefort_alvarado_poor",
      "Vehicle.v_sport1_quadra_sport_r7_poor",
      "Vehicle.v_sport1_quadra_turbo_poor",
      "Vehicle.v_sport2_villefort_deleon_poor",
      "Vehicle.v_utility4_kaukaz_zeya_barrels_dogtown",
      "Vehicle.v_utility4_kaukaz_zeya_container_dogtown",
      "Vehicle.v_utility4_kaukaz_zeya_full_dogtown",
      "Vehicle.v_utility4_kaukaz_bratsk_container_dogtown_ow",
      "Vehicle.v_utility4_kaukaz_bratsk_dogtown",
      "Vehicle.ma_wat_lch_03_garbage_truck"
    ]));

    ArrayPush(d.vehicleCategories, ATH_VehicleCategory.Create("common", [
      "Vehicle.v_standard2_archer_bandit",
      "Vehicle.v_standard2_archer_hella",
      "Vehicle.v_standard2_archer_hella_scavengers",
      "Vehicle.v_standard2_archer_hella_sixth_street",
      "Vehicle.v_standard2_archer_quartz_nomad",
      "Vehicle.v_standard2_archer_quartz",
      "Vehicle.v_standard2_archer_quartz_gt",
      "Vehicle.v_standard2_archer_quartz_tyger",
      "Vehicle.v_standard2_chevalier_thrax",
      "Vehicle.v_standard2_chevalier_thrax_maelstrom",
      "Vehicle.v_standard2_chevalier_thrax_premium",
      "Vehicle.v_standard2_chevalier_thrax_scavengers",
      "Vehicle.v_standard2_chevalier_thrax_sixth_street",
      "Vehicle.v_standard2_chevalier_thrax_valentinos",
      "Vehicle.v_standard2_makigai_maimai",
      "Vehicle.v_standard2_makigai_maimai_gt",
      "Vehicle.v_standard2_makigai_maimai_premium",
      "Vehicle.v_standard2_mizutani_hozuki",
      "Vehicle.v_standard2_mizutani_hozuki_premium",
      "Vehicle.v_standard2_mizutani_hozuki_sport",
      "Vehicle.v_standard2_thorton_colby",
      "Vehicle.v_standard2_thorton_colby_scavengers",
      "Vehicle.v_standard2_thorton_colby_valentinos",
      "Vehicle.v_standard2_thorton_galena",
      "Vehicle.v_standard2_thorton_galena_maelstrom",
      "Vehicle.v_standard2_thorton_galena_gt",
      "Vehicle.v_standard2_thorton_galena_nomad",
      "Vehicle.v_standard2_thorton_galena_voodoo_boys",
      "Vehicle.v_standard2_villefort_cortes",
      "Vehicle.v_standard2_villefort_cortes_kangtao",
      "Vehicle.v_standard2_villefort_cortes_premium",
      "Vehicle.v_standard2_villefort_cortes_arasaka",
      "Vehicle.v_standard25_mahir_supron",
      "Vehicle.v_standard25_mahir_supron_sport",
      "Vehicle.v_standard25_mahir_voodoo_boys",
      "Vehicle.v_standard25_thorton_colby_nomad",
      "Vehicle.v_standard25_thorton_colby_nomad_vulture",
      "Vehicle.v_standard25_thorton_colby_nomad_wraith",
      "Vehicle.v_standard25_thorton_colby_pickup",
      "Vehicle.v_standard25_thorton_merrimac",
      "Vehicle.v_standard25_thorton_merrimac_premium",
      "Vehicle.v_standard25_villefort_columbus",
      "Vehicle.v_standard25_villefort_columbus_corpo",
      "Vehicle.v_standard25_villefort_columbus_arasaka",
      "Vehicle.v_standard25_villefort_columbus_kangtao",
      "Vehicle.v_standard25_villefort_columbus_scavengers",
      "Vehicle.v_standard25_villefort_columbus_sixth_street",
      "Vehicle.v_standard25_villefort_columbus_tyger",
      "Vehicle.v_standard3_chevalier_emperor",
      "Vehicle.v_standard3_chevalier_emperor_sport",
      "Vehicle.v_standard3_mahir_supron_kurtz",
      "Vehicle.v_standard3_makigai_tanishi",
      "Vehicle.v_standard3_makigai_tanishi_hfs",
      "Vehicle.v_standard3_makigai_tanishi_premium",
      "Vehicle.v_standard3_thorton_mackinaw",
      "Vehicle.v_standard3_thorton_mackinaw_nomad",
      "Vehicle.v_standard3_thorton_mackinaw_country",
      "Vehicle.v_standard3_thorton_mackinaw_country_premium",
      "Vehicle.v_standard3_thorton_mackinaw_premium",
      "Vehicle.v_standard3_thorton_mackinaw_sixth_street",
      "Vehicle.v_standard3_thorton_mackinaw_valentinos",
      "Vehicle.v_utility4_chevalier_centurion",
      "Vehicle.v_utility4_chevalier_centurion_cargo",
      "Vehicle.v_utility4_chevalier_centurion_cargo_dogtown",
      "Vehicle.v_utility4_chevalier_centurion_flatbed",
      "Vehicle.v_utility4_kaukaz_bratsk_extended",
      "Vehicle.v_utility4_kaukaz_bratsk",
      "Vehicle.v_utility4_kaukaz_bratsk_machine",
      "Vehicle.v_utility4_kaukaz_bratsk_machine_dogtown",
      "Vehicle.v_utility4_kaukaz_bratsk_concrete",
      "Vehicle.v_utility4_kaukaz_bratsk_container",
      "Vehicle.v_utility4_kaukaz_bratsk_container_dogtown",
      "Vehicle.v_utility4_kaukaz_zeya",
      "Vehicle.v_utility4_kaukaz_zeya_freight",
      "Vehicle.v_utility4_kaukaz_zeya_full",
      "Vehicle.v_mahir_mt28_coach",
      "Vehicle.v_utility4_militech_behemoth",
      "Vehicle.v_standard3_militech_hellhound",
      "Vehicle.v_utility4_kaukaz_zeya_barrels",
      "Vehicle.v_utility4_kaukaz_zeya_container",
      "Vehicle.v_utility4_kaukaz_zeya_full_courier",
      "Vehicle.v_utility4_kaukaz_zeya_full_courier_expanded",
      "Vehicle.v_utility4_kaukaz_bratsk_dumpster",
      "Vehicle.v_standard2_archer_hella_combat_cab",
      "Vehicle.v_standard2_archer_quartz_mox",
      "Vehicle.v_standard2_chevalier_thrax_combat_cab",
      "Vehicle.v_standard25_mahir_mox",
      "Vehicle.v_standard25_thorton_colby_pickup_kurtz_cd",
      "Vehicle.v_standard25_thorton_merrimac_pickup",
      "Vehicle.v_standard3_makigai_tanishi_kuma"
    ]));

    ArrayPush(d.vehicleCategories, ATH_VehicleCategory.Create("rare", [
      "Vehicle.v_sport2_mizutani_shion",
      "Vehicle.v_sport2_mizutani_shion_sport",
      "Vehicle.v_sport2_quadra_type66",
      "Vehicle.v_sport2_quadra_type66_sport",
      "Vehicle.v_sport2_quadra_type66_avenger",
      "Vehicle.v_sport2_villefort_alvarado",
      "Vehicle.v_sport2_villefort_alvarado_cabrio",
      "Vehicle.v_sport2_villefort_alvarado_hearse",
      "Vehicle.v_sport2_villefort_alvarado_hearse_premium",
      "Vehicle.v_sport2_villefort_alvarado_premium",
      "Vehicle.v_sport2_villefort_alvarado_valentinos",
      "Vehicle.v_sport2_villefort_alvarado_valentinos_cabrio",
      "Vehicle.v_sport1_herrera_outlaw_heist",
      "Vehicle.v_sport1_herrera_riptide_terrier",
      "Vehicle.v_sport1_quadra_sport_r7_rocket",
      "Vehicle.v_sport2_mizutani_shion_tyger",
      "Vehicle.v_sport2_villefort_alvarado_mox",
      "Vehicle.v_standard2_mizutani_hozuki_sti"
    ]));

    ArrayPush(d.vehicleCategories, ATH_VehicleCategory.Create("exotic", [
      "Vehicle.v_sport1_herrera_outlaw",
      "Vehicle.v_sport1_herrera_riptide",
      "Vehicle.v_sport1_herrera_riptide_premium",
      "Vehicle.v_sport1_quadra_sport_r7",
      "Vehicle.v_sport1_quadra_sport_r7_gt",
      "Vehicle.v_sport1_quadra_sport_r7_premium",
      "Vehicle.v_sport1_quadra_turbo",
      "Vehicle.v_sport1_quadra_turbo_r",
      "Vehicle.v_sport1_quadra_turbo_tyger_claw",
      "Vehicle.v_sport2_villefort_deleon",
      "Vehicle.v_sport2_villefort_deleon_sport",
      "Vehicle.v_sport1_rayfield_aerondight",
      "Vehicle.v_sport1_rayfield_caliburn"
    ]));

    ArrayPush(d.vehicleCategories, ATH_VehicleCategory.Create("badlands", [
      "Vehicle.v_sport2_mizutani_shion_nomad_wraith",
      "Vehicle.v_sport2_mizutani_shion_nomad",
      "Vehicle.v_sport2_quadra_type66_nomad_wraith",
      "Vehicle.v_sport2_quadra_type66_nomad",
      "Vehicle.v_standard2_archer_quartz_nomad_wraith",
      "Vehicle.v_standard2_archer_quartz_nomad",
      "Vehicle.v_standard2_thorton_galena_nomad_scorpion",
      "Vehicle.v_standard2_thorton_galena_nomad_wraith",
      "Vehicle.v_standard2_thorton_galena_nomad",
      "Vehicle.v_standard25_thorton_colby_nomad_vulture",
      "Vehicle.v_standard25_thorton_colby_nomad_wraith",
      "Vehicle.v_standard25_thorton_colby_nomad",
      "Vehicle.v_standard3_thorton_mackinaw_nomad"
    ]));

    return d;
  }
}
