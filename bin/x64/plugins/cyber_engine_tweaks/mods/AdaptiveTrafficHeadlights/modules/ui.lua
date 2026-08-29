local Settings = require("modules/settings")
local Theme = require("modules/theme")

local UI = {}

-- --- helpers ---------------------------------------------------------------

local function getWindowFlags()
	if S.settings.autoResize and S.settings.lockWindow then
		return ImGuiWindowFlags.AlwaysAutoResize + ImGuiWindowFlags.NoMove
	elseif S.settings.autoResize then
		return ImGuiWindowFlags.AlwaysAutoResize
	elseif S.settings.lockWindow then
		return ImGuiWindowFlags.NoMove
	end
	return ImGuiWindowFlags.None
end

function SliderFloatStepped(label, v, v_min, v_max, v_step, display_format)
	if not display_format then
		display_format = "%.1f"
	end

	-- Format the current value for display
	local text_buf = string.format(display_format, v)

	-- Map from [v_min,v_max] to [0,N]
	local countValues = math.floor((v_max - v_min) / v_step)
	local v_i = math.floor((v - v_min) / v_step)

	-- Use SliderInt with custom display text
	local new_v_i, value_changed = ImGui.SliderInt(label, v_i, 0, countValues, text_buf)

	-- Remap from [0,N] to [v_min,v_max]
	local new_v = v_min + (new_v_i * v_step)

	return new_v, value_changed
end

-- --- header ----------------------------------------------------------------

function UI.drawHeader()
	local noDataLabel = "unavailable"

	ImGui.Text("Weather: ")
	ImGui.SameLine()
	if S.gotWeatherStates then
		ImGui.Text(tostring(S.state))
	else
		ImGui.Text(noDataLabel)
	end

	ImGui.Text("Hour: ")
	ImGui.SameLine()
	if S.gotWeatherStates then
		ImGui.Text(tostring(S.hours))
	else
		ImGui.Text(noDataLabel)
	end

	ImGui.Spacing()
	ImGui.Separator()
	ImGui.Spacing()
	ImGui.Spacing()
	ImGui.Spacing()
end

-- --- tabs ------------------------------------------------------------------

function UI.drawMainTab()
	local changed = false
	ImGui.Spacing()

	S.settings.useNaturalMode, changed =
		ImGui.Checkbox("Use Natural Mode", S.settings.useNaturalMode)

	if ImGui.IsItemHovered() then
		ImGui.SetTooltip(
			"Enables realistic lighting behavior: vehicles anticipate transitions and respond gradually, while street lights delay after weather changes")
	end
	if changed then Settings.SaveSettings() end
	ImGui.Spacing()

	S.settings.enableStreetLightControl, changed =
		ImGui.Checkbox("Enable street light control", S.settings.enableStreetLightControl)
	if changed then Settings.SaveSettings() end
	ImGui.Spacing()

	ImGui.Text("Headlights 'Off' brightness (1.0 = full on)")
	S.settings.lightsOffBrightnessMultiplier, changed =
		ImGui.SliderFloat("##lightsOffBrightnessMultiplier", S.settings.lightsOffBrightnessMultiplier, 0.0,
			1.0)
	if changed then Settings.SaveSettings() end
	ImGui.Spacing()

	S.settings.turnOffBrakeLights, changed =
		ImGui.Checkbox("Turn off brake lights", S.settings.turnOffBrakeLights)
	if changed then Settings.SaveSettings() end
	ImGui.Spacing()

	S.settings.turnOffBlinkers, changed =
		ImGui.Checkbox("Turn off blinkers", S.settings.turnOffBlinkers)
	if changed then Settings.SaveSettings() end
	ImGui.Spacing()

	S.settings.turnOffUtilityLights, changed =
		ImGui.Checkbox("Turn off utility lights (neons, rims, etc)", S.settings.turnOffUtilityLights)
	if changed then Settings.SaveSettings() end

	ImGui.Spacing()
	ImGui.Separator()
	ImGui.Spacing()

	S.settings.adjustAllWeatherStates, changed =
		ImGui.Checkbox("Use same times for all weather states", S.settings.adjustAllWeatherStates)
	if changed then Settings.SaveSettings() end

	ImGui.Spacing()

	if S.settings.adjustAllWeatherStates then
		ImGui.Text("Note: These sliders do not overwrite saved times per state.")
		ImGui.Spacing()

		ImGui.Text("All States Turn Off Time")
		S.settings.allOffTime, changed = SliderFloatStepped("##allOffTime", S.settings.allOffTime, 5, 12, 0.5)
		if changed then Settings.SaveSettings() end

		ImGui.Spacing()

		ImGui.Text("All States Turn On Time")
		S.settings.allOnTime, changed = SliderFloatStepped("##allOnTime", S.settings.allOnTime, 12, 20, 0.5)
		if changed then Settings.SaveSettings() end

		ImGui.Spacing()
	end

	UI.drawWeatherStatesList()
