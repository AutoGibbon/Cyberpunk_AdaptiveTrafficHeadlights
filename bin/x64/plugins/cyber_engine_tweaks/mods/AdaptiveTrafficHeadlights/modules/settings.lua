local Settings = {
}

function Settings.defaultSettings()
	return {
		adjustAllWeatherStates = false,
		allOnTime = 17,
		allOffTime = 7,
		autoResize = false,
		lockWindow = false,
		themeDisabled = false,
		lightsOffBrightnessMultiplier = 0,
		turnOffBlinkers = true,
		turnOffBrakeLights = true,
		turnOffUtilityLights = true,
		useNaturalMode = true,
		enableStreetLightControl = true
	}
end

function Settings.defaultHeadlightColors()
	return {
		warmWhite = { Alpha = 50, Red = 255, Green = 250, Blue = 225 },
		warmGreen = { Alpha = 75, Red = 235, Green = 245, Blue = 200 },
		economy = { Alpha = 50, Red = 245, Green = 230, Blue = 180 },
		halogen = { Alpha = 50, Red = 255, Green = 230, Blue = 150 },
		pureWhite = { Alpha = 50, Red = 255, Green = 255, Blue = 255 },
		modernGreen = { Alpha = 100, Red = 210, Green = 255, Blue = 210 },
		blueWhite = { Alpha = 50, Red = 235, Green = 235, Blue = 255 },
		sportPink = { Alpha = 50, Red = 255, Green = 220, Blue = 220 },
		sportPurple = { Alpha = 50, Red = 235, Green = 210, Blue = 255 },
		racingAmber = { Alpha = 50, Red = 250, Green = 180, Blue = 60 },
		modernBlue = { Alpha = 100, Red = 210, Green = 210, Blue = 255 }
	}
end

function Settings.defaultHeadlightCategories()
	return {
		poor = { "economy", "halogen", "warmWhite" },
		common = { "warmWhite", "pureWhite", "halogen", "economy", "modernBlue" },
		rare = { "warmGreen", "modernGreen", "blueWhite", "modernBlue", "sportPink" },
		exotic = { "sportPink", "sportPurple", "racingAmber", "modernGreen", "blueWhite" },
		badlands = { "racingAmber", "sportPurple", "modernBlue" }
	}
end

function Settings.defaultVehicleCategories()
	return {
		poor = { "Vehicle.v_standard2_archer_hella_getto",
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
			"Vehicle.ma_wat_lch_03_garbage_truck" },
		common = { "Vehicle.v_standard2_archer_bandit",
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
			"Vehicle.v_standard3_makigai_tanishi_kuma" },
		rare = { "Vehicle.v_sport2_mizutani_shion",
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
			"Vehicle.v_standard2_mizutani_hozuki_sti" },
		exotic = { "Vehicle.v_sport1_herrera_outlaw",
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
			"Vehicle.v_sport1_rayfield_caliburn" },
		badlands = { "Vehicle.v_sport2_mizutani_shion_nomad_wraith",
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
			"Vehicle.v_standard3_thorton_mackinaw_nomad" }
	}
end

function Settings.SaveSettings()
	local file = io.open('modsettings.json', 'w')
	if file then
		file:write(json.encode(S.settings))
		file:close()
	end
end

function Settings.LoadSettings()
	local file = io.open('modsettings.json', 'r')
	if file then
		local content = file:read('*all')
		file:close()
		S.settings = json.decode(content)
		local addedNew = false
		if S.settings.lightsOffBrightnessMultiplier == nil and S.settings.dayTimeLightMultiplier ~= nil then
			addedNew = true
			S.settings.lightsOffBrightnessMultiplier = S.settings.dayTimeLightMultiplier
			S.settings.dayTimeLightMultiplier = nil
		end

		if S.settings.useNaturalMode == nil then
			addedNew = true
			S.settings.useNaturalMode = true
		end
		if S.settings.enableStreetLightControl == nil then
			addedNew = true
			S.settings.enableStreetLightControl = true
		end

		if addedNew then
			Settings.SaveSettings()
		end
	else
		return
	end
end

function Settings.SaveWeatherStates()
	local file = io.open('weatherStateSettings.json', 'w')
	if file then
		file:write(json.encode(S.weatherStates))
		file:close()
	end
end

function Settings.LoadWeatherStates()
	local file = io.open('weatherStateSettings.json', 'r')
	if file then
		local content = file:read('*all')
		file:close()
		S.weatherStates = json.decode(content)
	else
		return
	end
end

function Settings.LoadHeadlightsAndVehicles()
	local file = io.open('vehicleSettings.json', 'r')
	if file then
		local content = file:read('*all')
		file:close()
		local data = json.decode(content)
		if data.headlightColors ~= nil then
			S.headlightColors = data.headlightColors
		end
		if data.headlightCategories ~= nil then
			S.headlightCategories = data.headlightCategories
		end
		if data.vehicleCategories ~= nil then
			S.vehicleCategories = data.vehicleCategories
		end
	else
		return
	end
end

function Settings.SaveHeadlightsAndVehicles()
	local data = {
		headlightColors = S.headlightColors,
		headlightCategories = S.headlightCategories,
		vehicleCategories = S.vehicleCategories
	}

	local file = io.open('vehicleSettings.json', 'w')
	if file then
		file:write(json.encode(data))
		file:close()
	end
end

return Settings