end

function UI.drawOtherSettingsTab()
	local changed = false

	ImGui.Spacing()

	S.settings.lockWindow, changed = ImGui.Checkbox("Lock Window Position", S.settings.lockWindow)
	if changed then Settings.SaveSettings() end

	ImGui.Spacing()

	S.settings.autoResize, changed = ImGui.Checkbox("Always Auto Resize Window", S.settings.autoResize)
	if changed then Settings.SaveSettings() end

	ImGui.Spacing()

	S.settings.themeDisabled, changed = ImGui.Checkbox("Disable Window Theme", S.settings.themeDisabled)
	if changed then Settings.SaveSettings() end
end

function UI.drawWeatherStatesList()
	ImGui.Separator()
	ImGui.Spacing()
	if not S.gotWeatherStates then
		ImGui.Text("Please load or reload a save to see all menu options.")
		return
	end
	ImGui.Text("Weather states")
	ImGui.Spacing()
	-- fixed-height scrollable area (tweak height as needed)
	if ImGui.BeginChild("WeatherStatesList", 0, -1, true) then
		for _, state in ipairs(S.weatherStates) do
			if state.name then
				local isCurrent = (S.state == state.name)

				ImGui.PushID("ws_" .. state.name)
				local treeNodeFlags = ImGuiTreeNodeFlags.Framed
				if isCurrent then
					Theme.PushStyleColor(ImGuiCol.Header, Theme.Colors.accentTeal)
					treeNodeFlags = ImGuiTreeNodeFlags.Selected + ImGuiTreeNodeFlags.Framed
				end

				ImGui.Spacing()
				if ImGui.TreeNodeEx(state.name, treeNodeFlags) then
					local changed = false
					ImGui.Spacing()
					ImGui.Text("Off Time")
					state.turnOffTime, changed = SliderFloatStepped("##off" .. state.name, state.turnOffTime, 5, 12, 0.5)
					if changed then Settings.SaveWeatherStates() end

					ImGui.Spacing()
					ImGui.Text("On Time")
					state.turnOnTime, changed = SliderFloatStepped("##on" .. state.name, state.turnOnTime, 12, 20, 0.5)
					if changed then Settings.SaveWeatherStates() end

					ImGui.Spacing()
					ImGui.Separator()
					ImGui.TreePop()
				end

				if isCurrent then
					Theme.PopStyleColor(1)
				end

				ImGui.PopID()
			end
		end
	end
	ImGui.EndChild()
end

function UI.drawHeadlightsTab()
	ImGui.Spacing()

	if ImGui.BeginTable("ColorTable", 3, ImGuiTableFlags.Borders + ImGuiTableFlags.Resizable) then
		ImGui.TableSetupColumn("Color", ImGuiTableColumnFlags.WidthFixed, 200)
		ImGui.TableSetupColumn("Name", ImGuiTableColumnFlags.WidthStretch)
		ImGui.TableSetupColumn("Category", ImGuiTableColumnFlags.WidthStretch)
		ImGui.TableHeadersRow()

		for name, color in pairs(S.headlightColors) do
			local changed = false
			ImGui.TableNextRow()

			-- Color column
			ImGui.TableNextColumn()
			ImGui.Spacing()
			local rgba = {
				color.Red / 255,
				color.Green / 255,
				color.Blue / 255,
				color.Alpha / 255
			}

			rgba, changed = ImGui.ColorEdit4("##" .. name, rgba, ImGuiColorEditFlags.NoInputs)
			if changed then
				color.Red = math.floor(rgba[1] * 255)
				color.Green = math.floor(rgba[2] * 255)
				color.Blue = math.floor(rgba[3] * 255)
				color.Alpha = math.floor(rgba[4] * 255)
				Settings.SaveHeadlightsAndVehicles()
				if S.cetLightOverrideName == name then
					S.cetLightOverrideColor = color
				end
			end

			-- Name column
			ImGui.Spacing()
			ImGui.TableNextColumn()
			ImGui.Spacing()

			ImGui.Text(name)

			ImGui.Spacing()
			ImGui.TableNextColumn()
			ImGui.Spacing()

			local isChecked = S.cetLightOverrideName == name
			local checkboxChanged = false

			isChecked, checkboxChanged = ImGui.Checkbox("Preview##" .. name, isChecked)

			if ImGui.IsItemHovered() then
				ImGui.SetTooltip("Will apply only this color to all new vehicles, for preview purposes")
			end

			-- Handle checkbox state change
			if checkboxChanged then
				if isChecked then
					-- This checkbox was just checked - set it as the active one
					S.cetLightOverrideColor = color
					S.cetLightOverrideName = name
				else
					-- This checkbox was just unchecked
					S.cetLightOverrideColor = nil
					S.cetLightOverrideName = nil
				end
			end

			ImGui.Spacing()
		end

		ImGui.EndTable()
	end
end

function UI.drawErrors()
	local errorWidth = ImGui.GetWindowContentRegionWidth()
	Theme.PushDanger()
	ImGui.Button(IconGlyphs.Alert .. " System Requirements Not Met", errorWidth, 36)
	Theme.PopDanger()
	ImGui.Separator()
	ImGui.Spacing()

	ImGui.Text("AdaptiveTrafficHeadlights cannot start due to:")
	ImGui.Spacing()

	for _, errorMsg in ipairs(S.errors) do
		ImGui.Indent(16)
		ImGui.Text(IconGlyphs.PackageVariantClosedRemove .. " " .. errorMsg)
		ImGui.Unindent(16)
	end

	ImGui.Spacing()
	ImGui.Separator()
	ImGui.TextWrapped("Either required mods missing, or something very wrong :(")
end

-- --- main window -----------------------------------------------------------

function UI.DrawMainWindow()
	if not S.settings.themeDisabled then
		Theme.ApplyTheme()
	end
	local sizeX, sizeY = GetDisplayResolution()
	ImGui.SetNextWindowSizeConstraints(500, 600, RoundFEx(sizeX * 0.75), RoundFEx(sizeY * 0.75))

	if ImGui.Begin("Adaptive Traffic Headlights", true, getWindowFlags()) then
		ImGui.Spacing()
		if not S.gotWeatherStates and #S.errors == 0 then
			ImGui.Text("Please load or reload a save to see all menu options.")
		elseif #S.errors > 0 then
			UI.drawErrors()
		else
			UI.drawHeader()

			if ImGui.BeginTabBar("ATHTabs") then
				if ImGui.BeginTabItem("Main") then
					UI.drawMainTab()
					ImGui.EndTabItem()
				end
				if ImGui.BeginTabItem("Headlights") then
					UI.drawHeadlightsTab()
					ImGui.EndTabItem()
				end
				if ImGui.BeginTabItem("Other") then
					UI.drawOtherSettingsTab()
					ImGui.EndTabItem()
				end
				ImGui.EndTabBar()
			end
		end

		ImGui.End()
		if not S.settings.themeDisabled then
			Theme.RemoveThemeAndVars()
		end
	end
end

return UI
